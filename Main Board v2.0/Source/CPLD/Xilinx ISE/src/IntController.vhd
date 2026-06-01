library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =============================================================================
-- Interrupt Controller
--
-- Implements a prioritised interrupt controller for the Z80 IM2 interrupt
-- mode, managing the system interrupt bus (SYSINT) and 8 expansion-bus IRQs.
--
-- Priority (highest → lowest):
--   SYSINT level 1 .. SYSINT level 7  (MCU-sourced, encoded on 3-bit bus)
--   BIRQ0 .. BIRQ7                     (expansion bus, BIRQ0 = highest)
--
-- SYSINT bus encoding:
--   0b000 = no interrupt; 0b001..0b111 = level 1 (highest) .. level 7 (lowest)
--   The MCU resolves priority among its own sources and presents only the
--   highest pending level on the bus.  The CPLD does not arbitrate within
--   SYSINT; any non-zero value beats all BIRQ lines.
--   SYSINTACK pulses high during the Z80 INTACK cycle when a SYSINT was the
--   winning source, signalling the MCU to de-assert the bus.
--
-- Z80 IM2 interrupt cycle:
--   1. SYSINT != 0 or any BIRQ high → CPU_INT_N asserted low.
--   2. Z80 finishes its current instruction and starts an interrupt-ack bus
--      cycle: M1_N='0' and IORQ_N='0' simultaneously.
--   3. This module places a vector byte on D, asserts BINTACK for the winning
--      BIRQ slot (if applicable), and drives BIACK_N low.
--   4. The Z80 uses (I << 8 | vector) as the ISR pointer address.
--
-- Vector map (word-aligned, 2 bytes per entry; base 0x40 places all vectors
--   in the free gap between RST $38 and NMI, avoiding RST slot conflicts):
--   SYSINT 1 → 0x40,  SYSINT 2 → 0x42,  SYSINT 3 → 0x44,  SYSINT 4 → 0x46
--   SYSINT 5 → 0x48,  SYSINT 6 → 0x4A,  SYSINT 7 → 0x4C
--   BIRQ0   → 0x4E,   BIRQ1   → 0x50,   BIRQ2   → 0x52,   BIRQ3   → 0x54
--   BIRQ4   → 0x56,   BIRQ5   → 0x58,   BIRQ6   → 0x5A,   BIRQ7   → 0x5C
--
-- DMA / bus-request arbitration:
--   A card requests the bus by asserting its BIRQ line AND pulling the
--   shared BBUSRQ_N line low simultaneously.  The same priority encoder
--   used for interrupts selects the winning card (BIRQ0 = highest).
--   SYSINT sources cannot request the bus.
--
--   When a bus request is detected the CPLD asserts CPU_BUSRQ_N to the Z80.
--   Once the Z80 releases its bus (CPU_BUSACK_N low) the winning card's
--   BINTACK line goes high as a bus-grant signal, allowing the card to drive
--   the bus for DMA.  When the card is done it deasserts both its BIRQ line
--   and BBUSRQ_N; the CPLD then deasserts CPU_BUSRQ_N and the Z80 reclaims
--   the bus.
--
--   BINTACK is reused as the bus-grant signal.  The two uses are mutually
--   exclusive: the Z80 cannot run an INTACK cycle while its bus is floating.
-- =============================================================================

entity IntController is
    port (
        CLK20       : in  std_logic;
        CPU_RST_N   : in  std_logic;

        -- System interrupt bus (from MCU); 0 = idle, 1..7 = interrupt level.
        -- Level 1 is highest priority; all levels beat any BIRQ line.
        SYSINT      : in  std_logic_vector(2 downto 0);

        -- Acknowledge to MCU: pulses high during INTACK when SYSINT won
        SYSINTACK   : out std_logic;

        -- Expansion bus IRQ inputs (active-high, wired-OR from cards)
        BIRQ        : in  std_logic_vector(7 downto 0);

        -- Z80 interrupt-ack cycle: M1_N='0' and IORQ_N='0' simultaneously
        CPU_IORQ_N  : in  std_logic;
        CPU_M1_N    : in  std_logic;

        -- CPU interrupt request (active-low)
        CPU_INT_N   : out std_logic;

        -- Expansion bus: per-slot interrupt acknowledge (one-hot, active-high)
        BINTACK     : out std_logic_vector(7 downto 0);

        -- Expansion bus: global interrupt enable (active-high)
        BINTEN      : out std_logic;

        -- Expansion bus: global interrupt acknowledge (active-low)
        BIACK_N     : out std_logic;

        -- Expansion bus: bus request from cards (wired-OR, active-low)
        BBUSRQ_N    : in  std_logic;

        -- Z80 bus acknowledge: Z80 has floated its bus (active-low)
        CPU_BUSACK_N : in  std_logic;

        -- Bus request to Z80: asserted when a card wins DMA arbitration
        CPU_BUSRQ_N : out std_logic;

        -- Data bus: IM2 vector byte driven during Z80 INTACK cycle
        D_OUT       : out std_logic_vector(7 downto 0);
        D_OE        : out std_logic
    );
end entity IntController;

-- =============================================================================
architecture rtl of IntController is

    -- -------------------------------------------------------------------------
    -- Combined priority index:
    --   0..6  → SYSINT level 1..7  (vector = 0x40 + index*2 → 0x40..0x4C)
    --   7..14 → BIRQ0..7           (vector = 0x40 + index*2 → 0x4E..0x5C)
    -- -------------------------------------------------------------------------
    -- Interrupt arbitration
    signal irq_any    : std_logic;
    signal irq_winner : integer range 0 to 14;

    signal irq_pending : std_logic;
    signal irq_latched : integer range 0 to 14;

    signal intack_cycle : std_logic;
    signal irq_vector   : std_logic_vector(7 downto 0);

    -- DMA bus-request arbitration (BIRQ only, no SYSINT)
    signal busrq_any    : std_logic;
    signal busrq_winner : integer range 0 to 7;
    signal busrq_pending : std_logic;
    signal busrq_latched : integer range 0 to 7;
    signal bus_granted   : std_logic;   -- BUSRQ pending AND Z80 BUSACK received

begin

    -- -------------------------------------------------------------------------
    -- Priority encoder (combinational)
    --
    -- BIRQ is checked first (lowest priority group); SYSINT overrides last
    -- (highest priority group).  Within BIRQ: lower index wins (last-write
    -- wins in the loop).  Within SYSINT: MCU presents only one level at a
    -- time so no further arbitration is needed here.
    -- -------------------------------------------------------------------------
    process(SYSINT, BIRQ)
        variable sys_lvl : integer range 0 to 7;
    begin
        irq_any    <= '0';
        irq_winner <= 0;
        sys_lvl    := to_integer(unsigned(SYSINT));

        -- Check BIRQ (indices 7..14); lower BIRQ index wins
        for i in 7 downto 0 loop
            if BIRQ(i) = '1' then
                irq_any    <= '1';
                irq_winner <= 7 + i;
            end if;
        end loop;

        -- SYSINT overrides any BIRQ (indices 0..6)
        if sys_lvl /= 0 then
            irq_any    <= '1';
            irq_winner <= sys_lvl - 1;  -- level 1→0, level 7→6
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Bus-request priority encoder (combinational, BIRQ only)
    -- Only active when BBUSRQ_N is asserted; lower BIRQ index wins.
    -- -------------------------------------------------------------------------
    process(BBUSRQ_N, BIRQ)
    begin
        busrq_any    <= '0';
        busrq_winner <= 0;
        if BBUSRQ_N = '0' then
            for i in 7 downto 0 loop
                if BIRQ(i) = '1' then
                    busrq_any    <= '1';
                    busrq_winner <= i;
                end if;
            end loop;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Bus-request state machine
    -- Latch the winner on the first cycle BBUSRQ_N is seen low.
    -- Release when BBUSRQ_N deasserts (card is done with the bus).
    -- -------------------------------------------------------------------------
    process(CLK20, CPU_RST_N)
    begin
        if CPU_RST_N = '0' then
            busrq_pending <= '0';
            busrq_latched <= 0;
        elsif rising_edge(CLK20) then
            if BBUSRQ_N = '1' then
                busrq_pending <= '0';
            elsif busrq_pending = '0' and busrq_any = '1' then
                busrq_pending <= '1';
                busrq_latched <= busrq_winner;
            end if;
        end if;
    end process;

    -- Z80 has released its bus once it drives BUSACK_N low
    bus_granted  <= busrq_pending and (not CPU_BUSACK_N);
    CPU_BUSRQ_N  <= not busrq_pending;

    -- -------------------------------------------------------------------------
    -- INTACK cycle detection
    -- Z80 asserts M1_N and IORQ_N together; distinct from a normal IO cycle
    -- where M1_N remains high.
    -- -------------------------------------------------------------------------
    intack_cycle <= '1' when CPU_M1_N = '0' and CPU_IORQ_N = '0' else '0';

    -- -------------------------------------------------------------------------
    -- Pending / latch register
    -- -------------------------------------------------------------------------
    process(CLK20, CPU_RST_N)
    begin
        if CPU_RST_N = '0' then
            irq_pending <= '0';
            irq_latched <= 0;
        elsif rising_edge(CLK20) then
            if intack_cycle = '1' then
                irq_pending <= '0';
            elsif irq_any = '1' and irq_pending = '0' then
                irq_pending <= '1';
                irq_latched <= irq_winner;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- CPU_INT_N
    -- -------------------------------------------------------------------------
    CPU_INT_N <= '0' when irq_pending = '1' else '1';

    -- -------------------------------------------------------------------------
    -- BINTEN: assert while an unacknowledged interrupt is pending
    -- -------------------------------------------------------------------------
    BINTEN <= irq_pending;

    -- -------------------------------------------------------------------------
    -- BINTACK: one-hot, used for both interrupt ACK and bus grant.
    -- The two are mutually exclusive: INTACK only occurs while the Z80 owns
    -- its bus; bus grant only occurs after the Z80 has floated its bus.
    -- -------------------------------------------------------------------------
    process(intack_cycle, irq_latched, bus_granted, busrq_latched)
        variable v : std_logic_vector(7 downto 0);
    begin
        v := (others => '0');
        -- Interrupt acknowledge (BIRQ sources only)
        if intack_cycle = '1' and irq_latched >= 7 then
            v(irq_latched - 7) := '1';
        end if;
        -- Bus grant (card may now drive the bus)
        if bus_granted = '1' then
            v(busrq_latched) := '1';
        end if;
        BINTACK <= v;
    end process;

    -- -------------------------------------------------------------------------
    -- BIACK_N: assert (low) during INTACK cycle
    -- -------------------------------------------------------------------------
    BIACK_N <= not intack_cycle;

    -- -------------------------------------------------------------------------
    -- SYSINTACK: pulse high during INTACK when a SYSINT source won
    -- -------------------------------------------------------------------------
    SYSINTACK <= '1' when intack_cycle = '1' and irq_latched < 7 else '0';

    -- -------------------------------------------------------------------------
    -- IM2 vector byte: 0x40 + index * 2
    -- Base offset 0x40 places all vectors in the free gap above RST $38.
    -- -------------------------------------------------------------------------
    irq_vector <= std_logic_vector(to_unsigned(16#40# + irq_latched * 2, 8));

    D_OUT <= irq_vector when intack_cycle = '1' else (others => '0');
    D_OE  <= intack_cycle;

end architecture rtl;

-- =============================================================================
-- Null implementation for test builds.
--
-- This architecture intentionally does nothing and keeps all outputs inactive.
-- Use from top-level with:
--   entity work.IntController(rtl_null)
-- =============================================================================
architecture rtl_null of IntController is
begin
    SYSINTACK   <= '0';
    CPU_INT_N   <= '1';
    BINTACK     <= (others => '0');
    BINTEN      <= '0';
    BIACK_N     <= '1';
    CPU_BUSRQ_N <= '1';
    D_OUT       <= (others => '0');
    D_OE        <= '0';

end architecture rtl_null;

