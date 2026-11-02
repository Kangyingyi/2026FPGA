# TTP226 八键颤音独立 Gowin 工程

用 Gowin V1.9.12.03 打开本目录的 `vibrato_standalone.gprj`。本工程只生成 I2S 音频，不需要 HDMI、电脑端页面或蓝牙。八个触摸键仍分别演奏 C4、D4、E4、F4、G4、A4、B4、C5，可同时发声。按住键时音高以约 5 Hz 周期性上下摆动，默认深度约 ±50 音分；所有键松开时静音，再触摸从颤音中心重新开始。

## 接线

TTP226 设为直接输出、高有效（OPS1=1、OPS0=1、AHL=1），用 **3.3 V** 供电并与 FPGA 共地；上电约 1 秒后再触摸。P3 的 DV 不连接。P3-9=OUT1→Y21、P3-8=OUT2→Y22、P3-7=OUT3→AB21、P3-6=OUT4→AB22、P3-5=OUT5→AA20、P3-4=OUT6→AA21、P3-3=OUT7→AA19、P3-2=OUT8→AB20；P3-10=VCC 3.3 V，P3-11=GND。不要把 5 V 送入这些 FPGA 输入。

沿用原工程的音频 DAC/功放连接：I2S_BCLK=Y17、I2S_LRCK=AB17、I2S_DIN=AA16、PA_EN=AB16。系统时钟 V22（50 MHz），低有效复位 Y12。`PA_EN` 与原工程一样恒为低电平。I2S 是约 48.828 kHz 的 16 位双声道流，左右声道相同；它不是可直接连接无源喇叭的模拟音频。

## 测试、构建与烧录

在本目录运行 `.\run_tests.ps1`；脚本只编译本目录的 `src` 和 `sim`，需要 ModelSim，可用 `-ModelSimBin` 指定安装目录。预期颤音调制、DDS 音频、整机音频、八键音高映射、标准 I2S 串行解码五项测试全部 PASS。仿真会生成本目录 `simlib`。

在 Gowin GUI 打开 `vibrato_standalone.gprj` 后运行完整构建，或在 PowerShell 执行：

```powershell
& 'E:\FPGA\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe' 'E:\FPGA\work\vibrato_standalone\build.tcl'
```

构建成功后烧录 `impl/pnr/vibrato_standalone.fs`。若调整 RTL 或参数，重新构建后再烧录；不要把滑音或原 HDMI 工程的 `.fs` 误当作本工程文件。

本机验证（2026-10-21）：五项独立仿真通过；Gowin 完整构建成功，`sys_clk` Fmax 82.794 MHz（约束 50 MHz）、Setup/Hold TNS 均为 0。当前 `.fs` SHA256 为 `56171769AB08683E8794E87E4995DA693823DC42B1A56FD1A0AA9E8AB1577699`。串行音频已按标准 Philips I2S 的 LRCK 后一位时钟发送 MSB；构建报告有 `PR1014` 系统时钟布线提示，后续调整需重新检查时序。

## 算法与可调参数

顶层 `src/vibrato_top.v` 的 `VIBRATO_RATE_HZ=5`、`VIBRATO_DEPTH_Q15=1024` 控制默认速度和深度。`src/pitch_vibrato.v` 在每个音频采样点累加 32 位相位，把相位变为三角波并乘深度，输出有符号 Q15 频率偏移。`src/vibrato_dds.v` 对八个音符的相位步进统一乘以 `(32768 + delta_q15)/32768`，八声部仍独立发声。全部松键时 LFO 相位复位。本工程用于没有蓝牙的自动演示，不包含颤音控制协议或音头/音尾音量包络。

构建、时序和实物听音是不同验证步骤：ModelSim 只能证明 RTL 行为，Gowin 构建只能证明可综合和约束，实际音频仍需在板上接 DAC/功放听取。
