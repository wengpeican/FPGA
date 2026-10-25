# Run after changing to this script directory in ModelSim.
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc work.tb_freeze
onfinish stop
add wave sim:/tb_freeze/code sim:/tb_freeze/db sim:/tb_freeze/active
add wave sim:/tb_freeze/wr_req sim:/tb_freeze/wr_ack sim:/tb_freeze/finish
add wave sim:/tb_freeze/ctrl/load_busy sim:/tb_freeze/ctrl/load_error
add wave -radix unsigned sim:/tb_freeze/fb/frame_fifo_read_m0/state sim:/tb_freeze/fb/frame_fifo_write_m0/state
run -all
wave zoom full