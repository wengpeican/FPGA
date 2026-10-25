# Run after changing to this script directory in ModelSim.
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../user_source/hdl_source/osd/*.v tb_display_controls.v
vsim -voptargs=+acc work.tb_display_controls
add wave -r sim:/tb_display_controls/ctrl/*
add wave -r sim:/tb_display_controls/adj/*
add wave -r sim:/tb_display_controls/mixer/*
run -all
