`timescale 1ns/1ps
module tb_monitor_fade_pixels;
reg clk=0;always #5 clk=~clk;
reg rst=1,de=0,request=0;reg [9:0] x=0,y=0;reg [2:0] resource=0;
wire [23:0] rgb;wire black;
osd_overlay_mixer dut(.clk(clk),.rst(rst),.key1_n(1'b1),.key2_n(1'b1),
 .rgb_in(24'h80c040),.hs(1'b1),.vs(1'b1),.de(de),.next_line(1'b0),.x(x),.y(y),
 .media_valid(1'b1),.media_zone(resource),.rgb_out(rgb),.switch_request(request),.switch_black(black));
integer errors=0,i,fd;reg [2:0] level;reg [23:0] expected;
task tick(input integer n);begin repeat(n)@(negedge clk);#1;end endtask
task check(input ok,input [511:0] msg);begin if(ok!==1'b1)begin errors=errors+1;$display("FAIL %0s",msg);end end endtask
task blank;begin de=0;x=0;y=480;tick(1);x=1;tick(3);end endtask
task pixel;begin de=1;x=620;y=430;tick(3);end endtask
task brightness;begin
level=dut.shade;pixel();expected=level>=4?0:{(8'h80>>level),(8'hc0>>level),(8'h40>>level)};
check(rgb===expected,"whole RGB stream obeys monitor fade brightness");
tick(20);check(dut.shade==level,"brightness stable throughout active frame");
end endtask
initial begin
tick(5);rst=0;de=1;x=0;y=0;tick(4);blank();tick(650);
brightness();check(rgb==24'h80c040,"initial full brightness");
request=1;tick(5);blank();check(dut.monitor_busy,"starts at blank");
for(i=0;i<8;i=i+1)begin blank();brightness();end
check(black && rgb==0,"black before buffer acknowledgement");
for(i=0;i<5;i=i+1)begin blank();brightness();check(black,"wait for storage to consume acknowledgement");end
resource=1;de=1;x=0;y=0;tick(4);request=0;tick(5);blank();
for(i=0;i<9;i=i+1)begin brightness();blank();end
check(!dut.monitor_busy && !black && dut.shade==0,"new image returns to full brightness");
// Cancel between request and commit; recover the old picture within bounded frames.
request=1;tick(5);blank();request=0;tick(5);
for(i=0;i<24;i=i+1)begin blank();brightness();end
check(!dut.monitor_busy && dut.shade==0,"cancelled request cannot leave a permanent black screen");
fd=$fopen("monitor_fade_pixels_result.txt","w");$fdisplay(fd,"errors=%0d",errors);$fclose(fd);
$display("MONITOR_FADE_PIXELS_RESULT errors=%0d",errors);$finish;
end
initial begin #1000000;errors=errors+1;$display("MONITOR_FADE_PIXELS_TIMEOUT");$finish;end
endmodule
