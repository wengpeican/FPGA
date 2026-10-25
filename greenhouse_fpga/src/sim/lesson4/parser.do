# Run after changing to this script directory in ModelSim.
onerror {error {Compilation or simulation failed; inspect Transcript}}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv tb_parser.v ../../user_source/hdl_source/SD/bmp_read.v
vsim -voptargs=+acc work.tb_parser
onfinish stop
add wave -r sim:/tb_parser/*
run -all
wave zoom full
