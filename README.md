# 九模式三音区电子琴 + 实时 HDMI 总集成工程

本目录以 `FPGA音乐键盘_九模式三音区/team_handoff` 为主工程，接入
`dianrong+hdmi_new/dianrong+hdmi/competition_polyphonic_hdmi` 的板载 HDMI
波形、连续 DFT 频谱、峰值检测和显示逻辑。原九模式、三音区、蓝牙协议、
电容触摸、ADS1115 压力音量、光电拨弦、LED 指引、录音回传及 Android App
都保留在本工程中。

## 工程入口

- FPGA：`fpga/ble_music_keyboard.gprj`，顶层 `src/top.v`，器件
  `GW5AT-LV60PG484AC1/I0`。
- Android：`android/`。应用与 FPGA 沿用九模式三音区版本的蓝牙协议。
- 命令行构建：在 `fpga/` 目录运行
  `E:\FPGA\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe build.tcl`。
- FPGA 仿真：运行 `fpga/sim/run_all_tests.ps1`。仿真中的 PLL 与加密 DVI IP
  使用 `hdmi_ip_stubs.v`；真实工程文件使用 `src/pll/` 和 `src/dvi_tx/` 下的
  Gowin IP。

Gowin V1.9.12.03 命令行在中文路径下会把路径转成问号，故总集成目录使用英文名。
构建产物位于 `fpga/impl/pnr/ble_music_keyboard.fs`；可直接选用
`release/keyboard_9mode_3octave_hdmi.fs` 烧录。`release/九模式_三音区_Android.apk`
是主工程原版 App，蓝牙协议与本版 FPGA 一致。使用 Gowin Programmer 烧录到
SRAM 后，断电会丢失配置，须重新下载。

## 音频与 HDMI 数据路径

`top.v` 的九模式音频选择经过 `audio_sample_pipe` 和 ADS1115 压力增益后，
同一条 `audio_pressure` 同时送到 I2S、录音采样器和 `hdmi_monitor`。
因此波形与频谱显示的是最终音频 PCM，而非另一套独立合成器；切换音色、
音区、滑音、颤音或效果模式时，HDMI 跟随真实音频。HDMI 模块不改写音频。

HDMI 输出使用原工程的 720p@60Hz TMDS 布局。256 点波形由
`waveform_history.v` 在每次 `sample_tick` 更新；频谱由 `spectrum_dft.v`
对音频抽样计算。画面底部的八个固定音符标签仍按原 HDMI 模板显示
C4～C5，它们没有随 App 的低、中、高音区选择变更；实时波形和频谱本身
跟随音区变化。

## 接线

原键盘全部引脚保留，见 `fpga/docs/PHYSICAL_WIRING.md`。新增的板载 HDMI
信号为 TMDS 数据 0/1/2 对 `J14/H14`、`J15/H15`、`K17/J17`，时钟对
`G15/G16`，HPD 使能 `K13`。完整引脚约束在
`fpga/src/ble_music_keyboard.cst`。HDMI 直接连接开发板接口，不需要上位机。

## 验证范围

`tb_top_hdmi_integration.v` 检查触摸键发声时 HDMI 波形缓存收到与 I2S
相同的最终音频采样，并检查 HPD 使能。仿真不模拟加密 TMDS 发射器的
物理信号；烧录后仍需在开发板和显示器上确认画面及实际音效。

2026-10-29 使用 Gowin V1.9.12.03 完成综合、布局布线和 bitstream 生成。
50 MHz 系统时钟实际 Fmax 为 50.014 MHz，74.25 MHz 像素时钟实际 Fmax
为 75.447 MHz；两组时钟的 Setup/Hold 违例端点均为 0。系统时钟余量仅
约 0.006 ns，若修改 RTL 或约束，必须重新跑时序。构建日志仍有原 HDMI
设计的 PLL 频率提示 `TA1123` 和系统时钟路由提示 `PR1014`。

本次 `release/keyboard_9mode_3octave_hdmi.fs` SHA256：
`4163F8EE5F82421DCCC12E5F3C53AB821B22843C0024B144ACFD7130CF4373D3`。
