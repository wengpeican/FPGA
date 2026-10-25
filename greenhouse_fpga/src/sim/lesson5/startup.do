# Run after changing to this script directory in ModelSim.
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc work.tb_startup
onfinish stop
add wave -r sim:/tb_startup/*
run -all
wave zoom full
