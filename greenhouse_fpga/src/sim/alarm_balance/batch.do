# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../user_source/hdl_source/osd/ui_page_ctrl.v ../../user_source/hdl_source/osd/sim_sensor_data_gen.v ../../user_source/hdl_source/osd/alarm_threshold_cmp.v tb_alarm_balance.v
vsim -voptargs=+acc work.tb_alarm_balance
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_alarm_balance/errors]; quit -code $n -f}
run -all
set n [examine -radix decimal sim:/tb_alarm_balance/errors]
quit -code $n -f
