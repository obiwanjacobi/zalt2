library ieee;
use ieee.std_logic_1164.all;

-- =============================================================================
-- Zalt2 Main Board v2.0 - MA[12..24] pull-up sanity test
-- Device : XC95288XL-TQ144 (U7), project board with all other chips removed
-- Purpose: MA<12..24> now has nothing on it but the external 10k pull-ups
--          (R1-R26) and this CPLD input. AND all 13 bits together so a
--          single probe point (MA_ALL_HIGH) reads solid HIGH only if every
--          line is actually pulled to a valid '1'; a weak/floating line
--          pulls the AND result down instead of just reading ~2V unnoticed.
-- =============================================================================

entity MaTest is
    port (
        MA          : in  std_logic_vector(24 downto 12);
        MA_ALL_HIGH : out std_logic
        -- MA_BITS     : out std_logic_vector(24 downto 12)   -- per-bit passthrough for a logic analyzer
    );
end entity MaTest;

architecture rtl of MaTest is
begin

    process (MA)
        variable result : std_logic;
    begin
        result := '1';
        for i in MA'range loop
            result := result and MA(i);
        end loop;
        MA_ALL_HIGH <= result;
    end process;

    -- MA_BITS <= MA;

end architecture rtl;
