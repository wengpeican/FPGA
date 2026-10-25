# 当前分区蜂鸣器验证（2026-10-17）

本次下载文件：`D:/FPGA/lab_ex4_tf/src/new/greenhouse_zone_alarm_buzzer_20261017.bit`。
旧的 `greenhouse_status_buzzer_20261016.bit` 是四区最高等级版本，不用于本次验收。

## 声音规则

|当前监控分区状态|音调|节奏|
|---|---|---|
|绿色正常|静音|不响|
|黄色预警|约 660 Hz|响 400 ms，停 600 ms|
|红色异常|约 2000 Hz|响 100 ms，停 25 ms|

声音取实际显示背景对应的 A/B/C/D 分区状态，与边框共用 frame_zone，不再取四区最高等级。PIC5/PIC6 页面沿用最近显示的监控分区。进入设置页不代表蜂鸣器自动静音；须将该分区状态恢复绿色。PCM 与蜂鸣器共用音源，因此 HDMI 状态音也遵循本表。

## 上板检验

1. 下载上面的新 bit，打开板载蜂鸣器开关 SW1。无需 HDMI 显示器内置扬声器。
2. 在监控页确认当前分区字母和状态颜色。通过原有阈值设置或内部模拟参数调节，分别制造绿色、黄色、红色状态，检查声音是否符合上表。
3. 绿色保持至少 5 秒，应完全静音；黄色听到较低音调且每秒一次；红色音调明显更高，约每秒 8 次。
4. 保持其他分区异常，将当前分区调至绿色，应静音；切到异常分区才应急促鸣响。切页时以新背景实际显示完成为准。
5. 将当前红色分区恢复绿色，应迅速停止鸣响；复位时蜂鸣器输出低电平。进入 PIC5/PIC6 后，验证声音仍对应之前的监控分区。
6. 连续运行和切页至少 30 分钟，检查 TF 读图、OSD、转场和声音均正常。所有环境数值仍来自 FPGA 内部模拟逻辑，无 MCU、无真实传感器采集。

## ModelSim 路径

在 ModelSim Transcript 执行：

```tcl
do D:/FPGA/lab_ex4_tf/src/sim/status_buzzer/run.do
```

该脚本显示 severity、PCM、buzzer 和节拍波形。正常时 buzzer 为低；黄色有效窗口中约 660 Hz；红色有效窗口中约 2 kHz。检查 `sim/status_buzzer/assertions.log` 最后一行为 `STATUS_BUZZER_RESULT errors=0`。

批处理回归路径：

- `sim/status_buzzer/batch.do`：实际输出引脚频率、节拍、绿色静音、在线恢复和复位。
- `sim/status_audio/batch.do`：当前分区选择、非当前分区告警不能覆盖当前声音、PCM 节拍和背压。
- `sim/status_audio/hdmi_batch.do`：HDMI 音频包、BCH、ACR、视频同步和正常状态静音。

每次须核对结果文件时间戳以及完整完成标志，不能仅看 ModelSim 退出码或旧的 errors=0 文件。

## 布线与限制

完整 TD 综合布局布线生成 bit，建立裕量 +0.162 ns、保持裕量 +0.014 ns，STA 覆盖率 99.94%。报告位于本目录 `greenhouse_zone_alarm_buzzer_timing.rpt`、`greenhouse_zone_alarm_buzzer_area.rpt`，蜂鸣器引脚为 H11。

时序约束变更：额外 SD 时钟 setup uncertainty 从 0.300 ns 改为 0，TD 默认 0.100 ns 不确定度仍保留。实际时钟频率未改变，也未添加 false path。该报告代表修改后约束下通过，不代表通过旧的额外裕量要求；长时间上板稳定性仍需按步骤验收。尚未替用户进行物理听音验证。

bit 大小 629624 字节，SHA256：
`76578632DBC0246ED72633DCCFE55181B4DA4C5235A1D1132CEB728480DF9488`。
