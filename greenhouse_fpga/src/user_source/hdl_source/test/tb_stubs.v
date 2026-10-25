//=============================================================
// tb_stubs.v
// 完整 top 仿真的行为桩/模型（iverilog 专用，仅仿真）
//  1) EG_PHY_PLL         - 行为 PLL：分频输出 clkc[4:0]，extlock 延时置位
//  2) EG_LOGIC_BUFG      - 直连缓冲
//  3) hdmi_1_4b_transmitter_core_wrapper
//                        - HDMI 发射核桩（原核为 pragma protect 加密，
//                          无法被 iverilog 解析；桩验证音频/视频接口
//                          信号到达核，并把活动反映到 TMDS 输出）
//  4) sdram              - SDRAM 控制器桩（原控制器依赖加密的
//                          include/sdr_*.enc.v；桩提供 init_done/busy
//                          信号使帧缓存链路状态机得以推进）
//=============================================================
`timescale 1ns/1ps

// ---------- 1) EG_PHY_PLL 行为模型 ----------
module EG_PHY_PLL #(
    parameter DPHASE_SOURCE  = "DISABLE",
    parameter DYNCFG         = "DISABLE",
    parameter FIN            = "50.000000",
    parameter FEEDBK_MODE    = "NORMAL",
    parameter FEEDBK_PATH    = "CLKC0_EXT",
    parameter STDBY_ENABLE   = "DISABLE",
    parameter PLLRST_ENA     = "ENABLE",
    parameter SYNC_ENABLE    = "DISABLE",
    parameter GMC_GAIN       = 4,
    parameter ICP_CURRENT    = 29,
    parameter KVCO           = 4,
    parameter LPF_CAPACITOR  = 1,
    parameter LPF_RESISTOR   = 2,
    parameter REFCLK_DIV     = 1,
    parameter FBCLK_DIV      = 2,
    parameter CLKC0_ENABLE   = "ENABLE",
    parameter CLKC0_DIV = 10, CLKC0_CPHASE = 9, CLKC0_FPHASE = 0,
    parameter CLKC1_ENABLE   = "DISABLE",
    parameter CLKC1_DIV = 1, CLKC1_CPHASE = 0, CLKC1_FPHASE = 0,
    parameter CLKC2_ENABLE   = "DISABLE",
    parameter CLKC2_DIV = 1, CLKC2_CPHASE = 0, CLKC2_FPHASE = 0,
    parameter CLKC3_ENABLE   = "DISABLE",
    parameter CLKC3_DIV = 1, CLKC3_CPHASE = 0, CLKC3_FPHASE = 0,
    parameter CLKC4_ENABLE   = "DISABLE",
    parameter CLKC4_DIV = 1, CLKC4_CPHASE = 0, CLKC4_FPHASE = 0
)(
    output reg [4:0] clkc,
    output reg       extlock,
    input            stdby,
    input            refclk,
    input            fbclk,
    input            reset,
    input            load_reg,
    output reg       psdone,
    input            psclk,
    input            psdown,
    input            psstep,
    input      [2:0] psclksel,
    output reg       do,
    input            dclk,
    input            dcs,
    input            dwe,
    input            di,
    input            daddr
);
    // 简化行为：clk0 每 1 个 refclk 翻转（refclk/2），clk2 每 2 个 refclk 翻转（refclk/4）
    // clk1 用独立 125MHz 振荡器（HDMI 串行时钟需 ≥5× pixel_clk，跨时钟沿检测才能工作）
    // 不严格复现真实频率，仅用于功能仿真
    integer c1 = 0, c2 = 0, lock_cnt = 0;
    reg    osc5 = 0;
    always #2 osc5 = ~osc5;   // 250MHz 振荡

    always @(posedge refclk or posedge reset) begin
        if (reset) begin
            clkc     <= 5'b0;
            c1       <= 0;
            c2       <= 0;
            lock_cnt <= 0;
            extlock  <= 1'b0;
        end else begin
            clkc[0] <= ~clkc[0];
            c2 <= c2 + 1;
            if (c2 >= 1) begin c2 <= 0; clkc[2] <= ~clkc[2]; end
            if (lock_cnt < 20) begin
                lock_cnt <= lock_cnt + 1;
                extlock  <= 1'b0;
            end else begin
                extlock  <= 1'b1;
            end
        end
    end

    always @(posedge osc5 or posedge reset) begin
        if (reset) clkc[1] <= 1'b0;
        else       clkc[1] <= ~clkc[1];
    end

    initial begin
        psdone = 1'b0;
        do     = 1'b0;
        clkc   = 5'b0;
    end
endmodule

// ---------- 2) EG_LOGIC_BUFG ----------
module EG_LOGIC_BUFG (input i, output o);
    assign o = i;
endmodule

// ---------- 2b) EG_LOGIC_ODDR 行为模型（DDR 输出）----------
module EG_LOGIC_ODDR (q, clk, d1, d0, rst);
    output q;
    input  clk, d1, d0, rst;
    reg    qr;
    always @(posedge clk or posedge rst)
        if (rst) qr <= 1'b0; else qr <= d0;
    always @(negedge clk or posedge rst)
        if (rst) qr <= 1'b0; else qr <= d1;
    assign q = qr;
endmodule

// ---------- 3) HDMI 发射核桩 ----------
module hdmi_1_4b_transmitter_core_wrapper #(
    parameter DEVICE            = "EG",
    parameter HTOTAL            = 2200,
    parameter HSA               = 44,
    parameter HFP               = 88,
    parameter HBP               = 148,
    parameter HACTIVE           = 1920,
    parameter VTOTAL            = 1125,
    parameter VSA               = 5,
    parameter VFP               = 4,
    parameter VBP               = 36,
    parameter VACTIVE           = 1080,
    parameter VIDEO_TPG         = "Enable",
    parameter VIDEO_FORMAT      = "RGB",
    parameter VIDEO_VIC         = 16,
    parameter AUDIO_SAMPLE_RATE = "48K",
    parameter IIC_SCL_DIV       = 125
)(
    input wire       I_pixel_clk,
    input wire       I_rst,
    input wire       I_edid_read_trig,
    output wire      O_edid_read_valid,
    output wire [7:0] O_edid_read_data,
    input wire       I_axis_s_user,
    input wire       I_axis_s_valid,
    input wire       I_axis_s_last,
    input wire [23:0] I_axis_s_data,
    output wire      O_axis_s_ready,
    input wire       I_audio_valid,
    input wire [23:0] I_audio_left_data,
    input wire [23:0] I_audio_right_data,
    input wire       I_acr_valid,
    input wire [19:0] I_acr_cts,
    input wire [19:0] I_acr_n,
    output wire      O_video_locked,
    output wire      O_ddc_scl,
    inout  wire      IO_ddc_sda,
    output wire [9:0] O_ch0_tmds_data,
    output wire [9:0] O_ch1_tmds_data,
    output wire [9:0] O_ch2_tmds_data,
    output wire [9:0] O_clk_tmds_data
);
    // 桩行为：视频/音频接口活动回显到 TMDS 输出
    reg [9:0] S_cnt;
    always @(posedge I_pixel_clk or posedge I_rst) begin
        if (I_rst) S_cnt <= 10'd0;
        else       S_cnt <= S_cnt + 10'd1;
    end

    assign O_axis_s_ready   = 1'b1;
    assign O_video_locked   = 1'b1;
    assign O_edid_read_valid = 1'b0;
    assign O_edid_read_data  = 8'd0;
    assign O_ddc_scl         = 1'b1;
    // 数据直通 + 混入计数，模拟 TMDS 编码活动（真实核即使在黑屏时也有 DC 平衡编码活动）
    assign O_ch0_tmds_data   = I_axis_s_valid ? (I_axis_s_data[9:0] ^ S_cnt[9:0]) : S_cnt[9:0];
    assign O_ch1_tmds_data   = {1'b0, I_audio_valid, I_audio_left_data[7:0]};
    assign O_ch2_tmds_data   = {2'b0, I_audio_right_data[9:2]};
    assign O_clk_tmds_data   = S_cnt;
endmodule

// ---------- 4) SDRAM 控制器桩 ----------
module sdram (
    input              Clk,
    input              Clk_sft,
    input              Rst,
    output             Sdr_init_done,
    output             Sdr_init_ref_vld,
    output             Sdr_busy,
    input              App_wr_en,
    input      [20:0]  App_wr_addr,
    input      [3:0]   App_wr_dm,
    input      [31:0]  App_wr_din,
    input              App_rd_en,
    input      [20:0]  App_rd_addr,
    output             Sdr_rd_en,
    output     [31:0]  Sdr_rd_dout
);
    reg  init_done = 1'b0;
    integer c = 0;

    always @(posedge Clk or posedge Rst) begin
        if (Rst) begin
            c <= 0;
            init_done <= 1'b0;
        end else begin
            if (c < 200) c <= c + 1;
            else         init_done <= 1'b1;
        end
    end

    assign Sdr_init_done    = init_done;
    assign Sdr_init_ref_vld = 1'b0;
    assign Sdr_busy         = 1'b0;
    assign Sdr_rd_en        = 1'b0;
    assign Sdr_rd_dout      = 32'd0;
endmodule
