library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =============================================================================
-- Zalt2 - XC95288XL Bring-up / Sanity Test
-- Device : XC95288XL-TQ144 (isolated test board, JTAG-only, no board logic)
-- Purpose: prove the CPLD die/IOBs are alive and drive full rail-to-rail
--          swing on pins spread across every I/O bank (VCCIO1..VCCIO6).
-- Usage  : feed any clock (Hz..MHz range) into CLK_IN. TEST_OUT<5:0> all
--          follow the counter's top bit (slow, DMM-readable). MON_OUT
--          follows the counter's bit 0 (fast, scope-readable) as a
--          "the design is alive" sanity check independent of the DMM reading.
--          ENABLE (P54) freezes the counter when '0', holding all outputs
--          at their last state, to exercise/probe an input pin (tie
--          high/low or leave floating to check its level).
-- =============================================================================

entity Bringup is
    generic (
        DIV_BITS : integer := 24   -- tune so counter(DIV_BITS-1) toggles ~1 Hz for your injected clock
    );
    port (
        CLK_IN   : in  std_logic;
        ENABLE   : in  std_logic;
        TEST_OUT : out std_logic_vector(5 downto 0);  -- one pin per VCCIO bank
        MON_OUT  : out std_logic
    );
end entity Bringup;

architecture rtl of Bringup is
    signal counter : unsigned(DIV_BITS - 1 downto 0) := (others => '0');
begin

    process (CLK_IN)
    begin
        if rising_edge(CLK_IN) then
            if ENABLE = '1' then
                counter <= counter + 1;
            end if;
        end if;
    end process;

    -- every output pin is driven by the same register bit so all six
    -- banks can be probed and compared while in the identical logic state
    TEST_OUT <= (others => counter(DIV_BITS - 1));
    MON_OUT  <= counter(0);

end architecture rtl;
