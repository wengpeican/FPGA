# Run after changing to this script directory in ModelSim.
onerror {error "PIC6 compilation failed"}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../../user_source/hdl_source/osd/*.v tb_pic6_fit.v
vsim -voptargs=+acc work.tb_pic6_fit
onfinish stop
add wave sim:/tb_pic6_fit/{resource,x,y,rgb,errors,changed}
add wave sim:/tb_pic6_fit/dut/{frame_resource,render_page}
run -all
