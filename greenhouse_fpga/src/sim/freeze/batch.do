# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc work.tb_freeze
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_freeze/errors]; set h [open modelsim_result.txt w]; puts $h "errors=$n"; close $h; quit -code $n -f}
run -all
quit -code 3 -f