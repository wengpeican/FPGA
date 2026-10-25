`timescale 1ns/1ps
// Catalog emits stable resource IDs 0..5; IDs 0..3 are the auto-play images,
// IDs 4 and 5 are the threshold and alarm-table pages.
module fat32_bmp_backend #(
 parameter integer CLK_FREQ_HZ=100000000, SD_READ_TIMEOUT_MS=500
)(input clk,rst,output ready,input scan_start,
 output reg scan_done,scan_found_valid,output reg [31:0] scan_found_sector,
 output reg [2:0] scan_found_total,input load_start,load_abort,input [31:0] load_sector,
 input sd_init_done,input [15:0] bmp_width,bmp_height,
 output reg write_req,input write_req_ack,
 output sd_sec_read,output [31:0] sd_sec_read_addr,
 input [7:0] sd_sec_read_data,input sd_sec_read_data_valid,sd_sec_read_end,
 output bmp_data_wr_en,output [23:0] bmp_data,
 output reg [2:0] bmp_error,output reg load_error,load_success,
 output reg [7:0] fs_error);
 localparam IDLE=0,SCAN=1,EMIT=2,ACK=3,STREAM=4;
 reg [2:0] state,emit_index;reg scanner_start,file_start,decode_start;
 reg stream_reset;reg [31:0] selected_cluster,selected_size;
 wire scanning=state==SCAN;
 wire active_reset=rst || load_abort || !sd_init_done;
 wire scanner_reset=rst || (scanning && (load_abort || !sd_init_done));
 wire file_reset=active_reset || stream_reset;
 wire scanner_done,scanner_busy,file_busy,file_done,file_valid;
 wire [7:0] scanner_error,stream_error,file_byte;
 wire [31:0] file_offset,partition_lba,fat_start,data_start,max_cluster;
 wire [7:0] spc;wire [5:0] resources;
 wire [31:0] c0,c1,c2,c3,c4,c5,z0,z1,z2,z3,z4,z5;
 wire scan_req,stream_req,sector_busy,sector_valid,sector_done;
 wire [31:0] scan_lba,stream_lba;wire [7:0] sector_byte,sector_error;wire [8:0] sector_index;
 wire decoder_success,decoder_error;wire [2:0] decoder_code;
 localparam [63:0] RAW=(64'd1*CLK_FREQ_HZ*SD_READ_TIMEOUT_MS)/1000;
 localparam [63:0] LIMIT=RAW<1?1:RAW;
 reg [((LIMIT>1)?$clog2(LIMIT):1)-1:0] ack_timer;
 assign ready=state==IDLE;
 function [31:0] cluster_lookup;input [2:0] i;begin case(i)0:cluster_lookup=c0;1:cluster_lookup=c1;2:cluster_lookup=c2;3:cluster_lookup=c3;4:cluster_lookup=c4;default:cluster_lookup=c5;endcase end endfunction
 function [31:0] size_lookup;input [2:0] i;begin case(i)0:size_lookup=z0;1:size_lookup=z1;2:size_lookup=z2;3:size_lookup=z3;4:size_lookup=z4;default:size_lookup=z5;endcase end endfunction
 function [2:0] visible_error;input [7:0] code;begin
 case(code)2:visible_error=2;3:visible_error=3;8'h20,8'h21:visible_error=4;8'h22:visible_error=5;default:visible_error=6;endcase
 end endfunction
 task fail;input [2:0] code;input [7:0] detail;begin bmp_error<=code;fs_error<=detail;load_error<=1;write_req<=0;state<=IDLE;stream_reset<=1;end endtask
 always @(posedge clk or posedge rst)begin
 if(rst)begin state<=IDLE;emit_index<=0;scanner_start<=0;file_start<=0;decode_start<=0;stream_reset<=1;selected_cluster<=0;selected_size<=0;scan_done<=0;scan_found_valid<=0;scan_found_sector<=0;scan_found_total<=0;write_req<=0;bmp_error<=0;load_error<=0;load_success<=0;fs_error<=0;ack_timer<=0;end
 else begin
 scanner_start<=0;file_start<=0;decode_start<=0;scan_found_valid<=0;load_error<=0;load_success<=0;
 if(load_abort || !sd_init_done)begin state<=IDLE;write_req<=0;stream_reset<=1;ack_timer<=0;end
 else case(state)
 IDLE:begin
 write_req<=0;ack_timer<=0;
 if(scan_start)begin scanner_start<=1;scan_done<=0;scan_found_total<=0;bmp_error<=0;fs_error<=0;state<=SCAN;end
 else if(load_start)begin
 bmp_error<=0;fs_error<=0;
 if(load_sector>5 || !resources[load_sector[2:0]])fail(5,8'h22);
 else begin selected_cluster<=cluster_lookup(load_sector[2:0]);selected_size<=size_lookup(load_sector[2:0]);write_req<=1;state<=ACK;stream_reset<=1;end
 end
 end
 SCAN:if(scanner_done)begin
 if(scanner_error!=0)fail(visible_error(scanner_error),scanner_error);
 else begin emit_index<=0;state<=EMIT;end
 end
 EMIT:begin
 if(emit_index==4)begin scan_done<=1;state<=IDLE;end
 else begin
 if(resources[emit_index[1:0]])begin scan_found_valid<=1;scan_found_sector<={30'd0,emit_index[1:0]};scan_found_total<=scan_found_total+1'b1;end
 emit_index<=emit_index+1'b1;
 end
 end
 ACK:begin
 if(write_req_ack)begin write_req<=0;stream_reset<=0;file_start<=1;decode_start<=1;state<=STREAM;end
 else if(ack_timer>=LIMIT-1)fail(2,8'h02);
 else ack_timer<=ack_timer+1'b1;
 end
 STREAM:begin
 if(file_done && stream_error!=0)fail(visible_error(stream_error),stream_error);
 else if(decoder_error)fail(decoder_code,{5'd0,decoder_code});
 else if(decoder_success)begin load_success<=1;state<=IDLE;stream_reset<=1;end
 end
 default:state<=IDLE;
 endcase
 end
 end
 sd_sector_adapter #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.TIMEOUT_MS(SD_READ_TIMEOUT_MS)) adapter(
 .clk(clk),.rst_n(~active_reset),.sector_req(scanning?scan_req:stream_req),.sector_lba(scanning?scan_lba:stream_lba),
 .sector_busy(sector_busy),.sector_valid(sector_valid),.sector_byte(sector_byte),.sector_byte_index(sector_index),.sector_done(sector_done),.sector_error(sector_error),
 .sd_sec_read(sd_sec_read),.sd_sec_read_addr(sd_sec_read_addr),.sd_sec_read_data_valid(sd_sec_read_data_valid),.sd_sec_read_data(sd_sec_read_data),.sd_sec_read_end(sd_sec_read_end));
 fat32_volume_scanner scanner(.clk(clk),.rst_n(~scanner_reset),.scan_start(scanner_start),.scan_busy(scanner_busy),.scan_done(scanner_done),.fs_error(scanner_error),
 .partition_lba(partition_lba),.sectors_per_cluster(spc),.fat_start_lba(fat_start),.data_start_lba(data_start),.max_cluster(max_cluster),
 .resource_valid(resources),.resource0_cluster(c0),.resource1_cluster(c1),.resource2_cluster(c2),.resource3_cluster(c3),.resource4_cluster(c4),.resource5_cluster(c5),
 .resource0_size(z0),.resource1_size(z1),.resource2_size(z2),.resource3_size(z3),.resource4_size(z4),.resource5_size(z5),
 .sector_req(scan_req),.sector_lba(scan_lba),.sector_busy(sector_busy),.sector_valid(sector_valid && scanning),.sector_byte(sector_byte),.sector_byte_index(sector_index),.sector_done(sector_done && scanning),.sector_error(sector_error));
 fat32_file_streamer streamer(.clk(clk),.rst_n(~file_reset),.file_start(file_start),.first_cluster(selected_cluster),.file_size(selected_size),
 .sectors_per_cluster(spc),.fat_start_lba(fat_start),.data_start_lba(data_start),.max_cluster(max_cluster),
 .file_busy(file_busy),.file_done(file_done),.file_valid(file_valid),.file_byte(file_byte),.file_byte_offset(file_offset),.fs_error(stream_error),
 .sector_req(stream_req),.sector_lba(stream_lba),.sector_busy(sector_busy),.sector_valid(sector_valid && state==STREAM),.sector_byte(sector_byte),.sector_byte_index(sector_index),.sector_done(sector_done && state==STREAM),.sector_error(sector_error));
 bmp_stream_decoder decoder(.clk(clk),.rst(file_reset),.start(decode_start),.directory_size(selected_size),.expected_width(bmp_width),.expected_height(bmp_height),
 .byte_valid(file_valid),.byte_data(file_byte),.byte_offset(file_offset),.file_done(file_done && stream_error==0),
 .pixel_valid(bmp_data_wr_en),.pixel(bmp_data),.success(decoder_success),.error(decoder_error),.error_code(decoder_code));
endmodule
