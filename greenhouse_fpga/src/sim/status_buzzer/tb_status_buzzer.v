`timescale 1ns/1ps
module tb_status_buzzer;
reg clk=0;always #5 clk=~clk;
reg rst=1;reg [1:0] severity=0;
wire valid,overflow,blip,buzzer;
wire signed [15:0] pcm,right;
pcm_media_tone #(.STATUS_AUDIO(1),.CLOCK_HZ(480000)) tone(
 .clk(clk),.rst_n(~rst),.media_id(2'd0),.volume(8'd128),
 .alarm_status(severity),.sample_valid(valid),.sample_ready(1'b1),
 .sample_left(pcm),.sample_right(right),.overflow(overflow),.blip_active(blip));
status_buzzer_output #(.CLOCK_HZ(480000)) dut(clk,rst,valid,pcm,severity,buzzer);
integer errors=0,n,i,rises,quiet,note_changes;
integer fd; initial fd=$fopen("assertions.log","w");
reg old_level,expected_level;
task check; input ok;input [511:0] msg;
 begin if(ok!==1'b1)begin errors=errors+1;if(errors<20)begin $display("FAIL %0s",msg);$fdisplay(fd,"FAIL %0s",msg);end end end
endtask
// Independent cadence windows, measured from sample number after reset.
// A one-sample tolerance covers the registered status update and FIFO latency.
task run_state; input [1:0] state;input integer samples,lo,hi;
 integer local_sample,first_quiet,quiet_count;reg prior,expected;
 begin
 @(negedge clk);rst=1;severity=state;
 repeat(3)@(negedge clk);check(!buzzer,"reset silences physical output");
 rst=0;local_sample=0;rises=0;quiet_count=0;prior=0;
 while(local_sample<samples)begin
 @(posedge clk);
 if(valid)begin
 expected=pcm>0;
 #1;
 if(state==1)check(buzzer===expected,"yellow equals unchanged PCM sign waveform");
 if(state==0)check(!buzzer,"green is silent");
 if(buzzer && !prior)rises=rises+1;
 prior=buzzer;
 // The PCM observation lags the direct red clock by one sample at wrap.
 if((state==1 && local_sample>=19201) || (state==2 && local_sample>=4801 && local_sample<5999))begin
 check(!buzzer,"buzzer low throughout cadence silence");quiet_count=quiet_count+1;
 end
 local_sample=local_sample+1;
 end else begin
 expected=buzzer;#1;if(state!=2)check(buzzer===expected,"hold level between PCM samples");
 end
 check(!overflow && !blip,"no FIFO error or page cue");
 end
 check(rises>=lo && rises<=hi,"audible pitch measured at buzzer pin");
 if(state!=0)check(quiet_count>100,"silence window observed");
 $display("BUZZER state=%0d samples=%0d rising_edges=%0d quiet_samples=%0d",state,samples,rises,quiet_count);
 $fdisplay(fd,"BUZZER state=%0d samples=%0d rising_edges=%0d quiet_samples=%0d",state,samples,rises,quiet_count);
 end
endtask
// Measure the physical output every clock over one complete red cadence.
// 200 cycles, 50% duty during 100ms ON, then 25ms quiet; compare old sign drive.
task red_drive_test;
 integer j,high_cycles,old_high_cycles,edges;reg prev;
 begin
 @(negedge clk);rst=1;severity=2;repeat(3)@(negedge clk);rst=0;
 high_cycles=0;old_high_cycles=0;edges=0;prev=0;
 for(j=0;j<60000;j=j+1)begin
  @(posedge clk);#1;
  if(buzzer)high_cycles=high_cycles+1;
  if(buzzer && !prev)edges=edges+1;
  prev=buzzer;
  if(pcm>0 && valid)old_high_cycles=old_high_cycles+10;
  if(j>=48000)check(!buzzer,"red 25ms gap remains silent");
 end
 check(high_cycles==24000,"red ON waveform has exactly 50 percent duty");
 check(edges==200,"red tone remains exactly 2kHz");
 check(high_cycles>old_high_cycles,"red positive drive exceeds old PCM sign drive");
 $fdisplay(fd,"RED_DRIVE high=%0d old_high=%0d edges=%0d",high_cycles,old_high_cycles,edges);
 end
endtask
initial begin
 red_drive_test;
 run_state(0,48000,0,0);     // normal: green status is silent.
 run_state(1,48000,260,275); // warning: approximately 660Hz for 0.4s.
 run_state(2,6000,190,210);  // error: approximately 2kHz, urgent cadence.
 run_state(1,48000,260,275);
 run_state(0,48000,0,0);
 // Reset while the speaker is high, without waiting for another PCM sample.
 @(negedge clk);severity=2;
 while(!buzzer)@(negedge clk);
 // Return to green without reset: queued PCM must drain to silence promptly.
 severity=0;repeat(100)@(negedge clk);
 repeat(1000)begin @(negedge clk);check(!buzzer,"live recovery to green silences pin");end
 severity=1;
 while(!buzzer)@(negedge clk);
 rst=1;#1;check(!buzzer,"asynchronous reset silences active speaker");
 $display("STATUS_BUZZER_RESULT errors=%0d",errors);
 $fdisplay(fd,"STATUS_BUZZER_RESULT errors=%0d",errors);$fclose(fd);
 n=$fopen("modelsim_result.txt","w");$fdisplay(n,"errors=%0d",errors);$fclose(n);
 $finish;
end
initial begin #100000000;$fatal(1,"watchdog");end
endmodule
