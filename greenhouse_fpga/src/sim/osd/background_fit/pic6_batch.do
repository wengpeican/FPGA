# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../../user_source/hdl_source/osd/*.v tb_pic6_fit.v
vsim -voptargs=+acc work.tb_pic6_fit
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_pic6_fit/errors]; set f [open pic6_modelsim_result.txt w]; puts $f "errors=$n"; close $f; quit -code $n -f}
run -all
