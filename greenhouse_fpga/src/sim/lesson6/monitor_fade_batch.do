# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists fade_work]} {vlib fade_work}
vmap fade_work fade_work
vlog -sv -work fade_work -f monitor_fade_files.f
vsim -novopt fade_work.tb_monitor_fade
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_monitor_fade/errors]; set h [open monitor_fade_modelsim_result.txt w]; puts $h "errors=$n"; close $h; quit -code $n -f}
run -all
set n [examine -radix decimal sim:/tb_monitor_fade/errors]
set h [open monitor_fade_modelsim_result.txt w]
puts $h "FAT32 errors=$n"
close $h
quit -code $n -f