create_clock -name sopc_clk  -period 20 [get_ports sys_clk_in]
set_false_path -from * -to [get_ports { leds_out*}]