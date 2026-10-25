# Run after changing to this script directory in ModelSim.
onerror {error "OSD compilation failed; inspect transcript"}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc work.tb_osd
onfinish stop
add wave -r sim:/tb_osd/dut/*
add wave sim:/tb_osd/errors
run -all
wave zoom full