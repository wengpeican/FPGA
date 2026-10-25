# Run after changing to this script directory in ModelSim.
onerror {abort all}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc work.tb_recovery
add wave sim:/tb_recovery/clk sim:/tb_recovery/k1 sim:/tb_recovery/k2
add wave -radix unsigned sim:/tb_recovery/code sim:/tb_recovery/dut/auto_cnt
add wave sim:/tb_recovery/dut/auto_play_en sim:/tb_recovery/dut/load_busy
add wave sim:/tb_recovery/dut/source_done_seen sim:/tb_recovery/dut/write_done_seen
add wave sim:/tb_recovery/dut/scan_complete sim:/tb_recovery/dut/load_abort sim:/tb_recovery/dut/load_error
onfinish stop
run -all
wave zoom full