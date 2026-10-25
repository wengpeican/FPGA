# Run after changing to this script directory in ModelSim.
onerror {error "FAT32 simulation compile/run failed; inspect transcript"}
if {![file exists fade_work]} {vlib fade_work}
vmap fade_work fade_work
vlog -sv -work fade_work -f monitor_fade_files.f
vsim -novopt fade_work.tb_monitor_fade
onfinish stop
add wave sim:/tb_monitor_fade/{rst,k1,k2,code,valid,db,active,errors,commits}
add wave -r sim:/tb_monitor_fade/ctrl/fat32_parser/backend/*
run -all
wave zoom full