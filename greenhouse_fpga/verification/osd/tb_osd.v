`timescale 1ns/1ps
module tb_osd;
reg clk=0;always #20 clk=~clk;
reg rst=1,k1=1,k2=1;reg [9:0] x=0,y=0;reg de=0,hs=1,vs=1,nl=0;reg [23:0] bg=24'h123456;
wire [23:0] rgb;wire ho,vo,dout,no,mnext,mauto;wire [9:0] xo;
osd_overlay_mixer #(.CLK_HZ(1000000)) dut(clk,rst,k1,k2,bg,hs,vs,de,nl,x,y,1'b0,3'd0,rgb,ho,vo,dout,no,xo,mnext,mauto,,,,1'b0,,,,,,,);
integer errors=0,fd,i,j;reg [35:0] bundle1,bundle2;reg [35:0] expected;
reg check_bg=0,free1=0,free2=0,expected_free;reg [23:0] bg_delay1,bg_delay2,expected_bg;
// Full bundle three-clock latency checked on EVERY clock, including transitions.
always @(posedge clk)begin
 if(rst)begin bundle1={1'b1,1'b1,1'b0,1'b0,10'd0,22'd0};bundle2=bundle1;free1=0;free2=0;bg_delay1=0;bg_delay2=0;end
 else begin
 expected=bundle2;bundle2=bundle1;bundle1={hs,vs,de,nl,x,22'd0};
 expected_bg=bg_delay2;bg_delay2=bg_delay1;bg_delay1=bg;
 expected_free=free2;free2=free1;free1=check_bg;
 #1;if({ho,vo,dout,no,xo}!==expected[35:22])begin errors=errors+1;$fdisplay(fd,"FAIL timing alignment %0t",$time);end
 if(!dout && rgb!==24'd0)begin errors=errors+1;$fdisplay(fd,"FAIL blank RGB");end
 if(expected_free && dout && rgb!==expected_bg)begin errors=errors+1;$fdisplay(fd,"FAIL streaming background latency");end
 end
end
 task check(input ok,input [511:0] message);begin if(ok!==1'b1)begin errors=errors+1;$fdisplay(fd,"FAIL %0t %0s",$time,message);end end endtask
 task tick(input integer cycles);begin repeat(cycles)@(negedge clk);#2;end endtask
 task blank;begin @(negedge clk);x=0;y=480;de=0;tick(1);x=10;tick(650);end endtask
 task pixel(input [9:0] xx,yy);begin @(negedge clk);x=xx;y=yy;de=1;tick(3);end endtask
 // Direct unit tests: boundary edits, automatic timer and transition frame pacing.
reg us1=0,ul1=0,us2=0,ul2=0;wire [1:0] page,zone;wire [4:0] field;wire ar;
wire [383:0] th;wire inc,dec;wire [3:0] sf;wire mn,ma,pc;
ui_page_ctrl #(.CLK_HZ(1000)) ui(clk,rst,1'b0,us1,ul1,us2,ul2,1'b0,page,zone,field,ar,th,inc,dec,sf,mn,ma,pc);
reg f=0,request=0;reg [1:0] target=0;wire [1:0] dp;wire busy;wire [2:0] shade;
page_transition_ctrl trans(clk,rst,f,request,target,dp,busy,shade);
reg btn=1;wire sp,lp;integer shorts=0,longs=0;
osd_button #(.CLK_HZ(1000)) button(clk,rst,btn,sp,lp);
always @(negedge clk)begin if(sp)shorts=shorts+1;if(lp)longs=longs+1;end
reg sample=0;reg [191:0] wvalues=0;reg [1:0] wz=0;reg [9:0] wx=64,wy=349,expected_base;wire wh;wire [23:0] wrgb;
trend_waveform_draw wave(clk,rst,sample,wz,wvalues,wx,wy,1'b1,wh,wrgb);
reg [191:0] aval;reg [383:0] ath;wire [7:0] states;
alarm_threshold_cmp alarm(clk,rst,aval,ath,states);
wire [191:0] simvalues;wire sv;reg si=0,sd=0;reg [3:0] edit=0;
sim_sensor_data_gen #(.CLK_HZ(1000000)) simgen(clk,rst,1'b1,si,sd,edit,simvalues,sv);
reg [1:0] expected_zone;
task event1;begin ul1=1;tick(1);ul1=0;tick(1);end endtask
task selectfield;begin us1=1;tick(1);us1=0;tick(1);end endtask
initial begin
 fd=$fopen("assertions.log","w");aval=0;ath=0;tick(10);rst=0;tick(2);blank();
 check(dut.text_ready,"BCD ready before next visible frame");
 check(dut.text_layer.bcd[0]==16'h0025,"temperature BCD");
 check(dut.text_layer.bcd[2]==16'h1000,"four digit light BCD");
 check(dut.text_layer.bcd[17]==16'h2800,"threshold BCD");
 check(dut.text_layer.bcd[12]==16'h0019 && dut.text_layer.bcd[13]==16'h0034 && dut.text_layer.bcd[14]==16'h0033 &&
  dut.text_layer.bcd[15]==16'h0077 && dut.text_layer.bcd[16]==16'h0850,"balanced default thresholds");
 pixel(33,16);check(rgb==bg,"BMP title unobscured");
 pixel(320,82);check(rgb==24'h008040,"normal green A status border");
 force dut.frame_zone=2;pixel(260,89);check(rgb==24'hdc2020,"alarm red C status border");release dut.frame_zone;
 pixel(620,240);check(rgb==bg,"transparent OSD background");
 // Colors and differences at the threshold boundaries (including low=0).
 aval={12{16'd25}};ath={24{16'd30}};
 for(i=0;i<12;i=i+1)begin ath[i*32+:16]=20;ath[i*32+16+:16]=30;end
 tick(3);check(states==8'h55,"light warning band applies independently");
 aval[15:0]=19;tick(3);check(states[1:0]==2,"out of range outranks warning");
 ath[15:0]=0;ath[31:16]=1;aval[15:0]=0;tick(3);check(states[1:0]==1,"no unsigned threshold underflow");
 // Per-type warning bands on zone A with the balanced defaults: temp 1, humidity 4, light 100.
 ath[95:0]={16'd2800,16'd850,16'd77,16'd33,16'd34,16'd19};
 aval[47:0]={16'd1500,16'd50,16'd25};tick(3);check(states[1:0]==0,"band reference green");
 aval[15:0]=20;tick(3);check(states[1:0]==1,"temperature band 1 low edge");
 aval[15:0]=21;tick(3);check(states[1:0]==0,"temperature outside band 1");
 aval[15:0]=33;tick(3);check(states[1:0]==1,"temperature band 1 high edge");aval[15:0]=25;
 aval[31:16]=37;tick(3);check(states[1:0]==1,"humidity band 4 low edge");
 aval[31:16]=38;tick(3);check(states[1:0]==0,"humidity outside band 4");
 aval[31:16]=73;tick(3);check(states[1:0]==1,"humidity band 4 high edge");
 aval[31:16]=78;tick(3);check(states[1:0]==2,"humidity above high limit");aval[31:16]=50;
 aval[47:32]=950;tick(3);check(states[1:0]==1,"light band 100 low edge");
 aval[47:32]=1000;tick(3);check(states[1:0]==0,"light outside band 100");
 aval[47:32]=2700;tick(3);check(states[1:0]==1,"light band 100 high edge");
 aval[47:32]=2850;tick(3);check(states[1:0]==2,"light above high limit");
 // Debounce chatter cannot count as presses; long release cannot create short.
 btn=0;tick(5);btn=1;tick(30);check(shorts==0,"bounce rejected");
 btn=0;tick(30);btn=1;tick(30);check(shorts==1,"short release once");
 btn=0;tick(1100);btn=1;tick(30);check(longs==1 && shorts==1,"one long event with suppressed short");
 // UI automatic cadence is 3 seconds, not a truncated timer.
 us2=1;tick(1);us2=0;tick(2);expected_zone=zone;tick(2990);check(zone==expected_zone,"no early auto advance");tick(12);check(zone==expected_zone+2'd1,"3 second auto advance");
 us2=1;tick(1);us2=0;tick(1);
 event1();check(page==1,"threshold page");
 for(i=0;i<100;i=i+1)begin us2=1;tick(1);us2=0;tick(1);end
 check(th[15:0]==34 && th[31:16]==34,"low limit clamps to high limit");
 selectfield();for(i=0;i<100;i=i+1)begin ul2=1;tick(1);ul2=0;tick(1);end
 check(th[15:0]==34 && th[31:16]==34,"high limit cannot cross low limit");
 for(i=0;i<23;i=i+1)selectfield();check(field==0,"24 fields wrap");
 event1();check(page==2,"simulation edit page");
 for(i=0;i<12;i=i+1)selectfield();check(sf==0,"12 simulated values wrap");
 si=1;tick(100);si=0;tick(2);check(simvalues[15:0]==80,"temperature increase saturates");
 sd=1;tick(100);sd=0;tick(2);check(simvalues[15:0]==0,"temperature decrease saturates");
 edit=2;si=1;tick(100);si=0;tick(2);check(simvalues[47:32]==4095,"light increase saturates");
 // Transition waits for vertical blank and advances once per frame.
 target=1;request=1;tick(1);request=0;tick(20);check(!busy && dp==0,"transition waits blank");
 f=1;tick(1);f=0;tick(100);check(busy && shade==0,"blank pixels do not advance fade");
 for(i=0;i<17;i=i+1)begin f=1;tick(1);f=0;tick(3);end
 check(!busy && dp==1 && shade==0,"fade completes with unchanged timing");
 // Synchronous history: empty samples masked, all three channels, zone clear.
 check(!wh,"no uninitialized waveform pixels");wvalues[15:0]=25;wvalues[31:16]=60;wvalues[47:32]=1024;
 sample=1;tick(1);sample=0;tick(3);check(wh && wrgb==24'h007e98,"temperature curve");
 wy=314;tick(3);check(wh && wrgb==24'hb07800,"humidity curve");
 wy=342;tick(3);check(wh && wrgb==24'h9830b0,"light curve");
 wx=576;tick(3);check(!wh,"waveform clipping");
 // Per-zone persistent history: switching zones never clears, every zone samples.
 wz=1;wx=64;wy=375;tick(4);check(wave.count==1 && wh && wrgb==24'h007e98,"zone switch keeps history; hidden zone B sampled its own data");
 for(i=0;i<4;i=i+1)begin wvalues[(i*3)*16+:16]=20+i;wvalues[(i*3+1)*16+:16]=50+i;wvalues[(i*3+2)*16+:16]=32*(10+i);end
 sample=1;tick(1);sample=0;tick(5);
 for(i=0;i<4;i=i+1)begin
  wz=i;wx=64;expected_base=i==0?374:i==1?375:i==2?387:415;
  wy=expected_base-(20+i);tick(3);check(wh && wrgb==24'h007e98,"newest temperature per zone");
  wy=expected_base-(50+i);tick(3);check(wh && wrgb==24'hb07800,"newest humidity per zone");
  wy=expected_base-(10+i);tick(3);check(wh && wrgb==24'h9830b0,"newest light per zone");
 end
 // Rapid zone switching without samples leaves every curve untouched.
 for(i=0;i<20;i=i+1)begin wz=i[1:0];tick(2);end
 wz=0;wx=68;wy=349;tick(3);check(wave.count==2 && wh && wrgb==24'h007e98,"previous A sample survives zone switching");
 wy=314;tick(3);check(wh && wrgb==24'hb07800,"previous A humidity survives");
 wy=342;tick(3);check(wh && wrgb==24'h9830b0,"previous A light survives");
 // Keep sampling while zone C is displayed; A continues from where it left off.
 wz=2;
 for(i=0;i<130;i=i+1)begin wvalues[15:0]=30+(i%10);wvalues[63:48]=40-(i%10);sample=1;tick(1);sample=0;tick(5);end
 check(wave.count==128,"history saturates at 128 points");
 wz=0;wx=64;wy=374-(30+129%10);tick(3);check(wh && wrgb==24'h007e98,"A advanced while hidden (newest)");
 wx=64+4*127;wy=374-(30+2%10);tick(3);check(wh && wrgb==24'h007e98,"A oldest of 128 after wrap");
 wz=1;wx=64;wy=375-(40-129%10);tick(3);check(wh && wrgb==24'h007e98,"B advanced while hidden (newest)");
 wz=3;wx=64;wy=415-23;tick(3);check(wh && wrgb==24'h007e98,"D unchanged channel holds its value");
 wx=576;tick(3);check(!wh,"waveform clipping after wrap");
 // Vary entire timing bundle and coordinates, not just DE.
 for(i=0;i<100;i=i+1)begin x=i;y=240;de=i[0];hs=i[1];vs=i[2];nl=i[3];tick(1);end
 // Pixel-changing input exposes RGB skew that a held-pixel screenshot cannot.
 check_bg=1;
 for(i=0;i<100;i=i+1)begin x=i;y=430;de=i[0];hs=i[1];vs=i[2];nl=i[3];bg=24'h312041+i*24'h010203;tick(1);end
 check_bg=0;tick(4);
 $fdisplay(fd,"OSD_RESULT errors=%0d",errors);$fclose(fd);$display("OSD_RESULT errors=%0d",errors);$finish;
end
initial begin #20000000;$display("OSD_TIMEOUT");$finish;end
endmodule
