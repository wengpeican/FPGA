`timescale 1ns/1ps

module fat32_volume_scanner (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        scan_start,
    output wire        scan_busy,
    output reg         scan_done,
    output reg  [7:0]  fs_error,
    output reg  [31:0] partition_lba,
    output reg  [7:0]  sectors_per_cluster,
    output reg  [31:0] fat_start_lba,
    output reg  [31:0] data_start_lba,
    output reg  [31:0] max_cluster,
    output reg  [5:0]  resource_valid,
    output reg  [31:0] resource0_cluster,
    output reg  [31:0] resource1_cluster,
    output reg  [31:0] resource2_cluster,
    output reg  [31:0] resource3_cluster, output reg [31:0] resource4_cluster, output reg [31:0] resource5_cluster,
    output reg  [31:0] resource0_size,
    output reg  [31:0] resource1_size,
    output reg  [31:0] resource2_size,
    output reg  [31:0] resource3_size, output reg [31:0] resource4_size, output reg [31:0] resource5_size,
    output reg         sector_req,
    output reg  [31:0] sector_lba,
    input  wire        sector_busy,
    input  wire        sector_valid,
    input  wire [7:0]  sector_byte,
    input  wire [8:0]  sector_byte_index,
    input  wire        sector_done,
    input  wire [7:0]  sector_error
);

    localparam ERR_NONE            = 8'h00;
    localparam ERR_SECTOR          = 8'h10;
    localparam ERR_BOOT_SIGNATURE  = 8'h20;
    localparam ERR_UNSUPPORTED_BPB = 8'h21;
    localparam ERR_RESOURCE_MISSING= 8'h22;

    localparam ST_IDLE       = 4'd0;
    localparam ST_READ0_REQ  = 4'd1;
    localparam ST_READ0_WAIT = 4'd2;
    localparam ST_BOOT_PARSE = 4'd3;
    localparam ST_BOOT_REQ   = 4'd4;
    localparam ST_BOOT_WAIT  = 4'd5;
    localparam ST_ROOT_REQ   = 4'd6;
    localparam ST_ROOT_WAIT  = 4'd7;
    localparam ST_DIR_SCAN   = 4'd8;
    localparam ST_FINISH     = 4'd9;
    localparam ST_BOOT_LAYOUT= 4'd10;
    localparam ST_BOOT_ROOT  = 4'd11;

    localparam ST_ROOT_FAT_REQ=12,ST_ROOT_FAT_WAIT=13,ST_ROOT_FAT_PARSE=14,ST_MBR=15,ST_LAYOUT_CHECK=16,ST_ROOT_ADDR=17,ST_ROOT_SHIFT=18,ST_ROOT_ADD=19,ST_ROOT_CHECK=20,ST_MBR_SUM=21,ST_MBR_CHECK=22,ST_LAYOUT_VERIFY=23;
localparam ST_BOOT_CHECK=24;
reg [3:0] invalid_bpb;
reg [4:0] state;
reg [1:0] partition_index;
reg [31:0] partition_size;
reg [15:0] fat_flags;
reg [7:0] root_sector_index;
reg [10:0] root_chain_count;
reg dir_end_seen;
reg [31:0] root_fat_value;
    reg [7:0] sector_buffer [0:511];
    reg [4:0] directory_entry_index;
    reg [31:0] root_cluster;
    reg [31:0] total_sectors;
    reg [31:0] fat_sectors;
    reg [7:0] fat_count;
    reg [15:0] reserved_sectors;
    reg [31:0] root_lba;
    reg [31:0] data_sector_count;
    reg [31:0] fat_span;
    reg [2:0] sectors_per_cluster_shift;
    reg [7:0] dir_name0;
    reg [7:0] dir_name1;
    reg [7:0] dir_name2;
    reg [7:0] dir_name3;
    reg [7:0] dir_name4;
    reg [7:0] dir_name5;
    reg [7:0] dir_name6;
    reg [7:0] dir_name7;
    reg [7:0] dir_name8;
    reg [7:0] dir_name9;
    reg [7:0] dir_name10;
    reg       dir_entry_match;
    reg [2:0] dir_resource_index;
    reg [15:0] dir_cluster_high;
    reg [15:0] dir_cluster_low;
    reg [31:0] dir_file_size;

reg [32:0] overhead;
reg [32:0] volume_end;
reg [32:0] root_delta,root_scaled,root_address;
wire [27:0] root_next=root_fat_value[27:0];
function [7:0] mbr_type; input [1:0] idx;begin case(idx)0:mbr_type=sector_buffer[450];1:mbr_type=sector_buffer[466];2:mbr_type=sector_buffer[482];3:mbr_type=sector_buffer[498];endcase end endfunction
function [31:0] mbr_start; input [1:0] idx;begin case(idx)0:mbr_start=le32(454);1:mbr_start=le32(470);2:mbr_start=le32(486);3:mbr_start=le32(502);endcase end endfunction
function [31:0] mbr_size; input [1:0] idx;begin case(idx)0:mbr_size=le32(458);1:mbr_size=le32(474);2:mbr_size=le32(490);3:mbr_size=le32(506);endcase end endfunction
reg [32:0] selected_partition_end;
reg [31:0] chosen_start,chosen_size;reg [7:0] chosen_type;

    assign scan_busy = (state != ST_IDLE);

    function [15:0] le16;
        input integer offset;
        begin
            le16 = {sector_buffer[offset+1], sector_buffer[offset]};
        end
    endfunction

    function [31:0] le32;
        input integer offset;
        begin
            le32 = {sector_buffer[offset+3], sector_buffer[offset+2],
                    sector_buffer[offset+1], sector_buffer[offset]};
        end
    endfunction

    function valid_spc;
        input [7:0] value;
        begin
            valid_spc = value != 0 && ((value & (value - 1'b1)) == 0);
        end
    endfunction

    function [2:0] spc_shift;
        input [7:0] value;
        begin
            case (value)
                8'd2:   spc_shift = 3'd1;
                8'd4:   spc_shift = 3'd2;
                8'd8:   spc_shift = 3'd3;
                8'd16:  spc_shift = 3'd4;
                8'd32:  spc_shift = 3'd5;
                8'd64:  spc_shift = 3'd6;
                8'd128: spc_shift = 3'd7;
                default: spc_shift = 3'd0;
            endcase
        end
    endfunction

    function [2:0] matching_resource;
        input integer base;
        begin
            if (sector_buffer[base+0] == "P" && sector_buffer[base+1] == "I" &&
                sector_buffer[base+2] == "C" && sector_buffer[base+3] == "1" &&
                sector_buffer[base+8] == "B" && sector_buffer[base+9] == "M" &&
                sector_buffer[base+10] == "P")
                matching_resource = 3'd0;
            else if (sector_buffer[base+0] == "P" && sector_buffer[base+1] == "I" &&
                     sector_buffer[base+2] == "C" && sector_buffer[base+3] == "2" &&
                     sector_buffer[base+8] == "B" && sector_buffer[base+9] == "M" &&
                     sector_buffer[base+10] == "P")
                matching_resource = 3'd1;
            else if (sector_buffer[base+0] == "P" && sector_buffer[base+1] == "I" &&
                     sector_buffer[base+2] == "C" && sector_buffer[base+3] == "3" &&
                     sector_buffer[base+8] == "B" && sector_buffer[base+9] == "M" &&
                     sector_buffer[base+10] == "P")
                matching_resource = 3'd2;
            else if (sector_buffer[base+0] == "P" && sector_buffer[base+1] == "I" &&
                     sector_buffer[base+2] == "C" && sector_buffer[base+3] == "4" &&
                     sector_buffer[base+8] == "B" && sector_buffer[base+9] == "M" &&
                     sector_buffer[base+10] == "P")
                matching_resource = 3'd3;
            else if (sector_buffer[base+0] == "P" && sector_buffer[base+1] == "I" &&
                     sector_buffer[base+2] == "C" && sector_buffer[base+3] == "5" &&
                     sector_buffer[base+8] == "B" && sector_buffer[base+9] == "M" &&
                     sector_buffer[base+10] == "P")
                matching_resource = 3'd4;
            else if (sector_buffer[base+0] == "P" && sector_buffer[base+1] == "I" &&
                     sector_buffer[base+2] == "C" && sector_buffer[base+3] == "6" &&
                     sector_buffer[base+8] == "B" && sector_buffer[base+9] == "M" &&
                     sector_buffer[base+10] == "P")
                matching_resource = 3'd5;
            else
                matching_resource = 3'd7;
        end
    endfunction

    task finish_with_error;
        input [7:0] code;
        begin
            fs_error <= code;
            state <= ST_FINISH;
        end
    endtask

    task accept_directory_entry;
        input integer base;
        reg [2:0] resource_index;
        reg [31:0] first_cluster;
        reg [31:0] file_size;
        begin
            resource_index = matching_resource(base);
            first_cluster = {sector_buffer[base+21], sector_buffer[base+20],
                             sector_buffer[base+27], sector_buffer[base+26]};
            file_size = le32(base+28);
            case (resource_index)
                2'd0: begin
                    resource0_cluster <= first_cluster;
                    resource0_size <= file_size;
                    resource_valid[0] <= 1'b1;
                end
                2'd1: begin
                    resource1_cluster <= first_cluster;
                    resource1_size <= file_size;
                    resource_valid[1] <= 1'b1;
                end
                2'd2: begin
                    resource2_cluster <= first_cluster;
                    resource2_size <= file_size;
                    resource_valid[2] <= 1'b1;
                end
                3'd4: begin resource4_cluster <= first_cluster; resource4_size <= file_size; resource_valid[4] <= 1'b1; end
                3'd5: begin resource5_cluster <= first_cluster; resource5_size <= file_size; resource_valid[5] <= 1'b1; end
                default: begin
                    resource3_cluster <= first_cluster;
                    resource3_size <= file_size;
                    resource_valid[3] <= 1'b1;
                end
            endcase
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            partition_index<=0;partition_size<=0;fat_flags<=0;root_sector_index<=0;root_chain_count<=0;dir_end_seen<=0;root_fat_value<=0;
            scan_done <= 1'b0;
            fs_error <= ERR_NONE;
            partition_lba <= 32'd0;
            sectors_per_cluster <= 8'd0;
            fat_start_lba <= 32'd0;
            data_start_lba <= 32'd0;
            max_cluster <= 32'd0;
            resource_valid <= 6'd0;invalid_bpb<=0;
            resource0_cluster <= 32'd0;
            resource1_cluster <= 32'd0;
            resource2_cluster <= 32'd0;
            resource3_cluster <= 32'd0;
            resource0_size <= 32'd0;
            resource1_size <= 32'd0;
            resource2_size <= 32'd0;
            resource3_size <= 32'd0;resource4_cluster<=0;resource4_size<=0;resource5_cluster<=0;resource5_size<=0;
            sector_req <= 1'b0;
            sector_lba <= 32'd0;
            directory_entry_index <= 5'd0;
            root_cluster <= 32'd0;
            total_sectors <= 32'd0;
            fat_sectors <= 32'd0;
            fat_count <= 8'd0;
            reserved_sectors <= 16'd0;
            root_lba <= 32'd0;
            data_sector_count <= 32'd0;
            fat_span <= 32'd0;
            sectors_per_cluster_shift <= 3'd0;
            dir_name0 <= 8'd0;
            dir_name1 <= 8'd0;
            dir_name2 <= 8'd0;
            dir_name3 <= 8'd0;
            dir_name4 <= 8'd0;
            dir_name5 <= 8'd0;
            dir_name6 <= 8'd0;
            dir_name7 <= 8'd0;
            dir_name8 <= 8'd0;
            dir_name9 <= 8'd0;
            dir_name10 <= 8'd0;
            dir_entry_match <= 1'b0;
            dir_resource_index <= 2'd3;
            dir_cluster_high <= 16'd0;
            dir_cluster_low <= 16'd0;
            dir_file_size <= 32'd0;
        end else begin
            scan_done <= 1'b0;
            sector_req <= 1'b0;
            if (sector_valid && (state == ST_READ0_WAIT || state == ST_BOOT_WAIT))
                sector_buffer[sector_byte_index] <= sector_byte;

            if(sector_valid && state==ST_ROOT_FAT_WAIT)begin
 if(sector_byte_index[8:2]==root_cluster[6:0])case(sector_byte_index[1:0])
 0:root_fat_value[7:0]<=sector_byte;1:root_fat_value[15:8]<=sector_byte;
 2:root_fat_value[23:16]<=sector_byte;3:root_fat_value[31:24]<=sector_byte;
 endcase
end
if (sector_valid && state == ST_ROOT_WAIT) begin
                case (sector_byte_index[4:0])
                    5'd0: begin
                        dir_name0 <= sector_byte; if(sector_byte==0)dir_end_seen<=1;
                        dir_entry_match <= 1'b0;
                    end
                    5'd1:  dir_name1 <= sector_byte;
                    5'd2:  dir_name2 <= sector_byte;
                    5'd3:  dir_name3 <= sector_byte;
                    5'd4:  dir_name4 <= sector_byte;
                    5'd5:  dir_name5 <= sector_byte;
                    5'd6:  dir_name6 <= sector_byte;
                    5'd7:  dir_name7 <= sector_byte;
                    5'd8:  dir_name8 <= sector_byte;
                    5'd9:  dir_name9 <= sector_byte;
                    5'd10: dir_name10 <= sector_byte;
                    5'd11: begin
                        if (!dir_end_seen && (sector_byte & 8'h18)==0 && sector_byte!=8'h0f &&
                            dir_name0 == "P" && dir_name1 == "I" &&
                            dir_name2 == "C" && dir_name3 >= "1" &&
                            dir_name3 <= "6" && dir_name4 == " " &&
                            dir_name5 == " " && dir_name6 == " " &&
                            dir_name7 == " " && dir_name8 == "B" &&
                            dir_name9 == "M" && dir_name10 == "P") begin
                            dir_entry_match <= 1'b1;
                            dir_resource_index <= dir_name3 - "1";
                        end
                    end
                    5'd20: dir_cluster_high[7:0] <= sector_byte;
                    5'd21: dir_cluster_high[15:8] <= sector_byte;
                    5'd26: dir_cluster_low[7:0] <= sector_byte;
                    5'd27: dir_cluster_low[15:8] <= sector_byte;
                    5'd28: dir_file_size[7:0] <= sector_byte;
                    5'd29: dir_file_size[15:8] <= sector_byte;
                    5'd30: dir_file_size[23:16] <= sector_byte;
                    5'd31: begin
                        dir_file_size[31:24] <= sector_byte;
                        if (dir_entry_match && !resource_valid[dir_resource_index] && {dir_cluster_high,dir_cluster_low}>=2 && {dir_cluster_high,dir_cluster_low}<=max_cluster && {sector_byte,dir_file_size[23:0]}>=54 && {sector_byte,dir_file_size[23:0]}<=16777216) begin
                            case (dir_resource_index)
                                2'd0: begin
                                    resource0_cluster <= {dir_cluster_high, dir_cluster_low};
                                    resource0_size <= {sector_byte, dir_file_size[23:0]};
                                    resource_valid[0] <= 1'b1;
                                end
                                2'd1: begin
                                    resource1_cluster <= {dir_cluster_high, dir_cluster_low};
                                    resource1_size <= {sector_byte, dir_file_size[23:0]};
                                    resource_valid[1] <= 1'b1;
                                end
                                2'd2: begin
                                    resource2_cluster <= {dir_cluster_high, dir_cluster_low};
                                    resource2_size <= {sector_byte, dir_file_size[23:0]};
                                    resource_valid[2] <= 1'b1;
                                end
                                3'd4: begin resource4_cluster<={dir_cluster_high,dir_cluster_low};resource4_size<={sector_byte,dir_file_size[23:0]};resource_valid[4]<=1;end
                                3'd5: begin resource5_cluster<={dir_cluster_high,dir_cluster_low};resource5_size<={sector_byte,dir_file_size[23:0]};resource_valid[5]<=1;end
                                default: begin
                                    resource3_cluster <= {dir_cluster_high, dir_cluster_low};
                                    resource3_size <= {sector_byte, dir_file_size[23:0]};
                                    resource_valid[3] <= 1'b1;
                                end
                            endcase
                        end
                    end
                    default: begin end
                endcase
            end

            case (state)
                ST_IDLE: if (scan_start) begin
                    fs_error <= ERR_NONE;
                    partition_lba <= 32'd0;
            resource_valid <= 6'd0;invalid_bpb<=0;
                    partition_size<=0;partition_index<=0;root_sector_index<=0;root_chain_count<=1;dir_end_seen<=0;
                    state <= ST_READ0_REQ;
                end
                ST_READ0_REQ: if (!sector_busy) begin
                    sector_lba <= 32'd0;
                    sector_req <= 1'b1;
                    state <= ST_READ0_WAIT;
                end
                ST_READ0_WAIT: if (sector_done) begin
                    if (sector_error != 0)
                        finish_with_error(sector_error);
                    else if (sector_buffer[510] != 8'h55 || sector_buffer[511] != 8'haa)
                        finish_with_error(ERR_BOOT_SIGNATURE);
                    else if ((sector_buffer[0]==8'heb || sector_buffer[0]==8'he9) && le16(11)==512 && le16(17)==0 && le16(22)==0) begin
 partition_lba<=0;state<=ST_BOOT_PARSE;
 end else begin partition_index<=0;state<=ST_MBR;end
 end
 ST_MBR:begin
 chosen_start<=mbr_start(partition_index);chosen_size<=mbr_size(partition_index);chosen_type<=mbr_type(partition_index);state<=ST_MBR_SUM;
 end
 ST_MBR_SUM:begin selected_partition_end<={1'b0,chosen_start}+{1'b0,chosen_size};state<=ST_MBR_CHECK;end
 ST_MBR_CHECK:begin
 if((chosen_type==8'h0b || chosen_type==8'h0c) && chosen_start!=0 && chosen_size!=0 && selected_partition_end<=33'h100000000)begin
 partition_lba<=chosen_start;partition_size<=chosen_size;sector_lba<=chosen_start;state<=ST_BOOT_REQ;
 end else if(partition_index==3)finish_with_error(ERR_UNSUPPORTED_BPB);
 else begin partition_index<=partition_index+1'b1;state<=ST_MBR;end
 end
                ST_BOOT_REQ: if (!sector_busy) begin
                    sector_req <= 1'b1;
                    state <= ST_BOOT_WAIT;
                end
                ST_BOOT_WAIT: if (sector_done) begin
                    if (sector_error != 0)
                        finish_with_error(sector_error);
                    else if (sector_buffer[510] != 8'h55 || sector_buffer[511] != 8'haa)
                        finish_with_error(ERR_BOOT_SIGNATURE);
                    else
                        state <= ST_BOOT_PARSE;
                end
                ST_BOOT_PARSE: begin
                    invalid_bpb[0]<=le16(11)!=512 || !valid_spc(sector_buffer[13]) || le16(14)==0;
                    invalid_bpb[1]<=(sector_buffer[16]!=1 && sector_buffer[16]!=2) || le16(17)!=0 || le16(22)!=0;
                    invalid_bpb[2]<=le32(32)==0 || le32(36)==0 || le32(36)>32'h7fffffff || le32(44)<2;
                    invalid_bpb[3]<=le16(42)!=0 || le16(19)!=0 || (sector_buffer[40][7] && sector_buffer[40][3:0]>=sector_buffer[16]);
                    state<=ST_BOOT_CHECK;
                end
                ST_BOOT_CHECK: begin
                    if(|invalid_bpb)finish_with_error(ERR_UNSUPPORTED_BPB);
                    else begin
                        fat_flags<=le16(40);
                        sectors_per_cluster <= sector_buffer[13];
                        reserved_sectors <= le16(14);
                        fat_count <= sector_buffer[16];
                        total_sectors <= le32(32);
                        fat_sectors <= le32(36);
                        root_cluster <= le32(44);
                        sectors_per_cluster_shift <= spc_shift(sector_buffer[13]);
                        fat_span <= sector_buffer[16] == 2 ? (le32(36) << 1) : le32(36);
                        fat_start_lba <= partition_lba + le16(14);
                        state <= ST_BOOT_LAYOUT;
                    end
                end
 ST_BOOT_LAYOUT:begin overhead<={17'd0,reserved_sectors}+{1'b0,fat_span};volume_end<={1'b0,partition_lba}+{1'b0,total_sectors};state<=ST_LAYOUT_VERIFY;end
 ST_LAYOUT_VERIFY:begin
 if(overhead>={1'b0,total_sectors} || volume_end>33'h100000000 || (partition_size!=0 && total_sectors>partition_size))finish_with_error(ERR_UNSUPPORTED_BPB);
 else begin
 data_start_lba<=partition_lba+overhead[31:0];
 data_sector_count<=total_sectors-overhead[31:0];
 fat_start_lba<=fat_start_lba+((fat_flags[7] && fat_flags[0])?fat_sectors:0);
 state<=ST_BOOT_ROOT;
 end
 end
 ST_BOOT_ROOT:begin max_cluster<=(data_sector_count>>sectors_per_cluster_shift)+1'b1;state<=ST_LAYOUT_CHECK;end
 ST_LAYOUT_CHECK:begin
 // FAT32 cluster-count definition and enough FAT entries for the volume.
 if(max_cluster<65526 || max_cluster>32'h0ffffff5 || root_cluster>max_cluster || {1'b0,fat_sectors}<(({1'b0,max_cluster}+33'd128)>>7))finish_with_error(ERR_UNSUPPORTED_BPB);
 else state<=ST_ROOT_ADDR;
 end
 ST_ROOT_ADDR:begin root_delta<={1'b0,root_cluster}-33'd2;state<=ST_ROOT_SHIFT;end
 ST_ROOT_SHIFT:begin root_scaled<=root_delta<<sectors_per_cluster_shift;state<=ST_ROOT_ADD;end
 ST_ROOT_ADD:begin root_address<={1'b0,data_start_lba}+root_scaled;state<=ST_ROOT_CHECK;end
 ST_ROOT_CHECK:begin
 if(root_address>=volume_end || root_address[32])finish_with_error(ERR_UNSUPPORTED_BPB);
 else begin root_lba<=root_address[31:0];sector_lba<=root_address[31:0];root_sector_index<=0;state<=ST_ROOT_REQ;end
 end
 ST_ROOT_REQ:if(!sector_busy)begin dir_entry_match<=0;sector_req<=1;state<=ST_ROOT_WAIT;end
 ST_ROOT_WAIT:if(sector_done)begin
 if(sector_error!=0)finish_with_error(sector_error);else state<=ST_DIR_SCAN;
 end
                ST_DIR_SCAN:begin
 if(resource_valid==63 || dir_end_seen)begin if(resource_valid[3:0]!=0)state<=ST_FINISH;else finish_with_error(ERR_RESOURCE_MISSING);end
 else if(root_sector_index+1'b1<sectors_per_cluster)begin root_sector_index<=root_sector_index+1'b1;sector_lba<=sector_lba+1'b1;state<=ST_ROOT_REQ;end
 else begin sector_lba<=fat_start_lba+(root_cluster>>7);state<=ST_ROOT_FAT_REQ;end
 end
 ST_ROOT_FAT_REQ:if(!sector_busy)begin sector_req<=1;root_fat_value<=0;state<=ST_ROOT_FAT_WAIT;end
 ST_ROOT_FAT_WAIT:if(sector_done)begin if(sector_error!=0)finish_with_error(sector_error);else state<=ST_ROOT_FAT_PARSE;end
 ST_ROOT_FAT_PARSE:begin
 if(root_next>=28'hffffff8)begin if(resource_valid[3:0]!=0)state<=ST_FINISH;else finish_with_error(ERR_RESOURCE_MISSING);end
 else if(root_next<2 || root_next>max_cluster || root_next==root_cluster || root_chain_count>=1024)finish_with_error(8'h23);
 else begin root_cluster<={4'd0,root_next};root_chain_count<=root_chain_count+1'b1;state<=ST_ROOT_ADDR;end
 end
                ST_FINISH: begin
                    scan_done <= 1'b1;
                    state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
