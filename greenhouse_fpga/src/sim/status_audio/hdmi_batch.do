# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f hdmi_files.f
vsim -voptargs=+acc work.tb_status_hdmi
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_status_hdmi/errors]; quit -code $n -f}
run -all
quit -code 3 -f
