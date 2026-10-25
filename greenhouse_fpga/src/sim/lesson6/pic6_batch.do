# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f pic6_files.f
vsim -voptargs=+acc work.tb_pic6_control
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_pic6_control/errors]; set h [open pic6_modelsim_result.txt w]; puts $h "errors=$n"; close $h; quit -code $n -f}
run -all
set n [examine -radix decimal sim:/tb_pic6_control/errors]
set h [open pic6_modelsim_result.txt w]
puts $h "FAT32 errors=$n"
close $h
quit -code $n -f