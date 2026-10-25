`timescale 1ns/1ps
// Behavioral storage only; real BMP/parser/frame state machines are in the DUT.
module fifo_model(input clkr,clkw,rst,we,re,input [31:0] di,
 output empty_flag,full_flag,output [8:0] wrusedw,rdusedw,output reg [31:0] dout);
reg [31:0] ram[0:511]; integer wp=0,rp=0;
assign empty_flag=wp==rp; assign full_flag=wp-rp>=512;
assign wrusedw=wp-rp; assign rdusedw=wp-rp;
always @(posedge clkw or posedge rst)
 if(rst) wp<=0; else if(we) begin ram[wp%512]<=di; wp<=wp+1; end
always @(posedge clkr or posedge rst)
 if(rst) begin rp<=0;dout<=0;end else if(re) begin dout<=ram[rp%512];rp<=rp+1;end
endmodule
module wfifo_32_32_512(input clkr,clkw,rst,we,re,input [31:0] di, output empty_flag,full_flag,output [8:0] wrusedw,rdusedw,output [31:0] dout);
fifo_model m(.*);
endmodule
module rfifo_32_32_512(input clkr,clkw,rst,we,re,input [31:0] di, output empty_flag,full_flag,output [8:0] wrusedw,rdusedw,output [31:0] dout);
fifo_model m(.*);
endmodule
module sd_card_top(input clk,rst,input SD_MISO,output SD_nCS,SD_DCLK,SD_MOSI,
 output reg sd_init_done,input sd_sec_read,input [31:0] sd_sec_read_addr,
 output reg [7:0] sd_sec_read_data,output reg sd_sec_read_data_valid,sd_sec_read_end,
 input sd_sec_write,input [31:0] sd_sec_write_addr,input [7:0] sd_sec_write_data,
 output sd_sec_write_data_req,sd_sec_write_end);
initial begin sd_init_done=0; sd_sec_read_data_valid=0; sd_sec_read_end=0; end
assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=1;assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
integer state=0,idx=0,delay_count=0; integer fault=0,failures_left=0,attempts=0; reg [31:0] bad_sector=1; reg inject=0;reg [31:0] sector;
function [7:0] data_byte(input integer index,input [31:0] sec);
 begin
 case(index)
 0:data_byte="B";1:data_byte="M";2:data_byte=246;10:data_byte=54;
 14:data_byte=40;18:data_byte=16;22:data_byte=4;26:data_byte=1;28:data_byte=24;
 default: data_byte=index<54 ? 0 : sec+1;
 endcase
 end
endfunction
always @(posedge clk) begin
 sd_sec_read_data_valid<=0;sd_sec_read_end<=0;
 if(rst) begin state<=0;sd_init_done<=0;delay_count<=0; end
 else begin
 sd_init_done<=1;
 case(state)
 0:if(sd_sec_read) begin sector<=sd_sec_read_addr; inject<=(fault!=0 && (sd_sec_read_addr==bad_sector || bad_sector==32'hffffffff) && failures_left!=0); if(fault!=0 && (sd_sec_read_addr==bad_sector || bad_sector==32'hffffffff) && failures_left!=0)begin failures_left<=failures_left-1;attempts<=attempts+1;end idx<=0;delay_count<=0;state<=1;end
 1:if(inject && fault==2 && idx==100) begin end else if(delay_count==3) begin
    delay_count<=0;
    if(idx==512 || (inject && fault==3 && idx==120)) begin sd_sec_read_end<=1;state<=2;end
    else begin sd_sec_read_data<=(inject && fault==1 && idx==28)?8'd16:data_byte(idx,sector);sd_sec_read_data_valid<=1;idx<=idx+1;end
   end else delay_count<=delay_count+1;
 2:if(!sd_sec_read) state<=0;
 endcase
 end
end
endmodule