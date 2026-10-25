`timescale 1ns/1ps
module tb_status_audio;
reg clk=0;always #5 clk=~clk;
reg rst=1;reg [1:0] severity=0,media=0;reg ready=1;
reg [7:0] volume=128;
wire valid,overflow,blip;wire signed [15:0] left,right;
integer errors=0,n,k,on_count,off_count,nonzero;
integer logfd;
reg signed [15:0] held;
pcm_media_tone #(.STATUS_AUDIO(1),.CLOCK_HZ(480000)) dut(
.clk(clk),.rst_n(~rst),.media_id(media),.volume(volume),.alarm_status(severity),
.sample_valid(valid),.sample_ready(ready),.sample_left(left),.sample_right(right),.overflow(overflow),.blip_active(blip));
wire [1:0] global_status;
osd_overlay_mixer osd(.clk(clk),.rst(rst),.key1_n(1'b1),.key2_n(1'b1),.rgb_in(24'd0),.hs(1'b1),.vs(1'b1),.de(1'b0),.next_line(1'b0),.x(10'd0),.y(10'd0),.media_valid(1'b0),.media_zone(3'd0),.switch_request(1'b0),.audio_status(global_status));
task check(input ok,input [511:0] msg);begin
if(ok!==1'b1)begin errors=errors+1;if(errors<20)begin $display("FAIL %s",msg);$fdisplay(logfd,"FAIL %s",msg);end end end endtask
task ticks(input integer count);begin repeat(count)@(negedge clk);end endtask
task cycle_test(input [1:0] state,input integer count,input integer expected_on);
integer i,on_samples,quiet_samples,nz,peak,expected_peak;reg [19:0] phase_before;reg gate;
reg signed [15:0] expected_sample;
begin
severity=state;ticks(4);on_samples=0;quiet_samples=0;nz=0;peak=0;
expected_peak=(12000*volume*(state==2 ? 2 : 1))/256;
if(state==0)expected_peak=0;
// Observe one complete PCM cadence, independent of HDMI clock acceleration.
for(i=0;i<count;i=i+1)begin
 while(!dut.sample_push)@(negedge clk);
 gate=dut.audible;phase_before=dut.phase_inc;
 expected_sample=gate ? dut.scaled_clamped : 16'sd0;
 if(state==2)check(phase_before==43691,"urgent 2kHz pitch");
 if(state==1)check(phase_before==14418,"warning 660Hz pitch");
 if(gate)on_samples=on_samples+1;else quiet_samples=quiet_samples+1;
 @(negedge clk); // queued sample drains on following cycle
 check(valid,"PCM not dropped");
 check(left===right && left<=expected_peak && left>=-expected_peak-1,"stereo and unclipped amplitude");
 if(left>peak)peak=left;
 check(left===expected_sample,"FIFO preserves boosted PCM sample");
 if(!gate)check(left===0,"silent portion of cadence");
 if(left!=0)nz=nz+1;
 @(negedge clk);
end
check(on_samples==expected_on,"audible sample count per cycle");
check(quiet_samples==count-expected_on,"silent sample count per cycle");
if(state!=0 && volume!=0)check(nz>100,"nonzero PCM generated for audible status");
if(volume==0)check(nz==0,"zero volume stays silent");
check(peak==expected_peak,"exact gain: yellow unchanged, red doubled");
$display("HDMI_GAIN state=%0d volume=%0d peak=%0d expected=%0d",state,volume,peak,expected_peak);
$fdisplay(logfd,"HDMI_GAIN state=%0d volume=%0d peak=%0d expected=%0d",state,volume,peak,expected_peak);
end endtask
initial begin
logfd=$fopen("hdmi_gain_assertions.log","w");
ticks(8);rst=0;ticks(3);
force osd.states=8'h00;ticks(3);check(global_status==0,"all zones normal");
// The displayed zone, rather than the highest severity anywhere, drives audio.
// Put a red state in an off-screen zone and verify the selected green zone is silent.
force osd.frame_zone=2'd0;
force osd.states=8'h80;ticks(3);check(global_status==0,"off-screen error does not mask displayed green zone");
for(k=0;k<4;k=k+1)begin
 case(k)
 0:force osd.states=8'h01;
 1:force osd.states=8'h04;
 2:force osd.states=8'h10;
 3:force osd.states=8'h40;
 endcase
 force osd.frame_zone=k[1:0];
 ticks(3);check(global_status==1,"each zone can raise warning");
end
force osd.states=8'h91;force osd.frame_zone=2'd0;ticks(3);check(global_status==1,"displayed warning is selected");
force osd.frame_zone=2'd1;ticks(3);check(global_status==0,"displayed green is selected");
force osd.frame_zone=2'd2;ticks(3);check(global_status==1,"displayed warning remains selected");
force osd.frame_zone=2'd3;ticks(3);check(global_status==2,"displayed red is selected");
force osd.states=8'h00;ticks(3);check(global_status==0,"recovery clears severity");release osd.states;
release osd.frame_zone;
cycle_test(0,48000,0);
volume=255;cycle_test(1,48000,19200);cycle_test(2,6000,4800);
volume=0;cycle_test(1,48000,19200);cycle_test(2,6000,4800);
volume=128;
media=3;ticks(3);check(!blip,"page cue cannot override status audio");
cycle_test(1,48000,19200);
cycle_test(2,6000,4800);
cycle_test(1,48000,19200);
cycle_test(0,48000,0);
check(!overflow,"no overflow under normal consumption");
ready=0;while(!valid)@(negedge clk);held=left;ticks(25);
check(valid && left===held,"backpressure holds sample");
ready=1;ticks(20);rst=1;ticks(3);check(!valid && !overflow,"reset clears FIFO and errors");
$display("STATUS_AUDIO_RESULT errors=%0d",errors);
$fdisplay(logfd,"STATUS_AUDIO_RESULT errors=%0d",errors);$fclose(logfd);
n=$fopen("modelsim_result.txt","w");$fdisplay(n,"errors=%0d",errors);$fclose(n);$finish;
end
initial begin #50000000;$fatal(1,"timeout");end
endmodule
