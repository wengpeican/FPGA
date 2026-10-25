`timescale 1ns/1ps
module tb_blink;
reg clk=0;always #625000 clk=~clk;
reg rst=1;reg [7:0] states=8'b00_10_01_00;
wire [3:0] blink;integer errors=0,i,red_edges=0,yellow_edges=0,green_edges=0;reg [3:0] previous;
alarm_blink_ctrl #(.CLK_HZ(800)) dut(clk,rst,states,blink);
initial begin
repeat(3)@(negedge clk);rst=0;previous=blink;
for(i=1;i<=1600;i=i+1)begin
@(negedge clk);
if(blink[2]!=previous[2])red_edges=red_edges+1;
if(blink[1]!=previous[1])yellow_edges=yellow_edges+1;
if(blink[0]!=previous[0])green_edges=green_edges+1;
if(blink[2]!==!((i/100)%2))errors=errors+1;
if(blink[1]!==!((i/400)%2))errors=errors+1;
if(blink[0]!==!((i/800)%2))errors=errors+1;
previous=blink;
end
if(red_edges!=16 || yellow_edges!=4 || green_edges!=2)errors=errors+1;
states=8'haa;#1;if(blink!={4{blink[2]}})errors=errors+1;
$display("BLINK_RESULT errors=%0d red_edges=%0d yellow_edges=%0d green_edges=%0d",errors,red_edges,yellow_edges,green_edges);
$finish;
end
endmodule
