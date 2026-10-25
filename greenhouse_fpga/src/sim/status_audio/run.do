# Run after changing to this script directory in ModelSim.
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f ../../user_source/hdl_source/lesson3/pcm_media_tone.v tb_status_audio.v
vsim -voptargs=+acc work.tb_status_audio
add wave -r sim:/tb_status_audio/*
run -all
