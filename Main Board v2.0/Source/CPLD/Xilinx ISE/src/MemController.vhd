library ieee;
use ieee.std_logic_1164.all;

-- =============================================================================
-- Memory Controller
--
-- Manages the two external mapping SRAM chips and the CPLD-internal address
-- latches that control them.
--
-- MMU_MAP is an 11-bit cell address, split into a task_id field (hi) and a
-- bank field (lo) by the TASK_BITS generic (bank width = MMU_MAP'length - TASK_BITS).
-- Both fields are generic-width so the split can be moved without touching
-- the write logic.
--
-- Two independent sets of latches drive the MMU_MAP address bus:
--
--   Normal latches (latch_bank / latch_task)
--     Hold the current CPU logical-page address.  MMU_MAP is driven by these
--     latches during ordinary CPU memory cycles so the mapping RAMs
--     continuously present the correct physical address bits (MA24..MA12)
--     to the SRAM array.  Both mapping RAMs are CE-enabled at all times;
--     write-enable and data buffers are inactive during normal operation.
--     The bank write is staged (pending_bank) and only committed to
--     latch_bank/latch_task together, on the task_id write, so all 11 bits
--     of MMU_MAP change atomically — software must write the bank latch
--     first, then the task_id latch to commit.
--
--   IO latches (io_latch_bank / io_latch_task)
--     Hold the mapping-RAM cell address for programming operations.
--     Software loads these before issuing an SRAM data read or write.
--     During an SRAM cycle MMU_MAP is switched to these latches.
--     MAP[3:0] of the cell address are provided by A[15:12] of the Z80
--     IN r,(C) / OUT (C),r instruction, but those lines are hardwired on the
--     PCB directly to the SRAM address pins and are invisible to the CPLD.
--     The CPLD drives MMU_MAP[10:4] only from io_latch_task and io_latch_bank.
--     These latches are written directly (no staging) — programming does not
--     affect the mapping currently in use by the CPU.
--
-- All CPLD system-IO ports require A[7:0]=0xFF so that normal user code
-- using an 8-bit port number (OUT (n),A) can never inadvertently hit the MMU.
--
-- IO address scheme:
--
--   Latch registers  A[15:12]="0000", A[7:0]=0xFF, A[11:8]=register select
--     0x00FF  Normal bank    latch  pending_bank   → staged, → MAP bank    (r/w)
--     0x01FF  Normal task_id latch  latch_task     → MAP task_id  (r/w)
--                                   commits pending_bank → latch_bank at the same time
--     0x02FF  IO     bank    latch  io_latch_bank  → MAP bank    (r/w)
--     0x03FF  IO     task_id latch  io_latch_task  → MAP task_id  (r/w)
--     0x05FF  RAM CE enable         bit0: '1'=enable both RAMs, '0'=disable  (w/o)
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
--   SRAM cycle  → MAP task_id = io_latch_task,  MAP bank = io_latch_bank
--   Normal      → MAP task_id = latch_task,      MAP bank = latch_bank
--   (MAP[3:0] CPLD output pins are not connected to the SRAM on the PCB;
--    A[15:12] are hardwired there to supply the low cell-address nibble.)
-- =============================================================================

entity MemController is
    generic (
        TASK_BITS     : natural := 3    -- width of the task_id field of MMU_MAP; bank field is MMU_MAP'length - TASK_BITS
    );
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

        -- Mapping RAM enable state, for MemProtection to suppress violations
        -- while the mapping RAM contents are not yet initialised.
        MMU_CE_EN     : out std_logic;

        -- CPU IO read interface
        D_OUT         : out std_logic_vector(7 downto 0);
        D_OE          : out std_logic
    );
end entity MemController;

-- =============================================================================
architecture rtl of MemController is

    -- Width of the bank field; task_id field width is TASK_BITS.
    constant BANK_BITS : natural := MMU_MAP'length - TASK_BITS;

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
    signal sel_bank    : std_logic;   -- 0x00FF → latch_bank    (MAP bank)
    signal sel_task    : std_logic;   -- 0x01FF → latch_task    (MAP task_id)
    -- IO latch selects
    signal sel_io_bank : std_logic;   -- 0x02FF → io_latch_bank (MAP bank)
    signal sel_io_task : std_logic;   -- 0x03FF → io_latch_task (MAP task_id)
    signal sel_ce    : std_logic;   -- 0x05FF → ram_ce_en   (write-only)

    -- -------------------------------------------------------------------------
    -- RAM CE enable flip-flop
    -- Controls MMU_RAM1_CE_N and MMU_RAM2_CE_N together (in addition to the
    -- per-chip SRAM access override below).
    -- Defaults to '0' (RAMs disabled outside of SRAM access) on reset so the
    -- MA bus is not driven until the OS explicitly enables the mapping RAMs
    -- after initialisation. The boot ROM can still program the mapping RAM
    -- via the SRAM data ports before ram_ce_en is set, since each chip's CE
    -- is force-enabled during its own data-port access.
    -- -------------------------------------------------------------------------
    signal ram_ce_en : std_logic;

    -- -------------------------------------------------------------------------
    -- CPLD-internal MMU_MAP latches — Normal (active during CPU memory cycles)
    --   latch_bank(BANK_BITS-1 downto 0) → MAP bank
    --   latch_task(TASK_BITS-1 downto 0) → MAP task_id
    --   pending_bank holds a bank write until the task_id write commits both
    --   latch_bank and latch_task together, so MMU_MAP changes atomically.
    -- -------------------------------------------------------------------------
    signal latch_bank   : std_logic_vector(BANK_BITS - 1 downto 0);
    signal latch_task   : std_logic_vector(TASK_BITS - 1 downto 0);
    signal pending_bank : std_logic_vector(BANK_BITS - 1 downto 0);

    -- -------------------------------------------------------------------------
    -- CPLD-internal MMU_MAP latches — IO (active during SRAM programming cycles)
    --   io_latch_bank(BANK_BITS-1 downto 0) → MAP bank
    --   io_latch_task(TASK_BITS-1 downto 0) → MAP task_id
    --   Written directly (no staging/atomicity) — programming does not affect
    --   the mapping currently driving CPU memory cycles.
    --   Note: MAP[3:0] CPLD output pins are not connected to the SRAM on the PCB;
    --         A[15:12] are hardwired to those SRAM address lines instead.
    -- -------------------------------------------------------------------------
    signal io_latch_bank : std_logic_vector(BANK_BITS - 1 downto 0);
    signal io_latch_task : std_logic_vector(TASK_BITS - 1 downto 0);

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

    -- Each latch write is a single 8-bit D_IN, so both fields must fit in a byte.
    assert TASK_BITS <= 8 and BANK_BITS <= 8
        report "MemController: TASK_BITS/BANK_BITS must each be <= 8 (D_IN is 8 bits wide)"
        severity failure;

    -- The two fields must exactly cover all 11 MMU_MAP bits.
    assert TASK_BITS + BANK_BITS = MMU_MAP'length
        report "MemController: TASK_BITS + BANK_BITS must equal MMU_MAP'length (11)"
        severity failure;

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

    sel_bank    <= '1' when sys_io = '1' and reg_sel = x"0" else '0';
    sel_task    <= '1' when sys_io = '1' and reg_sel = x"1" else '0';
    sel_io_bank <= '1' when sys_io = '1' and reg_sel = x"2" else '0';
    sel_io_task <= '1' when sys_io = '1' and reg_sel = x"3" else '0';
    sel_ce      <= '1' when sys_io = '1' and reg_sel = x"5" else '0';

    -- -------------------------------------------------------------------------
    -- MMU_MAP latch registers
    -- -------------------------------------------------------------------------
    process(CLK20, CPU_RST_N)
    begin
        if CPU_RST_N = '0' then
            latch_bank    <= (others => '0');
            latch_task    <= (others => '0');
            pending_bank  <= (others => '0');
            io_latch_bank <= (others => '0');
            io_latch_task <= (others => '0');
            ram_ce_en     <= '0';
        elsif rising_edge(CLK20) then
            if sys_write = '1' then
                if sel_bank    = '1' then pending_bank <= D_IN(BANK_BITS - 1 downto 0); end if;
                if sel_task    = '1' then
                    -- Commit the staged bank field together with the task_id
                    -- field so all MMU_MAP bits change on the same clock edge.
                    latch_bank <= pending_bank;
                    latch_task <= D_IN(TASK_BITS - 1 downto 0);
                end if;
                if sel_io_bank = '1' then io_latch_bank <= D_IN(BANK_BITS - 1 downto 0); end if;
                if sel_io_task = '1' then io_latch_task <= D_IN(TASK_BITS - 1 downto 0); end if;
                if sel_ce      = '1' then ram_ce_en <= D_IN(0); end if;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- MMU_MAP — always driven by latches only
    -- MAP[3:0] CPLD output pins are not connected to the SRAM on the PCB;
    -- A[15:12] are hardwired there. Outputs are still driven to avoid floating.
    -- -------------------------------------------------------------------------
    sram_active <= sel_ram1 or sel_ram2;

    MMU_MAP(BANK_BITS - 1 downto 0) <= io_latch_bank when sram_active = '1' else latch_bank;
    MMU_MAP(10 downto BANK_BITS)    <= io_latch_task when sram_active = '1' else latch_task;

    -- -------------------------------------------------------------------------
    -- IO read: return latch values on D bus, zero-padded to 8 bits.
    -- Bank reads return the committed latch, not the staged pending value.
    -- -------------------------------------------------------------------------
    D_OUT <= (7 downto BANK_BITS => '0') & latch_bank      when sys_read = '1' and sel_bank    = '1' else
             (7 downto TASK_BITS => '0') & latch_task      when sys_read = '1' and sel_task    = '1' else
             (7 downto BANK_BITS => '0') & io_latch_bank    when sys_read = '1' and sel_io_bank = '1' else
             (7 downto TASK_BITS => '0') & io_latch_task    when sys_read = '1' and sel_io_task = '1' else
             (others => '0');
    D_OE  <= sys_read and (sel_bank or sel_task or sel_io_bank or sel_io_task);

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
    -- CE follows ram_ce_en, but each chip is also force-enabled during its own
    -- SRAM data-port access so the boot ROM can program the mapping RAM before
    -- ram_ce_en is set.
    -- WE is pulsed only during an SRAM write cycle to the selected chip.
    -- -------------------------------------------------------------------------
    MMU_RAM1_CE_N <= not (ram_ce_en or (sel_ram1 and (io_read or io_write)));
    MMU_RAM2_CE_N <= not (ram_ce_en or (sel_ram2 and (io_read or io_write)));

    MMU_CE_EN <= ram_ce_en;

    MMU_RAM1_WE_N <= not (io_write and sel_ram1);
    MMU_RAM2_WE_N <= not (io_write and sel_ram2);

    -- -------------------------------------------------------------------------
    -- Data buffers (transceivers between CPU data bus and mapping RAM data pins)
    -- DE_N is asserted only during an SRAM data IO cycle to the matching chip.
    -- During normal memory operation DE_N is inactive so the mapping RAM data
    -- outputs drive only the MA lines and never appear on the CPU data bus.
    -- DDIR selects direction: '0' = CPU→RAM (write), '1' = RAM→CPU (read).
    -- -------------------------------------------------------------------------
    MMU_RAM1_DE_N <= not ((io_read or io_write) and sel_ram1);
    MMU_RAM2_DE_N <= not ((io_read or io_write) and sel_ram2);

    -- Direction: '0' = CPU→RAM (write), '1' = RAM→CPU (read)
    MMU_RAM_DDIR  <= not io_write;

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

    MMU_CE_EN <= '0';

    D_OUT <= (others => '0');
    D_OE  <= '0';

end architecture rtl_null;
