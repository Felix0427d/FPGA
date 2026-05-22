---------------------------------------------------------------------------------------------------
-- ECAM Brussels
-- FPGA lab: Robot project
-- File content: PWM motor driver channel for L298N
---------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_motor_channel is
    generic (
        -- 12 MHz / 25 kHz = 480 clock cycles per PWM period.
        -- Using a counter from 0 to 479 gives the requested PWM frequency.
        PwmPeriod_g : positive := 480
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        direction : in  std_logic;
        speed     : in  std_logic_vector(14 downto 0);
        pwm_out   : out std_logic_vector(1 downto 0)
    );
end entity pwm_motor_channel;

architecture rtl of pwm_motor_channel is
    -- 9 bits are sufficient because 2^9 = 512 > 480.
    signal pwm_counter : unsigned(8 downto 0) := (others => '0');
    signal duty_limit  : unsigned(8 downto 0);
    signal pwm_active  : std_logic;
begin
    -- Clamp the requested speed to the maximum duty value supported by the
    -- selected PWM period.
    duty_limit <= to_unsigned(PwmPeriod_g - 1, duty_limit'length)
        when unsigned(speed) > to_unsigned(PwmPeriod_g - 1, speed'length)
        else resize(unsigned(speed), duty_limit'length);

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pwm_counter <= (others => '0');
            elsif pwm_counter = to_unsigned(PwmPeriod_g - 1, pwm_counter'length) then
                pwm_counter <= (others => '0');
            else
                pwm_counter <= pwm_counter + 1;
            end if;
        end if;
    end process;

    -- The comparator creates the PWM pulse while the counter sweeps through
    -- the period.
    pwm_active <= '1' when pwm_counter < duty_limit and unsigned(speed) /= 0 else '0';

    -- The L298N uses two logic inputs per motor. Direction reversal is handled
    -- by routing the PWM pulse to one input or the other:
    --   direction = 0 -> forward  => IN1 = PWM, IN2 = 0
    --   direction = 1 -> reverse  => IN1 = 0,   IN2 = PWM
    -- When speed = 0, both outputs remain low so the motor is released.
    pwm_out(0) <= pwm_active when direction = '0' else '0';
    pwm_out(1) <= pwm_active when direction = '1' else '0';
end architecture rtl;