// All UI state is in the 25 MHz pixel domain. Apply visible state in blanking.
module osd_button #(parameter CLK_HZ=25000000, DEBOUNCE_MS=20, LONG_MS=1000)(
 input clk,rst,input key_n,output reg short_press,long_press);
 localparam DB=(CLK_HZ/1000)*DEBOUNCE_MS, LP=(CLK_HZ/1000)*LONG_MS;
 reg [1:0] sync; reg stable,fired; reg [31:0] count,held;
 always @(posedge clk or posedge rst) begin
 if(rst)begin sync<=3;stable<=1;count<=0;held<=0;fired<=0;short_press<=0;long_press<=0;end
 else begin
 sync<={sync[0],key_n};short_press<=0;long_press<=0;
 if(sync[1]==stable)count<=0;
 else if(count>=DB-1)begin
 count<=0;stable<=sync[1];
 if(sync[1])begin if(!fired)short_press<=1;held<=0;fired<=0;end
 end else count<=count+1;
 if(!stable && !fired)begin
 if(held>=LP-1)begin fired<=1;long_press<=1;end else held<=held+1;
 end
 end end
endmodule
module ui_page_ctrl #(parameter CLK_HZ=25000000)(
 input clk,rst,frame_tick,input key1_short,key1_long,key2_short,key2_long,input trans_busy,
 output reg [1:0] page,zone,output reg [4:0] field,output reg auto_run,
 output reg [383:0] thresholds,output reg sim_inc,sim_dec,output reg [3:0] sim_field,
 output reg media_next,media_auto,output reg page_change);
 reg [31:0] auto_cnt; integer k; reg [15:0] val,lo,hi,limit,step; reg [4:0] fi;
 always @* begin
 fi=field;val=thresholds[fi*16+:16];
 lo=thresholds[(fi & 5'b11110)*16+:16];hi=thresholds[(fi | 5'b00001)*16+:16];
 case(fi%6)0,1:begin limit=80;step=1;end 2,3:begin limit=100;step=1;end default:begin limit=4095;step=50;end endcase
 end
 always @(posedge clk or posedge rst)begin
 if(rst)begin
 page<=0;zone<=0;field<=0;auto_run<=0;auto_cnt<=0;sim_inc<=0;sim_dec<=0;sim_field<=0;media_next<=0;media_auto<=0;page_change<=0;
 // Defaults balanced against the simulated ranges (sim/alarm_balance): ~1/3 each green/yellow/red.
 for(k=0;k<4;k=k+1)begin thresholds[(k*6+0)*16+:16]<=19;thresholds[(k*6+1)*16+:16]<=34;thresholds[(k*6+2)*16+:16]<=33;thresholds[(k*6+3)*16+:16]<=77;thresholds[(k*6+4)*16+:16]<=850;thresholds[(k*6+5)*16+:16]<=2800;end
 end else begin
 sim_inc<=0;sim_dec<=0;media_next<=0;media_auto<=0;page_change<=0;
 if(page==0 && auto_run)begin if(auto_cnt>=CLK_HZ*3-1)begin auto_cnt<=0;zone<=zone+1'b1;end else auto_cnt<=auto_cnt+1;end else auto_cnt<=0;
 if(!trans_busy)begin
 if(key1_long)begin page<=page==2?0:page+1'b1;page_change<=1;auto_cnt<=0;end
 else case(page)
 0:begin
 if(key1_short)begin zone<=zone+1'b1;media_next<=1;auto_cnt<=0;end
 if(key2_short)begin auto_run<=~auto_run;media_auto<=1;auto_cnt<=0;end

 end
 1:begin
 if(key1_short)field<=field==23?0:field+1'b1;
 if(key2_short)begin
 if(!field[0])begin if(val+step<=hi)thresholds[field*16+:16]<=val+step;else thresholds[field*16+:16]<=hi;end
 else if(val+step<=limit)thresholds[field*16+:16]<=val+step;else thresholds[field*16+:16]<=limit;
 end
 if(key2_long)begin
 if(field[0])begin if(val>=lo+step)thresholds[field*16+:16]<=val-step;else thresholds[field*16+:16]<=lo;end
 else thresholds[field*16+:16]<=val>=step?val-step:0;
 end
 end
 2:begin
 if(key1_short)sim_field<=sim_field==11?0:sim_field+1'b1;
 if(key2_short)sim_inc<=1;
 if(key2_long)sim_dec<=1;
 end
 endcase
 end
 end end
endmodule