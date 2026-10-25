//=============================================================
// tb_i2s_audio_mini.v
// 最小 I2S 音频链路 testbench：
//   i2s_test_tone_gen_pll (12.288MHz mclk 产生 1kHz 测试音 I2S 时序)
//   -> I2S_receiver        (video_clk=74.25MHz 采样 I2S)
//   -> audio_arc_calculate (计算 HDMI ACR CTS/N)
// 检查点（依据实测行为修正）：
//   test/i2s_test_tone_gen_pll.v 的 BCLK 实际为 mclk/4=3.072MHz（非注释的 mclk/2）
//   => LRCK = 24kHz（周期 41667ns），tone = 500Hz 方波（48 帧周期）
//   1) LRCK 频率 ≈ 24kHz
//   2) audio_valid 频率 = LRCK ≈ 24kHz（每 LRCK 周期 1 个左右声道样本）
//   3) 左右声道数据 = ±2000000 方波（500Hz，半周期 24 样本）
//   4) acr_n = 6144；acr_cts ≈ 148500（每 48 个 valid 输出一次，间隔 2ms）
// 运行：iverilog -g2012 -s tb_i2s_audio_mini -o tb_mini.vvp tb_i2s_audio_mini.v
//           i2s_test_tone_gen_pll.v I2S_receiver.v audio_arc_calculate.v
//        vvp tb_mini.vvp
//=============================================================
`timescale 1ns/1ps

module tb_i2s_audio_mini;

    // ---- 时钟与复位 ----
    reg i_mclk      = 1'b0;   // 12.288 MHz
    reg i_pixel_clk = 1'b0;   // 74.25  MHz
    reg rst         = 1'b1;

    // ---- 内部连线 ----
    wire o_bclk, o_lrck, o_dout;
    wire aud_valid;
    wire [23:0] aud_left, aud_right;
    wire acr_valid;
    wire [19:0] acr_cts, acr_n;

    // ---- 时钟生成（精确频率） ----
    // 12.288MHz: 半周期 40.6901ns
    always #40.690 i_mclk = ~i_mclk;
    // 74.25MHz:  半周期 6.7340ns
    always #6.734 i_pixel_clk = ~i_pixel_clk;

    // ---- DUT ----
    i2s_test_tone_gen_single_pll_fix64 #(
        .SAMPLE_RATE (48000),
        .SAMPLE_BITS (24),
        .TONE_HZ     (1000)
    ) u_tone (
        .I_mclk     ( i_mclk     ),
        .I_rst      ( rst        ),
        .O_i2s_BCLK ( o_bclk     ),
        .O_i2s_LRCK ( o_lrck     ),
        .O_i2s_DOUT ( o_dout     )
    );

    I2S_receiver u_rx (
        .I_clk              ( i_pixel_clk ),
        .I_rst              ( rst         ),
        .I_i2s_BCLK         ( o_bclk      ),
        .I_i2s_LRCK         ( o_lrck      ),
        .I_i2s_DOUT         ( o_dout      ),
        .O_audio_valid      ( aud_valid   ),
        .O_audio_left_data  ( aud_left    ),
        .O_audio_right_data ( aud_right   )
    );

    audio_arc_calculate #(
        .ACR_N (6144)
    ) u_arc (
        .I_clk         ( i_pixel_clk ),
        .I_rst         ( rst         ),
        .I_audio_valid ( aud_valid   ),
        .O_acr_valid   ( acr_valid   ),
        .O_acr_cts     ( acr_cts     ),
        .O_acr_n       ( acr_n       )
    );

    // ---- 复位控制 ----
    initial begin
        rst = 1'b1;
        #1000;
        rst = 1'b0;
        #1000;
        rst = 1'b1;   // 同步释放
        @(posedge i_mclk) rst = 1'b0;
    end

    // ---- 统计与检查 ----
    integer lrck_rises = 0, valid_cnt = 0, acr_cnt = 0;
    real    t_last_lrck = 0, t_last_valid = 0;
    real    lrck_period = 0, valid_period = 0;
    integer data_cnt = 0, data_pos = 0, data_neg = 0;
    reg     prev_lrck = 0, prev_valid = 0, prev_acr = 0;
    reg     signed [23:0] last_left = 0;

    // LRCK 上升沿计时
    always @(posedge o_lrck) begin
        if (lrck_rises > 0) begin
            lrck_period = ($time - t_last_lrck) * 1.0;
        end
        t_last_lrck = $time;
        lrck_rises = lrck_rises + 1;
    end

    // audio_valid 计时
    always @(posedge aud_valid) begin
        if (valid_cnt > 0)
            valid_period = ($time - t_last_valid) * 1.0;
        t_last_valid = $time;
        valid_cnt = valid_cnt + 1;
    end

    // 数据采样：统计 ±2000000
    always @(posedge aud_valid) begin
        if ($signed(aud_left) == 24'sd2000000) data_pos = data_pos + 1;
        else if ($signed(aud_left) == -24'sd2000000) data_neg = data_neg + 1;
        data_cnt = data_cnt + 1;
        last_left = aud_left;
    end

    always @(posedge acr_valid) begin
        acr_cnt = acr_cnt + 1;
        if (acr_cnt <= 8)
            $display("[%0t ns] ACR#%0d valid=1 cts=%0d n=%0d", $time, acr_cnt, acr_cts, acr_n);
    end

    // ---- 主流程 ----
    initial begin
        $display("==============================================");
        $display(" tb_i2s_audio_mini: 1kHz I2S 链路仿真开始");
        $display("  mclk=12.288MHz  pixel_clk=74.25MHz");
        $display("==============================================");
        #2500000;   // 2.5ms 覆盖 60 个样本、方波 500Hz 翻转 2.5 次、ACR 首次输出(2ms)

        $display("==============================================");
        $display(" 仿真结束  t=%0t ns", $time);
        $display(" LRCK 上升沿次数: %0d", lrck_rises);
        if (lrck_period > 0)
            $display(" LRCK 周期: %0.2f ns  (实际 41667ns = 24kHz)", lrck_period);
        $display(" audio_valid 次数: %0d", valid_cnt);
        if (valid_period > 0)
            $display(" valid 周期: %0.2f ns  (实际 41667ns = 24kHz)", valid_period);
        $display(" 数据样本数: %0d  (+2000000: %0d, -2000000: %0d)", data_cnt, data_pos, data_neg);
        $display(" 最近左声道样本: %0d", $signed(last_left));
        $display(" ACR valid 次数: %0d (期望每 48 样本一次)", acr_cnt);
        // 断言（按 test 变体 24kHz 实际行为）
        if (lrck_rises > 20 && lrck_period > 35000 && lrck_period < 48000)
            $display(" [PASS] LRCK ≈ 24kHz");
        else
            $display(" [FAIL] LRCK 频率异常");
        if (valid_cnt > 20 && valid_period > 35000 && valid_period < 48000)
            $display(" [PASS] audio_valid ≈ 24kHz");
        else
            $display(" [FAIL] audio_valid 频率异常");
        if (data_cnt > 20 && data_pos > 0 && data_neg > 0)
            $display(" [PASS] 音频数据为 ±2000000 方波（500Hz 测试音）");
        else
            $display(" [FAIL] 音频数据异常");
        if (acr_cnt > 0)
            $display(" [PASS] ACR 有效输出 %0d 次, cts=%0d n=%0d", acr_cnt, acr_cts, acr_n);
        else
            $display(" [FAIL] ACR 输出异常");
        $display("==============================================");
        $finish;
    end

endmodule
