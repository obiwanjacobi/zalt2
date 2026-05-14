library ieee;
use ieee.std_logic_1164.all;

-- =============================================================================
-- Memory Decoder
-- Decodes the physical address bus (MA24..MA12 + A11..A0 implied) and the
-- CPU memory-cycle signals to generate chip-enable strobes for ROM and RAM.
--
-- Physical address space: 25 bits (MA24..MA12 from MMU + A11..A0 from Z80)
--   Total: 32 MB (0x0000000 .. 0x1FFFFFF)
--
-- Memory map:
--   ROM 512 kB : 0x1F80000 .. 0x1FFFFFF  MA[24:19] = "111111"
--   RAM 512 kB : 0x1F00000 .. 0x1F7FFFF  MA[24:19] = "111110"
-- =============================================================================

entity MemDecoder is
    port (
        -- Physical upper address bits from the MMU (lower 12 come from CPU A bus)
        MA         : in  std_logic_vector(24 downto 12);

        -- CPU memory-cycle strobes (active-low)
        CPU_MREQ_N : in  std_logic;
        CPU_RD_N   : in  std_logic;
        CPU_WR_N   : in  std_logic;

        -- Chip-enable outputs (active-low)
        ROM_CE_N   : out std_logic;
        RAM_CE_N   : out std_logic
    );
end entity MemDecoder;

-- =============================================================================
architecture rtl of MemDecoder is

    signal mem_active : std_logic;  -- '1' when a valid memory cycle is in progress
    signal rom_sel    : std_logic;  -- '1' when address falls in ROM region (top 512 kB)
    signal ram_sel    : std_logic;  -- '1' when address falls in RAM region (next 512 kB)

begin

    -- A memory cycle is active when MREQ is asserted and either RD or WR is
    -- asserted (excludes RFSH cycles which assert MREQ without RD/WR).
    mem_active <= (not CPU_MREQ_N) and ((not CPU_RD_N) or (not CPU_WR_N));

    -- ROM: top 512 kB of 32 MB physical space (0x1F80000..0x1FFFFFF)
    rom_sel <= '1' when MA(24 downto 19) = "111111" else '0';

    -- RAM: next 512 kB below ROM (0x1F00000..0x1F7FFFF)
    ram_sel <= '1' when MA(24 downto 19) = "111110" else '0';

    ROM_CE_N <= not (mem_active and rom_sel);
    RAM_CE_N <= not (mem_active and ram_sel);

end architecture rtl;
