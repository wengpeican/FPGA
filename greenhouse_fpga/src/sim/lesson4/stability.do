# Run after changing to this script directory in ModelSim.
onerror {error {Compilation or simulation failed; inspect Transcript}}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc work.tb_stability
onfinish stop
add wave -r sim:/tb_stability/*
run -all
wave zoom full
