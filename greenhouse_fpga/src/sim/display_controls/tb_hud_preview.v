`timescale 1ns/1ps
// Dump the simulated HUD pixels (x 0..295, y 0..59) for four states into one PPM.
module tb_hud_preview;
reg clk=0;always #5 clk=~clk;
reg rst=1;reg [9:0] x=0,y=0;reg [1:0] sel=0;reg [3:0] vol=5,bri=4,con=4;
wire hit;wire [23:0] rgb;
display_parameter_hud hud(clk,rst,1'b1,sel,vol,bri,con,x,y,1'b1,hit,rgb);
integer f,s,i,j;reg [23:0] p;
initial begin
repeat(2)@(negedge clk);rst=0;
f=$fopen("hud_preview.ppm","w");$fwrite(f,"P3\n296 240\n255\n");
for(s=0;s<4;s=s+1)begin
case(s)
0:begin sel=0;vol=5;bri=4;con=4;end
1:begin sel=1;vol=10;bri=0;con=4;end
2:begin sel=2;vol=0;bri=8;con=8;end
3:begin sel=3;vol=5;bri=4;con=4;end
endcase
for(j=0;j<60;j=j+1)for(i=0;i<296;i=i+1)begin
x=i;y=j;repeat(2)@(negedge clk);
p=hit?rgb:24'h506070;
$fwrite(f,"%0d %0d %0d\n",p[23:16],p[15:8],p[7:0]);
end end
$fclose(f);$display("PREVIEW_DONE");$finish;
end
endmodule
