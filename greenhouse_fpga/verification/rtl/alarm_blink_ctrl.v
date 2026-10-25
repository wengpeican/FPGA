module alarm_blink_ctrl #(parameter CLK_HZ=25000000)(input clk,rst,input [7:0] states,output [3:0] blink);
 // 125 ms base tick: complete on/off cycles are red 4 Hz, yellow 1 Hz,
 // green 0.5 Hz. Shared divider; each zone selects its own status phase.
 localparam TICK_CYCLES=CLK_HZ/8<1?1:CLK_HZ/8;
 reg [31:0] count;reg [3:0] phase;genvar i;
 always @(posedge clk or posedge rst)if(rst)begin count<=0;phase<=0;end
 else if(count>=TICK_CYCLES-1)begin count<=0;phase<=phase+1'b1;end else count<=count+1;
 generate for(i=0;i<4;i=i+1)begin:g
 assign blink[i]=states[i*2+:2]==2 ? ~phase[0] : states[i*2+:2]==1 ? ~phase[2] : ~phase[3];
 end endgenerate
endmodule
