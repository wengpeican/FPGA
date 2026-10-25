transcript on
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work
vlog -work work ../../user_source/hdl_source/SD/sd_card_bmp.v
vlog -work work ../../user_source/hdl_source/SD/bmp_read.v
vlog -work work ../../user_source/hdl_source/SD/sd_card_top.v
vlog -work work ../../user_source/hdl_source/SD/sd_card_sec_read_write.v
vlog -work work ../../user_source/hdl_source/SD/sd_card_cmd.v
vlog -work work ../../user_source/hdl_source/SD/spi_master.v
vlog -work work tb_lesson2.v
vsim -t 1ps -voptargs=+acc work.tb_lesson2
add wave -divider {Lesson2 control}
add wave sim:/tb_lesson2/clk
add wave sim:/tb_lesson2/rst
add wave sim:/tb_lesson2/key1
add wave sim:/tb_lesson2/key2
add wave sim:/tb_lesson2/number
add wave sim:/tb_lesson2/valid
add wave sim:/tb_lesson2/dut/auto_play_en
add wave sim:/tb_lesson2/dut/auto_cnt
add wave sim:/tb_lesson2/dut/auto_req_pending
add wave sim:/tb_lesson2/dut/load_busy
add wave sim:/tb_lesson2/dut/load_idx
add wave sim:/tb_lesson2/dut/img_idx
add wave sim:/tb_lesson2/dut/key_auto_short
add wave sim:/tb_lesson2/dut/key_auto_long
add wave sim:/tb_lesson2/dut/next_req_pending
add wave sim:/tb_lesson2/dut/prev_req_pending
run -all
write list lesson2_modelsim.lst
quit -f
