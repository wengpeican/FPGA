`timescale 1ns/1ps
// System-level: full osd_overlay_mixer with real key1 page switching (A->B->C->D->A)
// and real simulated data. Each zone's history must keep growing across switches
// and match the generator values captured at every sample, for all four zones.
module tb_wave_persist;
reg clk=0;always #250000 clk=~clk;
reg rst=1,k1=1;reg [9:0] x=0,y=0;reg de=0;
wire [23:0] rgb;wire ho,vo,dout,no,mn,ma;wire [9:0] xo;
// CLK_HZ=2000: data updates every 2000 clocks; 20 ms debounce = 40 clocks.
osd_overlay_mixer #(.CLK_HZ(2000)) dut(clk,rst,k1,1'b1,24'h203828,1'b1,1'b1,de,1'b0,x,y,1'b0,3'd0,rgb,ho,vo,dout,no,xo,mn,ma,,,,1'b0,,,,,,,);
integer errors=0,checks=0,fd,i,z,n,samples,s;
reg [23:0] ref_hist[0:3][0:1023];
reg [7:0] tt,hh,ll;reg [15:0] tv,hv,lv;
task check;input ok;input [511:0] msg;begin
checks=checks+1;if(ok!==1'b1)begin errors=errors+1;$fdisplay(fd,"FAIL %0t %0s",$time,msg);end end endtask
// Drive one frame-blank pulse (x==0,y==480) every 500 clocks.
always begin
repeat(499)@(negedge clk);x=0;y=480;@(negedge clk);x=1;y=479;
end
// Reference model: record the packed sample for all four zones at every real sample.
always @(posedge clk)if(!rst && dut.sample_now)begin
for(z=0;z<4;z=z+1)begin
tv=dut.values[(z*3)*16+:16];hv=dut.values[(z*3+1)*16+:16];lv=dut.values[(z*3+2)*16+:16];
tt=tv>80?80:tv[7:0];hh=hv>100?100:hv[7:0];ll=lv>4095?127:lv[11:5];
ref_hist[z][samples]={tt,hh,ll};
end
samples=samples+1;
end
task key1_short;begin k1=0;repeat(100)@(negedge clk);k1=1;repeat(100)@(negedge clk);end endtask
task verify_all;input [511:0] msg;integer zz,kk,lim,idx;begin
lim=samples<128?samples:128;
check(dut.wave.count==lim,"sample counter keeps running across switches");
for(zz=0;zz<4;zz=zz+1)for(kk=0;kk<lim;kk=kk+1)begin
idx=samples-1-kk;
check(dut.wave.history[{zz[1:0],dut.wave.wp-7'd1-kk[6:0]}]==ref_hist[zz][idx],msg);
end end endtask
initial begin
fd=$fopen("wave_persist_assertions.log","w");samples=0;
repeat(5)@(negedge clk);rst=0;
for(s=0;s<12;s=s+1)begin
// About 10 data updates per displayed zone, then switch with KEY2 (key1 port).
repeat(10)@(posedge dut.data_valid);
repeat(1200)@(negedge clk);
verify_all("all four zones hold exact continuous history");
n=dut.wave.count;
key1_short;
check(dut.ui.zone==((s+1)%4),"key1 short press advances zone");
repeat(1200)@(negedge clk);
check(dut.wave.count>=n,"history not cleared by page switch");
end
// 12 switches x ~10 samples wraps the 128-entry ring: verify after wrap too.
repeat(20)@(posedge dut.data_valid);repeat(1200)@(negedge clk);
check(samples>128,"ring buffer wrapped during test");
verify_all("history exact after ring wrap");
$fdisplay(fd,"WAVE_PERSIST_RESULT errors=%0d checks=%0d samples=%0d",errors,checks,samples);
$display("WAVE_PERSIST_RESULT errors=%0d checks=%0d samples=%0d",errors,checks,samples);
$fclose(fd);$finish;
end
initial begin #(64'd400000000000);$display("WAVE_PERSIST_TIMEOUT");$finish;end
endmodule

