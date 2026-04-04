library ieee;
use ieee.std_logic_1164.all;

-- 8<=>16-bit Data Bus Width Converter  (v2 – corrected capture timing)
--
-- Key changes from v1:
--   - Latch capture moved from post-strobe to intra-strobe:
--       SBA_MSB goes low on the FIRST clock ~RD is seen active (cycle 1 read).
--       SAB_LSB goes low on the FIRST clock ~WR is seen active (cycle 1 write).
--       The 646 closes its latch while the bus card / Z80 is still driving data.
--   - Two-FF synchroniser replaced by one FF (Z80 and CPLD share CLK20).
--
-- 74HC646 pin reminder:
--   SAB  pin 2  : A->B path  '1'=transparent  '0'=register (value frozen)
--   CPAB pin 1  : A->B register clock (captures A-input on rising edge when SAB='0')
--   SBA  pin 22 : B->A path  '1'=transparent  '0'=register
--   CPBA pin 23 : B->A register clock
--   ~OE  pin 21 : active-low output enable
--   DIR  pin 3  : '1'=A->B outputs  '0'=B->A outputs
--
-- CPAB / CPBA are tied '0' in this design (level-based latching via SAB/SBA
-- is sufficient given that we close the latch while data is valid).
--
-- Cycle protocol (unchanged from v1 – see that file for full description):
--   16-bit READ  : two 8-bit reads.  Cycle 1: D0-D7 live + D8-D15 latched.
--                  Cycle 2: latched D8-D15 served as D0-D7.  Card NOT re-read.
--   16-bit WRITE : two 8-bit writes.  Cycle 1: D0-D7 latched, strobe suppressed.
--                  Cycle 2: latched D0-D7 + new D8-D15 drive bus, strobe active.

entity DataBus16 is
    port (
        clk           : in  std_logic;  -- CLK20 (same source as Z80 clock)
        n_reset       : in  std_logic;

        -- CPU bus signals (after address/control 245 buffers)
        n_mreq        : in  std_logic;
        n_iorq        : in  std_logic;
        n_rd          : in  std_logic;
        n_wr          : in  std_logic;
        bd8_d16       : in  std_logic;  -- '1' = current card is a 16-bit device

        -- U18  74HC646  low byte  (CPU D0-D7 <-> bus D0-D7)
        sab_lsb       : out std_logic;  -- pin 2
        cpab_lsb      : out std_logic;  -- pin 1  (driven '0'; wired low acceptable)
        sba_lsb       : out std_logic;  -- pin 22

        -- U17  74HC646  high byte  (bus D8-D15 <-> CPU D0-D7 on cycle 2)
        sab_msb       : out std_logic;  -- pin 2
        cpba_msb      : out std_logic;  -- pin 23 (driven '0'; wired low acceptable)
        sba_msb       : out std_logic;  -- pin 22

        -- Shared to both 646s
        bd_dir        : out std_logic;  -- '1'=A->B (write)  '0'=B->A (read)
        n_bdlsb_oe    : out std_logic;  -- U18 ~OE
        n_bdmsb_oe    : out std_logic;  -- U17 ~OE

        -- To bus cycle decoder
        suppress_wr16 : out std_logic;  -- '1'=hold ~B16_MEM_WR / ~B16_IO_WR inactive
        latch_valid   : out std_logic;  -- '1'=mid 16-bit sequence

        -- Wait-state insertion (connect to Z80 ~WAIT via open-collector buffer)
        n_wait        : out std_logic   -- pulsed low for one CLK20 at cycle open
    );
end entity DataBus16;

architecture rtl of DataBus16 is

    type t_state is (
        IDLE,
        RD16_1,   -- cycle 1 read active: U18 live D0-D7, U17 latch holding D8-D15
        RD16_2,   -- cycle 2 read: U17 driving latched D8-D15 to CPU as D0-D7
        WR16_1,   -- cycle 1 write done: D0-D7 in U18 latch, waiting for cycle 2
        WR16_2    -- cycle 2 write active: U18 (latched) + U17 (transparent) on bus
    );
    signal state : t_state := IDLE;

    -- Single-FF input capture (one stage is enough; see header)
    signal rd_r   : std_logic := '1';
    signal wr_r   : std_logic := '1';
    signal d16_r  : std_logic := '0';
    signal mreq_r : std_logic := '1';
    signal iorq_r : std_logic := '1';

    signal rd_prev   : std_logic := '1';
    signal wr_prev   : std_logic := '1';
    signal mreq_prev : std_logic := '1';
    signal iorq_prev : std_logic := '1';

    signal rd_act     : std_logic;
    signal wr_act     : std_logic;
    signal bus_act    : std_logic;
    signal rd_rose    : std_logic;
    signal wr_rose    : std_logic;
    signal cycle_start : std_logic;  -- pulses when ~MREQ or ~IORQ first goes active
    signal d16_latched : std_logic := '0';  -- BD8_D16 captured at cycle open
    signal wait_r      : std_logic := '1';  -- drives n_wait (active low)

begin

    -- ----------------------------------------------------------------
    -- Input capture + edge detectors
    -- ----------------------------------------------------------------
    p_sync : process(clk, n_reset)
    begin
        if n_reset = '0' then
            rd_r      <= '1';  wr_r   <= '1';
            d16_r     <= '0';  mreq_r <= '1';  iorq_r <= '1';
            rd_prev   <= '1';  wr_prev   <= '1';
            mreq_prev <= '1';  iorq_prev <= '1';
        elsif rising_edge(clk) then
            rd_r      <= n_rd;
            wr_r      <= n_wr;
            d16_r     <= bd8_d16;
            mreq_r    <= n_mreq;
            iorq_r    <= n_iorq;
            rd_prev   <= rd_r;
            wr_prev   <= wr_r;
            mreq_prev <= mreq_r;
            iorq_prev <= iorq_r;
        end if;
    end process p_sync;

    rd_act      <= not rd_r;
    wr_act      <= not wr_r;
    bus_act     <= not (mreq_r and iorq_r);
    rd_rose     <= (not rd_prev) and rd_r;        -- pulse when ~RD deasserts
    wr_rose     <= (not wr_prev) and wr_r;        -- pulse when ~WR deasserts
    cycle_start <= (mreq_prev and not mreq_r)     -- pulse on first clock of new cycle
               or (iorq_prev and not iorq_r);

    -- ----------------------------------------------------------------
    -- FSM + registered outputs
    -- ----------------------------------------------------------------
    p_ctrl : process(clk, n_reset)
    begin
        if n_reset = '0' then
            state         <= IDLE;
            sab_lsb       <= '1';   cpab_lsb  <= '0';  sba_lsb  <= '1';
            sab_msb       <= '1';   cpba_msb  <= '0';  sba_msb  <= '1';
            bd_dir        <= '0';
            n_bdlsb_oe    <= '1';   n_bdmsb_oe  <= '1';
            suppress_wr16 <= '0';   latch_valid <= '0';
            d16_latched   <= '0';   wait_r      <= '1';

        elsif rising_edge(clk) then

            case state is

                -- --------------------------------------------------------
                when IDLE =>

                    latch_valid   <= '0';
                    suppress_wr16 <= '0';

                    -- At the start of every bus cycle (~MREQ or ~IORQ first active):
                    --   1. Snapshot BD8_D16 into d16_latched while it is still
                    --      settling (we don't USE it yet).
                    --   2. Assert ~WAIT for exactly one CLK20 period (50 ns).
                    --      This gives the card ~65 ns from address valid to assert
                    --      BD8_D16 before the FSM below acts on d16_latched.
                    if cycle_start = '1' then
                        d16_latched <= d16_r;
                        wait_r      <= '0';    -- assert ~WAIT
                    elsif wait_r = '0' then
                        d16_latched <= d16_r;  -- re-sample: card may have just asserted it
                        wait_r      <= '1';    -- release ~WAIT after one clock
                    end if;

                    if bus_act = '0' then
                        n_bdlsb_oe <= '1';
                        n_bdmsb_oe <= '1';

                    elsif d16_latched = '0' then
                        -- 8-bit cycle: U18 transparent, U17 off
                        bd_dir      <= wr_act;
                        sba_lsb     <= '1';
                        sab_lsb     <= '1';
                        n_bdlsb_oe  <= '0';
                        n_bdmsb_oe  <= '1';

                    elsif rd_act = '1' then
                        -- *** 16-bit READ – cycle 1 entry ***
                        --
                        -- U18: transparent B->A, OE on → D0-D7 live to CPU.
                        -- U17: SBA_MSB goes '1'→'0' on THIS clock edge.
                        --      The 646 closes the B->A latch immediately, freezing
                        --      whatever D8-D15 the card is driving right now.
                        --      ~RD is still active → card IS still driving → valid.
                        --      U17 OE stays off; CPU does not see D8-D15 yet.
                        bd_dir      <= '0';
                        sba_lsb     <= '1';
                        n_bdlsb_oe  <= '0';   -- U18 active for D0-D7
                        sba_msb     <= '0';   -- <<< LATCH D8-D15 now, while ~RD active
                        n_bdmsb_oe  <= '1';   -- U17 output to CPU: not yet
                        latch_valid <= '1';
                        state       <= RD16_1;

                    elsif wr_act = '1' then
                        -- *** 16-bit WRITE – cycle 1 entry ***
                        --
                        -- U18: SAB_LSB goes '1'→'0' on THIS clock edge.
                        --      Freezes CPU D0-D7 (A-inputs) into A->B register.
                        --      Z80 is holding data valid with ~WR active → valid.
                        --      U18 OE off; write strobe suppressed.
                        bd_dir        <= '1';
                        sab_lsb       <= '0';   -- <<< LATCH D0-D7 now, while ~WR active
                        n_bdlsb_oe    <= '1';   -- U18 not driving bus yet
                        n_bdmsb_oe    <= '1';
                        suppress_wr16 <= '1';   -- suppress ~B16_MEM_WR / ~B16_IO_WR
                        latch_valid   <= '1';
                        state         <= WR16_1;
                    end if;

                -- --------------------------------------------------------
                -- RD16_1: U18 passing D0-D7 live; U17 holding D8-D15 in latch.
                --         Wait for ~RD end (CPU has sampled D0-D7).
                -- --------------------------------------------------------
                when RD16_1 =>
                    -- Hold current output state each cycle; wait for rd_rose.
                    if rd_rose = '1' then
                        n_bdlsb_oe <= '1';    -- release U18
                        state      <= RD16_2;
                    end if;

                -- --------------------------------------------------------
                -- RD16_2: U17 driving its latched D8-D15 as D0-D7 to CPU.
                --         Card is NOT re-addressed; no new bus read strobe needed.
                -- --------------------------------------------------------
                when RD16_2 =>
                    bd_dir     <= '0';
                    sba_msb    <= '0';     -- hold B->A register
                    n_bdmsb_oe <= '0';     -- U17 drives CPU D0-D7
                    n_bdlsb_oe <= '1';     -- U18 off

                    if rd_rose = '1' then
                        sba_msb     <= '1';    -- restore transparent
                        n_bdmsb_oe  <= '1';
                        latch_valid <= '0';
                        state       <= IDLE;
                    end if;

                -- --------------------------------------------------------
                -- WR16_1: D0-D7 frozen in U18 A->B register.
                --         Drive bus D0-D7 from latch (strobe still suppressed).
                --         Wait for ~WR end before cycle 2.
                -- --------------------------------------------------------
                when WR16_1 =>
                    suppress_wr16 <= '1';
                    n_bdlsb_oe    <= '0';   -- latched D0-D7 visible on bus D0-D7
                    n_bdmsb_oe    <= '1';   -- D8-D15 not driven yet

                    if wr_rose = '1' then
                        state <= WR16_2;
                    end if;

                -- --------------------------------------------------------
                -- WR16_2: U18 holds latched D0-D7 on bus; U17 transparent
                --         so CPU D0-D7 (new high byte) drives bus D8-D15.
                --         Write strobe is now ACTIVE → card sees full 16 bits.
                -- --------------------------------------------------------
                when WR16_2 =>
                    bd_dir        <= '1';
                    sab_lsb       <= '0';   -- U18: register holds D0-D7
                    n_bdlsb_oe    <= '0';   -- U18 drives bus D0-D7
                    sab_msb       <= '1';   -- U17: transparent (CPU D0-D7 -> D8-D15)
                    n_bdmsb_oe    <= '0';   -- U17 drives bus D8-D15
                    suppress_wr16 <= '0';   -- *** write strobe released ***

                    if wr_rose = '1' then
                        sab_lsb     <= '1';
                        sab_msb     <= '1';
                        n_bdlsb_oe  <= '1';
                        n_bdmsb_oe  <= '1';
                        suppress_wr16 <= '0';
                        latch_valid <= '0';
                        state       <= IDLE;
                    end if;

            end case;
        end if;
    end process p_ctrl;

    -- CPAB / CPBA not used in the level-latch scheme above.
    -- Connect pins 1 and 23 of U17/U18 to GND on the PCB,
    -- or leave these ports unconnected and tie the schematic pins low.
    cpab_lsb <= '0';
    cpba_msb <= '0';

    -- ~WAIT output: open-collector; must be combined (wired-OR) with any other
    -- ~WAIT sources before reaching the Z80.  Held high in all non-IDLE states
    -- so 16-bit multi-cycle operations are not inadvertently stretched.
    n_wait <= wait_r;

end architecture rtl;
