
module top(
    input                       clk,
    input                       rst_n,
    input                       key1,           // 手动下一张
    input                       key2,           // 自动播放 开/关

    input                       key_param_n, // Independent B1 parameter button
    input [1:0]                 param_sw_n,  // C8/C7, active low

    output                      buzzer,         // Board passive speaker, H11
    output [5:0]                seg_sel,
    output [7:0]                seg_data,

    // HDMI TMDS
    output                      HDMI_CLK_P,
    output                      HDMI_D2_P,
    output                      HDMI_D1_P,
    output                      HDMI_D0_P,

    // HDMI DDC
    output                      HDMI_DDC_SCL,
    inout                       HDMI_DDC_SDA,

    // TF card SPI
    output                      sd_ncs,
    output                      sd_dclk,
    output                      sd_mosi,
    input                       sd_miso
);

parameter MEM_DATA_BITS = 32;
parameter ADDR_BITS     = 21;
parameter BUSRT_BITS    = 10;
parameter FRAME_PIXELS  = 24'd307200;   // 640*480
parameter BUF0_ADDR     = 24'd0;
parameter BUF1_ADDR     = FRAME_PIXELS;

wire osd_media_next_n,osd_media_auto_n,osd_settings,osd_pause;
wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;

wire sd_card_clk;
wire read_active_buf;
wire ext_mem_clk;
wire ext_mem_clk_sft;
wire video_clk;
wire hdmi_5x_clk;

wire hs;
wire vs;
wire de;

wire [23:0] vout_data_raw;
wire [23:0] vout_data;
wire        display_valid;

wire [3:0]  state_code;
wire osd_table_request,monitor_switch_request,monitor_switch_black;
wire [6:0] seg_data_0,seg_error;
wire [2:0] media_error_code;
wire media_degraded;

wire        video_read_req;
wire        video_read_req_ack;
wire        video_read_en;
wire [31:0] video_read_data;

wire        sd_card_write_en;
wire [31:0] sd_card_write_data;
wire        sd_card_write_req;
wire        sd_card_write_req_ack;
wire        frame_write_finish;
reg         frame_write_toggle_mem;

wire [1:0]  write_buf_idx;
wire [1:0]  disp_buf_idx;

wire App_rd_en;
wire [ADDR_BITS-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [MEM_DATA_BITS-1:0] Sdr_rd_dout;
wire App_wr_en;
wire [ADDR_BITS-1:0] App_wr_addr;
wire [MEM_DATA_BITS-1:0] App_wr_din;
wire [3:0] App_wr_dm;

wire hs_0;
wire vs_0;
wire de_0;

// Lesson 3: pixel-clock PCM and packet/symbol path; no audio PLL or I2S loop.
wire sys_locked, video_locked;
wire rst_request, pll_reset, storage_ready;
wire rst_all, rst_pixel, rst_mem;
lesson5_startup u_startup(
 .ext_rst_n(rst_n),.sys_locked(sys_locked),.video_locked(video_locked),
 .sd_clk(sd_card_clk),.mem_clk(ext_mem_clk),.pixel_clk(video_clk),
 .mem_init_done(Sdr_init_done),.pll_reset(pll_reset),.rst_request(rst_request),
 .rst_sd(rst_all),.rst_mem(rst_mem),.rst_pixel(rst_pixel),.storage_ready(storage_ready));
sys_pll sys_pll_m0(.refclk(clk), .reset(pll_reset), .locked(sys_locked),
    .clk0_out(sd_card_clk), .clk1_out(ext_mem_clk), .clk2_out(ext_mem_clk_sft));
video_pll video_pll_m0(.refclk(clk), .reset(pll_reset), .locked(video_locked),
    .clk0_out(video_clk), .clk1_out(hdmi_5x_clk));
// mem_clk 域把 write_finish 单拍转成 toggle，供 sd_card_clk 域可靠同步
always @(posedge ext_mem_clk or posedge rst_mem) begin
    if (rst_mem)
        frame_write_toggle_mem <= 1'b0;
    else if (frame_write_finish)
        frame_write_toggle_mem <= ~frame_write_toggle_mem;
end

// ===================== TF 多图扫描与缓存（双缓冲） =====================
sd_card_bmp #(.ENABLE_TRANSITION(1),.ENABLE_SETTINGS(1),
    .CLK_FREQ_HZ       (100_000_000),
    .SCAN_START_SECTOR (32'd0),
    .SCAN_MAX_SECTOR   (32'd131071),
    .SCAN_TARGET_COUNT (3'd4),
    .WAIT_READ_ACK     (1),
    .AUTO_PLAY_MS      (3000)
) sd_card_bmp_m0(
    .startup_ready     (storage_ready),
    .clk               (sd_card_clk),
    .rst               (rst_all),
    .transition_black(monitor_switch_black),.transition_request(monitor_switch_request),.settings_request(osd_settings),.media_pause(osd_pause),.table_request(osd_table_request),
    .key_next          (osd_media_next_n),
    .key_auto          (osd_media_auto_n),
    .state_code        (state_code),
    .error_code(media_error_code),.degraded(media_degraded),
    .bmp_width         (16'd640),
    .bmp_height        (16'd480),
    .display_valid     (display_valid),

    .write_finish_toggle(frame_write_toggle_mem),
    .read_active_buf   (read_active_buf),
    .write_buf_idx     (write_buf_idx),
    .disp_buf_idx      (disp_buf_idx),

    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso)
);

seg_decoder u_error_decoder(.bin_data({1'b0,media_error_code}),.seg_data(seg_error));
seg_decoder seg_decoder_m0(
    .bin_data          (state_code),
    .seg_data          (seg_data_0)
);

seg_scan #(.CLK_FREQ(100000000)) seg_scan_m0(
    .clk               (sd_card_clk),
    .rst_n             (~rst_all),
    .seg_sel           (seg_sel),
    .seg_data          (seg_data),
    .seg_data_0        ({1'b1,7'b1111_111}),
    .seg_data_1        ({1'b1,7'b1111_111}),
    .seg_data_2        ({1'b1,7'b1111_111}),
    .seg_data_3        (media_error_code!=0 ? {1'b1,7'b0000110} : 8'hff),
    .seg_data_4        (media_error_code!=0 ? {1'b1,seg_error} : 8'hff),
    .seg_data_5        ({1'b1,seg_data_0})
);

// ===================== 原图像时序与帧缓存 =====================
video_timing_data video_timing_data_m0(
    .video_clk         (video_clk),
    .rst               (rst_pixel),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0)
);

// Carry the image ID in the unused SDRAM pixel byte, aligned with RGB.
wire [26:0] tagged_video;
reg [2:0] aligned_resource;
always @(posedge video_clk or posedge rst_pixel)
 if(rst_pixel)aligned_resource<=0;else aligned_resource<=tagged_video[2:0];
assign vout_data_raw=tagged_video[26:3];
video_delay #(.DATA_WIDTH(27)) video_delay_m0(
    .video_clk         (video_clk),
    .rst               (rst_pixel),
    .read_en           (video_read_en),
    .read_data         ({video_read_data[31:8],video_read_data[2:0]}),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .hs_r              (hs),
    .vs_r              (vs),
    .de_r              (de),
    .vout_data         (tagged_video)
);

// 首图提交前黑屏；提交后一直显示当前显示缓冲区内容
wire display_valid_sync;
reg display_frame_valid;
sync_2ff u_display_valid_sync(.clk(video_clk),.rst_n(~rst_pixel),
 .async_in(display_valid),.sync_out(display_valid_sync));
always @(posedge video_clk or posedge rst_pixel)
 if(rst_pixel)display_frame_valid<=0;
 else if(video_read_req && video_read_req_ack)display_frame_valid<=display_valid_sync;
assign vout_data = display_frame_valid ? vout_data_raw : 24'd0;

frame_read_write #(
    .WRITE_V_FLIP     (1),
    .FRAME_WIDTH      (640),
    .FRAME_HEIGHT     (480)
) frame_read_write_m0(
    .mem_clk           (ext_mem_clk),
    .read_active_buf   (read_active_buf),
    .rst               (rst_request),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),

    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout),

    .read_clk          (video_clk),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .read_finish       (),
    .read_addr_0       (BUF0_ADDR),
    .read_addr_1       (BUF1_ADDR),
    .read_addr_2       (24'd0),
    .read_addr_3       (24'd0),
    .read_addr_index   (disp_buf_idx),
    .read_len          (FRAME_PIXELS),
    .read_en           (video_read_en),
    .read_data         (video_read_data),

    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_din        (App_wr_din),
    .App_wr_dm         (App_wr_dm),

    .write_clk         (sd_card_clk),
    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_finish      (frame_write_finish),
    .write_addr_0      (BUF0_ADDR),
    .write_addr_1      (BUF1_ADDR),
    .write_addr_2      (24'd0),
    .write_addr_3      (24'd0),
    .write_addr_index  (write_buf_idx),
    .write_len         (FRAME_PIXELS),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data)
);

sdram U3(
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),
    .Rst               (rst_mem),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_dm         (App_wr_dm),
    .App_wr_din        (App_wr_din),
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout)
);

wire aligned_hs, aligned_vs, aligned_de, next_line_active;
wire [9:0] video_x, video_y;
wire [23:0] aligned_rgb;
// Transfer image metadata atomically and apply it on the first active pixel.
wire [1:0] source_media = state_code == 0 ? 2'd0 : state_code[1:0]-2'd1;
wire [1:0] audible_media;
lesson3_media_cdc u_media_cdc(
 .source_clk(sd_card_clk),.source_rst(rst_all),.source_id(source_media),
 .pixel_clk(video_clk),.pixel_rst(rst_pixel),
 .frame_start(aligned_de && video_x==0 && video_y==0),.media_id(audible_media));
lesson3_video_align u_lesson3_video_align(
    .clk(video_clk), .rst(rst_pixel), .hs(hs), .vs(vs), .de(de), .rgb(vout_data),
    .hs_q(aligned_hs), .vs_q(aligned_vs), .de_q(aligned_de), .rgb_q(aligned_rgb),
    .x(video_x), .y(video_y), .next_line_active(next_line_active));
wire [23:0] osd_rgb;wire osd_hs,osd_vs,osd_de,osd_next_line;wire [9:0] osd_x;
wire [1:0] audio_status;
wire [7:0] parameter_volume;wire [3:0] parameter_level,parameter_brightness,parameter_contrast;
wire [1:0] parameter_selected;wire parameter_show;
display_parameter_ctrl u_parameter_ctrl(
 .clk(video_clk),.rst(rst_pixel),.frame_tick(video_x==0 && video_y==480),
 .key_n(key_param_n),.sw_n(param_sw_n),.volume(parameter_volume),.vol_level(parameter_level),
 .brightness(parameter_brightness),.contrast(parameter_contrast),.selected(parameter_selected),.hud_show(parameter_show));
osd_overlay_mixer #(.DISPLAY_CONTROLS(1)) u_osd(
 .clk(video_clk),.rst(rst_pixel),.key1_n(key1),.key2_n(key2),
 .rgb_in(aligned_rgb),.hs(aligned_hs),.vs(aligned_vs),.de(aligned_de),.next_line(next_line_active),
 .x(video_x),.y(video_y),.media_valid(display_frame_valid),.media_zone(aligned_resource),
 .rgb_out(osd_rgb),.hs_out(osd_hs),.vs_out(osd_vs),.de_out(osd_de),.next_line_out(osd_next_line),.x_out(osd_x),
 .media_next_n(osd_media_next_n),.media_auto_n(osd_media_auto_n),.settings_request(osd_settings),.media_pause(osd_pause),.table_request(osd_table_request),.switch_request(monitor_switch_request),.switch_black(monitor_switch_black),.audio_status(audio_status),.control_volume(parameter_level),.control_brightness(parameter_brightness),
 .control_contrast(parameter_contrast),.control_selected(parameter_selected),.control_show(parameter_show));
wire [9:0] tmds_ch0_data, tmds_ch1_data, tmds_ch2_data;
wire [9:0] tmds_clk_data = 10'b1111100000;
wire audio_sequence_error, audio_overflow, audio_contract_error, audio_blip;
wire pcm_tap_valid;
wire signed [15:0] pcm_tap_left;
media_hdmi_audio_bridge #(.STATUS_AUDIO(1)) u_audio_bridge(
    .pixel_clk(video_clk), .pixel_rst_n(~rst_pixel),
    .video_hsync(osd_hs), .video_vsync(osd_vs), .video_de(osd_de),
    .video_x(osd_x), .video_next_line_active(osd_next_line), .video_rgb(osd_rgb),
    .media_id(audible_media), .volume(parameter_volume), .alarm_status(audio_status),
    .channel0_symbol(tmds_ch0_data), .channel1_symbol(tmds_ch1_data),
    .channel2_symbol(tmds_ch2_data), .sequence_error(audio_sequence_error),
    .tone_overflow(audio_overflow), .pcm_contract_error(audio_contract_error),
    .blip_active(audio_blip), .pcm_tap_valid(pcm_tap_valid), .pcm_tap_left(pcm_tap_left));
// Current-zone status drives both outputs; red buzzer has a full-duty carrier.
status_buzzer_output u_status_buzzer(
 .clk(video_clk),.rst(rst_pixel),.sample_valid(pcm_tap_valid),
 .sample_pcm(pcm_tap_left),.alarm_status(audio_status),.buzzer(buzzer));
// Fixed 640x480 mode; no EDID transaction is needed. Release the DDC bus.
assign HDMI_DDC_SCL=1'bz;
assign HDMI_DDC_SDA=1'bz;
hdmi_phy_wrapper #(
    .DEVICE ( "EG" )
) u_hdmi2phy_wrapper(
    .I_pixel_clk        (video_clk),
    .I_serial_clk       (hdmi_5x_clk),
    .I_rst              (rst_request),
    .I_tmds_channel_0   (tmds_ch0_data),
    .I_tmds_channel_1   (tmds_ch1_data),
    .I_tmds_channel_2   (tmds_ch2_data),
    .I_tmds_channel_clk (tmds_clk_data),
    .O_tmds_ch0_p       (HDMI_D0_P),
    .O_tmds_ch1_p       (HDMI_D1_P),
    .O_tmds_ch2_p       (HDMI_D2_P),
    .O_tmds_clk_p       (HDMI_CLK_P)
);

endmodule
