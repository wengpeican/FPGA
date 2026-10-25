# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc work.tb_osd
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_osd/errors]; set h [open modelsim_result.txt w]; puts $h "errors=$n"; close $h; quit -code $n -f}
run -all
set n [examine -radix decimal sim:/tb_osd/errors]
set h [open modelsim_result.txt w]
puts $h "OSD errors=$n"
close $h
quit -code $n -f