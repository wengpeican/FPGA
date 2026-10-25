# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../user_source/hdl_source/osd/*.v tb_display_controls.v
vsim -voptargs=+acc work.tb_display_controls
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_display_controls/errors]; set h [open assertions.log w]; puts $h "errors=$n"; close $h; quit -code $n -f}
run -all
