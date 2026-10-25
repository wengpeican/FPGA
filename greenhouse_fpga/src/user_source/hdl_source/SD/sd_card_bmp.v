
module sd_card_bmp #(
    parameter integer CLK_FREQ_HZ       = 100_000_000,
    parameter [31:0]  SCAN_START_SECTOR = 32'd0,
    parameter [31:0]  SCAN_MAX_SECTOR   = 32'd131071,
    parameter [2:0]   SCAN_TARGET_COUNT = 3'd4,
    parameter integer LONG_PRESS_MS = 1000,
    parameter integer AUTO_PLAY_MS = 3000,
    parameter integer LOAD_TIMEOUT_MS = 10000,
    parameter integer WAIT_READ_ACK = 0,
    parameter integer SD_READ_TIMEOUT_MS = 500,
    parameter integer MAX_RETRIES = 1,
    parameter integer ENABLE_TRANSITION = 0, parameter integer ENABLE_SETTINGS = 0, parameter integer USE_FAT32 = 1
)(
    input                       clk,
    input                       rst,
    input settings_request, input media_pause, input table_request, // pixel-domain levels, synchronized below
    input                       startup_ready, // synchronized SDRAM initialization status
    input                       key_next,
    input                       key_auto,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,
    output reg                  display_valid,
    output      [3:0]           state_code,
    output reg [2:0] error_code, output reg degraded,

    input                       read_active_buf,
    input                       write_finish_toggle,
    output reg [1:0]            write_buf_idx,
    output reg [1:0]            disp_buf_idx,

    output                      write_req,
    input                       write_req_ack,
    output                      write_en,
    output [31:0]               write_data,
    output                      SD_nCS,
    output                      SD_DCLK,
    output                      SD_MOSI,
    input transition_black, output transition_request, input                       SD_MISO
);

localparam [63:0] AUTO_CYCLES_RAW = (64'd1 * CLK_FREQ_HZ / 1000) * AUTO_PLAY_MS;
localparam [63:0] LONG_CYCLES_RAW = (64'd1 * CLK_FREQ_HZ / 1000) * LONG_PRESS_MS;
localparam [63:0] AUTO_CYCLES = AUTO_CYCLES_RAW < 1 ? 1 : AUTO_CYCLES_RAW;
localparam [63:0] LONG_CYCLES = LONG_CYCLES_RAW < 1 ? 1 : LONG_CYCLES_RAW;
localparam [63:0] LOAD_TIMEOUT_CYCLES = (64'd1 * CLK_FREQ_HZ / 1000) * LOAD_TIMEOUT_MS;

reg [1:0] settings_sync,pause_sync,table_sync;
reg [1:0] settings_previous,displaying_settings,load_settings;
wire [1:0] want_settings=ENABLE_SETTINGS ? (table_sync[1] ? 2'd2 : settings_sync[1] ? 2'd1 : 2'd0) : 2'd0;
wire pause_media=ENABLE_SETTINGS && pause_sync[1];
always @(posedge clk or posedge rst)
 if(rst)begin settings_sync<=0;pause_sync<=0;table_sync<=0;end
 else begin settings_sync<={settings_sync[0],settings_request};pause_sync<={pause_sync[0],media_pause};table_sync<={table_sync[0],table_request};end
wire key_next_press;
wire key_auto_press;
wire key_auto_stable;
reg key_auto_stable_d;
reg [((LONG_CYCLES > 1) ? $clog2(LONG_CYCLES) : 1)-1:0] long_press_cnt;
reg long_press_marked;
reg key_auto_short;
reg key_auto_long;
reg prev_req_pending;

wire             sd_sec_read;
wire [31:0]      sd_sec_read_addr;
wire [7:0]       sd_sec_read_data;
wire             sd_sec_read_data_valid;
wire             sd_sec_read_end;
wire [3:0]       state_code_i;
wire             bmp_data_wr_en;
wire [23:0]      bmp_data;
wire             sd_init_done;
wire             bmp_ready;
wire             scan_done;
wire             scan_found_valid;
wire [31:0]      scan_found_sector;
wire [2:0]       scan_found_total;

reg              scan_start_pulse;
reg              load_start_pulse;
reg [31:0]       load_sector;
reg              scan_kicked;
reg              first_image_committed;
reg              auto_play_en;
reg [((AUTO_CYCLES > 1) ? $clog2(AUTO_CYCLES) : 1)-1:0] auto_cnt;
reg              auto_req_pending;

reg [2:0]        img_found_count;
reg [1:0]        img_idx;              
reg [1:0]        load_idx;             
reg [1:0]        pending_buf_idx;      
reg [31:0]       img_sector0;
reg [31:0]       img_sector1;
reg [31:0]       img_sector2;
reg [31:0]       img_sector3;
reg              next_req_pending;
reg              load_busy;
reg [((LOAD_TIMEOUT_CYCLES > 1) ? $clog2(LOAD_TIMEOUT_CYCLES) : 1)-1:0] load_timeout_cnt;
reg [1:0] read_active_sync;
always @(posedge clk or posedge rst)
    if (rst) read_active_sync <= 0;
    else read_active_sync <= {read_active_sync[0],read_active_buf};
reg scan_complete;
reg reader_busy_seen;
reg load_is_auto;
reg load_error;

wire parser_error,parser_success;
wire [2:0] parser_error_code;
reg retry_pending;
reg [3:0] bad_mask,retry_count,scan_retries;
reg [5:0] recovery_guard;
reg transport_reset,scan_blocked;
reg [((LOAD_TIMEOUT_CYCLES > 1) ? $clog2(LOAD_TIMEOUT_CYCLES) : 1)-1:0] init_timeout_cnt;
wire [1:0] next_healthy;
assign next_healthy=healthy_index(img_idx,img_found_count,bad_mask,1'b0);
reg load_abort;
function [1:0] healthy_index;
 input [1:0] cur; input [2:0] count;input [3:0] mask;input backwards;
 reg [3:0] good;
 begin
 case(count)
 0:good=0;1:good=4'b0001 & ~mask;2:good=4'b0011 & ~mask;
 3:good=4'b0111 & ~mask;default:good=~mask;
 endcase
 // Parallel eligibility, then a fixed circular priority order. Avoid four
 // cascaded variable wraparound increments in the 100 MHz control path.
 if(backwards)case(cur)
 0:healthy_index=good[3]?3:good[2]?2:good[1]?1:cur;
 1:healthy_index=good[0]?0:good[3]?3:good[2]?2:cur;
 2:healthy_index=good[1]?1:good[0]?0:good[3]?3:cur;
 3:healthy_index=good[2]?2:good[1]?1:good[0]?0:cur;
 endcase
 else case(cur)
 0:healthy_index=good[1]?1:good[2]?2:good[3]?3:cur;
 1:healthy_index=good[2]?2:good[3]?3:good[0]?0:cur;
 2:healthy_index=good[3]?3:good[0]?0:good[1]?1:cur;
 3:healthy_index=good[0]?0:good[1]?1:good[2]?2:cur;
 endcase
 end
endfunction


reg [1:0] black_sync;
reg transition_armed;
wire transition_needed=ENABLE_TRANSITION && first_image_committed &&
 !displaying_settings && !load_settings && load_idx!=img_idx;
always @(posedge clk or posedge rst)
 if(rst)begin black_sync<=0;transition_armed<=0;end
 else begin
 black_sync<={black_sync[0],transition_black};
 if(!load_busy)transition_armed<=0;
 else if(!black_sync[1])transition_armed<=1;
 end
reg              source_done_seen;
reg              write_done_seen;


reg [2:0]        wrfin_tgl_sync;
wire             write_finish_pulse;

wire auto_tick;
assign transition_request=transition_needed && load_busy && source_done_seen && write_done_seen &&
 load_settings==want_settings && (!load_is_auto || (auto_tick && auto_play_en && !pause_media));

wire [1:0] next_from_current;

assign write_en   = bmp_data_wr_en;
// Resource ID follows RGB through the same FIFO and SDRAM frame buffer.
wire [2:0] pixel_resource_id = USE_FAT32 ? load_sector[2:0] : {1'b0,load_idx};
assign write_data = {bmp_data[23:16], bmp_data[15:8], bmp_data[7:0], 5'b0, pixel_resource_id};
assign auto_tick  = (auto_cnt >= AUTO_CYCLES - 1);
assign next_from_current = next_index_limited(img_idx, img_found_count);
assign write_finish_pulse = wrfin_tgl_sync[2] ^ wrfin_tgl_sync[1];
wire [31:0] displayed_resource=sector_lut(img_idx);
// Independent synchronized single-bit page request levels.
assign state_code = displaying_settings ? (displaying_settings==2 ? 4'd6 : 4'd5) : display_valid ? ((USE_FAT32 ? {2'b00,displayed_resource[1:0]} : {2'b00,img_idx}) + 4'd1) : 4'd0;

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (20)
) u_key_next (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_next),
    .press_pulse(key_next_press)
);

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (20)
) u_key_auto (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_auto),
    .press_pulse(key_auto_press),
    .button_stable_out(key_auto_stable)
);

// KEY2: one long event per hold; short event only on debounced release.
always @(posedge clk or posedge rst) begin
    if (rst) begin
        key_auto_stable_d <= 1'b1;
        long_press_cnt <= 0;
        long_press_marked <= 1'b0;
        key_auto_short <= 1'b0;
        key_auto_long <= 1'b0;
    end else begin
        key_auto_stable_d <= key_auto_stable;
        key_auto_short <= 1'b0;
        key_auto_long <= 1'b0;
        if (!key_auto_stable) begin
            if (!long_press_marked) begin
                if (long_press_cnt >= LONG_CYCLES - 1) begin
                    key_auto_long <= 1'b1;
                    long_press_marked <= 1'b1;
                end else
                    long_press_cnt <= long_press_cnt + 1'b1;
            end
        end else begin
            if (!key_auto_stable_d && !long_press_marked)
                key_auto_short <= 1'b1;
            long_press_cnt <= 0;
            long_press_marked <= 1'b0;
        end
    end
end

function [1:0] prev_index_limited;
    input [1:0] cur;
    input [2:0] count;
    begin
        case (count)
            0, 1: prev_index_limited = 0;
            2: prev_index_limited = cur == 0 ? 1 : cur - 1'b1;
            3: prev_index_limited = cur == 0 ? 2 : cur - 1'b1;
            default: prev_index_limited = cur == 0 ? 3 : cur - 1'b1;
        endcase
    end
endfunction

function [1:0] next_index_limited;
    input [1:0] cur;
    input [2:0] count;
    begin
        case (count)
            3'd0: next_index_limited = 2'd0;
            3'd1: next_index_limited = 2'd0;
            3'd2: next_index_limited = (cur == 2'd1) ? 2'd0 : (cur + 2'd1);
            3'd3: next_index_limited = (cur == 2'd2) ? 2'd0 : (cur + 2'd1);
            default: next_index_limited = (cur == 2'd3) ? 2'd0 : (cur + 2'd1);
        endcase
    end
endfunction

function [31:0] sector_lut;
    input [1:0] idx;
    begin
        case (idx)
            2'd0: sector_lut = img_sector0;
            2'd1: sector_lut = img_sector1;
            2'd2: sector_lut = img_sector2;
            2'd3: sector_lut = img_sector3;
            default: sector_lut = img_sector0;
        endcase
    end
endfunction

function [1:0] next_buf_lut;
    input [1:0] cur_disp_buf;
    input       valid_now;
    begin
        if (!valid_now)
            next_buf_lut = 2'd0;                 
        else if (cur_disp_buf == 2'd0)
            next_buf_lut = 2'd1;
        else
            next_buf_lut = 2'd0;
    end
endfunction

// Recovery is part of the transaction FSM; retry count survives a retry start.
always @(posedge clk or posedge rst) begin
 if(rst)begin
 settings_previous<=0;displaying_settings<=0;load_settings<=0;
 wrfin_tgl_sync<=0;scan_start_pulse<=0;load_start_pulse<=0;load_abort<=0;transport_reset<=0;
 scan_kicked<=0;scan_complete<=0;reader_busy_seen<=0;first_image_committed<=0;display_valid<=0;
 auto_play_en<=0;auto_cnt<=0;auto_req_pending<=0;img_found_count<=0;img_idx<=0;load_idx<=0;
 write_buf_idx<=0;disp_buf_idx<=0;pending_buf_idx<=0;img_sector0<=0;img_sector1<=0;img_sector2<=0;img_sector3<=0;
 load_sector<=0;next_req_pending<=0;prev_req_pending<=0;load_busy<=0;load_timeout_cnt<=0;
 source_done_seen<=0;write_done_seen<=0;load_is_auto<=0;load_error<=0;
 retry_pending<=0;bad_mask<=0;retry_count<=0;scan_retries<=0;recovery_guard<=0;
 error_code<=0;degraded<=0;scan_blocked<=0;init_timeout_cnt<=0;
 end else begin
 wrfin_tgl_sync<={wrfin_tgl_sync[1:0],write_finish_toggle};
settings_previous<=want_settings;
if(settings_previous!=want_settings)begin degraded<=0;retry_pending<=0;retry_count<=0;end
 scan_start_pulse<=0;load_start_pulse<=0;load_abort<=0;transport_reset<=0;
 if(recovery_guard!=0)recovery_guard<=recovery_guard-1'b1;
 // Transport reinitialization never invalidates the displayed frame.
 if(!sd_init_done)begin
 if(init_timeout_cnt<LOAD_TIMEOUT_CYCLES-1)init_timeout_cnt<=init_timeout_cnt+1'b1;
 else begin error_code<=2;degraded<=1;auto_play_en<=0;retry_pending<=0;scan_blocked<=1;end
 end else init_timeout_cnt<=0;
 if(key_next_press && degraded)begin
 degraded<=0;scan_blocked<=0;scan_retries<=0;bad_mask<=0;init_timeout_cnt<=0;
 if(!scan_complete)scan_kicked<=0;
 if(!sd_init_done)begin transport_reset<=1;recovery_guard<=32;end
 end
 if(scan_found_valid && !scan_complete)begin
 case(img_found_count)
 0:img_sector0<=scan_found_sector;1:img_sector1<=scan_found_sector;
 2:img_sector2<=scan_found_sector;3:img_sector3<=scan_found_sector;
 endcase
 if(img_found_count<4)img_found_count<=img_found_count+1'b1;
 end
 if(scan_done && scan_kicked && !scan_complete && !scan_start_pulse)begin
 scan_complete<=1;
 if(img_found_count==0 && !scan_found_valid)begin error_code<=1;degraded<=1;end
 end
 if(startup_ready && !scan_kicked && !scan_blocked && sd_init_done && bmp_ready && recovery_guard==0 && !transport_reset)begin
 scan_start_pulse<=1;scan_kicked<=1;img_found_count<=0;
 end
 if(key_next_press && scan_complete && img_found_count==0)begin
 scan_complete<=0;scan_kicked<=0;scan_blocked<=0;bad_mask<=0;scan_retries<=0;
 end
 if(scan_complete && img_found_count!=0)begin
 if(key_next_press)next_req_pending<=1;
 if(key_auto_long)prev_req_pending<=1;
 if(key_auto_short && img_found_count>1)begin auto_play_en<=~auto_play_en;degraded<=0;bad_mask<=0;end
 end
 if(key_auto_short || !auto_play_en || !display_valid || pause_media || displaying_settings)begin auto_cnt<=0;auto_req_pending<=0;end
 else if(!auto_tick)auto_cnt<=auto_cnt+1'b1;
 else auto_req_pending<=1;
 if(parser_error && !load_busy && !scan_complete)begin
 error_code<=parser_error_code;load_abort<=1;recovery_guard<=32;
 if(parser_error_code==2)transport_reset<=1;
 if(scan_retries<MAX_RETRIES)begin scan_retries<=scan_retries+1'b1;scan_kicked<=0;img_found_count<=0;end
 else begin scan_blocked<=1;degraded<=1;end
 end
 if(load_busy)begin
 if(!bmp_ready)reader_busy_seen<=1;
 if(parser_success)source_done_seen<=1;
 if(write_finish_pulse)write_done_seen<=1;
 if(parser_error || (!(source_done_seen && write_done_seen) && load_timeout_cnt>=LOAD_TIMEOUT_CYCLES-1))begin
 error_code<=parser_error?parser_error_code:3'd2;
 load_abort<=1;load_busy<=0;load_error<=1;source_done_seen<=0;write_done_seen<=0;
 load_timeout_cnt<=0;recovery_guard<=32;
 // FAT32 may reject a BMP before the current raw sector has drained.
 if(USE_FAT32 || !parser_error || parser_error_code==2)transport_reset<=1;
 if(retry_count<MAX_RETRIES)begin retry_count<=retry_count+1'b1;retry_pending<=1;end
 else begin
 if(!load_settings)bad_mask[load_idx]<=1;retry_pending<=0;
 if(load_settings)degraded<=1;else if(load_is_auto || !first_image_committed)begin
 if((bad_mask | (4'b0001<<load_idx)) == ((5'b00001<<img_found_count)-1))begin degraded<=1;auto_play_en<=0;end
 else begin
 load_idx<=healthy_index(load_idx,img_found_count,bad_mask | (4'b0001<<load_idx),1'b0);
 load_sector<=sector_lut(healthy_index(load_idx,img_found_count,bad_mask | (4'b0001<<load_idx),1'b0));
 retry_count<=0;retry_pending<=1;
 end
 end else degraded<=1;
 end
 end else if(source_done_seen && write_done_seen)begin
 load_timeout_cnt<=0;
 if((load_settings!=want_settings) || (load_is_auto && (pause_media || !auto_play_en || key_auto_short || next_req_pending || prev_req_pending || key_next_press || key_auto_long)))begin
 load_busy<=0;load_is_auto<=0;source_done_seen<=0;write_done_seen<=0;auto_cnt<=0;auto_req_pending<=0;
 end else if((!load_is_auto || auto_tick) && (!transition_needed || (transition_armed && black_sync[1])))begin
 disp_buf_idx<=pending_buf_idx;if(!load_settings)img_idx<=load_idx;displaying_settings<=load_settings;display_valid<=1;first_image_committed<=1;
 load_busy<=0;load_is_auto<=0;load_error<=0;degraded<=0;retry_count<=0;
 source_done_seen<=0;write_done_seen<=0;auto_cnt<=0;auto_req_pending<=0;
 end
 end else load_timeout_cnt<=load_timeout_cnt+1'b1;
 end else if(startup_ready && retry_pending && sd_init_done && bmp_ready && recovery_guard==0 && !transport_reset && !load_abort)begin
 if((load_settings!=want_settings) || (load_is_auto && (!auto_play_en || pause_media)))retry_pending<=0;
 else begin load_start_pulse<=1;load_busy<=1;retry_pending<=0;reader_busy_seen<=0;source_done_seen<=0;write_done_seen<=0;load_timeout_cnt<=0;end
 end else if(startup_ready && !retry_pending && !degraded && !load_abort && recovery_guard==0 && sd_init_done && scan_complete && bmp_ready && img_found_count!=0 &&
 (!WAIT_READ_ACK || !display_valid || read_active_sync[1]==disp_buf_idx[0]))begin
 if((want_settings!=displaying_settings) || (!first_image_committed && !load_error) || (!pause_media && (next_req_pending || prev_req_pending)) ||
 (!pause_media && !displaying_settings && auto_play_en && !key_auto_short && img_found_count>1 && next_healthy!=img_idx))begin
 load_settings<=want_settings;
 if(want_settings!=displaying_settings)begin load_idx<=img_idx;load_sector<=want_settings?(want_settings==2?32'd5:32'd4):sector_lut(img_idx);load_is_auto<=0;end
 else if(!first_image_committed)begin load_idx<=0;load_sector<=img_sector0;load_is_auto<=0;end
 else if(prev_req_pending && !next_req_pending)begin load_idx<=healthy_index(img_idx,img_found_count,bad_mask,1'b1);load_sector<=sector_lut(healthy_index(img_idx,img_found_count,bad_mask,1'b1));load_is_auto<=0;end
 else begin load_idx<=next_healthy;load_sector<=sector_lut(next_healthy);load_is_auto<=!next_req_pending;end
 if(next_req_pending)next_req_pending<=key_next_press;else if(prev_req_pending)prev_req_pending<=key_auto_long;
 pending_buf_idx<=next_buf_lut(disp_buf_idx,display_valid);write_buf_idx<=next_buf_lut(disp_buf_idx,display_valid);
 load_start_pulse<=1;load_busy<=1;load_timeout_cnt<=0;reader_busy_seen<=0;source_done_seen<=0;write_done_seen<=0;load_error<=0;retry_count<=0;
 end
 end
 end
end
generate if(USE_FAT32)begin: fat32_parser
 wire [7:0] filesystem_error;
 fat32_bmp_backend #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.SD_READ_TIMEOUT_MS(SD_READ_TIMEOUT_MS)) backend(
 .clk(clk),.rst(rst),.ready(bmp_ready),.scan_start(scan_start_pulse),.scan_done(scan_done),
 .scan_found_valid(scan_found_valid),.scan_found_sector(scan_found_sector),.scan_found_total(scan_found_total),
 .load_start(load_start_pulse),.load_abort(load_abort),.load_sector(load_sector),.sd_init_done(sd_init_done),
 .bmp_width(bmp_width),.bmp_height(bmp_height),.write_req(write_req),.write_req_ack(write_req_ack),
 .sd_sec_read(sd_sec_read),.sd_sec_read_addr(sd_sec_read_addr),.sd_sec_read_data(sd_sec_read_data),.sd_sec_read_data_valid(sd_sec_read_data_valid),.sd_sec_read_end(sd_sec_read_end),
 .bmp_data_wr_en(bmp_data_wr_en),.bmp_data(bmp_data),.bmp_error(parser_error_code),.load_error(parser_error),.load_success(parser_success),.fs_error(filesystem_error));
end else begin: legacy_parser
bmp_read #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.SD_READ_TIMEOUT_MS(SD_READ_TIMEOUT_MS)) bmp_read_m0(
    .bmp_error(parser_error_code),.load_error(parser_error),.load_success(parser_success),
    .clk                    (clk),
    .rst                    (rst),
    .ready                  (bmp_ready),

    .scan_start             (scan_start_pulse),
    .scan_start_sector      (SCAN_START_SECTOR),
    .scan_max_sector        (SCAN_MAX_SECTOR),
    .scan_target_count      (SCAN_TARGET_COUNT),
    .scan_done              (scan_done),
    .scan_found_valid       (scan_found_valid),
    .scan_found_sector      (scan_found_sector),
    .scan_found_total       (scan_found_total),

    .load_start             (load_start_pulse),
    .load_abort             (load_abort),
    .load_sector            (load_sector),

    .sd_init_done           (sd_init_done),
    .state_code             (state_code_i),
    .bmp_width              (bmp_width),
    .bmp_height             (bmp_height),
    .write_req              (write_req),
    .write_req_ack          (write_req_ack),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_end        (sd_sec_read_end),
    .bmp_data_wr_en         (bmp_data_wr_en),
    .bmp_data               (bmp_data)
);

end endgenerate
sd_card_top sd_card_top_m0(
    .clk                    (clk),
    .rst                    (rst | transport_reset),
    .SD_nCS                 (SD_nCS),
    .SD_DCLK                (SD_DCLK),
    .SD_MOSI                (SD_MOSI),
    .SD_MISO                (SD_MISO),
    .sd_init_done           (sd_init_done),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_end        (sd_sec_read_end),
    .sd_sec_write           (1'b0),
    .sd_sec_write_addr      (32'd0),
    .sd_sec_write_data      (8'd0),
    .sd_sec_write_data_req  (),
    .sd_sec_write_end       ()
);

endmodule

module key_press_debounce #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst,
    input  wire button_in,    
    output wire button_stable_out,
    output reg  press_pulse
);


localparam integer DEBOUNCE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
reg button_sync0;
reg button_sync1;
reg button_stable;
assign button_stable_out = button_stable;
reg [31:0] cnt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        button_sync0  <= 1'b1;
        button_sync1  <= 1'b1;
        button_stable <= 1'b1;
        cnt           <= 32'd0;
        press_pulse   <= 1'b0;
    end else begin
        button_sync0 <= button_in;
        button_sync1 <= button_sync0;
        press_pulse  <= 1'b0;

        if (button_sync1 == button_stable) begin
            cnt <= 32'd0;
        end else begin
            if (cnt >= DEBOUNCE_CYCLES - 1) begin
                if (button_stable && !button_sync1)
                    press_pulse <= 1'b1;
                button_stable <= button_sync1;
                cnt           <= 32'd0;
            end else begin
                cnt <= cnt + 32'd1;
            end
        end
    end
end

endmodule
