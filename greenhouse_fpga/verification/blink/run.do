catch {quit -sim}
# Run after changing to this script directory in ModelSim.

transcript off
transcript file final_run.log
transcript on
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc -wlf blink.wlf work.tb_blink
onfinish stop
view wave
delete wave *
add wave -noupdate -radix binary -label states_00_10_01_00 sim:/tb_blink/states
add wave -noupdate -label GREEN_0p5Hz {sim:/tb_blink/blink[0]}
add wave -noupdate -label YELLOW_1Hz {sim:/tb_blink/blink[1]}
add wave -noupdate -label RED_4Hz {sim:/tb_blink/blink[2]}
add wave -noupdate -radix decimal -label green_edges sim:/tb_blink/green_edges
add wave -noupdate -radix decimal -label yellow_edges sim:/tb_blink/yellow_edges
add wave -noupdate -radix decimal -label red_edges sim:/tb_blink/red_edges
add wave -noupdate -radix decimal -label errors sim:/tb_blink/errors
configure wave -namecolwidth 280
configure wave -valuecolwidth 130
configure wave -rowmargin 8
update
onbreak {resume}
run -all
set errors [examine -radix decimal sim:/tb_blink/errors]
echo "EVIDENCE_BLINK errors=$errors"
wave zoom full
update



set h [open result.txt w]
set line "BLINK_RESULT errors=[examine -radix decimal sim:/tb_blink/errors] red_edges=[examine -radix decimal sim:/tb_blink/red_edges] yellow_edges=[examine -radix decimal sim:/tb_blink/yellow_edges] green_edges=[examine -radix decimal sim:/tb_blink/green_edges]"
puts $h $line
close $h
echo $line
