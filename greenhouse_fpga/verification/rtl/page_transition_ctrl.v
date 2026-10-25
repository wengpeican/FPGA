// Fade through black, advanced ONCE at each vertical blank. Busy requests ignored.
module page_transition_ctrl(input clk,rst,frame_tick,request,input [1:0] requested_page,
 output reg [1:0] display_page,output reg busy,output reg [2:0] shade);
 reg pending;reg [1:0] target;reg [4:0] phase;
 always @(posedge clk or posedge rst)begin
 if(rst)begin pending<=0;target<=0;phase<=0;display_page<=0;busy<=0;shade<=0;end
 else begin
 if(request && !busy && !pending)begin pending<=1;target<=requested_page;end
 if(frame_tick)begin
 if(pending)begin pending<=0;busy<=1;phase<=0;shade<=0;end
 else if(busy)begin
 phase<=phase+1'b1;
 if(phase<7)shade<=(phase+1'b1)>>1;
 else if(phase==7)begin display_page<=target;shade<=4;end
 else if(phase<15)shade<=(15-phase)>>1;
 else begin busy<=0;shade<=0;end
 end
 end
 end end
endmodule

// Four-phase level handshake: storage waits for black before committing its
// completed frame. Fade-in waits for the new resource tag in the video stream.
module monitor_transition_ctrl(input clk,rst,frame_tick,request,enable,
 input [2:0] resource,output busy,output black,output reg [2:0] shade);
 reg [1:0] request_sync,state;
 reg [3:0] phase;reg [2:0] old_resource;reg [2:0] settle;
 assign busy=state!=0;
 assign black=state==2;
 always @(posedge clk or posedge rst)begin
 if(rst)begin request_sync<=0;state<=0;phase<=0;old_resource<=0;settle<=0;shade<=0;end
 else begin
 request_sync<={request_sync[0],request};
 if(frame_tick)case(state)
 0:if(request_sync[1] && enable)begin state<=1;phase<=0;shade<=0;old_resource<=resource;end
 1:begin
 if(phase<7)begin phase<=phase+1'b1;shade<=(phase+1'b1)>>1;end
 else begin state<=2;shade<=4;settle<=0;end
 end
 2:begin
 // If a request was cancelled, restore the old picture after a bounded wait.
 if(!request_sync[1])begin
 if(resource!=old_resource || settle==3)begin state<=3;phase<=8;shade<=3;end
 else settle<=settle+1'b1;
 end
 end
 3:begin
 if(phase<15)begin phase<=phase+1'b1;shade<=(14-phase)>>1;end
 else begin state<=0;shade<=0;end
 end
 endcase
 end
 end
endmodule
