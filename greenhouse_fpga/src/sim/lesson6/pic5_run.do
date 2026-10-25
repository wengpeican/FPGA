# Run after changing to this script directory in ModelSim.
onerror {error "FAT32 simulation compile/run failed; inspect transcript"}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f pic5_files.f
vsim -voptargs=+acc work.tb_pic5_control
onfinish stop
add wave sim:/tb_pic5_control/{rst,k1,k2,code,valid,db,active,errors,commits}
add wave -r sim:/tb_pic5_control/ctrl/fat32_parser/backend/*
run -all
wave zoom full