# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc work.tb_stability
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_stability/errors]; set h [open stability_result.txt w]; puts $h "errors=$n"; close $h; quit -code $n -f}
run -all
quit -code 3 -f
