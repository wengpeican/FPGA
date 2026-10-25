catch {quit -sim}
# Run after changing to this script directory in ModelSim.

transcript off
transcript file final_run.log
transcript on
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc -wlf osd.wlf work.tb_osd
onfinish stop
view wave
delete wave *
add wave -noupdate -label pixel_clk_25MHz sim:/tb_osd/clk
add wave -noupdate -label HS_in sim:/tb_osd/hs
add wave -noupdate -label HS_out_3clocks sim:/tb_osd/ho
add wave -noupdate -label VS_in sim:/tb_osd/vs
add wave -noupdate -label VS_out_3clocks sim:/tb_osd/vo
add wave -noupdate -label DE_in sim:/tb_osd/de
add wave -noupdate -label DE_out_3clocks sim:/tb_osd/dout
add wave -noupdate -radix unsigned -label X_in sim:/tb_osd/x
add wave -noupdate -radix unsigned -label X_out_3clocks sim:/tb_osd/xo
add wave -noupdate -radix hex -label RGB_in sim:/tb_osd/bg
add wave -noupdate -radix hex -label RGB_out sim:/tb_osd/rgb
add wave -noupdate -radix decimal -label errors sim:/tb_osd/errors
configure wave -namecolwidth 280
configure wave -valuecolwidth 130
configure wave -rowmargin 8
update
onbreak {resume}
run -all
set errors [examine -radix decimal sim:/tb_osd/errors]
echo "EVIDENCE_OSD errors=$errors"
wave zoom full
update


set h [open assertions.log r]
set content [read $h]
close $h
echo $content
