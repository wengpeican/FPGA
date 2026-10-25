# Run after changing to this script directory in ModelSim.
onerror {quit -code 2 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv tb_parser.v ../../user_source/hdl_source/SD/bmp_read.v
vsim -voptargs=+acc work.tb_parser
onfinish stop
onbreak {set n [examine -radix decimal sim:/tb_parser/errors]; set h [open parser_result.txt w]; puts $h "errors=$n"; close $h; quit -code $n -f}
run -all
quit -code 3 -f
