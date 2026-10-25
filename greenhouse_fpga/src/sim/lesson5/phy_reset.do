# Run after changing to this script directory in ModelSim.
if {![file exists work]} {vlib work}
vmap work work
vlog -sv tb_phy_reset.v ../../user_source/hdl_source/lane_lvds_10_1.v ../../user_source/hdl_source/lesson5/reset_sync.v
vsim -voptargs=+acc work.tb_phy_reset
onfinish stop
add wave -r sim:/tb_phy_reset/*
run -all
wave zoom full
