`timescale 1ns/1ps
// Strict one-pass BMP24 decoder; writer must acknowledge before file_start.
module bmp_stream_decoder(input clk,rst,input start,input [31:0] directory_size,
 input [15:0] expected_width,expected_height,
 input byte_valid,input [7:0] byte_data,input [31:0] byte_offset,input file_done,
 output reg pixel_valid,output reg [23:0] pixel,output reg success,error,
 output reg [2:0] error_code);
 reg active,header_seen;
 reg [7:0] sig0,sig1;
 reg [31:0] declared_size,pixel_offset,dib_size,width,height,compression;
 reg [15:0] planes,bpp;
 reg [31:0] pixels,row_byte;reg [1:0] component;
 wire [31:0] row_bytes={16'd0,expected_width}*32'd3;
 wire [31:0] stride=(row_bytes+3)&32'hfffffffc;
 wire [31:0] expected_pixels={16'd0,expected_width}*{16'd0,expected_height};
 wire [32:0] extent={1'b0,pixel_offset}+({1'b0,stride}*expected_height);
 wire [32:0] dib_end={1'b0,dib_size}+33'd14;
 reg header_ok,short_payload;reg [31:0] payload_end;
 // One-stage input pipeline: the 32-bit payload-window compares are registered
 // with the byte instead of driving the pixel enables directly. All inputs are
 // delayed together, so event order is unchanged. pixel_offset/payload_end are
 // final by byte 14, long before any byte >= 54 is compared.
 reg s_start,s_valid,s_done,s_ge54,s_window;reg [7:0] s_data;reg [31:0] s_offset;
 always @(posedge clk or posedge rst)begin
 if(rst)begin s_start<=0;s_valid<=0;s_done<=0;s_ge54<=0;s_window<=0;s_data<=0;s_offset<=0;end
 else begin
 s_start<=start;s_valid<=byte_valid;s_done<=file_done;s_data<=byte_data;s_offset<=byte_offset;
 s_ge54<=byte_offset>=54;s_window<=byte_offset>=pixel_offset && byte_offset<payload_end;
 end end
 always @(posedge clk)begin
 header_ok<=sig0=="B" && sig1=="M" && dib_size>=40 && dib_end<={1'b0,pixel_offset} &&
 width=={16'd0,expected_width} && height=={16'd0,expected_height} && expected_width!=0 && expected_height!=0 &&
 planes==1 && bpp==24 && compression==0 && pixel_offset>=54 && pixel_offset<declared_size &&
 declared_size<=directory_size && directory_size<=32'd16777216 && !extent[32];
 short_payload<={1'b0,declared_size}<extent || {1'b0,directory_size}<extent;
 payload_end<=extent[31:0];
 end
 always @(posedge clk or posedge rst)begin
 if(rst)begin active<=0;header_seen<=0;sig0<=0;sig1<=0;declared_size<=0;pixel_offset<=0;dib_size<=0;width<=0;height<=0;compression<=0;planes<=0;bpp<=0;pixels<=0;row_byte<=0;component<=0;pixel_valid<=0;pixel<=0;success<=0;error<=0;error_code<=0;end
 else begin
 pixel_valid<=0;success<=0;error<=0;
 if(s_start)begin active<=1;header_seen<=0;sig0<=0;sig1<=0;declared_size<=0;pixel_offset<=0;dib_size<=0;width<=0;height<=0;compression<=0;planes<=0;bpp<=0;pixels<=0;row_byte<=0;component<=0;error_code<=0;end
 else if(active)begin
 if(s_valid)begin
 case(s_offset)
 0:sig0<=s_data;1:sig1<=s_data;
 2:declared_size[7:0]<=s_data;3:declared_size[15:8]<=s_data;4:declared_size[23:16]<=s_data;5:declared_size[31:24]<=s_data;
 10:pixel_offset[7:0]<=s_data;11:pixel_offset[15:8]<=s_data;12:pixel_offset[23:16]<=s_data;13:pixel_offset[31:24]<=s_data;
 14:dib_size[7:0]<=s_data;15:dib_size[15:8]<=s_data;16:dib_size[23:16]<=s_data;17:dib_size[31:24]<=s_data;
 18:width[7:0]<=s_data;19:width[15:8]<=s_data;20:width[23:16]<=s_data;21:width[31:24]<=s_data;
 22:height[7:0]<=s_data;23:height[15:8]<=s_data;24:height[23:16]<=s_data;25:height[31:24]<=s_data;
 26:planes[7:0]<=s_data;27:planes[15:8]<=s_data;28:bpp[7:0]<=s_data;29:bpp[15:8]<=s_data;
 30:compression[7:0]<=s_data;31:compression[15:8]<=s_data;32:compression[23:16]<=s_data;33:compression[31:24]<=s_data;
 endcase
 if(s_ge54 && !header_seen)begin
 header_seen<=1;
 if(!header_ok || short_payload)begin active<=0;error<=1;error_code<=short_payload?3:1;end
 end
 if(s_ge54 && header_ok && !short_payload && s_window)begin
 row_byte<=row_byte==stride-1?0:row_byte+1'b1;
 if(row_byte<row_bytes)begin
 case(component)
 0:pixel[7:0]<=s_data;
 1:pixel[15:8]<=s_data;
 2:begin pixel[23:16]<=s_data;pixel_valid<=1;pixels<=pixels+1'b1;end
 endcase
 component<=component==2?0:component+1'b1;
 end
 end
 end
 if(s_done)begin
 active<=0;
 if(!header_seen || !header_ok)begin error<=1;error_code<=1;end
 else if(short_payload || pixels!=expected_pixels || component!=0)begin error<=1;error_code<=3;end
 else success<=1;
 end
 end
 end
 end
endmodule