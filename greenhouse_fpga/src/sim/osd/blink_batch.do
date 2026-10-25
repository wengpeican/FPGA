# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../user_source/hdl_source/osd/alarm_blink_ctrl.v tb_blink.v
vsim -voptargs=+acc work.tb_blink
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_blink/errors]; set h [open blink_modelsim_result.txt w]; puts $h "errors=$n"; close $h; quit -code $n -f}
run -all
quit -code 2 -f
