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
        led_b : out std_logic;

        -- PWM motor control registers.
        pwm1_direction : out std_logic;
        pwm1_speed     : out std_logic_vector(14 downto 0);
        pwm2_direction : out std_logic;
        pwm2_speed     : out std_logic_vector(14 downto 0)
    );
end entity config_regs;

architecture rtl of config_regs is
    -- Requested register map for this lab session:
    --   0x00 -> Red LED control   (bit 0 used)
    --   0x02 -> Green LED control (bit 0 used)
    --   0x04 -> Blue LED control  (bit 0 used)
    --
    -- A full FSM is not required for this APB slave because the register bank
    -- does not have any multi-cycle behavior. The transfer is simple enough to
    -- be handled with one synchronous write process and one combinatorial read
    -- mux.
    signal led_r_reg : std_logic := '0';
    signal led_g_reg : std_logic := '0';
    signal led_b_reg : std_logic := '0';
    signal pwm1_reg  : std_logic_vector(15 downto 0) := (others => '0');
    signal pwm2_reg  : std_logic_vector(15 downto 0) := (others => '0');

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
                led_r_reg <= '0';
                led_g_reg <= '0';
                led_b_reg <= '0';
                pwm1_reg  <= (others => '0');
                pwm2_reg  <= (others => '0');
            elsif s_psel = '1' and s_penable = '1' and s_pwrite = '1' then
                -- APB data is actually written during the access phase, i.e.
                -- when both PSEL and PENABLE are high on a write transfer.
                case s_paddr is
                    when x"00" =>
                        led_r_reg <= s_pwdata(0);

                    when x"02" =>
                        led_g_reg <= s_pwdata(0);

                    when x"04" =>
                        led_b_reg <= s_pwdata(0);

                    when x"06" =>
                        -- bit 15 = direction, bits 14:0 = speed command
                        pwm1_reg <= s_pwdata;

                    when x"08" =>
                        -- bit 15 = direction, bits 14:0 = speed command
                        pwm2_reg <= s_pwdata;

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    -- Read mux.
    -- Read data is made available combinatorially from the addressed register.
    -- The APB master samples it during the access phase of a read transfer.
    process (s_paddr, led_r_reg, led_g_reg, led_b_reg, pwm1_reg, pwm2_reg)
    begin
        prdata_i <= (others => '0');

        case s_paddr is
            when x"00" =>
                prdata_i(0) <= led_r_reg;

            when x"02" =>
                prdata_i(0) <= led_g_reg;

            when x"04" =>
                prdata_i(0) <= led_b_reg;

            when x"06" =>
                prdata_i <= pwm1_reg;

            when x"08" =>
                prdata_i <= pwm2_reg;

            when others =>
                prdata_i <= (others => '0');
        end case;
    end process;

    s_prdata <= prdata_i;

    -- Drive the visible outputs from the APB-accessible LED registers.
    led_r <= led_r_reg;
    led_g <= led_g_reg;
    led_b <= led_b_reg;
    pwm1_direction <= pwm1_reg(15);
    pwm1_speed     <= pwm1_reg(14 downto 0);
    pwm2_direction <= pwm2_reg(15);
    pwm2_speed     <= pwm2_reg(14 downto 0);


end architecture;