# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../user_source/hdl_source/lesson3/pcm_media_tone.v ../../user_source/hdl_source/lesson3/status_buzzer_output.v tb_status_buzzer.v
vsim -voptargs=+acc work.tb_status_buzzer
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_status_buzzer/errors]; quit -code $n -f}
run -all
set n [examine -radix decimal sim:/tb_status_buzzer/errors]
quit -code $n -f