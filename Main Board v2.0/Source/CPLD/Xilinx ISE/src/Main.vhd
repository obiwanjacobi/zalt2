library ieee;
use ieee.std_logic_1164.all;

-- =============================================================================
-- Zalt2 Main Board v2.0 - Control Logic CPLD
-- Device : XC95288XL-TQ144 (U7)
-- Toolchain : Xilinx ISE WebPack 14.7
-- =============================================================================

entity Main is
    port (
        -- --------------------------------------------------------------------
        -- Clocks
        -- --------------------------------------------------------------------
        CLK20       : in  std_logic;    -- 20 MHz system clock
        BCLK        : out  std_logic;    -- Expansion bus clock

        -- --------------------------------------------------------------------
        -- CPU Bus - Address (inputs from Z80)
        -- --------------------------------------------------------------------
        A           : in  std_logic_vector(15 downto 0);

        -- --------------------------------------------------------------------
        -- CPU Bus - Data (bidirectional with Z80)
        -- --------------------------------------------------------------------
        --D           : inout std_logic_vector(7 downto 0);
        D           : in std_logic_vector(7 downto 0);

        -- --------------------------------------------------------------------
        -- CPU Control Signals
        -- Active-low signals use the _N suffix.
        -- --------------------------------------------------------------------
        CPU_MREQ_N   : in  std_logic;
        CPU_IORQ_N   : in  std_logic;
        CPU_RD_N     : in  std_logic;
        CPU_WR_N     : in  std_logic;
        CPU_M1_N     : in  std_logic;
        CPU_RFSH_N   : in  std_logic;
        CPU_HALT_N   : in  std_logic;   -- TODO: add to interrupt controller
        CPU_WAIT_N   : out std_logic;
        CPU_INT_N    : out std_logic;
        CPU_NMI_N    : out std_logic;
        CPU_RST_N    : in  std_logic;
        CPU_BUSRQ_N  : out std_logic;
        CPU_BUSACK_N : in  std_logic;

        -- --------------------------------------------------------------------
        -- Memory Chip Selects (outputs)
        -- --------------------------------------------------------------------
        ROM_CE_N    : out std_logic;
        RAM_CE_N    : out std_logic;

        -- --------------------------------------------------------------------
        -- MMU - Physical Memory Address Extension (outputs to SRAM)
        -- MA12..MA24 are the extended physical address bits driven by the MMU.
        -- --------------------------------------------------------------------
        MA          : in std_logic_vector(24 downto 12);

        -- --------------------------------------------------------------------
        -- MMU - Mapping RAM Control
        -- --------------------------------------------------------------------
        MMU_MAP     : out std_logic_vector(10 downto 0);  -- MAP10..MAP0
        
        MMU_RAM1_CE_N : out std_logic;
        MMU_RAM2_CE_N : out std_logic;
        MMU_RAM1_WE_N : out std_logic;
        MMU_RAM2_WE_N : out std_logic;
        MMU_RAM1_DE_N : out std_logic;  -- data buffer enable RAM1
        MMU_RAM2_DE_N : out std_logic;  -- data buffer enable RAM2
        MMU_RAM_DDIR  : out std_logic;  -- data buffer direction (0=read, 1=write)

        -- --------------------------------------------------------------------
        -- MMU - Memory Protection Unit
        -- --------------------------------------------------------------------
        MMU_MP_EXE  : in std_logic;   -- execute access (M1 + MREQ + RD)
        MMU_MP_RD   : in std_logic;   -- read access    (MREQ + RD)
        MMU_MP_WR   : in std_logic;   -- write access   (MREQ + WR)

        -- --------------------------------------------------------------------
        -- Expansion Bus - IRQ inputs (from cards)
        -- --------------------------------------------------------------------
        BIRQ        : in  std_logic_vector(7 downto 0);

        -- --------------------------------------------------------------------
        -- Expansion Bus - INTACK outputs
        -- --------------------------------------------------------------------
        BINTACK     : out std_logic_vector(7 downto 0);

        -- --------------------------------------------------------------------
        -- Expansion Bus - Bus arbitration
        -- --------------------------------------------------------------------
        BINTEN      : out std_logic;   -- interrupt enable to bus
        BIACK_N     : out std_logic;   -- ~{BIACK} interrupt acknowledge from bus
        BBUSRQ_N    : in  std_logic;   -- ~{BBUSRQ} bus request from expansion

        -- --------------------------------------------------------------------
        -- Expansion Bus - Memory / IO Strobes (outputs)
        -- --------------------------------------------------------------------
        B8_MEM_WR_N : out std_logic;
        B8_MEM_RD_N : out std_logic;
        BIO_WR_N    : out std_logic;
        BIO_RD_N    : out std_logic;

        -- --------------------------------------------------------------------
        -- System Interface (MCU <-> CPLD)
        -- --------------------------------------------------------------------
        SYSINT      : in  std_logic_vector(2 downto 0);   -- interrupt request from MCU
        SYSINTACK   : out std_logic;   -- interrupt acknowledge to MCU
        SYSCMD      : out std_logic;   -- command strobe from MCU
        SYSDDIR     : out std_logic;   -- system data bus direction
        SYSDEN_N    : out std_logic;   -- ~{SYSDEN} system data bus enable

        -- --------------------------------------------------------------------
        -- Expansion Bus - Bus Control Lines (not used for now)
        -- --------------------------------------------------------------------
        BC1         : in std_logic;
        BC2         : in std_logic;
        BC3         : in std_logic;
        BC4         : in std_logic;
        BC5         : in std_logic;
        BC13        : in std_logic;
        BC14        : in std_logic;
        BC15        : in std_logic;
        BC16        : in std_logic;
        BC17        : in std_logic;
        BC18        : in std_logic;

        -- Unused but fixed
        GNDPIN      : in std_logic  -- P38
    );
end entity Main;

-- =============================================================================
architecture rtl of Main is

    -- Data bus mux: each sub-module that can drive D exposes D_OUT/D_OE.
    -- Main combines them here; only one module should assert D_OE at a time.
    signal mpu_d_out : std_logic_vector(7 downto 0);
    signal mpu_d_oe  : std_logic;

    signal int_d_out : std_logic_vector(7 downto 0);
    signal int_d_oe  : std_logic;

    signal mmc_d_out : std_logic_vector(7 downto 0);
    signal mmc_d_oe  : std_logic;

    signal bclk_int  : std_logic;

begin

    -- -------------------------------------------------------------------------
    -- Clock Divider: BCLK = CLK20 / 2 = 10 MHz
    -- -------------------------------------------------------------------------
    u_ClockDiv : entity work.ClockDiv(rtl)
        port map (
            CLK20 => CLK20,
            BCLK  => bclk_int
        );

    BCLK <= bclk_int;

    -- -------------------------------------------------------------------------
    -- Memory Decoder
    -- Decode MA24..MA12 + CPU_MREQ_N + CPU_RD_N + CPU_WR_N to generate ROM_CE_N and RAM_CE_N.
    -- -------------------------------------------------------------------------
    u_MemDecoder : entity work.MemDecoder(rtl)
        port map (
            MA         => MA,
            CPU_MREQ_N => CPU_MREQ_N,
            CPU_RD_N   => CPU_RD_N,
            CPU_WR_N   => CPU_WR_N,
            ROM_CE_N   => ROM_CE_N,
            RAM_CE_N   => RAM_CE_N
        );

    -- -------------------------------------------------------------------------
    -- MMU - Mapping RAM Control
    -- -------------------------------------------------------------------------
    --u_MemController : entity work.MemController(rtl)
    u_MemController : entity work.MemController(rtl_null)
        port map (
            CLK20         => CLK20,
            CPU_RST_N     => CPU_RST_N,
            A             => A,
            D_IN          => D,
            CPU_IORQ_N    => CPU_IORQ_N,
            CPU_RD_N      => CPU_RD_N,
            CPU_WR_N      => CPU_WR_N,
            CPU_M1_N      => CPU_M1_N,
            MMU_MAP       => MMU_MAP,
            MMU_RAM1_CE_N => MMU_RAM1_CE_N,
            MMU_RAM2_CE_N => MMU_RAM2_CE_N,
            MMU_RAM1_WE_N => MMU_RAM1_WE_N,
            MMU_RAM2_WE_N => MMU_RAM2_WE_N,
            MMU_RAM1_DE_N => MMU_RAM1_DE_N,
            MMU_RAM2_DE_N => MMU_RAM2_DE_N,
            MMU_RAM_DDIR  => MMU_RAM_DDIR,
            D_OUT         => mmc_d_out,
            D_OE          => mmc_d_oe
        );

    -- -------------------------------------------------------------------------
    -- Memory Protection Unit (MPU)
    -- -------------------------------------------------------------------------
    --u_MemProtection : entity work.MemProtection(rtl)
    u_MemProtection : entity work.MemProtection(rtl_null)
        port map (
            CLK20      => CLK20,
            CPU_RST_N  => CPU_RST_N,
            MMU_MP_EXE => MMU_MP_EXE,
            MMU_MP_RD  => MMU_MP_RD,
            MMU_MP_WR  => MMU_MP_WR,
            CPU_NMI_N  => CPU_NMI_N,
            A          => A,
            CPU_IORQ_N => CPU_IORQ_N,
            CPU_RD_N   => CPU_RD_N,
            CPU_M1_N   => CPU_M1_N,
            D_OUT      => mpu_d_out,
            D_OE       => mpu_d_oe
        );

    -- Data bus tri-state mux
    -- Priority: IntController (INTACK vector) > MemController (latch read)
    --           > MemProtection (cause register).
    -- Only one module asserts D_OE at a time in normal operation.
    -- D <= int_d_out when int_d_oe = '1' else
    --      mmc_d_out when mmc_d_oe = '1' else
    --      mpu_d_out when mpu_d_oe = '1' else
    --      (others => 'Z');

    -- -------------------------------------------------------------------------
    -- Expansion Bus - IRQ / INTACK
    -- -------------------------------------------------------------------------
    --u_IntController : entity work.IntController(rtl)
    u_IntController : entity work.IntController(rtl_null)
        port map (
            CLK20      => CLK20,
            CPU_RST_N  => CPU_RST_N,
            SYSINT     => SYSINT,
            SYSINTACK  => SYSINTACK,
            BIRQ       => BIRQ,
            CPU_IORQ_N => CPU_IORQ_N,
            CPU_M1_N   => CPU_M1_N,
            CPU_INT_N  => CPU_INT_N,
            BINTACK      => BINTACK,
            BINTEN       => BINTEN,
            BIACK_N      => BIACK_N,
            BBUSRQ_N     => BBUSRQ_N,
            CPU_BUSACK_N => CPU_BUSACK_N,
            CPU_BUSRQ_N  => CPU_BUSRQ_N,
            D_OUT        => int_d_out,
            D_OE         => int_d_oe
        );

    -- CPU_BUSRQ_N and CPU_BUSACK_N are handled by IntController (DMA arbitration)
    
    -- -------------------------------------------------------------------------
    -- Expansion Bus - Strobes
    -- -------------------------------------------------------------------------
    B8_MEM_WR_N <= CPU_MREQ_N or CPU_WR_N;
    B8_MEM_RD_N <= CPU_MREQ_N or CPU_RD_N;
    BIO_WR_N    <= CPU_IORQ_N or CPU_WR_N;
    BIO_RD_N    <= CPU_IORQ_N or CPU_RD_N;

    -- -------------------------------------------------------------------------
    -- System Interface - CPU <-> MCU bridge
    -- -------------------------------------------------------------------------
    --u_SysBridge : entity work.SysBridge(rtl)
    u_SysBridge : entity work.SysBridge(rtl_null)
        port map (
            CLK20      => CLK20,
            CPU_RST_N  => CPU_RST_N,
            A          => A,
            CPU_IORQ_N => CPU_IORQ_N,
            CPU_RD_N   => CPU_RD_N,
            CPU_WR_N   => CPU_WR_N,
            CPU_M1_N   => CPU_M1_N,
            CPU_WAIT_N => CPU_WAIT_N,
            SYSCMD     => SYSCMD,
            SYSDDIR    => SYSDDIR,
            SYSDEN_N   => SYSDEN_N
        );

end architecture rtl;
