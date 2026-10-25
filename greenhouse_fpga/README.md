# 温室智慧农业环境可视化监控终端——比赛代码提交版

## 打开与编译

建议解压到不含中文或空格的短路径，例如 D:/contest/greenhouse_fpga。
使用安路 Tang Dynasty（TD）6.2.168116，器件 EG4S20BG256，顶层模块 top。
打开 src/td_project/lab_ex4_tf_lesson6_fat32.al；顶层 RTL 为 src/user_source/hdl_source/top_tf_hdmi_audio.v。
引脚约束 src/user_source/constraints_source/pin.adc，时序约束同目录 timing.sdc。
在 TD Tcl 环境中执行 source <解压目录>/src/td_project/rebuild_wave_persist.tcl 可执行最新版本构建流程；需安装支持该器件的 TD 库。
脚本包含布线后 setup/hold 检查，通过后生成 bit；输出在 src/new 及工程 Runs/verified 目录。

## 文件结构

- src/user_source：完整 HDL、约束、厂商 IP 及 ROM/音频初始化数据。保留工程引用的旧模块，综合启用状态以 .al 为准。
- src/td_project：工程文件、工程 IP、最新版本重建 Tcl。
- src/sim：各功能仿真源码、文件列表、ModelSim do 脚本和像素输入数据；工作库由脚本生成。
- verification：此前实际运行的四组报告仿真源码快照、便携脚本和原始结果日志（OSD、闪烁、蜂鸣器、波形翻页保留）。
- resources/tf_card：PIC1.BMP～PIC6.BMP 六张底图，640×480、24 位、不压缩 BMP；复制到 FAT32 TF 卡根目录。资源来源见 resources/资源来源.json。
- deliverables：已有最新 bit、对应资源/时序报告、构建日志及原工程验证说明。
- tools：BMP 格式转换辅助脚本。
- SHA256SUMS.txt：提交包内各文件校验值。

## 运行与验证

视频输出连接 HDMI_B。KEY1/A2 复位，KEY2/B2 翻页，KEY3/B1 调参，KEY4/C1 自动轮播；拨码 C8/C7 选择参数，具体说明见 deliverables/display_controls_validation.md。
本工程环境数据由 RTL 自动模拟产生；四区历史波形各保存 128 点、每秒更新，切换页面继续保留。
在 ModelSim Transcript 中先执行 cd {<解压目录>/verification/osd}，再执行 do run.do，即可重新执行报告对应仿真；其余三组先切换到 blink、buzzer、history 各自目录再运行。src/sim 下测试同样先 cd 到 do 文件所在目录再运行。
保留的原始日志包含 OSD_RESULT errors=0、BLINK_RESULT errors=0、STATUS_BUZZER_RESULT errors=0、WAVE_PERSIST_RESULT errors=0。
其他开发阶段测试位于 src/sim；其 run.do 通常为交互波形，batch.do 为批处理。此前报告用四组测试对时钟比例及超时做了调整，详见 verification 中的调整记录；两套测试均保留来源，不混同测试结论。

## 整理与验证说明

本提交版由原工程复制整理，硬件 RTL、引脚/时序约束和 IP 内容保持逐文件一致；仅修改副本工程根路径、ModelSim 工作目录和最新重建脚本路径，使其可随解压目录移动。
排除了 Git 历史、备份目录、仿真 work 库、vvp、临时输出、旧版 bit、旧编译缓存以及报告/视频等非代码文件。未包含用于修改旧 RTL 的历史集成/升级脚本。
PIC1～PIC4 原 BMP 路径已失效，使用工程保存的 bg0～bg3.hex 还原，逐像素核对一致；PIC5/PIC6 直接采用原工程图片。
deliverables 中的 bit 为原工程 2026-10-19 已有生成文件，本次整理未重新综合或上板；原验证文档中的上板待确认项仍按其实际状态理解。
src.zip 不属于本提交包；原文件保持不变。
