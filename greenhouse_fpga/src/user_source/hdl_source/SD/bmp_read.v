// Lesson 4: bounded sector transactions and strict bottom-up BMP24 validation.
module bmp_read #(
 parameter integer CLK_FREQ_HZ=100000000,
 parameter integer SD_READ_TIMEOUT_MS=500,
 parameter [31:0] MAX_FILE_BYTES=16777216
)(
 input clk,rst,output ready,
 input scan_start,input [31:0] scan_start_sector,scan_max_sector,
 input [2:0] scan_target_count,
 output reg scan_done,scan_found_valid,output reg [31:0] scan_found_sector,
 output reg [2:0] scan_found_total,
 input load_start,load_abort,input [31:0] load_sector,
 input sd_init_done,output reg [3:0] state_code,
 input [15:0] bmp_width,bmp_height,
 output reg write_req,input write_req_ack,
 output reg sd_sec_read,output reg [31:0] sd_sec_read_addr,
 input [7:0] sd_sec_read_data,input sd_sec_read_data_valid,sd_sec_read_end,
 output reg bmp_data_wr_en,output reg [23:0] bmp_data,
 output reg [2:0] bmp_error,output reg load_error,load_success
);
localparam ST_IDLE=0,ST_SCAN=1,ST_LOAD_HDR=2,ST_LOAD_WAIT=3,ST_LOAD_DATA=4,
 ST_VALIDATE=5,ST_GAP=6,ST_COMPLETE=7;
localparam ERR_NONE=0,ERR_HEADER=1,ERR_TIMEOUT=2,ERR_TRUNCATED=3;
localparam [63:0] TIMEOUT_RAW=(64'd1*CLK_FREQ_HZ*SD_READ_TIMEOUT_MS)/1000;
localparam [63:0] TIMEOUT_CYCLES=TIMEOUT_RAW<1?1:TIMEOUT_RAW;
reg [2:0] state,return_state;
reg [2:0] gap_count;
reg scanning;
reg [9:0] rd_cnt;
reg [31:0] scan_sector,load_sector_latched;
reg [7:0] header_0,header_1;
reg [31:0] file_len,pixel_offset,dib_size,width,height,compression;
reg [15:0] planes,bit_count;
reg [31:0] bmp_len_cnt,pixel_count,row_byte;
reg [1:0] bmp_byte_idx;
reg [((TIMEOUT_CYCLES>1)?$clog2(TIMEOUT_CYCLES):1)-1:0] sd_timeout_cnt;
wire [31:0] row_bytes={16'd0,bmp_width}*32'd3;
wire [31:0] row_stride=(row_bytes+3)&32'hfffffffc;
wire [31:0] expected_pixels={16'd0,bmp_width}*{16'd0,bmp_height};
wire [32:0] required_end={1'b0,pixel_offset}+({1'b0,row_stride}*bmp_height);
wire [32:0] dib_end={1'b0,dib_size}+33'd14;
wire signature_ok=header_0==8'h42 && header_1==8'h4d;
wire structural_ok=signature_ok && dib_size>=40 && dib_end<={1'b0,pixel_offset} &&
 width=={16'd0,bmp_width} && height=={16'd0,bmp_height} && bmp_width!=0 && bmp_height!=0 &&
 planes==1 && bit_count==24 && compression==0 && pixel_offset>=54 &&
 pixel_offset<file_len && file_len<=MAX_FILE_BYTES && !required_end[32];
// Header pipeline settles during the rest of the 512-byte header sector.
reg header_match,header_truncated,skip_sane;
reg [31:0] payload_end;
reg [32:0] file_sectors,next_scan;
always @(posedge clk) begin
 header_match<=structural_ok && {1'b0,file_len}>=required_end;
 header_truncated<=structural_ok && {1'b0,file_len}<required_end;
 payload_end<=required_end[31:0];
 file_sectors<=({1'b0,file_len}+33'd511)>>9;
 skip_sane<=signature_ok && dib_size>=40 && dib_size<=file_len &&
  pixel_offset>=54 && pixel_offset<file_len && file_len<=MAX_FILE_BYTES;
 next_scan<={1'b0,scan_sector}+((skip_sane && file_sectors!=0)?file_sectors:33'd1);
end
assign ready=state==ST_IDLE;
wire receiving=state==ST_SCAN || state==ST_LOAD_HDR || state==ST_LOAD_DATA;
wire timed_state=receiving || state==ST_LOAD_WAIT;
wire pixel_byte=state==ST_LOAD_DATA && sd_sec_read_data_valid &&
 bmp_len_cnt>=pixel_offset && bmp_len_cnt<payload_end && row_byte<row_bytes;

task fail_transaction;
 input [2:0] code;
 begin
 bmp_error<=code;load_error<=1;state<=ST_IDLE;sd_sec_read<=0;write_req<=0;
 bmp_data_wr_en<=0;sd_timeout_cnt<=0;
 end
endtask
always @(posedge clk or posedge rst) begin
 if(rst) begin
 state<=ST_IDLE;return_state<=ST_IDLE;gap_count<=0;scanning<=0;
 state_code<=0;scan_done<=0;scan_found_valid<=0;scan_found_sector<=0;scan_found_total<=0;
 scan_sector<=0;load_sector_latched<=0;sd_sec_read<=0;sd_sec_read_addr<=0;write_req<=0;
 rd_cnt<=0;sd_timeout_cnt<=0;bmp_len_cnt<=0;pixel_count<=0;row_byte<=0;bmp_byte_idx<=0;
 bmp_data<=0;bmp_data_wr_en<=0;bmp_error<=0;load_error<=0;load_success<=0;
 header_0<=0;header_1<=0;file_len<=0;pixel_offset<=0;dib_size<=0;width<=0;height<=0;
 planes<=0;bit_count<=0;compression<=0;
 end else begin
 scan_found_valid<=0;load_error<=0;load_success<=0;bmp_data_wr_en<=0;
 state_code<={1'b0,state};
 if(load_abort || !sd_init_done) begin
 state<=ST_IDLE;sd_sec_read<=0;write_req<=0;sd_timeout_cnt<=0;rd_cnt<=0;
 end else if(timed_state && sd_timeout_cnt>=TIMEOUT_CYCLES-1 && !sd_sec_read_end) begin
 fail_transaction(ERR_TIMEOUT);
 end else begin
 if(timed_state)sd_timeout_cnt<=sd_timeout_cnt+1'b1;else sd_timeout_cnt<=0;
 if(receiving && sd_sec_read_data_valid) rd_cnt<=rd_cnt+1'b1;
 if((state==ST_SCAN || state==ST_LOAD_HDR) && sd_sec_read_data_valid) begin
 case(rd_cnt)
 0:header_0<=sd_sec_read_data;1:header_1<=sd_sec_read_data;
 2:file_len[7:0]<=sd_sec_read_data;3:file_len[15:8]<=sd_sec_read_data;
 4:file_len[23:16]<=sd_sec_read_data;5:file_len[31:24]<=sd_sec_read_data;
 10:pixel_offset[7:0]<=sd_sec_read_data;11:pixel_offset[15:8]<=sd_sec_read_data;
 12:pixel_offset[23:16]<=sd_sec_read_data;13:pixel_offset[31:24]<=sd_sec_read_data;
 14:dib_size[7:0]<=sd_sec_read_data;15:dib_size[15:8]<=sd_sec_read_data;
 16:dib_size[23:16]<=sd_sec_read_data;17:dib_size[31:24]<=sd_sec_read_data;
 18:width[7:0]<=sd_sec_read_data;19:width[15:8]<=sd_sec_read_data;
 20:width[23:16]<=sd_sec_read_data;21:width[31:24]<=sd_sec_read_data;
 22:height[7:0]<=sd_sec_read_data;23:height[15:8]<=sd_sec_read_data;
 24:height[23:16]<=sd_sec_read_data;25:height[31:24]<=sd_sec_read_data;
 26:planes[7:0]<=sd_sec_read_data;27:planes[15:8]<=sd_sec_read_data;
 28:bit_count[7:0]<=sd_sec_read_data;29:bit_count[15:8]<=sd_sec_read_data;
 30:compression[7:0]<=sd_sec_read_data;31:compression[15:8]<=sd_sec_read_data;
 32:compression[23:16]<=sd_sec_read_data;33:compression[31:24]<=sd_sec_read_data;
 endcase
 end
 if(state==ST_LOAD_DATA && sd_sec_read_data_valid) begin
 bmp_len_cnt<=bmp_len_cnt+1'b1;
 if(bmp_len_cnt>=pixel_offset && bmp_len_cnt<payload_end)
  row_byte<=row_byte==row_stride-1?0:row_byte+1'b1;
 if(pixel_byte) begin
 case(bmp_byte_idx)
 0:bmp_data[7:0]<=sd_sec_read_data;
 1:bmp_data[15:8]<=sd_sec_read_data;
 2:begin bmp_data[23:16]<=sd_sec_read_data;bmp_data_wr_en<=1;pixel_count<=pixel_count+1'b1;end
 endcase
 bmp_byte_idx<=bmp_byte_idx==2?0:bmp_byte_idx+1'b1;
 end
 end
 case(state)
 ST_IDLE:begin
 sd_sec_read<=0;write_req<=0;rd_cnt<=0;
 if(scan_start || load_start) begin
 bmp_error<=0;bmp_len_cnt<=0;pixel_count<=0;row_byte<=0;bmp_byte_idx<=0;
 header_0<=0;header_1<=0;file_len<=0;pixel_offset<=0;dib_size<=0;
 width<=0;height<=0;planes<=0;bit_count<=0;compression<=0;
 if(scan_start)begin
 scanning<=1;scan_done<=0;scan_found_total<=0;scan_sector<=scan_start_sector;
 sd_sec_read_addr<=scan_start_sector;state<=ST_SCAN;
 end else begin scanning<=0;load_sector_latched<=load_sector;sd_sec_read_addr<=load_sector;state<=ST_LOAD_HDR;end
 end
 end
 ST_SCAN,ST_LOAD_HDR:begin
 sd_sec_read<=1;
 if(sd_sec_read_end)begin
 sd_sec_read<=0;sd_timeout_cnt<=0;
 if(rd_cnt!=512) fail_transaction(ERR_TRUNCATED);
 else state<=ST_VALIDATE;
 end
 end
 ST_VALIDATE:begin
 if(scanning)begin
 if(header_match)begin scan_found_valid<=1;scan_found_sector<=scan_sector;scan_found_total<=scan_found_total+1'b1;end
 else if(signature_ok) bmp_error<=header_truncated?ERR_TRUNCATED:ERR_HEADER;
 if((header_match && scan_found_total+1>=scan_target_count) || next_scan>{1'b0,scan_max_sector} || next_scan[32])begin
 scan_done<=1;state<=ST_IDLE;
 end else begin
 scan_sector<=next_scan[31:0];sd_sec_read_addr<=next_scan[31:0];gap_count<=0;return_state<=ST_SCAN;state<=ST_GAP;
 end
 end else if(!header_match)fail_transaction(header_truncated?ERR_TRUNCATED:ERR_HEADER);
 else begin write_req<=1;sd_sec_read_addr<=load_sector_latched;state<=ST_LOAD_WAIT;end
 end
 ST_LOAD_WAIT:if(write_req_ack)begin
 write_req<=0;gap_count<=0;return_state<=ST_LOAD_DATA;state<=ST_GAP;
 end
 ST_LOAD_DATA:begin
 sd_sec_read<=1;
 if(sd_sec_read_end)begin
 sd_sec_read<=0;sd_timeout_cnt<=0;
 if(rd_cnt!=512)fail_transaction(ERR_TRUNCATED);
 else if(bmp_len_cnt>=payload_end)state<=ST_COMPLETE;
 else if(sd_sec_read_addr==32'hffffffff)fail_transaction(ERR_HEADER);
 else begin sd_sec_read_addr<=sd_sec_read_addr+1'b1;gap_count<=0;return_state<=ST_LOAD_DATA;state<=ST_GAP;end
 end
 end
 ST_GAP:begin
 sd_sec_read<=0;rd_cnt<=0;
 if(gap_count==3)state<=return_state;else gap_count<=gap_count+1'b1;
 end
 ST_COMPLETE:begin
 if(pixel_count!=expected_pixels || bmp_byte_idx!=0)fail_transaction(ERR_TRUNCATED);
 else begin load_success<=1;bmp_error<=0;state<=ST_IDLE;end
 end
 default:fail_transaction(ERR_HEADER);
 endcase
 end
 end
end
endmodule