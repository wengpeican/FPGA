catch {quit -sim}
# Run after changing to this script directory in ModelSim.

transcript off
transcript file final_run.log
transcript on
if {![file exists work]} {vlib work}
vmap work work
vlog -sv -f files.f
vsim -voptargs=+acc -wlf history.wlf work.tb_wave_persist
onfinish stop
view wave
delete wave *
add wave -noupdate -label KEY2_active_low sim:/tb_wave_persist/k1
add wave -noupdate -radix unsigned -label zone_0A_1B_2C_3D sim:/tb_wave_persist/dut/ui/zone
add wave -noupdate -label sample_1Hz sim:/tb_wave_persist/dut/sample_now
add wave -noupdate -radix decimal -label sample_total sim:/tb_wave_persist/samples
add wave -noupdate -radix unsigned -label history_count_max128 sim:/tb_wave_persist/dut/wave/count
add wave -noupdate -radix unsigned -label ring_write_pointer sim:/tb_wave_persist/dut/wave/wp
add wave -noupdate -radix decimal -label checks sim:/tb_wave_persist/checks
add wave -noupdate -radix decimal -label errors sim:/tb_wave_persist/errors
configure wave -namecolwidth 280
configure wave -valuecolwidth 130
configure wave -rowmargin 8
update
onbreak {resume}
run -all
set errors [examine -radix decimal sim:/tb_wave_persist/errors]
echo "EVIDENCE_HISTORY errors=$errors"
wave zoom full
update





set h [open wave_persist_assertions.log r]
set content [read $h]
close $h
echo $content
