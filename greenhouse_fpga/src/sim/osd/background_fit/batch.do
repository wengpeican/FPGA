# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../../user_source/hdl_source/osd/*.v tb_background_fit.v
vsim -voptargs=+acc work.tb_background_fit
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_background_fit/errors]; set h [open modelsim_result.txt w]; puts $h "errors=$n"; close $h; quit -code $n -f}
run -all
quit -code 2 -f
