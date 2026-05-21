--
-- Synopsys
-- Vhdl wrapper for top level design, written on Mon May  4 11:43:43 2026
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wrapper_for_led is
   port (
      clk : in std_logic;
      btn : in std_logic;
      led_r : out std_logic;
      led_g : out std_logic;
      led_b : out std_logic
   );
end wrapper_for_led;

architecture rtl of wrapper_for_led is

component led
 port (
   clk : in std_logic;
   btn : in std_logic;
   led_r : out std_logic;
   led_g : out std_logic;
   led_b : out std_logic
 );
end component;

signal tmp_clk : std_logic;
signal tmp_btn : std_logic;
signal tmp_led_r : std_logic;
signal tmp_led_g : std_logic;
signal tmp_led_b : std_logic;

begin

tmp_clk <= clk;

tmp_btn <= btn;

led_r <= tmp_led_r;

led_g <= tmp_led_g;

led_b <= tmp_led_b;



u1:   led port map (
		clk => tmp_clk,
		btn => tmp_btn,
		led_r => tmp_led_r,
		led_g => tmp_led_g,
		led_b => tmp_led_b
       );
end rtl;
