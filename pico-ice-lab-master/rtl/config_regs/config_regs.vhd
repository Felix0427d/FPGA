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

        -- APB slave interface
        -- This block is the APB target selected by uart_protocol.
        s_paddr : in std_logic_vector(7 downto 0);
        s_psel : in std_logic;
        s_penable : in std_logic;
        s_pwrite : in std_logic;
        s_pwdata : in std_logic_vector(15 downto 0);
        s_prdata : out std_logic_vector(15 downto 0);

        -- Outputs controlled by software-visible registers.
        led_r : out std_logic;
        led_g : out std_logic;
        led_b : out std_logic
    );
end entity config_regs;

architecture rtl of config_regs is
    -- Register 0x00: LED control register.
    --   bit 0 -> red LED
    --   bit 1 -> green LED
    --   bit 2 -> blue LED
    signal led_reg : std_logic_vector(2 downto 0) := (others => '0');

    -- Register 0x01: generic 16-bit scratch register.
    -- This is useful to validate read and write transactions over UART.
    signal scratch_reg : std_logic_vector(15 downto 0) := (others => '0');

    -- Read data mux output.
    signal prdata_i : std_logic_vector(15 downto 0) := (others => '0');

begin
    -- Register write process.
    -- In APB, a write is applied during the access phase when PSEL and
    -- PENABLE are both high.
    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                led_reg     <= (others => '0');
                scratch_reg <= (others => '0');
            elsif s_psel = '1' and s_penable = '1' and s_pwrite = '1' then
                case s_paddr is
                    when x"00" =>
                        led_reg <= s_pwdata(2 downto 0);

                    when x"01" =>
                        scratch_reg <= s_pwdata;

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    -- Read mux.
    -- Since this lab bus does not model PREADY, the master simply samples the
    -- combinatorial read data during the access phase.
    process (s_paddr, led_reg, scratch_reg)
    begin
        prdata_i <= (others => '0');

        case s_paddr is
            when x"00" =>
                prdata_i(2 downto 0) <= led_reg;

            when x"01" =>
                prdata_i <= scratch_reg;

            when x"02" =>
                -- Constant identification value to make readback debugging easy.
                prdata_i <= x"EC10";

            when others =>
                prdata_i <= (others => '0');
        end case;
    end process;

    s_prdata <= prdata_i;

    -- Drive the visible outputs from the LED control register.
    led_r <= led_reg(0);
    led_g <= led_reg(1);
    led_b <= led_reg(2);


end architecture;