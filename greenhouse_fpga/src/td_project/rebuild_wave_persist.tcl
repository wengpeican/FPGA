# Rebuild directly from the GUI project, never from a stale generated .prj.
set lesson6_project_dir [file dirname [file normalize [info script]]]
set lesson6_src_dir [file dirname $lesson6_project_dir]
set lesson6_build_dir [file join $lesson6_project_dir lab_ex4_tf_lesson6_fat32_Runs verified]
file mkdir $lesson6_build_dir
file mkdir [file join $lesson6_src_dir new]
cd $lesson6_build_dir
set f [open [file join $lesson6_project_dir lab_ex4_tf_lesson6_fat32.al] r]
set xml [read $f]
close $f
set xml [string map [list {Path="../} "Path=\"$lesson6_src_dir/" {Path="al_ip/} "Path=\"$lesson6_project_dir/al_ip/"] $xml]
set f [open lab_ex4_tf_lesson6_fat32.prj w]
puts $f $xml
close $f
import_device eagle_s20.db -package EG4S20BG256
open_project [file join $lesson6_project_dir {lab_ex4_tf_lesson6_fat32_Runs/verified/lab_ex4_tf_lesson6_fat32.prj}]
elaborate -top top
read_adc [file join $lesson6_src_dir {user_source/constraints_source/pin.adc}]
read_sdc [file join $lesson6_src_dir {user_source/constraints_source/timing.sdc}]
read_sdc -ip rfifo_32_32_512 [file join $lesson6_src_dir {user_source/hdl_source/ip/afifo_32_16_256.tcl}]
read_sdc -ip wfifo_32_32_512 [file join $lesson6_src_dir {user_source/hdl_source/ip/afifo_16_32_256.tcl}]
insert_debugger
optimize_rtl
optimize_gate -packarea lesson6_fixed_gate.area
legalize_phy_inst
place
phys_opt -post_place -effort ultra
route
update_timing -mode final
report_timing_summary -file lesson6_fixed_timing.rpt
report_timing_status -file lesson6_fixed_status.txt
report_area -io_info -file lesson6_fixed_area.rpt
export_db lesson6_fixed_routed.db
# A generated bit is deliverable only after the routed timing checks pass.
set osd_timing_handle [open lesson6_fixed_timing.rpt r]
set osd_timing_text [read $osd_timing_handle]
close $osd_timing_handle
if {![regexp {SWNS: *([-+0-9.]+)ns} $osd_timing_text all osd_setup]} {error "Missing setup timing result"}
if {![regexp {HWNS: *([-+0-9.]+)ns} $osd_timing_text all osd_hold]} {error "Missing hold timing result"}
if {$osd_setup < 0 || $osd_hold < 0} {error "Timing failed: setup=$osd_setup hold=$osd_hold"}
bitgen -bit greenhouse_wave_persist_20261019.bit
file copy -force greenhouse_wave_persist_20261019.bit [file join $lesson6_src_dir {new/greenhouse_wave_persist_20261019.bit}]
file copy -force lesson6_fixed_timing.rpt [file join $lesson6_src_dir {new/greenhouse_wave_persist_timing.rpt}]
file copy -force lesson6_fixed_area.rpt [file join $lesson6_src_dir {new/greenhouse_wave_persist_area.rpt}]
puts "LESSON6_FAT32_BUILD_COMPLETE"
