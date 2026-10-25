# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f tb_wave_persist.v
vsim -voptargs=+acc work.tb_wave_persist
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_wave_persist/errors]; quit -code $n -f}
run -all
set n [examine -radix decimal sim:/tb_wave_persist/errors]
quit -code $n -f