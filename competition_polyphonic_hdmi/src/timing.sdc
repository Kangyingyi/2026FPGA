create_clock -name sys_clk -period 20 -waveform {0 10} [get_ports {sys_clk}]
create_generated_clock -name clk_tmds_5x -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 40 -multiply_by 297 [get_pins {u_tmds_pll/PLLA_inst/CLKOUT0}]
create_generated_clock -name clk_74_25 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 200 -multiply_by 297 [get_pins {u_tmds_pll/PLLA_inst/CLKOUT1}]
set_clock_groups -asynchronous -group [get_clocks {clk_tmds_5x}] -group [get_clocks {clk_74_25}] -group [get_clocks {sys_clk}]
