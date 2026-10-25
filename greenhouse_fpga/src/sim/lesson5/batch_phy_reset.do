onerror {quit -code 2 -f}
# Run after changing to this script directory in ModelSim.
if {![file exists work]} {vlib work}
vmap work work
vlog -sv tb_phy_reset.v ../../user_source/hdl_source/lane_lvds_10_1.v ../../user_source/hdl_source/lesson5/reset_sync.v
vsim -voptargs=+acc work.tb_phy_reset
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_phy_reset/errors]; set h [open phy_reset_result.txt w]; puts $h "errors=$n"; close $h; quit -code $n -f}
run -all
quit -code 3 -f
