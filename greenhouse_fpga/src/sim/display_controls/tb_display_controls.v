`timescale 1ns/1ps
module tb_display_controls;
reg clk=0;always #5 clk=~clk;
reg rst=1,frame=0,key_n=1;reg [1:0] sw_n=3;
wire [7:0] volume;wire [3:0] level,bri,con;wire [1:0] selected;wire show;
integer errors=0,checks=0,i,j,k,a,b,c,expected;
display_parameter_ctrl #(.CLK_HZ(1000)) ctrl(clk,rst,frame,key_n,sw_n,volume,level,bri,con,selected,show);
task check;input ok;input [511:0] msg;begin
checks=checks+1;if(ok!==1'b1)begin errors=errors+1;$display("FAIL %0s",msg);end end endtask
task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
task commit;begin frame=1;cycles(1);frame=0;end endtask
task tap;begin key_n=0;cycles(35);key_n=1;cycles(35);end endtask
task hold;begin key_n=0;cycles(1100);key_n=1;cycles(35);end endtask
task select_item;input [1:0] n;begin sw_n=~n;cycles(30);commit;end endtask

reg [23:0] pixel=0;reg [3:0] pbri=4,pcon=4;wire [23:0] adjusted;
video_display_adjust adj(clk,rst,pixel,pbri,pcon,adjusted);
function integer clamp;input integer v;begin clamp=v<0?0:v>255?255:v;end endfunction
// Integer reference model: part-selects are unsigned, so widen before subtracting.
function integer ref_channel;input [7:0] v;input [3:0] br,co;integer d,c,o;begin
d=v;d=d-128;c=co;o=br;o=(o-4)*16;
ref_channel=clamp(((d*c)>>>2)+128+o);
end endfunction
task pixel_test;input [23:0] p;input [3:0] br,co;integer r,g,b;begin
pixel=p;pbri=br;pcon=co;cycles(2);
r=ref_channel(p[23:16],br,co);
g=ref_channel(p[15:8],br,co);
b=ref_channel(p[7:0],br,co);
check(adjusted=={r[7:0],g[7:0],b[7:0]},"RGB signed arithmetic / saturation / two-cycle alignment");
end endtask

reg [9:0] hx=0,hy=12;wire hh;wire [23:0] hr;
reg [1:0] hsel=0;reg [3:0] hvol=5,hbri=4,hcon=4;
display_parameter_hud hud(clk,rst,1'b1,hsel,hvol,hbri,hcon,hx,hy,1'b1,hh,hr);
reg [7:0] expect_code [0:31];
// Chinese cell code: glyph index (see G_* in the HUD) and left/right half.
function [7:0] cj;input [3:0] g;input h;begin cj={3'b100,g,h};end endfunction
task expect_clear;integer n;begin for(n=0;n<32;n=n+1)expect_code[n]=32;end endtask
task expect_pair;input integer c;input [3:0] g;begin expect_code[c]=cj(g,0);expect_code[c+1]=cj(g,1);end endtask
task expect_text;input integer c;input [31:0] s;input integer n;integer m;begin
for(m=0;m<n;m=m+1)expect_code[c+m]=s[(n-1-m)*8+:8];end endtask
task expect_line1;input [23:0] v,b,cn;begin expect_clear;
expect_pair(0,0);expect_pair(2,1);expect_text(5,{v,"%"},4);
expect_pair(11,2);expect_pair(13,3);expect_text(16,b,3);
expect_pair(21,4);expect_pair(23,5);expect_pair(25,3);expect_text(28,{cn,"%"},4);end endtask
task check_line;input [9:0] row_y;input [511:0] msg;integer n;begin
hy=row_y;for(n=0;n<32;n=n+1)begin hx=16+n*8;#1;check(hud.code==expect_code[n],msg);end end endtask
task check_pixel;input [9:0] px,py;input [23:0] color;input [511:0] msg;
reg dot;reg [15:0] bits;reg [34:0] shape;integer c,r,p;begin
hx=px;hy=py;#1;c=hud.col;r=hud.dy;p=px-16-c*8;
bits=hud.cjk_row(hud.code[4:1],r[3:0]);shape=hud.font(hud.code);
dot=hud.code[7]?bits[15-(hud.code[0]*8+p)]:(r<14 && p<5 && shape[34-(r/2)*5-p]);
cycles(2);check(hh && hr==(dot?color:24'h102030),msg);end endtask
reg [23:0] mix_in=0;wire [23:0] mix_out;reg mh=0,mv=0,md=0,mn=0;
wire oh,ov,od,onl;wire [9:0] ox;wire next_n,auto_n;
osd_overlay_mixer #(.CLK_HZ(1000),.DISPLAY_CONTROLS(1)) mixer(
 .clk(clk),.rst(rst),.key1_n(1'b1),.key2_n(1'b1),.rgb_in(mix_in),
 .hs(mh),.vs(mv),.de(md),.next_line(mn),.x(10'd620),.y(10'd400),
 .media_valid(1'b0),.media_zone(3'd0),.rgb_out(mix_out),.hs_out(oh),.vs_out(ov),
 .de_out(od),.next_line_out(onl),.x_out(ox),.media_next_n(next_n),.media_auto_n(auto_n),
 .switch_request(1'b0),.control_volume(level),.control_brightness(bri),.control_contrast(con),
 .control_selected(selected),.control_show(show));
reg [23:0] delay0,delay1,delay2;
reg [3:0] t0,t1,t2;
initial begin
cycles(4);rst=0;cycles(4);
check(volume==128 && level==5 && bri==4 && con==4 && !show,"reset defaults");
// A contact bounce shorter than the debounce period must not change anything.
key_n=0;cycles(4);key_n=1;cycles(30);commit;
check(level==5,"button bounce rejection");
tap;check(level==5 && volume==128,"no change before frame blank");commit;
check(level==6 && volume==153 && show,"short press volume increase");
hold;commit;check(level==5,"long decrease exactly once, no release increment");
for(i=0;i<12;i=i+1)tap;commit;check(level==10 && volume==255,"upper volume clamp");
for(i=0;i<12;i=i+1)hold;commit;check(level==0 && volume==0,"lower volume clamp and HDMI mute");
select_item(1);tap;commit;check(bri==5 && level==0 && selected==1,"brightness independent selection");
for(i=0;i<6;i=i+1)tap;commit;check(bri==8,"brightness upper clamp");
for(i=0;i<10;i=i+1)hold;commit;check(bri==0,"brightness lower clamp");
select_item(2);tap;commit;check(con==5 && bri==0 && selected==2,"contrast independent selection");
for(i=0;i<6;i=i+1)tap;commit;check(con==8,"contrast upper clamp");
for(i=0;i<10;i=i+1)hold;commit;check(con==0,"contrast lower clamp");
select_item(3);tap;commit;check(level==0 && bri==0 && con==0,"reset requires hold");
hold;commit;check(volume==128 && level==5 && bri==4 && con==4,"restore all defaults");
check(next_n && auto_n && mixer.ui.page==0 && !mixer.ui.auto_run,"parameter key never triggers page or autoplay");
cycles(3100);commit;check(!show,"three-second popup timeout");
sw_n=3;cycles(5);sw_n=0;cycles(30);commit;check(selected==3,"DIP switch bounce rejection");
// Exhaustive 81 setting combinations with edge values and RGB asymmetry.
for(a=0;a<=8;a=a+1)for(b=0;b<=8;b=b+1)begin
pixel_test(24'h000000,a,b);pixel_test(24'hffffff,a,b);
pixel_test(24'h017ffe,a,b);pixel_test(24'h80c040,a,b);
end
for(i=0;i<256;i=i+1)pixel_test({i[7:0],i[7:0],i[7:0]},4,4);
// Continuous samples: prove no channel/pixel mixing through the pipeline.
pbri=4;pcon=4;delay0=0;delay1=0;
for(i=0;i<30;i=i+1)begin
pixel={i[7:0],8'd128,8'd255};cycles(1);
if(i>1)check(adjusted==delay0,"continuous adjusted pixel alignment");delay0=pixel;
end
// Chinese HUD: row 1 labels/values at defaults and at the limits.
expect_line1("050","+00","100");check_line(12,"HUD Chinese row 1 defaults");
hvol=10;hbri=0;hcon=8;expect_line1("100","-64","200");check_line(12,"HUD Chinese row 1 limits");
hvol=0;hbri=8;hcon=0;expect_line1("000","+64","000");check_line(12,"HUD Chinese row 1 zero/max");
hvol=5;hbri=4;hcon=4;
// Row 2 operating hint: KEY3 短按加 长按减 / 长按 KEY3 恢复默认.
expect_clear;expect_text(0,"KEY3",4);expect_pair(5,6);expect_pair(7,7);expect_pair(9,8);
expect_pair(12,9);expect_pair(14,7);expect_pair(16,10);check_line(32,"HUD Chinese row 2 hint");
hsel=3;expect_clear;expect_pair(0,9);expect_pair(2,7);expect_text(5,"KEY3",4);
expect_pair(10,11);expect_pair(12,12);expect_pair(14,13);expect_pair(16,14);check_line(32,"HUD Chinese reset hint");
hsel=0;
// Pixel-exact 16x16 glyphs for 音量 (highlighted), digits, and an unselected glyph.
for(i=0;i<32;i=i+1)for(j=0;j<16;j=j+1)check_pixel(16+i,12+j,24'hffe040,"HUD Chinese glyph pixels selected");
for(i=0;i<8;i=i+1)for(j=0;j<14;j=j+1)check_pixel(56+i,12+j,24'hffe040,"HUD digit pixels");
for(i=0;i<16;i=i+1)for(j=0;j<16;j=j+1)check_pixel(104+i,12+j,24'he0e8f0,"HUD Chinese glyph pixels unselected");
hsel=2;for(i=0;i<16;i=i+1)for(j=0;j<16;j=j+1)check_pixel(184+i,12+j,24'hffe040,"HUD contrast highlight");hsel=0;
check(hud.cjk_row(0,2)!=0 && hud.cjk_row(14,8)!=0,"HUD font table populated");
hx=8;hy=8;cycles(2);check(hh && hr==24'h102030,"HUD opaque panel alignment");
hx=400;cycles(2);check(!hh,"HUD clipping right");
hx=16;hy=52;cycles(2);check(!hh,"HUD clipping bottom");
// Complete timing bundle stays exactly three clocks with controls enabled.
delay0=0;delay1=0;delay2=0;t0=0;t1=0;t2=0;
for(i=0;i<60;i=i+1)begin
mix_in={i[7:0],8'h80,8'hfe};mh=i%2;mv=(i/2)%2;md=(i/3)%2;mn=(i/4)%2;
delay2=delay1;delay1=delay0;delay0=mix_in;t2=t1;t1=t0;t0={mh,mv,md,mn};cycles(1);
if(i>3)begin
check({oh,ov,od,onl}==t2,"enabled mixer full timing bundle three clocks");
check(mix_out==(t2[1]?delay2:24'd0),"enabled mixer default RGB identity / blanking");
end end
$display("RESULT errors=%0d checks=%0d",errors,checks);
$finish;
end
initial begin #10000000;$display("FAIL timeout");errors=errors+1;$finish;end
endmodule
