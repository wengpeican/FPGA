# Run after changing to this script directory in ModelSim.
onerror {error "Background fit compilation failed"}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../../user_source/hdl_source/osd/*.v tb_background_fit.v
vsim -voptargs=+acc work.tb_background_fit
onfinish stop
add wave sim:/tb_background_fit/resource sim:/tb_background_fit/dut/frame_zone sim:/tb_background_fit/x sim:/tb_background_fit/y sim:/tb_background_fit/rgb sim:/tb_background_fit/errors
run -all
