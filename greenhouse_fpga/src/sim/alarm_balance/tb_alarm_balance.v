`timescale 1ns/1ps
// Runs the real RTL defaults (ui_page_ctrl reset thresholds) against the real
// simulated data generator for one full common period (2400 updates) and checks
// that every zone spends a balanced share of time in green/yellow/red.
module tb_alarm_balance;
reg clk=0;always #5 clk=~clk;
reg rst=1;
wire [1:0] page,zone;wire [4:0] field;wire auto_run,si,sd,mn,ma,pc;wire [3:0] sf;
wire [383:0] thresholds;wire [191:0] values;wire valid;wire [7:0] states;
ui_page_ctrl #(.CLK_HZ(4)) ui(clk,rst,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,page,zone,field,auto_run,thresholds,si,sd,sf,mn,ma,pc);
sim_sensor_data_gen #(.CLK_HZ(4)) gen(clk,rst,1'b0,1'b0,1'b0,4'd0,values,valid);
alarm_threshold_cmp cmp(clk,rst,values,thresholds,states);
integer errors=0,checks=0,fd,z,c,t,n,run,longest,all_red;
integer count[0:3][0:2];
reg [1:0] s;
task check;input ok;input [511:0] msg;begin
checks=checks+1;if(ok!==1'b1)begin errors=errors+1;$fdisplay(fd,"FAIL %0s",msg);$display("FAIL %0s",msg);end end endtask
initial begin
fd=$fopen("assertions.log","w");
for(z=0;z<4;z=z+1)for(c=0;c<3;c=c+1)count[z][c]=0;
longest=0;run=0;all_red=0;
repeat(3)@(negedge clk);rst=0;
// Reset demo: zone A green, zone C red.
repeat(3)@(negedge clk);
check(states[1:0]==0,"reset zone A green");check(states[5:4]==2,"reset zone C red");
for(t=0;t<2400;t=t+1)begin
// Sample the state of the values present before each 1 s update (two compare cycles settled).
for(z=0;z<4;z=z+1)begin s=states[z*2+:2];count[z][s]=count[z][s]+1;end
if(states==8'haa)all_red=all_red+1;
run=states[1:0]==2?run+1:0;if(run>longest)longest=run;
@(posedge valid);repeat(3)@(negedge clk);
end
for(z=0;z<4;z=z+1)begin
$fdisplay(fd,"zone %0d green=%0d yellow=%0d red=%0d of 2400",z,count[z][0],count[z][1],count[z][2]);
$display("zone %0d green=%0d yellow=%0d red=%0d of 2400",z,count[z][0],count[z][1],count[z][2]);
// Each colour 30%..37% of the period (720..888 s) in every zone.
for(c=0;c<3;c=c+1)check(count[z][c]>=720 && count[z][c]<=888,"balanced colour share per zone");
end
check(all_red<=24,"four zones rarely red together");
check(longest<=30,"zone A red never lasts more than 30 s");
$fdisplay(fd,"all_red=%0d longest_red_A=%0d",all_red,longest);
$fdisplay(fd,"ALARM_BALANCE_RESULT errors=%0d checks=%0d",errors,checks);
$display("all_red=%0d longest_red_A=%0d",all_red,longest);
$display("ALARM_BALANCE_RESULT errors=%0d checks=%0d",errors,checks);
$fclose(fd);$finish;
end
endmodule
