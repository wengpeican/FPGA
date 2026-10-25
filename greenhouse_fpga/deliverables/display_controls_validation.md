# 显示参数实时调节与信息叠加验证（2026-10-18）

## 下载文件

**最新推荐** `D:/FPGA/lab_ex4_tf/src/new/greenhouse_wave_persist_20261019.bit`：中文参数框 + TF 读图时序修复 + 告警阈值均衡 + 四区波形连续保存（见文末）。上一版 `greenhouse_alarm_balance_20261018.bit` 保留。上一版中文 `greenhouse_display_controls_cn_20261018.bit` 保留。英文版 `greenhouse_display_controls_20261018.bit` 保留作对照。

GUI 中直接编译生成的 `td_project/lab_ex4_tf_lesson6_fat32_Runs/phy_1/lab_ex4_tf_lesson6_fat32.bit`（18:24，setup −0.013 ns）时序未通过，不要下载。

英文版在上一版 `greenhouse_hdmi_red_gain_20261018.bit` 的基础上增加音量、亮度、对比度调节和画面参数信息框，原有翻页、自动轮播、告警、状态音和蜂鸣器行为不变。

## 操作方式

参数键 B1 和拨码 C8/C7 专用于参数调节；翻页键 key1（B2）、自动轮播键 key2（C1）不变。

板上丝印对应（依据官方 DEMO/2_key_led/key_led.v 注释“按键1~按键4”对应 key[0]~key[3]）：

| 丝印 | 引脚 | 作用 |
|------|------|------|
| KEY1 | A2 | 复位 |
| KEY2 | B2 | 翻页/切换监控页 |
| KEY3 | B1 | 参数调节键 |
| KEY4 | C1 | 自动轮播开/关 |
| SW1 | C8（推断） | 参数选择位 0 |
| SW2 | C7（推断） | 参数选择位 1 |
| BUZ/SW | — | 板载蜂鸣器硬件开关 |

SW1/SW2 与 C8/C7 的对应按官方 SW[0]~SW[3] = C8/C7/C6/C5 的编号规律推断；本地原理图文件未下载完整，需按下方第 2 步上板确认。

| C7 | C8 | 调节项 | B1 短按 | B1 长按约 1 s |
|----|----|--------|---------|---------------|
| 关 | 关 | 音量 VOL 0%~100%（0~10 级，默认 50%） | +1 级 | −1 级 |
| 关 | 开 | 亮度 BRI −64~+64（0~8 级，默认 +00） | +1 级 | −1 级 |
| 开 | 关 | 对比度 CON 0%~200%（0~8 级，默认 100%） | +1 级 | −1 级 |
| 开 | 开 | 恢复默认 | 无动作 | 三项恢复默认 |

任一参数或拨码变化后，画面左上角显示 3 s 参数框，选中项为黄色。

中文版（`greenhouse_display_controls_cn_20261018.bit`）参数框内容：

```
音量 050%  亮度 +00  对比度 100%
KEY3 短按加 长按减          （SW1、SW2 都拨上时：长按 KEY3 恢复默认）
```

仿真画面预览：`sim/display_controls/hud_preview.png`。

## 上板验证

1. 下载 bit，HDMI 连接带扬声器的显示器。上电默认画面颜色、音量应与上一版一致，左上角无参数框。
2. 只拨 SW1，参数框出现且高亮由 音量/VOL 变为 亮度/BRI；只拨 SW2，高亮变为 对比度/CON；两者都拨上，第二行显示 “长按 KEY3 恢复默认”（英文版为 “HOLD B1: RESTORE DEFAULTS”）。若高亮项与拨码相反，说明实板 ON 为高电平，以高亮项为准操作，并反馈以便调整极性；若 SW1/SW2 均无反应，说明映射推断不符，反馈实际起作用的开关。
3. 音量：短按逐级增大，长按逐级减小；0% 时 HDMI 静音，100% 为最大。板载蜂鸣器不受此调节。
4. 亮度/对比度：背景图随之变亮/变暗、增强/减弱；告警边框、数值、文字和波形颜色保持不变。
5. 按 B1 时不应翻页或切换自动轮播；按 key1/key2 时参数不应改变。
6. 快速连按、长按、到达上下限后继续按，数值应确定无连跳；停止操作 3 s 后参数框消失。
7. 连续运行 30 分钟，检查画面、OSD、转场、告警和声音稳定。重新上电后三项参数恢复默认。

## 本次执行结果

- 参数控制单元测试：ModelSim `errors=0`；Icarus `RESULT errors=0 checks=773`。覆盖按键抖动、短按/长按、上下限、独立选择、恢复默认、3 s 超时、拨码抖动、参数键不触发翻页/轮播、81 组亮度×对比度与 256 级灰度运算、连续像素对齐、信息框字符/高亮/裁剪、完整时序 3 拍对齐。
- 原测试平台参考模型使用无符号部分选择相减，导致 344 项误报；已改为整数模型，RTL 未改动。
- 回归：OSD、状态音频、蜂鸣器、HDMI（lesson3）、FAT32（lesson6）、冻结、恢复测试均 `errors=0`。
- 完整布线：SWNS=+0.115 ns，HWNS=+0.014 ns，STA coverage=99.93%，通过构建脚本时序门禁。
- 资源：LUT 15409/19600（78.62%），REG 6436/19600（32.84%），PAD 36/188。B1、C8、C7 已按 LVCMOS33 上拉约束。
- U3/sdram 布局 CRITICAL-WARNING 与上一版相同（3 条），非本次引入。
- bit 大小 629624 字节，生成时间 2026-10-18 18:06:45。构建脚本：`td_project/rebuild_display_controls.tcl`。

## 中文版执行结果

- 参数框汉字为 15 个 16×16 宋体点阵（`sim/display_controls/gen_cjk_font.ps1` 生成），仿真预览 `sim/display_controls/hud_preview.png`。
- 首次构建 setup −0.249 ns 被时序门禁拦截。最差路径在原有 TF 读图 `bmp_stream_decoder.v`（sd_card_clk 100 MHz，32 位 pixel_offset/payload_end 比较直接驱动像素寄存器使能），非中文 HUD 本身。修复：解码器输入整体加一级寄存器，比较结果寄存后使用；事件顺序不变，加载完成信号晚 1 拍（10 ns）。
- 回归：参数控制 ModelSim/Icarus `errors=0 checks=2038`；FAT32 `errors=0 commits=44`；转场 `errors=0 fades=11`；PIC5 `errors=0 commits=13`；PIC6 `errors=0 commits=18`；OSD、状态音频、蜂鸣器、HDMI、冻结、恢复均 `errors=0`。
- 完整布线：SWNS=+0.260 ns，HWNS=+0.014 ns，STA coverage=99.93%。
- 资源：LUT 15904/19600（81.14%），REG 6579/19600（33.57%）。
- CRITICAL-WARNING：U3/sdram 布局 3 条、PHY-5079 时钟本地布线 1 条，以往各版构建均相同，非本次引入。
- bit 大小 629624 字节，生成时间 2026-10-18 18:54:36。构建脚本：`td_project/rebuild_display_controls_cn.tcl`。

## 告警阈值均衡版执行结果

- 默认阈值：温度 19~34、湿度 33~77、光照 850~2800；预警带：温度 1、湿度 4、光照 100。原默认值下自动模拟数据红色占 80.6%。
- RTL 全周期 2400 s 统计：A 区 绿 790 / 黄 804 / 红 806 s，B/C/D 同样各约 33%；四区同时红 7 s；A 区单次红色最长 21 s。
- 回归：sim/alarm_balance `ALARM_BALANCE_RESULT errors=0 checks=16`；OSD（含三类预警带边界）、参数调节、状态音频、蜂鸣器、HDMI、FAT32、转场、PIC5、PIC6、冻结、恢复、底图对齐均 errors=0。
- 完整布线：SWNS=+0.137 ns，HWNS=+0.014 ns，STA coverage=99.92%；LUT 15628/19600（79.73%），REG 6478（33.05%）。CRITICAL-WARNING 与以往相同（SDRAM 布局 3 条、PHY-5079 1 条）。
- 上板：自动模拟模式下观察 A~D 区边框，应能看到绿、黄、红交替出现，约每 4 s 变化一次；进入阈值页可看到新默认值。
- bit 生成时间 2026-10-18 21:13:10。构建脚本：`td_project/rebuild_alarm_balance.tcl`。

## 四区波形连续保存版执行结果

- 每区独立 128 点历史（4×128×24 位），每秒同时采样四区；切换分区或页面不清空、不暂停，回到该区接着往下画，满 128 点后滚动。
- 回归：tb_osd `OSD_RESULT errors=0`；系统级 `sim/osd/tb_wave_persist.v` `WAVE_PERSIST_RESULT errors=0 checks=3966 samples=153`（真实 KEY2 翻页 12 次、四区逐点比对、含回绕）；改动前旧模块跑同一测试失败 3799 项。其余全部回归 errors=0。
- 完整布线：SWNS=+0.044 ns，HWNS=+0.014 ns，STA coverage=99.93%，通过门禁但 setup 余量偏薄；最差路径在原 TF 读图 sd_card_clk 域（img_found_count -> load_sector），非波形模块。LUT 15720（80.20%），REG 6575，BRAM9K 6 块（与上一版相同），波形模块 190 LUT。CRITICAL-WARNING 与以往相同。
- 上板：在 A 区看一段波形后按 KEY2 切到 B/C/D 再切回 A，A 区曲线应完整保留并继续向右推进；B/C/D 第一次显示时即已有之前累计的曲线。复位后四区波形清空。
- bit 生成时间 2026-10-19 21:08:53。构建脚本：`td_project/rebuild_wave_persist.tcl`。
