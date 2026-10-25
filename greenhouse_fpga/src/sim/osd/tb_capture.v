`timescale 1ns/1ps
// Visual inspection only. Functional controls are independently asserted in tb_osd.
module tb_capture;
reg clk=0;always #5 clk=~clk;
reg rst=1;reg [9:0] x=0,y=0;reg de=0;wire [23:0] rgb;wire ho,vo,dout,no,mn,ma;wire [9:0] xo;
osd_overlay_mixer dut(clk,rst,1'b1,1'b1,24'h203828,1'b1,1'b1,de,1'b0,x,y,1'b0,3'd0,rgb,ho,vo,dout,no,xo,mn,ma,,,,1'b0,,,,,,,);
reg [7:0] t,h,l;integer xx,yy,mode,fd,i;reg [1:0] page_mode;
initial begin
repeat(5)@(negedge clk);rst=0;
for(mode=0;mode<3;mode=mode+1)begin
page_mode=mode;force dut.transition.display_page=page_mode;
x=0;y=480;@(negedge clk);x=1;repeat(700)@(negedge clk);
// Give renderer nonempty historical data for visual review of all 3 traces.
force dut.wave.count=128;force dut.wave.wp=0;
for(i=0;i<128;i=i+1)begin t=20+i%25;h=40+i%40;l=30+i%60;dut.wave.history[i]={t,h,l};end
case(mode)0:fd=$fopen("monitor.ppm","wb");1:fd=$fopen("thresholds.ppm","wb");2:fd=$fopen("simulation.ppm","wb");endcase
$fwrite(fd,"P6\n640 480\n255\n");
for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
@(negedge clk);x=xx;y=yy;de=1;
repeat(3)@(negedge clk);
$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
end
$fclose(fd);
end
$display("CAPTURE_COMPLETE");$finish;
end
endmodule