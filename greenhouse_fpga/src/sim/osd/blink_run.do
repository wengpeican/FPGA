# Run after changing to this script directory in ModelSim.
onerror {error "Blink simulation failed"}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../user_source/hdl_source/osd/alarm_blink_ctrl.v tb_blink.v
vsim -voptargs=+acc work.tb_blink
onfinish stop
add wave sim:/tb_blink/states sim:/tb_blink/blink sim:/tb_blink/errors sim:/tb_blink/red_edges sim:/tb_blink/yellow_edges sim:/tb_blink/green_edges
run -all
wave zoom full
