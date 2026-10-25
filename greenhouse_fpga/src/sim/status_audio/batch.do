# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f ../../user_source/hdl_source/lesson3/pcm_media_tone.v tb_status_audio.v
vsim -voptargs=+acc work.tb_status_audio
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_status_audio/errors]; quit -code $n -f}
run -all
set n [examine -radix decimal sim:/tb_status_audio/errors]
quit -code $n -f
