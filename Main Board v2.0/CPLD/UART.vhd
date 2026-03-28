library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 8N1 soft UART for Z80 I/O bus
--
-- Two I/O ports (base address configurable via generic):
--   BASE+0  DATA   : write = transmit byte; read = receive byte
--   BASE+1  STATUS : read only
--                    bit 0 = RX data available  (1 = byte ready)
--                    bit 1 = TX ready           (1 = safe to write)
--
-- Clock  : 20 MHz (CLK_FREQ_HZ generic)
-- Baud   : 115200 target  (CLK_FREQ_HZ generic)
--          Actual with 20 MHz: 20000000 / (11 * 16) = 113636 bd  (1.4% error, within spec)
-- Format : 8N1, LSB first
-- RX     : 16x oversampled, double-flop synchroniser, false-start detection
--
-- Typical Z80 BIOS usage:
--
--   UART_DATA   EQU  80h
--   UART_STATUS EQU  81h
--
--   ; --- transmit character in A ---
--   TX_WAIT: IN   A, (UART_STATUS)
--            BIT  1, A
--            JR   Z, TX_WAIT
--            LD   A, CHAR
--            OUT  (UART_DATA), A
--
--   ; --- receive character into A ---
--   RX_WAIT: IN   A, (UART_STATUS)
--            BIT  0, A
--            JR   Z, RX_WAIT
--            IN   A, (UART_DATA)
--
-- Instantiation example (in SystemLogic or top-level entity):
--
--   uart0: entity work.UART(UART_rtl)
--       generic map (CLK_FREQ_HZ => 20_000_000,
--                    BAUD_RATE   => 115_200,
--                    IO_BASE_ADDR => 16#80#)
--       port map (clk     => clk,
--                 n_reset => n_reset,
--                 n_ioreq => n_ioreq,
--                 n_rd    => n_rd,
--                 n_wr    => n_wr,
--                 a       => a(7 downto 0),
--                 d       => d,
--                 tx      => uart_tx,
--                 rx      => uart_rx);

entity UART is
    generic (
        CLK_FREQ_HZ  : integer := 20_000_000;   -- system clock frequency in Hz
        BAUD_RATE    : integer := 115_200;       -- target baud rate
        IO_BASE_ADDR : integer := 16#80#         -- Z80 I/O base address (DATA=BASE, STATUS=BASE+1)
    );
    port (
        clk      : in    std_logic;              -- system clock
        n_reset  : in    std_logic;              -- active-low reset

        -- Z80 bus
        n_ioreq  : in    std_logic;              -- !IOREQ
        n_rd     : in    std_logic;              -- !RD
        n_wr     : in    std_logic;              -- !WR
        a        : in    std_logic_vector(7 downto 0);   -- low address byte (A7..A0)
        d        : inout std_logic_vector(7 downto 0);   -- data bus (tristate)

        -- Serial interface  →  3-pin header: GND / TX / RX
        tx       : out   std_logic;              -- serial TX (to USB-TTL RXD pin)
        rx       : in    std_logic               -- serial RX (from USB-TTL TXD pin)
    );
end entity UART;


architecture UART_rtl of UART is

    ------------------------------------------------------------
    -- Baud rate generator
    -- baud_div = CLK_FREQ_HZ / (BAUD_RATE * 16)   (16x oversampling)
    --
    -- 20 MHz / (115200 * 16) = 10.85  -->  11
    -- Actual baud: 20_000_000 / (11 * 16) = 113636  (1.4% error, within UART spec)
    ------------------------------------------------------------
    constant BAUD_DIV : integer := CLK_FREQ_HZ / (BAUD_RATE * 16);

    signal baud_ctr  : integer range 0 to BAUD_DIV - 1 := 0;
    signal baud_tick : std_logic := '0';        -- pulses once every 1/16 bit period

    ------------------------------------------------------------
    -- TX signals
    -- tx_sr : 10-bit shift register  stop(1) | data[7:0] | start(0)
    --         LSB is always the current output bit
    -- tx_phase: counts 0..15 baud_ticks per bit period
    -- tx_cnt  : counts 0..9 (10 bits total: start + 8 data + stop)
    ------------------------------------------------------------
    signal tx_sr    : std_logic_vector(9 downto 0) := (others => '1');
    signal tx_phase : integer range 0 to 15 := 0;
    signal tx_cnt   : integer range 0 to 9  := 0;
    signal tx_busy  : std_logic := '0';

    -- Edge detection on n_wr to generate a single-cycle write pulse
    signal n_wr_d   : std_logic := '1';

    ------------------------------------------------------------
    -- RX signals
    -- rx_meta / rx_d : two-stage synchroniser (prevents metastability)
    -- rx_sr    : 8-bit shift register (assembled data byte, LSB first)
    -- rx_buf   : latched received byte (held until CPU reads)
    -- rx_phase : 0..15 oversampling count within the current bit period
    -- rx_cnt   : 0 = start bit, 1..8 = data bits, 9 = stop bit
    -- rx_active: '1' while a byte is being received
    -- rx_ready : '1' when rx_buf holds an unread byte
    ------------------------------------------------------------
    signal rx_meta   : std_logic := '1';
    signal rx_d      : std_logic := '1';
    signal rx_sr     : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_buf    : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_phase  : integer range 0 to 15 := 0;
    signal rx_cnt    : integer range 0 to 9  := 0;
    signal rx_active : std_logic := '0';
    signal rx_ready  : std_logic := '0';

    -- Edge detection on n_rd to generate a single-cycle read-clear pulse
    signal n_rd_d    : std_logic := '1';

    ------------------------------------------------------------
    -- Bus decode
    ------------------------------------------------------------
    signal data_sel   : std_logic;
    signal status_sel : std_logic;

begin

    data_sel   <= '1' when n_ioreq = '0' and to_integer(unsigned(a)) = IO_BASE_ADDR     else '0';
    status_sel <= '1' when n_ioreq = '0' and to_integer(unsigned(a)) = IO_BASE_ADDR + 1 else '0';

    ------------------------------------------------------------
    -- Baud tick generator  (16x oversampling rate)
    ------------------------------------------------------------
    process(clk, n_reset)
    begin
        if n_reset = '0' then
            baud_ctr  <= 0;
            baud_tick <= '0';
        elsif rising_edge(clk) then
            baud_tick <= '0';
            if baud_ctr = BAUD_DIV - 1 then
                baud_ctr  <= 0;
                baud_tick <= '1';
            else
                baud_ctr <= baud_ctr + 1;
            end if;
        end if;
    end process;

    ------------------------------------------------------------
    -- TX engine
    --
    -- Packing: tx_sr = stop(1) & data(7:0) & start(0)
    -- tx_sr(0) is driven to the TX pin continuously.
    -- Shift right every 16 baud_ticks (new '1' shifts in from MSB = idle level).
    -- 10 bit periods: start(1) + data(8) + stop(1)
    ------------------------------------------------------------
    process(clk, n_reset)
    begin
        if n_reset = '0' then
            tx_sr    <= (others => '1');
            tx_phase <= 0;
            tx_cnt   <= 0;
            tx_busy  <= '0';
            n_wr_d   <= '1';
        elsif rising_edge(clk) then
            n_wr_d <= n_wr;

            -- Load on falling edge of n_wr while addressed and idle
            if n_wr_d = '1' and n_wr = '0' and data_sel = '1' and tx_busy = '0' then
                tx_sr    <= '1' & d & '0';    -- stop(1) | data[7:0] | start(0)
                tx_busy  <= '1';
                tx_phase <= 0;
                tx_cnt   <= 0;
            end if;

            -- Shift engine
            if tx_busy = '1' and baud_tick = '1' then
                if tx_phase = 15 then
                    tx_phase <= 0;
                    tx_sr    <= '1' & tx_sr(9 downto 1);   -- shift right, insert idle '1'
                    if tx_cnt = 9 then
                        tx_busy <= '0';                     -- stop bit done
                    else
                        tx_cnt <= tx_cnt + 1;
                    end if;
                else
                    tx_phase <= tx_phase + 1;
                end if;
            end if;

        end if;
    end process;

    tx <= tx_sr(0);     -- current bit always on TX pin (idle='1' from reset value)

    ------------------------------------------------------------
    -- RX engine
    --
    -- Idle:        wait for falling edge (start bit)
    -- Start bit:   count 7 baud_ticks to reach bit centre, verify still low
    -- Data bits:   sample rx_d at tick 15 of each bit period (centre), 8 bits LSB first
    -- Stop bit:    sample at tick 15, verify high, latch rx_sr into rx_buf
    ------------------------------------------------------------
    process(clk, n_reset)
    begin
        if n_reset = '0' then
            rx_meta   <= '1';
            rx_d      <= '1';
            rx_sr     <= (others => '0');
            rx_buf    <= (others => '0');
            rx_phase  <= 0;
            rx_cnt    <= 0;
            rx_active <= '0';
            rx_ready  <= '0';
            n_rd_d    <= '1';
        elsif rising_edge(clk) then

            -- Two-stage synchroniser (prevents metastability on async RX input)
            rx_meta <= rx;
            rx_d    <= rx_meta;

            -- Clear rx_ready on falling edge of n_rd while DATA port addressed
            n_rd_d <= n_rd;
            if n_rd_d = '1' and n_rd = '0' and data_sel = '1' then
                rx_ready <= '0';
            end if;

            if rx_active = '0' then
                -- Waiting for start bit: look for RX going low
                if rx_d = '0' then
                    rx_active <= '1';
                    rx_phase  <= 0;
                    rx_cnt    <= 0;
                end if;

            elsif baud_tick = '1' then

                if rx_cnt = 0 then
                    -- Start bit: count to centre (phase 7) then verify still low
                    if rx_phase = 7 then
                        if rx_d = '0' then
                            rx_cnt   <= 1;      -- confirmed valid start bit
                            rx_phase <= 0;
                        else
                            rx_active <= '0';   -- glitch / false start, abort
                        end if;
                    else
                        rx_phase <= rx_phase + 1;
                    end if;

                elsif rx_cnt <= 8 then
                    -- Data bits: sample at centre of each bit (phase 15)
                    if rx_phase = 15 then
                        rx_sr    <= rx_d & rx_sr(7 downto 1);   -- LSB first, shift right
                        rx_cnt   <= rx_cnt + 1;
                        rx_phase <= 0;
                    else
                        rx_phase <= rx_phase + 1;
                    end if;

                else
                    -- Stop bit: sample at phase 15
                    if rx_phase = 15 then
                        if rx_d = '1' then          -- valid stop bit
                            rx_buf   <= rx_sr;
                            rx_ready <= '1';        -- signal byte available
                            -- Note: if previous rx_ready was '1' the old byte is overwritten
                            -- (no FIFO). Keep BIOS polling fast or add a second buffer.
                        end if;
                        rx_active <= '0';           -- back to idle
                    else
                        rx_phase <= rx_phase + 1;
                    end if;
                end if;
            end if;

        end if;
    end process;

    ------------------------------------------------------------
    -- Data bus read (tristate)
    --
    -- DATA   port read: returns rx_buf
    -- STATUS port read: bit1=TX_READY, bit0=RX_AVAILABLE
    ------------------------------------------------------------
    d <= rx_buf                                  when data_sel   = '1' and n_rd = '0' else
         "000000" & (not tx_busy) & rx_ready     when status_sel = '1' and n_rd = '0' else
         (others => 'Z');

end architecture UART_rtl;
