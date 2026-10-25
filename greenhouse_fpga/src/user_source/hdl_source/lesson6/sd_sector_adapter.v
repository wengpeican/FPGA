`timescale 1ns/1ps
// One outstanding sector, bounded transaction time, exact 512-byte completion.
module sd_sector_adapter #(
 parameter integer CLK_FREQ_HZ=100000000, TIMEOUT_MS=500
)(input clk,rst_n,input sector_req,input [31:0] sector_lba,
 output sector_busy,output sector_valid,output [7:0] sector_byte,
 output [8:0] sector_byte_index,output reg sector_done,output reg [7:0] sector_error,
 output reg sd_sec_read,output reg [31:0] sd_sec_read_addr,
 input sd_sec_read_data_valid,input [7:0] sd_sec_read_data,input sd_sec_read_end);
 localparam [63:0] RAW=(64'd1*CLK_FREQ_HZ*TIMEOUT_MS)/1000;
 localparam [63:0] LIMIT=RAW<1?1:RAW;
 reg [1:0] state;reg [2:0] gap;reg [9:0] count;
 reg [((LIMIT>1)?$clog2(LIMIT):1)-1:0] timer;
 wire [10:0] received={1'b0,count}+(sd_sec_read_data_valid?11'd1:11'd0);
 assign sector_busy=state!=0;
 assign sector_valid=state==1 && sd_sec_read_data_valid && count<512;
 assign sector_byte=sd_sec_read_data;
 assign sector_byte_index=count[8:0];
 always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin state<=0;gap<=0;count<=0;timer<=0;sector_done<=0;sector_error<=0;sd_sec_read<=0;sd_sec_read_addr<=0;end
 else begin
 sector_done<=0;
 case(state)
 0:if(sector_req)begin sd_sec_read<=1;sd_sec_read_addr<=sector_lba;count<=0;timer<=0;sector_error<=0;state<=1;end
 1:begin
 if(sd_sec_read_data_valid && count<513)count<=count+1'b1;
 if(sd_sec_read_end)begin sector_error<=received==512?0:8'h03;sd_sec_read<=0;state<=2;gap<=0;end
 else if(timer>=LIMIT-1)begin sector_error<=8'h02;sd_sec_read<=0;state<=2;gap<=0;end
 else timer<=timer+1'b1;
 end
 2:begin // Request stays low for several clocks before admitting a new one.
 if(gap==3)begin sector_done<=1;state<=0;end else gap<=gap+1'b1;
 end
 default:state<=0;
 endcase
 end
 end
endmodule