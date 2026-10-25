// Internal simulated data only. No physical sensor or MCU interface is used.
module sim_sensor_data_gen #(parameter CLK_HZ=25000000)(
 input clk,rst,manual_mode,inc,dec,input [3:0] edit_field,
 output reg [191:0] values,output reg data_valid);
 reg [31:0] count;reg [11:0] direction;integer j;
 reg [15:0] v,step,upper,lower;
 always @(posedge clk or posedge rst)begin
 if(rst)begin
 count<=0;data_valid<=0;direction<=12'hfff;
 values<={16'd1200,16'd68,16'd22,16'd3000,16'd48,16'd31,16'd2200,16'd55,16'd28,16'd1000,16'd60,16'd25};
 end else begin
 data_valid<=0;
 if(count>=CLK_HZ-1)begin count<=0;data_valid<=1;
 if(!manual_mode)for(j=0;j<12;j=j+1)begin
 case(j%3)0:begin lower=18;upper=36;step=1;end 1:begin lower=30;upper=80;step=1;end default:begin lower=800;upper=3200;step=50;end endcase
 v=values[j*16+:16];
 if(direction[j])begin if(v+step>=upper)begin values[j*16+:16]<=upper;direction[j]<=0;end else values[j*16+:16]<=v+step;end
 else begin if(v<=lower+step)begin values[j*16+:16]<=lower;direction[j]<=1;end else values[j*16+:16]<=v-step;end
 end
 end else count<=count+1;
 if(manual_mode && (inc || dec) && edit_field<12)begin
 v=values[edit_field*16+:16];
 case(edit_field%3)0:begin upper=80;step=1;end 1:begin upper=100;step=1;end default:begin upper=4095;step=50;end endcase
 if(inc)values[edit_field*16+:16]<=v+step<=upper?v+step:upper;
 else values[edit_field*16+:16]<=v>=step?v-step:0;
 data_valid<=1;
 end
 end end
endmodule