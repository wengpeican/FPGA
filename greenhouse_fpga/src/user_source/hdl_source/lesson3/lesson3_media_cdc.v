// Bundled-data request/acknowledge transfer. The ID is held until the pixel
// domain acknowledges it; safe for any transition, including 3-image wrap.
module lesson3_media_cdc(
 input source_clk,input source_rst,input [1:0] source_id,
 input pixel_clk,input pixel_rst,input frame_start,
 output reg [1:0] media_id
);
 reg [1:0] held_id,pending_id;
 reg request,ack;
 reg [1:0] ack_sync,request_sync;
 always @(posedge source_clk or posedge source_rst) begin
   if(source_rst) begin held_id<=0; request<=0; ack_sync<=0; end
   else begin
     ack_sync<={ack_sync[0],ack};
     if(ack_sync[1]==request && source_id!=held_id) begin
       held_id<=source_id;
       request<=~request;
     end
   end
 end
 always @(posedge pixel_clk or posedge pixel_rst) begin
   if(pixel_rst) begin request_sync<=0; ack<=0; pending_id<=0; media_id<=0; end
   else begin
     request_sync<={request_sync[0],request};
     if(request_sync[1]!=ack) begin
       pending_id<=held_id;
       ack<=request_sync[1];
     end
     if(frame_start) media_id<=pending_id;
   end
 end
endmodule