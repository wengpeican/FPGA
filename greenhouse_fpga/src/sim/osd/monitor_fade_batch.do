# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists fade_pixels_work]} {vlib fade_pixels_work}
vmap fade_pixels_work fade_pixels_work
vlog -sv -work fade_pixels_work ../../user_source/hdl_source/osd/*.v tb_monitor_fade_pixels.v
vsim -novopt fade_pixels_work.tb_monitor_fade_pixels
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_monitor_fade_pixels/errors]; quit -code $n -f}
run -all
