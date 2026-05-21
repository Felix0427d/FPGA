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

    -- UART
    signal uart_tx_valid : std_logic := '0';
    signal uart_tx_ready : std_logic;
    signal uart_tx_data : STD_LOGIC_VECTOR(7 downto 0);
    signal uart_rx_valid : STD_LOGIC := '0';
    signal uart_rx_data : STD_LOGIC_VECTOR(7 downto 0);

    -- LEDs
    signal led_out_r : STD_LOGIC := '0';
    signal led_out_g : STD_LOGIC := '0';
    signal led_out_b : STD_LOGIC := '0';

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

    -------- TO BE REMOVED DURING EXERCISES -----------------
    led_out_r <= counter(counter'high);
    led_out_g <= counter(counter'high);
    led_out_b <= counter(counter'high);

    olo_base_fifo_sync_inst : entity work.olo_base_fifo_sync
    generic map (
      Width_g => 8,
      Depth_g => 32
    )
    port map (
      Clk => Clk,
      Rst => reset,
      In_Data => uart_rx_data,
      In_Valid => uart_rx_valid,
      In_Ready => open,
      Out_Data => uart_tx_data,
      Out_Valid => uart_tx_valid,
      Out_Ready => uart_tx_ready
    );

    process (clk)
    begin
        if rising_edge(clk) then
            counter <= counter + 1;
        end if;
    end process;
    ----------------------------------------

	-- *** LED drivers ***
    led_r <= '0' when led_out_r = '1' else 'Z';
    led_g <= '0' when led_out_g = '1' else 'Z';
    led_b <= '0' when led_out_b = '1' else 'Z';

end architecture;