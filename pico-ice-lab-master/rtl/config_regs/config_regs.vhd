---------------------------------------------------------------------------------------------------
-- ECAM Brussels
-- FPGA lab: Robot project
-- Author:
-- File content: Configuration registers
---------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity config_regs is
    port (
        clk   : in std_logic;
        reset  : in std_logic;

        -- APB interface
        s_paddr : out std_logic_vector(7 downto 0);
        s_psel : out std_logic;
        s_penable : out std_logic;
        s_pwrite : out std_logic;
        s_pwdata : out std_logic_vector(15 downto 0);
        s_prdata : in std_logic_vector(15 downto 0);

        -- Outputs
        led_r : out std_logic;
        led_g : out std_logic;
        led_b : out std_logic
    );
end entity config_regs;

architecture rtl of config_regs is

begin


end architecture;