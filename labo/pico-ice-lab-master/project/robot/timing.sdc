create_clock -name {main_clk} -period 83.3333333333333 [get_ports clk]
set_false_path -from [get_ports rstn]
set_false_path -from [get_ports uart_rxd]
set_false_path -to [get_ports {uart_txd led_b led_g led_r}]
