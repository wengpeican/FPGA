module alarm_threshold_cmp(input clk,rst,input [191:0] values,input [383:0] thresholds,output reg [7:0] states);
 function [1:0] check_value;input [15:0] v,lo,hi,band;begin
 if(lo>hi || v<lo || v>hi)check_value=2;
 else if((v-lo)<=band || (hi-v)<=band)check_value=1;
 else check_value=0;
 end endfunction
 integer i,j;reg [1:0] result,part;
 always @(posedge clk or posedge rst)begin
 if(rst)states<=0;
 else for(i=0;i<4;i=i+1)begin
 result=0;
 for(j=0;j<3;j=j+1)begin
 // Warning band inside each limit: temperature 1, humidity 4, light 100.
 part=check_value(values[(i*3+j)*16+:16],thresholds[(i*6+j*2)*16+:16],thresholds[(i*6+j*2+1)*16+:16],j==2?16'd100:j==1?16'd4:16'd1);
 if(part>result)result=part;
 end
 states[i*2+:2]<=result;
 end end
endmodule