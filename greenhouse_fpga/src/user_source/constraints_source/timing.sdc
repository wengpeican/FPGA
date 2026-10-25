# 50 MHz board input. PLL clocks remain related and are analyzed together.
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
derive_clocks
rename_clock -name {sd_card_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[0]}]
rename_clock -name {ext_mem_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[1]}]
rename_clock -name {video_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[0]}]
rename_clock -name {hdmi_5x_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[1]}]
# SDRAM controller: 50 MHz, external clock rising 8 ns after controller clock.
# Pixel (25 MHz) and serializer (125 MHz) run simultaneously, NOT exclusively.
# No blanket clock groups or false paths are added to hide interface timing.
# Extra setup margin for the TF clock; keep all real clock periods unchanged.
set_clock_uncertainty -setup 0.000 [get_clocks {sd_card_clk}]
