onerror {quit -code 2 -f}
# Run after changing to this script directory in ModelSim.
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc work.tb_startup
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_startup/errors]; set h [open startup_result.txt w]; puts $h "errors=$n"; close $h; quit -code $n -f}
run -all
quit -code 3 -f
