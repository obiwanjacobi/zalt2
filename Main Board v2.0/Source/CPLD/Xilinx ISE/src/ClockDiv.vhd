library ieee;
use ieee.std_logic_1164.all;

-- =============================================================================
-- ClockDiv - CLK20 divide-by-2 to produce BCLK (10 MHz)
-- =============================================================================
entity ClockDiv is
    port (
        CLK20 : in  std_logic;
        BCLK  : out std_logic
    );
end entity ClockDiv;

architecture rtl of ClockDiv is
    signal clk_div : std_logic := '0';
begin

    process(CLK20)
    begin
        if rising_edge(CLK20) then
            clk_div <= not clk_div;
        end if;
    end process;

    BCLK <= clk_div;

end architecture rtl;
