library ieee;
use ieee.std_logic_1164.all;

-- =============================================================================
-- Memory Controller
--
-- Manages the two external mapping SRAM chips and the CPLD-internal address
-- latches that control them.
--
-- Two independent sets of 11-bit latches drive the MMU_MAP address bus:
--
--   Normal latches (latch_lo / latch_hi)
--     Hold the current CPU logical-page address.  MMU_MAP is driven by these
--     latches during ordinary CPU memory cycles so the mapping RAMs
--     continuously present the correct physical address bits (MA24..MA12)
--     to the SRAM array.  Both mapping RAMs are CE-enabled at all times;
--     write-enable and data buffers are inactive during normal operation.
--
--   IO latches (io_latch_lo / io_latch_hi)
--     Hold the mapping-RAM cell address for programming operations.
--     Software loads these before issuing an SRAM data read or write.
--     During an SRAM cycle MMU_MAP is switched to these latches.
--     MAP[3:0] of the cell address are provided by A[15:12] of the Z80
--     IN r,(C) / OUT (C),r instruction, but those lines are hardwired on the
--     PCB directly to the SRAM address pins and are invisible to the CPLD.
--     The CPLD drives MMU_MAP[10:4] only from io_latch_hi and io_latch_lo.
--
-- All CPLD system-IO ports require A[7:0]=0xFF so that normal user code
-- using an 8-bit port number (OUT (n),A) can never inadvertently hit the MMU.
--
-- IO address scheme:
--
--   Latch registers  A[15:12]="0000", A[7:0]=0xFF, A[11:8]=register select
--     0x00FF  Normal lower latch  latch_lo[7:0]    → MAP[7:0]   (r/w)
--     0x01FF  Normal upper latch  latch_hi[2:0]    → MAP[10:8]  (r/w)
--     0x02FF  IO lower latch      io_latch_lo[7:0] → MAP[7:0]   (r/w)
--     0x03FF  IO upper latch      io_latch_hi[2:0] → MAP[10:8]  (r/w)
--     0x05FF  RAM CE enable       bit0: '1'=enable both RAMs, '0'=disable  (w/o)
--             Defaults to '0' (disabled) on reset.
--
--   SRAM data ports  A[7:0]=0xFF, A[11:8]=E or F, A[15:12]=MAP[3:0]
--     The Z80 uses IN r,(C) / OUT (C),r with B={MAP[3:0], 0xE/F}, C=0xFF.
--     A[15:12] carries the low cell-address nibble MAP[3:0] but is routed
--     to the SRAM address pins directly on the PCB — the CPLD does not use
--     A[15:12] at all.
--     0xXEFF  MMU RAM1  (low  byte of the 16-bit mapping entry)  X = MAP[3:0]
--     0xXFFF  MMU RAM2  (high byte of the 16-bit mapping entry)  X = MAP[3:0]
--
-- MMU_MAP is always driven by the latches only:
--   SRAM cycle  → MAP[10:8] = io_latch_hi,  MAP[7:0] = io_latch_lo
--   Normal      → MAP[10:8] = latch_hi,      MAP[7:0] = latch_lo
--   (MAP[3:0] CPLD output pins are not connected to the SRAM on the PCB;
--    A[15:12] are hardwired there to supply the low cell-address nibble.)
-- =============================================================================

entity MemController is
    port (
        CLK20         : in  std_logic;
        CPU_RST_N     : in  std_logic;

        -- CPU address bus
        A             : in  std_logic_vector(15 downto 0);

        -- CPU data bus input (for IO writes to MMU_MAP latches)
        D_IN          : in  std_logic_vector(7 downto 0);

        -- CPU control strobes (active-low)
        CPU_IORQ_N    : in  std_logic;
        CPU_RD_N      : in  std_logic;
        CPU_WR_N      : in  std_logic;
        CPU_M1_N      : in  std_logic;   -- low during interrupt-ack; exclude from IO decode

        -- Mapping RAM address bus (driven by CPLD latches)
        MMU_MAP       : out std_logic_vector(10 downto 0);

        -- Mapping RAM control (active-low CE/WE/DE)
        MMU_RAM1_CE_N : out std_logic;
        MMU_RAM2_CE_N : out std_logic;
        MMU_RAM1_WE_N : out std_logic;
        MMU_RAM2_WE_N : out std_logic;
        MMU_RAM1_DE_N : out std_logic;   -- data buffer enable for RAM1
        MMU_RAM2_DE_N : out std_logic;   -- data buffer enable for RAM2
        MMU_RAM_DDIR  : out std_logic;   -- '0' = RAM→CPU (read), '1' = CPU→RAM (write)

        -- CPU IO read interface
        D_OUT         : out std_logic_vector(7 downto 0);
        D_OE          : out std_logic
    );
end entity MemController;

-- =============================================================================
architecture rtl of MemController is

    -- -------------------------------------------------------------------------
    -- System IO decode — latch registers
    --   Qualifies: IORQ='0', M1='1' (excludes INT-ack), A[15:12]="0000", A[7:0]=0xFF
    --   A[11:8] then selects the target register.
    -- -------------------------------------------------------------------------
    signal sys_io    : std_logic;   -- '1' for any valid latch-register IO cycle
    signal sys_write : std_logic;
    signal sys_read  : std_logic;
    signal reg_sel   : std_logic_vector(3 downto 0);  -- A[11:8]
    -- Normal latch selects
    signal sel_lo    : std_logic;   -- 0x00FF → latch_lo    (MAP[7:0])
    signal sel_hi    : std_logic;   -- 0x01FF → latch_hi    (MAP[10:8])
    -- IO latch selects
    signal sel_io_lo : std_logic;   -- 0x02FF → io_latch_lo (MAP[7:0])
    signal sel_io_hi : std_logic;   -- 0x03FF → io_latch_hi (MAP[10:8])
    signal sel_ce    : std_logic;   -- 0x05FF → ram_ce_en   (write-only)

    -- -------------------------------------------------------------------------
    -- RAM CE enable flip-flop
    -- Controls MMU_RAM1_CE_N and MMU_RAM2_CE_N together.
    -- Defaults to '0' (RAMs disabled) on reset so the MA bus is not driven
    -- until the OS explicitly enables the mapping RAMs after initialisation.
    -- -------------------------------------------------------------------------
    signal ram_ce_en : std_logic;

    -- -------------------------------------------------------------------------
    -- CPLD-internal MMU_MAP latches — Normal (active during CPU memory cycles)
    --   latch_lo[7:0] → MAP[7:0]
    --   latch_hi[2:0] → MAP[10:8]  (bits [7:3] of the write data are ignored)
    -- -------------------------------------------------------------------------
    signal latch_lo    : std_logic_vector(7 downto 0);
    signal latch_hi    : std_logic_vector(2 downto 0);

    -- -------------------------------------------------------------------------
    -- CPLD-internal MMU_MAP latches — IO (active during SRAM programming cycles)
    --   io_latch_lo[7:0] → MAP[7:0]
    --   io_latch_hi[2:0] → MAP[10:8] (bits [7:3] of the write data are ignored)
    --   Note: MAP[3:0] CPLD output pins are not connected to the SRAM on the PCB;
    --         A[15:12] are hardwired to those SRAM address lines instead.
    -- -------------------------------------------------------------------------
    signal io_latch_lo : std_logic_vector(7 downto 0);
    signal io_latch_hi : std_logic_vector(2 downto 0);

    -- -------------------------------------------------------------------------
    -- SRAM data-port decode
    --   Qualifies: IORQ='0', M1='1', A[11:8]=E (RAM1) or F (RAM2), A[7:0]=0xFF
    --   A[15:12] is not used by the CPLD; it is hardwired on the PCB to the
    --   SRAM address pins MAP[3:0] to supply the low cell-address nibble.
    -- -------------------------------------------------------------------------
    signal io_cycle    : std_logic;   -- base IORQ+M1 qualification
    signal io_write    : std_logic;
    signal io_read     : std_logic;
    signal sel_ram1    : std_logic;   -- 0xXEFF → RAM1 (low  byte)
    signal sel_ram2    : std_logic;   -- 0xXFFF → RAM2 (high byte)
    signal sram_active : std_logic;   -- gates MMU_MAP mux and buffer controls

begin

    -- -------------------------------------------------------------------------
    -- System IO decode (latch registers)
    -- -------------------------------------------------------------------------
    sys_io <= '1' when CPU_IORQ_N = '0' and CPU_M1_N = '1'
                       and A(15 downto 12) = "0000"
                       and A(7 downto 0)   = x"FF"
              else '0';

    sys_write <= sys_io and (not CPU_WR_N);
    sys_read  <= sys_io and (not CPU_RD_N);
    reg_sel   <= A(11 downto 8);

    sel_lo    <= '1' when sys_io = '1' and reg_sel = x"0" else '0';
    sel_hi    <= '1' when sys_io = '1' and reg_sel = x"1" else '0';
    sel_io_lo <= '1' when sys_io = '1' and reg_sel = x"2" else '0';
    sel_io_hi <= '1' when sys_io = '1' and reg_sel = x"3" else '0';
    sel_ce    <= '1' when sys_io = '1' and reg_sel = x"5" else '0';

    -- -------------------------------------------------------------------------
    -- MMU_MAP latch registers
    -- -------------------------------------------------------------------------
    process(CLK20, CPU_RST_N)
    begin
        if CPU_RST_N = '0' then
            latch_lo    <= (others => '0');
            latch_hi    <= (others => '0');
            io_latch_lo <= (others => '0');
            io_latch_hi <= (others => '0');
            ram_ce_en   <= '0';
        elsif rising_edge(CLK20) then
            if sys_write = '1' then
                if sel_lo    = '1' then latch_lo    <= D_IN;              end if;
                if sel_hi    = '1' then latch_hi    <= D_IN(2 downto 0); end if;
                if sel_io_lo = '1' then io_latch_lo <= D_IN;              end if;
                if sel_io_hi = '1' then io_latch_hi <= D_IN(2 downto 0); end if;
                if sel_ce    = '1' then ram_ce_en   <= D_IN(0);           end if;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- MMU_MAP — always driven by latches only
    -- MAP[3:0] CPLD output pins are not connected to the SRAM on the PCB;
    -- A[15:12] are hardwired there. Outputs are still driven to avoid floating.
    -- -------------------------------------------------------------------------
    sram_active <= sel_ram1 or sel_ram2;

    MMU_MAP(7 downto 0)  <= io_latch_lo when sram_active = '1' else latch_lo;
    MMU_MAP(10 downto 8) <= io_latch_hi when sram_active = '1' else latch_hi;

    -- -------------------------------------------------------------------------
    -- IO read: return latch values on D bus
    -- io_latch_lo is stored as 4 bits; pad to 8 for readback.
    -- Upper bits of the 'hi' latches read back as '0'.
    -- -------------------------------------------------------------------------
    D_OUT <= latch_lo                    when sys_read = '1' and sel_lo    = '1' else
             "00000" & latch_hi         when sys_read = '1' and sel_hi    = '1' else
             io_latch_lo                when sys_read = '1' and sel_io_lo = '1' else
             "00000" & io_latch_hi      when sys_read = '1' and sel_io_hi = '1' else
             (others => '0');
    D_OE  <= sys_read and (sel_lo or sel_hi or sel_io_lo or sel_io_hi);

    -- -------------------------------------------------------------------------
    -- SRAM data-port decode
    -- io_cycle is the base qualification (IORQ='0', M1='1').
    -- sel_ram1/2 additionally require A[11:8]=E/F and A[7:0]=0xFF.
    -- A[15:12] is not examined here; the PCB routes it to the SRAM directly.
    -- -------------------------------------------------------------------------
    io_cycle <= (not CPU_IORQ_N) and CPU_M1_N;
    io_write <= io_cycle and (not CPU_WR_N);
    io_read  <= io_cycle and (not CPU_RD_N);

    sel_ram1 <= '1' when io_cycle = '1' and A(11 downto 8) = x"E" and A(7 downto 0) = x"FF" else '0';
    sel_ram2 <= '1' when io_cycle = '1' and A(11 downto 8) = x"F" and A(7 downto 0) = x"FF" else '0';

    -- -------------------------------------------------------------------------
    -- Mapping RAM chip enables
    -- CE is gated by ram_ce_en so the OS can disable the RAMs during init.
    -- WE is pulsed only during an SRAM write cycle to the selected chip.
    -- -------------------------------------------------------------------------
    MMU_RAM1_CE_N <= not ram_ce_en;
    MMU_RAM2_CE_N <= not ram_ce_en;

    MMU_RAM1_WE_N <= not (io_write and sel_ram1);
    MMU_RAM2_WE_N <= not (io_write and sel_ram2);

    -- -------------------------------------------------------------------------
    -- Data buffers (transceivers between CPU data bus and mapping RAM data pins)
    -- DE_N is asserted only during an SRAM data IO cycle to the matching chip.
    -- During normal memory operation DE_N is inactive so the mapping RAM data
    -- outputs drive only the MA lines and never appear on the CPU data bus.
    -- DDIR selects direction: '1' = CPU→RAM (write), '0' = RAM→CPU (read).
    -- -------------------------------------------------------------------------
    MMU_RAM1_DE_N <= not ((io_read or io_write) and sel_ram1);
    MMU_RAM2_DE_N <= not ((io_read or io_write) and sel_ram2);

    -- Direction: '1' = CPU→RAM (write), '0' = RAM→CPU (read)
    MMU_RAM_DDIR  <= io_write;

end architecture rtl;

-- =============================================================================
-- Test architecture: disables the mapping RAMs.
--
-- Use from top-level with:
--   entity work.MemController(rtl_null)
-- =============================================================================
architecture rtl_null of MemController is
begin

    -- Force the mapping SRAM address to 0x000 so both bytes feeding MA lines
    -- come from the first MMU cell.
    MMU_MAP <= (others => '0');

    -- Keep both SRAMs disabled at all times in this test mode.
    MMU_RAM1_CE_N <= '1';
    MMU_RAM2_CE_N <= '1';

    -- Disable SRAM programming and CPU data-bus path in this mode.
    MMU_RAM1_WE_N <= '1';
    MMU_RAM2_WE_N <= '1';
    MMU_RAM1_DE_N <= '1';
    MMU_RAM2_DE_N <= '1';
    MMU_RAM_DDIR  <= '0';

    D_OUT <= (others => '0');
    D_OE  <= '0';

end architecture rtl_null;
