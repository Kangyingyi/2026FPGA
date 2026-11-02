# TTP226 八键滑音独立 Gowin 工程

用 Gowin V1.9.12.03 打开本目录的 `glide_standalone.gprj`。本工程只生成 I2S 音频，不需要 HDMI、电脑端页面或蓝牙。八个触摸键仍分别演奏 C4、D4、E4、F4、G4、A4、B4、C5，并可同时发声。每个音符初始约低 200 音分，约 123 ms 内平滑上滑到该键的正常音高；松开后再触摸会重新滑一次。没有按键时静音。

## 接线

TTP226 设为直接输出、高有效（OPS1=1、OPS0=1、AHL=1），用 **3.3 V** 供电并与 FPGA 共地；上电约 1 秒后再触摸。P3 的 DV 不连接。P3 排针顺序不是 OUT1～OUT8 的自然顺序：P3-9=OUT1→Y21、P3-8=OUT2→Y22、P3-7=OUT3→AB21、P3-6=OUT4→AB22、P3-5=OUT5→AA20、P3-4=OUT6→AA21、P3-3=OUT7→AA19、P3-2=OUT8→AB20；P3-10=VCC 3.3 V，P3-11=GND。不要把 5 V 送入这些 FPGA 输入。

沿用原工程的音频 DAC/功放连接：I2S_BCLK=Y17、I2S_LRCK=AB17、I2S_DIN=AA16、PA_EN=AB16。系统时钟 V22（50 MHz），低有效复位 Y12。`PA_EN` 与原工程一样恒为低电平。I2S 是约 48.828 kHz 的 16 位双声道流，左右声道相同；它不是可直接连接无源喇叭的模拟音频。

## 测试、构建与烧录

在本目录运行 `./run_tests.ps1`（PowerShell 中也可用 `.\run_tests.ps1`）；脚本只编译本目录的 `src` 和 `sim`，需要 ModelSim，可用 `-ModelSimBin` 指定安装目录。预期滑音状态、整机音频、八键音高映射、标准 I2S 串行解码四项测试全部 PASS。仿真会生成本目录 `simlib`。

在 Gowin GUI 打开 `glide_standalone.gprj` 后运行完整构建，或在 PowerShell 执行：

```powershell
& 'E:\FPGA\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe' 'E:\FPGA\work\glide_standalone\build.tcl'
```

构建成功后烧录 `impl/pnr/glide_standalone.fs`。若调整 RTL 或参数，重新构建后再烧录；不要把原 HDMI 工程的 `.fs` 误当作本工程文件。

本机验证（2026-10-21）：四项独立仿真通过；Gowin 完整构建成功，`sys_clk` Fmax 114.335 MHz（约束 50 MHz）、Setup/Hold TNS 均为 0。当前 `.fs` SHA256 为 `9DE5F50F3CE9CB5820F2D831109728F80F130AA4F94673C98D0214B729AC0ADE`。串行音频已按标准 Philips I2S 的 LRCK 后一位时钟发送 MSB；构建报告有 `PR1014` 系统时钟布线提示，后续调整需重新检查时序。

## 算法与可调参数

顶层 `src/glide_top.v` 的 `START_OFFSET_Q15=-3577` 决定起始约低 200 音分，`RAMP_STEP_Q8=153` 决定每个采样向目标移动约 0.598 个 Q15 单位，默认约 123 ms 到达 0 偏移。八声部各自有滑音状态；`src/glide_dds.v` 对相位步进按 `(32768 + offset_q15)/32768` 缩放，最终回到原 C4～C5 音高。此工程用于没有蓝牙的自动演示，不包含方向控制协议或音头/音尾音量包络。

构建、时序和实物听音是不同验证步骤：ModelSim 只能证明 RTL 行为，Gowin 构建只能证明可综合和约束，实际音频仍需在板上接 DAC/功放听取。
