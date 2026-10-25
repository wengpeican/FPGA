# Run after changing to this script directory in ModelSim.
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../user_source/hdl_source/lesson3/pcm_media_tone.v ../../user_source/hdl_source/lesson3/status_buzzer_output.v tb_status_buzzer.v
vsim -voptargs=+acc work.tb_status_buzzer
add wave sim:/tb_status_buzzer/severity sim:/tb_status_buzzer/valid sim:/tb_status_buzzer/pcm sim:/tb_status_buzzer/buzzer sim:/tb_status_buzzer/tone/cadence_sample
run -all