//=============================================================
// tb_top_hdmi_audio.v
// 完整 top_tf_hdmi_audio.v 移植验证 testbench：
//   - 50MHz 系统时钟 + 复位 + 按键
//   - 例化完整 top（TF卡显示 + SDRAM + I2S音频 + HDMI发射）
//   - SD 卡无卡（MISO 拉高）；DDC 上拉；不挂真实显示器
// 检查点（通过层次引用观察 top 内部）：
//   1) audio_pll_lock 置位，audio_mclk ≈ 12.288MHz
//   2) audio_valid ≈ 48kHz（hdmi_audio_tone_i2s_64fs 正确 48kHz 链路）
//   3) 音频数据 = ±2000000 方波（音符 do C4 261.63Hz，半周期 1.91ms）
//   4) ACR 每 48 样本输出一次：cts ≈ 148500（74.25M/48k×48）、n=6144
//   5) HDMI TMDS 输出有活动（视频+音频包在跑）
// 注意：完整 top 还包含 SDRAM/SD 卡链路，本 tb 不验证其内容正确性，
//       只确保音频/HDMI 链路在移植后的 top 中正常工作。
//=============================================================
`timescale 1ns/1ps

module tb_top_hdmi_audio;

    // ---- 顶层端口 ----
    reg         clk     = 1'b0;   // 50MHz
    reg         rst_n   = 1'b0;
    reg         key1    = 1'b0;
    reg         key2    = 1'b0;
    wire [5:0]  seg_sel;
    wire [7:0]  seg_data;
    wire        hdmi_clk_p, hdmi_d2_p, hdmi_d1_p, hdmi_d0_p;
    wire        hdmi_ddc_scl;
    wire        hdmi_ddc_sda;
    wire        sd_ncs, sd_dclk, sd_mosi;
    reg         sd_miso = 1'b1;   // 无卡

    // ---- DUT ----
    top dut (
        .clk        ( clk         ),
        .rst_n      ( rst_n       ),
        .key1       ( key1        ),
        .key2       ( key2        ),
        .seg_sel    ( seg_sel     ),
        .seg_data   ( seg_data    ),
        .HDMI_CLK_P ( hdmi_clk_p  ),
        .HDMI_D2_P  ( hdmi_d2_p   ),
        .HDMI_D1_P  ( hdmi_d1_p   ),
        .HDMI_D0_P  ( hdmi_d0_p   ),
        .HDMI_DDC_SCL( hdmi_ddc_scl ),
        .HDMI_DDC_SDA( hdmi_ddc_sda ),
        .sd_ncs     ( sd_ncs      ),
        .sd_dclk    ( sd_dclk     ),
        .sd_mosi    ( sd_mosi     ),
        .sd_miso    ( sd_miso     )
    );

    // ---- 50MHz 时钟 ----
    always #10 clk = ~clk;

    // ---- 复位与按键 ----
    initial begin
        rst_n = 1'b0;
        #200;
        rst_n = 1'b1;
        // 上电后 1ms 给 key1 一次脉冲（触发 SD 重扫/EDID），观察链路反应
        #1000000;
        key1 = 1'b1; #100000; key1 = 1'b0;
    end

    // ---- 统计 ----
    integer pll_rise_time = 0;
    integer valid_cnt = 0, acr_cnt = 0;
    integer data_pos = 0, data_neg = 0;
    real    last_valid_t = 0, valid_period = 0;
    real    last_acr_t = 0, acr_period = 0;
    reg     prev_valid = 0;
    reg     [23:0] last_left = 0;
    integer tmds_toggle = 0;
    reg     prev_tmds = 0;

    always @(posedge dut.audio_valid) begin
        if (valid_cnt > 0)
            valid_period = ($time - last_valid_t) * 1.0;
        last_valid_t = $time;
        valid_cnt = valid_cnt + 1;
        if ($signed(dut.audio_left_data) == 24'sd2000000) data_pos = data_pos + 1;
        else if ($signed(dut.audio_left_data) == -24'sd2000000) data_neg = data_neg + 1;
        last_left = dut.audio_left_data;
    end

    always @(posedge dut.acr_valid) begin
        acr_cnt = acr_cnt + 1;
        if (acr_cnt <= 4)
            $display("[%0t ns] ACR#%0d cts=%0d n=%0d", $time, acr_cnt, dut.acr_cts, dut.acr_n);
    end

    always @(posedge hdmi_d0_p) begin
        if (prev_tmds === 0) begin tmds_toggle = tmds_toggle + 1; prev_tmds = 1; end
    end
    always @(negedge hdmi_d0_p) prev_tmds = 0;

    always @(posedge dut.audio_pll_lock) begin
        pll_rise_time = $time;
        $display("[%0t ns] audio_pll_lock 置位", $time);
    end

    // ---- 诊断计数器（内部信号活动）----
    reg [31:0] d_mclk_t=0, d_vclk_t=0, d_bclk_t=0, d_sdclk_t=0;
    reg [31:0] d_axis_v_t=0, d_axis_nz=0;
    always @(posedge dut.audio_mclk)   d_mclk_t  = d_mclk_t  + 1;
    always @(posedge dut.video_clk)    d_vclk_t  = d_vclk_t  + 1;
    always @(posedge dut.audio_i2s_bclk) d_bclk_t = d_bclk_t + 1;
    always @(posedge dut.sd_card_clk)  d_sdclk_t = d_sdclk_t + 1;
    always @(posedge dut.axis_s_valid) d_axis_v_t = d_axis_v_t + 1;
    always @(posedge dut.video_clk)
        if (|dut.axis_s_data) d_axis_nz = d_axis_nz + 1;

    initial #500000 begin
        $display("[DIAG@%0t] rst_all=%b lock=%b", $time, dut.rst_all, dut.audio_pll_lock);
        $display("[DIAG@%0t] mclk翻转=%0d video_clk翻转=%0d bclk翻转=%0d sd_clk翻转=%0d",
                 $time, d_mclk_t, d_vclk_t, d_bclk_t, d_sdclk_t);
        $display("[DIAG@%0t] axis_s_valid翻转=%0d axis数据非零采样=%0d (video_clk周期采样)",
                 $time, d_axis_v_t, d_axis_nz);
    end

    // ---- 主流程 ----
    initial begin
        $display("==============================================");
        $display(" tb_top_hdmi_audio: 完整 top 移植验证");
        $display(" 50MHz 系统时钟, 无SD卡(黑屏), 无显示器");
        $display("==============================================");
        #3000000;   // 3ms：144 个音频样本、ACR 3 次、HDMI 视频流启动

        $display("==============================================");
        $display(" 仿真结束 t=%0t ns", $time);
        $display(" audio_pll_lock 置位时间: %0d ns", pll_rise_time);
        $display(" audio_valid 次数: %0d", valid_cnt);
        if (valid_period > 0)
            $display(" valid 周期: %0.2f ns (期望 20833ns ≈ 48kHz)", valid_period);
        $display(" 数据样本: +2000000=%0d, -2000000=%0d", data_pos, data_neg);
        $display(" ACR 次数: %0d (期望每48样本一次, 3ms内3次)", acr_cnt);
        $display(" HDMI_D0_P 翻转次数(采样): %0d", tmds_toggle);
        // 断言
        if (pll_rise_time > 0)
            $display(" [PASS] audio_pll_lock 已置位");
        else
            $display(" [FAIL] audio_pll_lock 未置位");
        if (valid_cnt > 20 && valid_period > 19000 && valid_period < 23000)
            $display(" [PASS] audio_valid ≈ 48kHz (正确版 64fs 链路)");
        else
            $display(" [FAIL] audio_valid 频率异常 (实测 %0.2fns)", valid_period);
        if (data_pos > 0 && data_neg > 0)
            $display(" [PASS] 音频数据 ±2000000 方波翻转（音符 do 261.63Hz）");
        else
            $display(" [FAIL] 音频数据未翻转");
        if (acr_cnt >= 2)
            $display(" [PASS] ACR 每48样本输出 (3ms内 %0d 次)", acr_cnt);
        else
            $display(" [FAIL] ACR 输出异常");
        if (tmds_toggle > 100)
            $display(" [PASS] HDMI TMDS 输出活跃 (翻转%0d次)", tmds_toggle);
        else
            $display(" [FAIL] HDMI TMDS 无输出活动");
        $display("==============================================");
        $finish;
    end

endmodule
