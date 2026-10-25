# lab_ex4_tf（已移植音频版）仿真验证说明

本目录（`user_source/hdl_source/test/`）包含两个仿真 testbench，用于验证从
`lab_ex5_i2s` 移植 I2S 音频链路到 `lab_ex4_tf` 是否成功。

## 环境

- iverilog：`D:\iverilog\bin\iverilog.exe` / `vvp.exe`
- 必须使用 `-g2005` 模式：TD IP（PLL 封装等）的端口名 `do` 在 `-g2012`
  （SystemVerilog）下是 do-while 关键字，会报语法错误。

## 1) tb_i2s_audio_mini.v —— 最小 I2S 音频链路

验证对象：`i2s_test_tone_gen_pll.v`（音源）→ `I2S_receiver.v`（I2S 接收）→
`audio_arc_calculate.v`（ACR 计算）。

要点：
- mclk 12.288MHz、pixel_clk 74.25MHz。
- `i2s_test_tone_gen_pll.v` 的注释声称 BCLK=mclk/2、LRCK=48kHz，实际实现是
  BCLK=mclk/4 → LRCK=24kHz（实测周期 41667ns）。断言按实际行为校准。
- 断言项：LRCK/valid 周期 24kHz、数据 ±2000000 方波、ACR 每 48 样本输出。

编译运行：
```powershell
cd D:\FPGA\lab_ex4_tf\src\user_source\hdl_source\test
iverilog -g2005 -s tb_i2s_audio_mini -o tb_mini.vvp tb_i2s_audio_mini.v i2s_test_tone_gen_pll.v ..\I2S_receiver.v ..\audio_arc_calculate.v
vvp tb_mini.vvp
```
结果：全部 PASS（LRCK 41667ns=24kHz；ACR#1 在 2002133ns 输出 cts=148505、n=6144，
与理论 cts=148500 几乎一致）。

## 2) tb_top_hdmi_audio.v —— 完整 top 移植验证

验证对象：`top_tf_hdmi_audio.v` 完整顶层（无 SD 卡、无显示器、无按键）。

要点：
- 50MHz 系统时钟；SD 卡 MISO 置 1（无卡）、按键不按。
- 因 TD 加密文件（`hdmi_1_4b_transmitter_core_wrapper.enc.v`、
  `include/sdr_*.enc.v`、`sim_release/eg4/eg_phy_pll.v` 等）无法被 iverilog
  解析，由 `tb_stubs.v` 提供行为模型：
  - `EG_PHY_PLL`（分频输出 + extlock；clk1 独立 125MHz 振荡，保证 HDMI
    串行时钟 ≥5× pixel_clk，lane_lvds 跨时钟沿检测才能工作）
  - `EG_LOGIC_BUFG`（直连）、`EG_LOGIC_ODDR`（DDR 双沿输出）
  - `hdmi_1_4b_transmitter_core_wrapper`（桩：axis/音频活动混入计数回显到
    TMDS 输出）
  - `sdram`（控制器桩：200 拍后 init_done、busy=0）
- 断言项：audio_pll_lock 置位、audio_valid ≈ 48kHz、音频数据 ±2000000 方波、
  ACR ≥ 2 次（每 48 样本）、HDMI TMDS 输出活跃。

编译运行（完整文件清单，缺一不可）：
```powershell
cd D:\FPGA\lab_ex4_tf\src\user_source\hdl_source\test
iverilog -g2005 -s tb_top_hdmi_audio -o tb_top.vvp -I ..\SD -I ..\include tb_top_hdmi_audio.v tb_stubs.v ..\top_tf_hdmi_audio.v ..\hdmi_audio_tone_i2s_64fs.v ..\I2S_receiver.v ..\audio_arc_calculate.v ..\video_source_test.v ..\video_rgb_to_axis_640x480.v ..\key_remove_shakes.v ..\startup_pulse.v ..\hdmi_phy_warpper.v ..\lane_lvds_10_1.v ..\SD\sd_card_bmp.v ..\SD\bmp_read.v ..\SD\seg_decoder.v ..\SD\seg_scan.v ..\SD\frame_fifo_read.v ..\SD\frame_fifo_write.v ..\SD\frame_read_write.v ..\SD\video_timing_data.v ..\SD\video_delay.v ..\SD\sd_card_top.v ..\SD\sd_card_sec_read_write.v ..\SD\sd_card_cmd.v ..\SD\spi_master.v ..\SD\ax_debounce.v ..\SD\color_bar.v ..\IP\sys_pll.v ..\IP\video_pll.v ..\IP\afifo_16_32_256.v ..\IP\afifo_32_16_256.v ..\..\..\td_project\al_ip\PLL_HDMI_AUDIO.v
vvp tb_top.vvp
```
结果：全部 PASS。注意仿真中 valid 周期 20480ns（≈48.8kHz）而非 20833ns，
是因为 PLL 桩的 mclk 为 12.5MHz（真实 12.288MHz），比率关系正确即可。

## 仿真未覆盖项（桩的局限）

- HDMI 发射核本体为加密 IP，仿真用桩替代：不验证 TMDS 编码/打包/EDID 细节。
- SDRAM 控制器为桩：不验证真实 DDR 时序，仅让帧缓存状态机推进。
- SD 卡读图、按键、真实上板行为需硬件验证（插入 SD 卡 + HDMI 显示器听音/看图）。
