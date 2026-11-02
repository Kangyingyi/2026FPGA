# Tang Mega 60K 复音 HDMI 工程烧录说明

## 已生成文件

烧录文件：

`impl/pnr/competition_polyphonic_hdmi.fs`

器件已经按板卡设置为 `GW5AT-LV60PG484AC1/I0`，视频输出采用参考工程验证过的 720p@60Hz TMDS/HDMI 引脚。

## 烧录步骤

1. 给 Tang Mega NEO Dock 上电，并用 `DEBUG-USB2` 连接电脑。
2. 关闭 Gowin Programmer、串口监视器和浏览器串口监视页面，避免占用 DEBUG-USB2 的端口。
3. 打开 Gowin Programmer，扫描/识别 FPGA 器件。
4. 加载本目录下的 `impl/pnr/competition_polyphonic_hdmi.fs`。
5. 选择 Program/下载，等待完成。
6. 关闭 Gowin Programmer，给开发板重新上电或复位。
7. 用 HDMI 线连接板卡 HDMI 接口和显示器，显示器输入源选择 HDMI。

本工程不需要 HTML 页面、USB 串口或 COM 口才能显示画面；HTML 监视器只属于原来的调试方案。

当前 TTP226 触摸版（2026-10-21，Gowin V1.9.12.03）bitstream SHA256：`8B33A11274D3B8E7AA4EAB7A93B8ADDAD0E932586BD54D121AD3711C0F48192B`。滑音与颤音 RTL 已加入工程，但顶层控制线目前固定关闭；只有蓝牙控制寄存器接入后，才能从手机实时控制效果。交接端口见 [滑音颤音接口说明](docs/PITCH_EFFECT_INTERFACE.md)。

构建前的旧版 `.fs` 已备份为同级目录的 `competition_polyphonic_hdmi_pre_ttp226_20261020.fs`，可用于回退。
本次修改前的 `.fs` 另备份为同级目录的 `competition_polyphonic_hdmi_pre_effects_20261021.fs`。

## TTP226 触摸和音频连接

原有 FPGA 的 8 个输入管脚位置保持不变，但输入源改为 TTP226 八路电容触摸模块。TTP226 使用 3.3V 供电，并与 FPGA 共地。直接输出模式需要 OPS1=1、OPS0=1；高有效输出需要 AHL=1。根据模块原理图和芯片数据手册，这些选项脚内部上拉，相关跳线保持断开即可为 1；不要把 AHL 短接到 GND。上电后等待约 1 秒再触摸。HDMI 直接从板卡 HDMI 接口输出。

模块 P3 排针不是 OUT1 到 OUT8 的顺序排列，请按下表连接：

| TTP226 P3 | 信号 | FPGA 信号 |
|---|---|---|
| 1 | DV | 不连接 |
| 2 | OUT8 | key_in[7] |
| 3 | OUT7 | key_in[6] |
| 4 | OUT6 | key_in[5] |
| 5 | OUT5 | key_in[4] |
| 6 | OUT4 | key_in[3] |
| 7 | OUT3 | key_in[2] |
| 8 | OUT2 | key_in[1] |
| 9 | OUT1 | key_in[0] |
| 10 | VCC | 3.3V |
| 11 | GND | FPGA GND |

| 功能 | FPGA 管脚 |
|---|---|
| 系统时钟 | V22 |
| 复位 | Y12 |
| TTP226 OUT1..OUT8 / key_in[0..7] | Y21, Y22, AB21, AB22, AA20, AA21, AA19, AB20 |
| I2S_BCLK | Y17 |
| I2S_LRCK | AB17 |
| I2S_DIN | AA16 |
| PA_EN | AB16 |
| HDMI TMDS clock P/N | G15 / G16 |
| HDMI TMDS data0 P/N | J14 / H14 |
| HDMI TMDS data1 P/N | J15 / H15 |
| HDMI TMDS data2 P/N | K17 / J17 |
| HDMI HPD enable | K13 |

## 画面内容

显示器上会显示接近原 HTML 监视器的硬件仪表盘：`POLY` 显示当前复音数（0～8），`KEY` 显示按键状态条，`SAMPLE` 显示 48.8K，`PEAK` 显示 DFT 实测最强非直流频点的约略中心频率（如 `389 Hz`）。没有明显峰值时显示 `--- Hz`。`PEAK` 仅表示最强的一个频点，不代表所有同时发音的音符。另有最新 256 点实时波形、0–1000 Hz 连续频谱曲线和 `0/250/500/750/1000 Hz` 横坐标。底部仍保留 C4～C5 八个目标音符卡片。波形取消了音量数字刻度，显示增益改为 PCM 样本值的 1/32，使单音波形更清晰；多音同相叠加时若超出绘图区，只有显示曲线被裁切，音频运算不受影响。

波形来自 `polyphonic_dds` 输出的真实 `audio_sample`，每个 `sample_tick` 写入循环缓存。HDMI 在相邻真实样本之间作仅用于显示的 1/4 像素步进线性插值，使原先每点 4 像素宽的断续短线连成平滑曲线；插值不产生新的音频样本，不参与 I2S 输出或频谱计算。连续频谱由 `spectrum_dft` 每 24 个音频采样抽取一个高字节，形成 256 点、约 2034.5 Hz 的分析帧，在 FPGA 内部时分复用计算 126 个 DFT bin。帧完成后才发布到 HDMI，不能仅靠按键位图伪造。原 `spectrum_detector` 仍对真实采样逐点执行 8 路正交相关，供底部 C4～C5 音符卡片显示。

当前修正版已将 HDMI 的横坐标频点地址连接到 DFT 读地址。上一版地址线未连接，显示器只读了第 0 个频点，因此只能看到整条横线升降。现在 0–1000 Hz 的各列读取各自的 DFT bin；第一次完整分析帧约需 0.126 秒，按住音符约 0.2 秒再观察峰值。

本次 P&R 时序已闭合：`sys_clk` Fmax 51.019 MHz（要求 50 MHz），HDMI 像素时钟 `clk_74_25` Fmax 74.533 MHz（要求 74.25 MHz），两组 Setup/Hold TNS 均为 0。报告仍有 `TA1123` PLL 频率提示和 `PR1014` 系统时钟约束提示。由于效果控制目前为常数，Gowin 将两种效果模块优化掉；蓝牙同学接入动态控制后必须重新综合与检查时序，不能沿用这里的 Fmax。

如果显示器没有画面，先确认显示器输入源为 HDMI；仍无画面时断电重启开发板，并优先尝试另一根 HDMI 线或另一台支持 720p@60Hz 的显示器。
