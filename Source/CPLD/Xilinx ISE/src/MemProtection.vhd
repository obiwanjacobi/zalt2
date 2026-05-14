library ieee;
use ieee.std_logic_1164.all;

-- =============================================================================
-- Memory Protection Unit (MPU)
--
-- Monitors the three memory-access qualifier signals produced by external
-- mapping-RAM protection logic and triggers a Z80 NMI on a violation.
--
-- The mapping RAMs carry per-page protection bits that are decoded externally
-- into the three MP flags:
--   MMU_MP_EXE  - page is not executable  (active-high violation)
--   MMU_MP_RD   - page is not readable    (active-high violation)
--   MMU_MP_WR   - page is not writable    (active-high violation)
--
-- Z80 NMI behaviour:
--   NMI is negative-edge triggered.  The CPLD asserts CPU_NMI_N low for one
--   full CLK20 cycle on detection of a violation, then releases it.
--   A register holds "nmi_pending" so a new violation cannot re-trigger until
--   the previous one has been serviced (CPU_NMI_N has returned high).
--
-- The NMI handler is responsible for:
--   1. Identifying the violation type from the saved MP flags.
--   2. Either killing the offending task or performing copy-on-write fixup
--      and returning execution (see readme).
-- =============================================================================

entity MemProtection is
    port (
        CLK20       : in  std_logic;
        CPU_RST_N   : in  std_logic;

        -- Memory protection violation flags (active-high, from mapping RAM)
        MMU_MP_EXE  : in  std_logic;
        MMU_MP_RD   : in  std_logic;
        MMU_MP_WR   : in  std_logic;

        -- NMI to CPU (active-low)
        CPU_NMI_N   : out std_logic;

        -- CPU IO read interface (for cause register)
        A           : in  std_logic_vector(15 downto 0);
        CPU_IORQ_N  : in  std_logic;
        CPU_RD_N    : in  std_logic;
        CPU_M1_N    : in  std_logic;   -- exclude interrupt-ack cycles

        -- Data bus output (tri-state; only driven when this port is selected)
        D_OUT       : out std_logic_vector(7 downto 0);
        D_OE        : out std_logic    -- '1' = drive D_OUT onto the data bus
    );
end entity MemProtection;

-- =============================================================================
architecture rtl of MemProtection is

    -- Registered copies for edge / level detection
    signal mp_violation  : std_logic;
    signal mp_prev       : std_logic;
    signal nmi_pending   : std_logic;

    -- Latch the cause so the NMI handler can read it via IO
    signal cause_exe     : std_logic;
    signal cause_rd      : std_logic;
    signal cause_wr      : std_logic;

    -- IO port decode
    -- IO port 0xD2: cause register (read-only)
    --   bit 0 = cause_exe
    --   bit 1 = cause_rd
    --   bit 2 = cause_wr
    -- Adjust the port address to match the system IO map.
    signal io_sel        : std_logic;

begin

    -- Any active-high violation flag triggers the NMI
    mp_violation <= MMU_MP_EXE or MMU_MP_RD or MMU_MP_WR;

    -- -------------------------------------------------------------------------
    -- NMI generation
    -- Trigger on the rising edge of mp_violation (first cycle of a violation).
    -- Hold nmi_pending until reset; the NMI pulse itself is one CLK20 cycle.
    -- -------------------------------------------------------------------------
    process (CLK20, CPU_RST_N)
    begin
        if CPU_RST_N = '0' then
            mp_prev     <= '0';
            nmi_pending <= '0';
            cause_exe   <= '0';
            cause_rd    <= '0';
            cause_wr    <= '0';

        elsif rising_edge(CLK20) then
            mp_prev <= mp_violation;

            -- Rising edge of any violation and no NMI already pending
            if mp_violation = '1' and mp_prev = '0' and nmi_pending = '0' then
                nmi_pending <= '1';
                cause_exe   <= MMU_MP_EXE;
                cause_rd    <= MMU_MP_RD;
                cause_wr    <= MMU_MP_WR;
            end if;

            -- Release pending flag once violation clears
            -- (the CPU is now in the NMI handler with interrupts disabled)
            if mp_violation = '0' then
                nmi_pending <= '0';
            end if;
        end if;
    end process;

    -- NMI is asserted (low) for exactly one CLK20 cycle on the rising edge
    -- of mp_violation.  nmi_pending goes high one cycle later, so the window
    -- is: mp_violation='1' and mp_prev='0' and nmi_pending='0'.
    CPU_NMI_N <= '0' when (mp_violation = '1' and mp_prev = '0' and nmi_pending = '0')
                         and CPU_RST_N = '1'
                 else '1';

    -- -------------------------------------------------------------------------
    -- IO cause register read
    -- Follows the system-IO convention: A[15:12]="0000", A[7:0]=0xFF, A[11:8]=register.
    -- Port 0x04FF (A[11:8]=4) is the MPU cause register (read-only).
    -- A true IO read: IORQ='0', RD='0', M1='1' (M1='0' = interrupt ack).
    -- -------------------------------------------------------------------------
    io_sel <= '1' when CPU_IORQ_N = '0' and CPU_RD_N = '0' and CPU_M1_N = '1'
                       and A(15 downto 12) = "0000"
                       and A(11 downto 8)  = x"4"
                       and A(7 downto 0)   = x"FF"
              else '0';

    -- Cause register: bit2=WR, bit1=RD, bit0=EXE; upper bits read as 0.
    D_OUT <= "00000" & cause_wr & cause_rd & cause_exe when io_sel = '1' else (others => '0');
    D_OE  <= io_sel;

end architecture rtl;
