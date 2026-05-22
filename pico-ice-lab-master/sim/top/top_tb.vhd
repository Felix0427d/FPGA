library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.vc_context;
use vunit_lib.sync_pkg.all;

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
    signal pwm_mot1 : std_logic_vector(1 downto 0);
    signal pwm_mot2 : std_logic_vector(1 downto 0);

    constant uart_master_bfm : uart_master_t := new_uart_master(initial_baud_rate => 115200);
    constant uart_master_stream : stream_master_t := as_stream(uart_master_bfm);

begin
    test_runner_watchdog(runner, 50 ms);

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
        pwm_mot1 => pwm_mot1,
        pwm_mot2 => pwm_mot2,
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
        procedure write_reg(
            constant addr  : in std_logic_vector(7 downto 0);
            constant data  : in std_logic_vector(15 downto 0)
        ) is
        begin
            push_stream(net, uart_master_stream, X"AA");
            push_stream(net, uart_master_stream, addr);
            push_stream(net, uart_master_stream, data(15 downto 8));
            push_stream(net, uart_master_stream, data(7 downto 0));
            wait for 450 us;
        end procedure;
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
                wait_until_idle(net, as_sync(uart_master_bfm));
                wait for 1 ms;
            end if;

            if run("ramp_sequence") then
                -- Configure both motors with a fixed forward direction.
                write_reg(X"06", X"000A");
                write_reg(X"08", X"000A");

                -- Configure a short ramp so the bench completes quickly.
                write_reg(X"16", X"0004"); -- time delay in clock cycles
                write_reg(X"18", X"0014"); -- target speed = 20
                write_reg(X"1A", X"0003"); -- hold time = 3 delay periods
                write_reg(X"1C", X"0005"); -- acceleration step = 5
                write_reg(X"1E", X"0004"); -- deceleration step = 4
                write_reg(X"20", X"0001"); -- execute ramp

                -- Wait until the generated PWM becomes active on both motors.
                wait until pwm_mot1 /= "00" for 5 ms;
                check_true(pwm_mot1 /= "00", "PWM motor 1 never became active during the ramp");
                check_true(pwm_mot2 /= "00", "PWM motor 2 never became active during the ramp");

                -- The ramp must eventually end and bring both outputs back low.
                wait until pwm_mot1 = "00" and pwm_mot2 = "00" for 20 ms;
                check_equal(pwm_mot1, std_logic_vector'("00"), "PWM motor 1 did not return to zero after the ramp");
                check_equal(pwm_mot2, std_logic_vector'("00"), "PWM motor 2 did not return to zero after the ramp");

                wait_until_idle(net, as_sync(uart_master_bfm));
                wait for 1 ms;
            end if;
        end loop;
        
        test_runner_cleanup(runner); -- Simulation ends here
    end process;
end architecture;
