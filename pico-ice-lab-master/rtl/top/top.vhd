---------------------------------------------------------------------------------------------------
-- ECAM Brussels
-- FPGA lab: Robot project
-- Author:
-- File content: Robot project toplevel
---------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity top is
    port (
        clk   : in std_logic;
        rstn  : in std_logic;

        uart_txd : out std_logic;
        uart_rxd : in std_logic;

        us_trig : out std_logic; -- Ultrasound Trigger
        us_echo : in std_logic; -- Ultrasound Echo

        quad1 : in std_logic_vector(1 downto 0); -- Quadrature Encoder 1
        quad2 : in std_logic_vector(1 downto 0); -- Quadrature Encoder 2

        pwm_mot1 : out std_logic_vector(1 downto 0); -- Motor 1 control
        pwm_mot2 : out std_logic_vector(1 downto 0); -- Motor 2 control

        led_r : out std_logic;
        led_g : out std_logic;
        led_b : out std_logic
    );
end entity top;

architecture rtl of top is
    -- Reset
    signal reset : std_logic;

    -- UART byte-stream signals between the Open Logic UART core and the custom
    -- UART/APB protocol adapter.
    signal uart_tx_valid : std_logic := '0';
    signal uart_tx_ready : std_logic;
    signal uart_tx_data : STD_LOGIC_VECTOR(7 downto 0);
    signal uart_rx_valid : STD_LOGIC := '0';
    signal uart_rx_data : STD_LOGIC_VECTOR(7 downto 0);

    -- Internal APB bus.
    -- uart_protocol is the APB master and config_regs is the APB slave.
    signal apb_paddr   : std_logic_vector(7 downto 0);
    signal apb_psel    : std_logic;
    signal apb_penable : std_logic;
    signal apb_pwrite  : std_logic;
    signal apb_pwdata  : std_logic_vector(15 downto 0);
    signal apb_prdata  : std_logic_vector(15 downto 0);

    -- LEDs driven by the APB register bank.
    signal led_out_r : STD_LOGIC := '0';
    signal led_out_g : STD_LOGIC := '0';
    signal led_out_b : STD_LOGIC := '0';

    -- PWM control words coming from the APB register bank.
    signal pwm1_direction : std_logic;
    signal pwm1_speed     : std_logic_vector(14 downto 0);
    signal pwm2_direction : std_logic;
    signal pwm2_speed     : std_logic_vector(14 downto 0);
    signal pwm1_speed_cmd : std_logic_vector(14 downto 0);
    signal pwm2_speed_cmd : std_logic_vector(14 downto 0);

    -- Ramp-generator configuration and outputs.
    signal ramp_time_delay      : std_logic_vector(15 downto 0);
    signal ramp_target_speed    : std_logic_vector(15 downto 0);
    signal ramp_fast_time       : std_logic_vector(15 downto 0);
    signal ramp_speed_increment : std_logic_vector(15 downto 0);
    signal ramp_speed_decrement : std_logic_vector(15 downto 0);
    signal ramp_execute         : std_logic;
    signal ramp_execute_clear   : std_logic;
    signal ramp_busy            : std_logic;
    signal ramp_speed           : std_logic_vector(14 downto 0);

    signal counter : unsigned(23 downto 0) := (others => '0');
begin
    -- *** Reset resynchronization ***
    reset_gen_inst : entity work.olo_base_reset_gen
    generic map (
        RstInPolarity_g => '0'
    )
    port map (
        Clk => Clk,
        RstOut => reset,
        RstIn => rstn
    );

	-- *** UART ***
    uart_inst : entity work.olo_intf_uart
    generic map (
        ClkFreq_g => 12.0e6,
        BaudRate_g => 115200.0
    )
    port map (
        Clk => Clk,
        Rst => reset,
        Tx_Valid => uart_tx_valid,
        Tx_Ready => uart_tx_ready,
        Tx_Data => uart_tx_data,
        Rx_Valid => uart_rx_valid,
        Rx_Data => uart_rx_data,
        Rx_ParityError => open,
        Uart_Tx => uart_txd,
        Uart_Rx => uart_rxd
    );

    -- *** UART protocol adapter ***
    -- This block converts UART command frames into APB master transactions.
    uart_protocol_inst : entity work.uart_protocol
    port map (
        clk       => clk,
        reset     => reset,
        rx_data   => uart_rx_data,
        rx_valid  => uart_rx_valid,
        tx_data   => uart_tx_data,
        tx_valid  => uart_tx_valid,
        tx_ready  => uart_tx_ready,
        m_paddr   => apb_paddr,
        m_psel    => apb_psel,
        m_penable => apb_penable,
        m_pwrite  => apb_pwrite,
        m_pwdata  => apb_pwdata,
        m_prdata  => apb_prdata
    );

    -- *** APB register bank ***
    -- For this lab, the APB slave exposes a small software-visible register map.
    config_regs_inst : entity work.config_regs
    port map (
        clk       => clk,
        reset     => reset,
        s_paddr   => apb_paddr,
        s_psel    => apb_psel,
        s_penable => apb_penable,
        s_pwrite  => apb_pwrite,
        s_pwdata  => apb_pwdata,
        s_prdata  => apb_prdata,
        led_r     => led_out_r,
        led_g     => led_out_g,
        led_b     => led_out_b,
        pwm1_direction => pwm1_direction,
        pwm1_speed     => pwm1_speed,
        pwm2_direction => pwm2_direction,
        pwm2_speed     => pwm2_speed,
        ramp_time_delay      => ramp_time_delay,
        ramp_target_speed    => ramp_target_speed,
        ramp_fast_time       => ramp_fast_time,
        ramp_speed_increment => ramp_speed_increment,
        ramp_speed_decrement => ramp_speed_decrement,
        ramp_execute         => ramp_execute,
        ramp_execute_clear   => ramp_execute_clear
    );

    -- *** Ramp generator ***
    -- The ramp block follows the requested sequence:
    -- accelerate -> stay at full speed -> decelerate.
    ramp_generator_inst : entity work.ramp_generator
    port map (
        clk               => clk,
        reset             => reset,
        execute           => ramp_execute,
        time_delay        => ramp_time_delay,
        target_speed      => ramp_target_speed,
        fast_time         => ramp_fast_time,
        speed_increment   => ramp_speed_increment,
        speed_decrement   => ramp_speed_decrement,
        current_speed     => ramp_speed,
        busy              => ramp_busy,
        execute_clear     => ramp_execute_clear
    );

    -- When a ramp is running, both motors use the generated ramp speed.
    -- Otherwise the manual APB PWM speed registers are used directly.
    pwm1_speed_cmd <= ramp_speed when ramp_busy = '1' else pwm1_speed;
    pwm2_speed_cmd <= ramp_speed when ramp_busy = '1' else pwm2_speed;

    -- *** PWM generators ***
    -- One channel is instantiated per motor. Each channel generates two logic
    -- outputs compatible with one half-bridge input pair of the L298N.
    pwm_motor1_inst : entity work.pwm_motor_channel
    generic map (
        PwmPeriod_g => 480
    )
    port map (
        clk       => clk,
        reset     => reset,
        direction => pwm1_direction,
        speed     => pwm1_speed_cmd,
        pwm_out   => pwm_mot1
    );

    pwm_motor2_inst : entity work.pwm_motor_channel
    generic map (
        PwmPeriod_g => 480
    )
    port map (
        clk       => clk,
        reset     => reset,
        direction => pwm2_direction,
        speed     => pwm2_speed_cmd,
        pwm_out   => pwm_mot2
    );


	-- *** LED drivers ***
    led_r <= '0' when led_out_r = '1' else 'Z';
    led_g <= '0' when led_out_g = '1' else 'Z';
    led_b <= '0' when led_out_b = '1' else 'Z';

    -- Unused outputs are driven to a safe idle value for now.
    us_trig  <= '0';

end architecture;