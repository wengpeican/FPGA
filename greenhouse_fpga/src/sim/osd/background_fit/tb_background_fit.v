`timescale 1ns/1ps
module tb_background_fit;
reg clk=0;always #5 clk=~clk;
reg rst=1,de=0;reg [9:0] x=0,y=0;reg [23:0] bg=0;
reg [2:0] resource=0;reg valid=1;
wire [23:0] rgb;wire ho,vo,dout,no,mn,ma;wire [9:0] xo;
osd_overlay_mixer dut(clk,rst,1'b1,1'b1,bg,1'b1,1'b1,de,1'b0,x,y,valid,resource,rgb,ho,vo,dout,no,xo,mn,ma,,,,1'b0,,,,,,,);
reg [23:0] pixels[0:307199];
integer errors=0,mode,xx,yy,i,fd,changed,ox,oy,sx,sy,ly,base,bx,by,br,bb,pos,j;
reg allowed;reg [7:0] t,h,l;reg [1:0] page_mode=0;
task check(input ok,input [511:0] msg);begin if(ok!==1'b1)begin errors=errors+1;if(errors<20)$display("FAIL %0s",msg);end end endtask
task tick(input integer n);begin repeat(n)@(negedge clk);#1;end endtask
initial begin
tick(5);rst=0;
force dut.transition.display_page=page_mode;
for(mode=0;mode<5;mode=mode+1)begin
resource=mode;
case(mode)
0:begin $readmemh("bg0.hex",pixels);ox=120;oy=88;sx=352;sy=116;ly=208;base=374;bx=320;by=82;br=587;bb=169;fd=$fopen("A.ppm","wb");end
1:begin $readmemh("bg1.hex",pixels);ox=100;oy=92;sx=296;sy=126;ly=224;base=375;bx=264;by=116;br=604;bb=152;fd=$fopen("B.ppm","wb");end
2:begin $readmemh("bg2.hex",pixels);ox=96;oy=90;sx=296;sy=118;ly=208;base=387;bx=260;by=89;br=592;bb=161;fd=$fopen("C.ppm","wb");end
3:begin $readmemh("bg3.hex",pixels);ox=96;oy=88;sx=288;sy=94;ly=212;base=415;bx=254;by=81;br=602;bb=122;fd=$fopen("D.ppm","wb");end
4:begin $readmemh("bg4.hex",pixels);fd=$fopen("PIC5.ppm","wb");end
endcase
de=0;x=0;y=480;tick(1);x=1;tick(650);
de=1;x=0;y=0;tick(4);
if(mode<4)check(dut.frame_zone==mode,"displayed resource controls selected zone, not UI timer");
else check(dut.render_page==1 && dut.frame_resource==4,"PIC5 tag selects threshold layout without wrapping to A");
// Dense deterministic history is injected only for preview and clipping assertions.
force dut.wave.count=128;force dut.wave.wp=0;
for(i=0;i<128;i=i+1)begin t=20+i%25;h=40+i%40;l=30+i%60;dut.wave.history[(mode%4)*128+i]={t,h,l};end
$fwrite(fd,"P6\n640 480\n255\n");changed=0;
for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
x=xx;y=yy;bg=pixels[yy*640+xx];tick(3);
$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
// Every pixel outside intended fields must preserve the original BMP exactly.
allowed=0;
for(j=0;j<3;j=j+1)begin pos=oy+(mode==0?34:mode==1?37:mode==2?30:34)*j;
if(xx>=ox && xx<ox+128 && yy>=pos && yy<pos+14)allowed=1;end
if(xx>=sx && xx<sx+224 && yy>=sy && yy<sy+14)allowed=1;
if(xx>=72 && xx<552 && yy>=ly && yy<ly+14)allowed=1;
if(xx>=64 && xx<576 && yy>=440 && yy<454)allowed=1;
if(xx>=64 && xx<576 && yy>=base-127 && yy<=base)allowed=1;
if(xx>=bx && xx<=br && yy>=by && yy<=bb && (xx<=bx+1 || xx>=br-1 || yy<=by+1 || yy>=bb-1))allowed=1;
if(mode==4)begin
allowed=0;
for(i=0;i<4;i=i+1)for(j=0;j<6;j=j+1)
if(xx>=110+j*84 && xx<182+j*84 && yy>=144+i*51 && yy<184+i*51)allowed=1;
end
if(!allowed)check(rgb===bg,"OSD changed a BMP title, label or area outside its allocated field");
if(rgb!==bg)changed=changed+1;
end
$fclose(fd);check(changed>500 && changed<16000,"visible content without opaque full-width bars");
// A background ID arriving mid-frame must not change the active layout.
resource=mode+1;x=200;y=200;tick(4);check(dut.frame_resource==mode,"resource selection is frame atomic");
end
// Validate all 24 cell mappings and selection borders, not just the first cell.
for(i=0;i<24;i=i+1)begin
force dut.frame_field=i;
x=110+(i%6)*84;y=144+(i/6)*51;tick(3);
check(rgb==24'h007e98,"selected cell border");
x=116+(i%6)*84;y=157+(i/6)*51;tick(3);
check(dut.text_layer.numidx==12+i,"threshold index matches PIC5 row and column");
end
release dut.frame_field;
$display("BACKGROUND_FIT_RESULT errors=%0d",errors);$finish;
end
initial begin #100000000;errors=errors+1;$display("BACKGROUND_FIT_TIMEOUT");$finish;end
endmodule
