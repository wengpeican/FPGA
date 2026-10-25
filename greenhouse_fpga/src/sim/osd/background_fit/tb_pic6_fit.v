`timescale 1ns/1ps
module tb_pic6_fit;
reg clk=0;always #5 clk=~clk;
reg rst=1,de=0;reg [9:0] x=0,y=0;reg [23:0] bg=0;
reg [2:0] resource=5;
wire [23:0] rgb;wire ho,vo,dout,no,mn,ma;wire [9:0] xo;
osd_overlay_mixer dut(clk,rst,1'b1,1'b1,bg,1'b1,1'b1,de,1'b0,x,y,1'b1,resource,rgb,ho,vo,dout,no,xo,mn,ma,,,,1'b0,,,,,,,);
reg [23:0] pixels[0:307199];
integer errors=0,xx,yy,i,j,r,fd,changed,ox,oy,idx;
reg allowed;reg [1:0] test_page=2;reg [7:0] test_states=8'h24;
task check(input ok,input [511:0] msg);begin if(ok!==1'b1)begin errors=errors+1;if(errors<20)$display("FAIL %0s",msg);end end endtask
task tick(input integer n);begin repeat(n)@(negedge clk);#1;end endtask
initial begin
$readmemh("bg5.hex",pixels);tick(5);rst=0;
force dut.transition.display_page=test_page;
force dut.frame_states=test_states;
de=0;x=0;y=480;tick(1);x=1;tick(650);
de=1;x=0;y=0;tick(4);
check(dut.render_page==2 && dut.frame_resource==5,"PIC6 resource selects table layout");
fd=$fopen("PIC6.ppm","wb");$fwrite(fd,"P6\n640 480\n255\n");changed=0;
for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
x=xx;y=yy;bg=pixels[yy*640+xx];tick(3);
$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
allowed=0;
// Independent cell boundaries from the supplied PIC6 image, excluding grid lines.
if(yy>173 && yy<424 && yy!=237 && yy!=238 && yy!=301 && yy!=302 && yy!=364 && yy!=365)
 if((xx>150 && xx<267)||(xx>268 && xx<382)||(xx>383 && xx<494)||(xx>495 && xx<600))allowed=1;
if(!allowed)check(rgb===bg,"background title, row labels, grid and exterior must remain unchanged");
if(rgb!==bg)changed=changed+1;
end
$fclose(fd);check(changed>500 && changed<9000,"table data visible without opaque panels");
for(i=0;i<12;i=i+1)begin
force dut.frame_sim_field=i;r=i/3;j=i%3;
ox=j==0?166:j==1?284:399;oy=r==0?185:r==1?249:r==2?313:376;
x=ox;y=oy;tick(3);check(rgb==24'h007e98,"each selected value has a cell cursor");
x=ox+10;y=oy+13;tick(3);check(dut.text_layer.numidx==i,"A-D temperature/humidity/light index order");
end
release dut.frame_sim_field;
for(i=0;i<4;i=i+1)begin
x=516;y=(i==0?185:i==1?249:i==2?313:376)+13;tick(3);
check(dut.text_layer.state_value==test_states[i*2+:2],"status from the correct zone");
check(dut.text_layer.color==(test_states[i*2+:2]==2?24'hdc2020:test_states[i*2+:2]==1?24'hb08000:24'h008040),"status color mapping");
end
resource=0;x=200;y=200;tick(3);check(dut.render_page==2,"resource change must wait for next frame");
x=0;y=0;tick(3);check(dut.render_page==3,"do not draw PIC6 values over a monitoring background");
$display("PIC6_FIT_RESULT errors=%0d changed=%0d",errors,changed);$finish;
end
initial begin #100000000;errors=errors+1;$display("PIC6_FIT_TIMEOUT");$finish;end
endmodule
