library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.vc_context;

entity top_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of top_tb is
    signal clk : std_logic := '0';
    signal rstn : std_logic := '0';
    signal uart_txd : std_logic := '0';
    signal uart_rxd : std_logic := '1';
    signal led_r : std_logic;
    signal led_g : std_logic;
    signal led_b : std_logic;
    signal debug : std_logic;
    signal us_trig : std_logic;
    signal us_echo : std_logic;
    signal quad1 : std_logic_vector(1 downto 0);
    signal quad2 : std_logic_vector(1 downto 0);

    constant uart_master_bfm : uart_master_t := new_uart_master(initial_baud_rate => 115200);
    constant uart_master_stream : stream_master_t := as_stream(uart_master_bfm);

begin
    top_inst : entity work.top
    port map (
        clk => clk,
        rstn => rstn,
        uart_txd => uart_txd,
        uart_rxd => uart_rxd,
        us_trig => us_trig,
        us_echo => us_echo,
        quad1 => quad1,
        quad2 => quad2,
        led_r => led_r,
        led_g => led_g,
        led_b => led_b
    );

    uart_master_bfm_inst : entity vunit_lib.uart_master
    generic map (
      uart => uart_master_bfm)
    port map (
      tx => uart_rxd);

    clk <= not clk after (83.333/2.0)* 1 ns;
    rstn <= '0', '1' after 500 ns;

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("uart_command_sequence") then
                -- 400 us = largement suffisant pour envoyer 4 octets a 115200 bauds (~347 us)
                for i in 0 to 1 loop
                    push_stream(net, uart_master_stream, X"AA");
                    push_stream(net, uart_master_stream, std_logic_vector(to_unsigned(i, 8)));
                    push_stream(net, uart_master_stream, X"00");
                    push_stream(net, uart_master_stream, X"01");
                    wait for 400 us;
                end loop;

                for i in 0 to 1 loop
                    push_stream(net, uart_master_stream, X"AA");
                    push_stream(net, uart_master_stream, std_logic_vector(to_unsigned(i, 8)));
                    push_stream(net, uart_master_stream, X"00");
                    push_stream(net, uart_master_stream, X"00");
                    wait for 400 us;
                end loop;

                for i in 0 to 1 loop
                    push_stream(net, uart_master_stream, X"55");
                    push_stream(net, uart_master_stream, std_logic_vector(to_unsigned(i, 8)));
                    wait for 400 us;
                end loop;
            end if;
        end loop;
        
        test_runner_cleanup(runner); -- Simulation ends here
    end process;
end architecture;
