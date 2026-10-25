# Run after changing to this script directory in ModelSim.
onerror {error "Monitor fade simulation failed"}
if {![file exists fade_pixels_work]} {vlib fade_pixels_work}
vmap fade_pixels_work fade_pixels_work
vlog -sv -work fade_pixels_work ../../user_source/hdl_source/osd/*.v tb_monitor_fade_pixels.v
vsim -novopt fade_pixels_work.tb_monitor_fade_pixels
onfinish stop
add wave sim:/tb_monitor_fade_pixels/{request,resource,black,rgb,errors}
add wave sim:/tb_monitor_fade_pixels/dut/{shade,page_shade,monitor_shade,monitor_busy}
run -all
