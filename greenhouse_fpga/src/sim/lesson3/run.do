# Run after changing to this script directory in ModelSim.
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc work.tb_lesson3
onfinish stop
add wave -radix unsigned sim:/tb_lesson3/x sim:/tb_lesson3/y
add wave sim:/tb_lesson3/ah sim:/tb_lesson3/av sim:/tb_lesson3/ad
add wave sim:/tb_lesson3/media sim:/tb_lesson3/blip sim:/tb_lesson3/tap
add wave -radix decimal sim:/tb_lesson3/pcm
add wave sim:/tb_lesson3/seq_err sim:/tb_lesson3/overflow sim:/tb_lesson3/contract_err
run -all
wave zoom full