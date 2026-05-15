library ieee;
use ieee.std_logic_1164.all;

-- =============================================================================
-- SysBridge - CPU <-> MCU byte-stream interface
--
-- Decodes two CPU IO ports and drives the tri-state data buffer that sits
-- between the CPU data bus (D[7:0]) and the MCU.
--
-- IO port convention: A[15:12]="0000", A[7:0]=0xFF, index in A[11:8].
--
--   0x06FF  Command / Status port
--             CPU write  →  command byte to MCU   (SYSCMD=1, SYSDDIR=1)
--             CPU read   ←  status byte from MCU  (SYSCMD=1, SYSDDIR=0)
--
--   0x07FF  Data exchange port
--             CPU write  →  data byte to MCU      (SYSCMD=0, SYSDDIR=1)
--             CPU read   ←  data byte from MCU    (SYSCMD=0, SYSDDIR=0)
--
-- Signal roles:
--   SYSDEN_N   Active-low enable for the D-bus ↔ MCU data buffer.
--   SYSDDIR    Buffer direction: '1' = CPU→MCU (write), '0' = MCU→CPU (read).
--   SYSCMD     Port discriminator: '1' = command/status, '0' = data.
--              Sampled by the MCU together with SYSDEN_N to route the byte.
--   CPU_WAIT_N Held low for WAIT_CYCLES CLK20 periods at the start of any
--              system-port cycle, giving the MCU time to respond.
--
-- Wait-state timing (CLK20 = 20 MHz, 50 ns/cycle):
--   WAIT_CYCLES = 0  →  no extra time (MCU must respond within one T-state)
--   WAIT_CYCLES = 3  →  150 ns extra  (default; suitable for most MCUs)
--   WAIT_CYCLES = N  →  N × 50 ns extra
-- =============================================================================

entity SysBridge is
    generic (
        WAIT_CYCLES : integer := 3    -- CLK20 cycles to hold CPU_WAIT_N low
    );
    port (
        CLK20       : in  std_logic;
        CPU_RST_N   : in  std_logic;

        A           : in  std_logic_vector(15 downto 0);
        CPU_IORQ_N  : in  std_logic;
        CPU_RD_N    : in  std_logic;
        CPU_WR_N    : in  std_logic;
        CPU_M1_N    : in  std_logic;

        CPU_WAIT_N  : out std_logic;   -- WAIT to Z80 (active-low)
        SYSCMD      : out std_logic;   -- '1' = command/status port, '0' = data
        SYSDDIR     : out std_logic;   -- '1' = CPU→MCU (write), '0' = MCU→CPU
        SYSDEN_N    : out std_logic    -- data buffer enable (active-low)
    );
end entity SysBridge;

-- =============================================================================
architecture rtl of SysBridge is

    signal sys_io   : std_logic;
    signal cmd_port : std_logic;
    signal dat_port : std_logic;
    signal sys_port : std_logic;   -- cmd_port or dat_port

    signal wait_cnt : integer range 0 to WAIT_CYCLES := 0;

begin

    -- -------------------------------------------------------------------------
    -- Port decode (combinational)
    -- Qualify all CPLD system IO: normal IO cycle (M1_N='1'), IORQ active,
    -- A[15:12]="0000", A[7:0]=0xFF.
    -- -------------------------------------------------------------------------
    sys_io <= '1' when CPU_IORQ_N = '0' and CPU_M1_N = '1'
                   and A(15 downto 12) = "0000"
                   and A(7  downto  0) = x"FF"
              else '0';

    cmd_port <= '1' when sys_io = '1' and A(11 downto 8) = x"6" else '0';
    dat_port <= '1' when sys_io = '1' and A(11 downto 8) = x"7" else '0';
    sys_port <= cmd_port or dat_port;

    -- -------------------------------------------------------------------------
    -- Wait-state counter
    -- Increments each CLK20 rising edge while sys_port is active.
    -- Resets to 0 as soon as the IO cycle ends so the next cycle starts fresh.
    -- -------------------------------------------------------------------------
    process(CLK20, CPU_RST_N)
    begin
        if CPU_RST_N = '0' then
            wait_cnt <= 0;
        elsif rising_edge(CLK20) then
            if sys_port = '1' then
                if wait_cnt < WAIT_CYCLES then
                    wait_cnt <= wait_cnt + 1;
                end if;
            else
                wait_cnt <= 0;
            end if;
        end if;
    end process;

    -- Assert WAIT_N low from cycle start until the counter reaches WAIT_CYCLES.
    CPU_WAIT_N <= '0' when sys_port = '1' and wait_cnt < WAIT_CYCLES else '1';

    -- -------------------------------------------------------------------------
    -- Drive MCU interface outputs
    -- -------------------------------------------------------------------------
    SYSCMD   <= cmd_port;
    SYSDDIR  <= not CPU_WR_N;    -- '1' while WR_N='0' (CPU writing to MCU)
    SYSDEN_N <= not sys_port;    -- enable buffer only on a matched port

end architecture rtl;
