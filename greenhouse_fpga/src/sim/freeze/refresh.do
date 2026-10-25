# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists refresh_work]} {vlib refresh_work}
vmap refresh_work refresh_work
vlog -work refresh_work -sv -suppress 2121 +incdir+../../user_source/hdl_source/include +incdir+../../td_project ../../user_source/hdl_source/include/sdr_init_ref.enc.v tb_refresh.v
vsim -voptargs=+acc refresh_work.tb_refresh
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_refresh/errors]; quit -code $n -f}
run -all
quit -code 3 -f