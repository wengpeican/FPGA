catch {quit -sim}
# Run after changing to this script directory in ModelSim.

transcript off
transcript file final_run.log
transcript on
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc -wlf buzzer.wlf work.tb_status_buzzer
onfinish stop
view wave
delete wave *
add wave -noupdate -label reset sim:/tb_status_buzzer/rst
add wave -noupdate -radix unsigned -label severity_0G_1Y_2R sim:/tb_status_buzzer/severity
add wave -noupdate -label BUZZER_pin sim:/tb_status_buzzer/buzzer
add wave -noupdate -radix decimal -label PCM sim:/tb_status_buzzer/pcm
add wave -noupdate -radix unsigned -label red_cadence_cycles sim:/tb_status_buzzer/dut/red_cadence
add wave -noupdate -radix decimal -label errors sim:/tb_status_buzzer/errors
configure wave -namecolwidth 280
configure wave -valuecolwidth 130
configure wave -rowmargin 8
update
onbreak {resume}
run -all
set errors [examine -radix decimal sim:/tb_status_buzzer/errors]
echo "EVIDENCE_BUZZER errors=$errors"
wave zoom full
update





set h [open assertions.log r]
set content [read $h]
close $h
echo $content
