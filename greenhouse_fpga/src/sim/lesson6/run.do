# Run after changing to this script directory in ModelSim.
onerror {error "FAT32 simulation compile/run failed; inspect transcript"}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc work.tb_fat32
onfinish stop
add wave sim:/tb_fat32/{rst,k1,k2,code,valid,db,active,errors,commits}
add wave -r sim:/tb_fat32/ctrl/fat32_parser/backend/*
run -all
wave zoom full