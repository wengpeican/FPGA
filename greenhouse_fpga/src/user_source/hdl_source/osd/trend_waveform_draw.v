// 128 samples of T/H/L for EACH of the four zones, one pixel clock domain.
// All zones are sampled together, so switching the displayed zone or page never
// clears or pauses any history; returning to a zone continues its own curves.
// history[{zone,slot}]: each sample is written to the four zones over the next
// four clocks (issued at frame_tick, inside vertical blanking).
// Synchronous RAM read; request metadata is delayed one pixel alongside it.
module trend_waveform_draw(input clk,rst,sample,input [1:0] zone,input [191:0] values,
 input [9:0] x,y,input de,output wire hit,output reg [23:0] rgb);
 reg [23:0] history[0:511];reg [6:0] wp,wslot;reg [7:0] count;
 reg [95:0] snap;reg [2:0] wcnt;
 reg [23:0] sample_q;reg [9:0] yq,base_q;reg visible;
 wire [9:0] baseline=zone==0?10'd374:zone==1?10'd375:zone==2?10'd387:10'd415;
 function [23:0] pack;input [1:0] z;input [191:0] v;reg [15:0] tv,hv,lv;begin
 tv=v[(z*3)*16+:16];hv=v[(z*3+1)*16+:16];lv=v[(z*3+2)*16+:16];
 pack={tv>80?8'd80:tv[7:0],hv>100?8'd100:hv[7:0],lv>4095?8'd127:{1'b0,lv[11:5]}};
 end endfunction
 wire [6:0] slot=(x-64)>>2;
 wire [6:0] address=wp-7'd1-slot;
 always @(posedge clk or posedge rst)begin
 if(rst)begin wp<=0;wslot<=0;count<=0;snap<=0;wcnt<=4;yq<=0;base_q<=374;visible<=0;end
 else begin
 yq<=y;base_q<=baseline;
 visible<=de && x>=64 && x<576 && y>=baseline-127 && y<=baseline && {1'b0,slot}<count;
 if(sample)begin
 snap<={pack(3,values),pack(2,values),pack(1,values),pack(0,values)};
 wslot<=wp;wcnt<=0;wp<=wp+1'b1;if(count<128)count<=count+1'b1;
 end else if(wcnt<4)wcnt<=wcnt+1'b1;
 end end
 always @(posedge clk)begin
 if(wcnt<4)history[{wcnt[1:0],wslot}]<=snap[wcnt[1:0]*24+:24];
 sample_q<=history[{zone,address}];
 end
 wire ht=visible && yq==base_q-sample_q[23:16];
 wire hh_hit=visible && yq==base_q-sample_q[15:8];
 wire hl=visible && yq==base_q-sample_q[7:0];
 assign hit=ht||hh_hit||hl;
 always @* begin if(ht)rgb=24'h007e98;else if(hh_hit)rgb=24'hb07800;else rgb=24'h9830b0;end
endmodule
