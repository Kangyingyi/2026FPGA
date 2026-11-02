# TTP226 Legato 上下滑音独立 Gowin 工程

用 Gowin V1.9.12.03 打开本目录的 `legato_glide_standalone.gprj`。这是独立的**单声部**声音演示工程，不影响原来的 `glide_standalone` 音头自动上滑模式，也不需要 HDMI 或蓝牙。

## 演奏规则

八个触摸键分别对应 C4、D4、E4、F4、G4、A4、B4、C5。单独按键直接发出该键的正常音高；保持旧键时再触摸新键，声音从当前频率向新键频率平滑移动，固定用 14,648 个音频采样点，约 **300 ms**。高音方向是上滑，低音方向是下滑。滑动中触摸第三键，会从当时的频率重新开始 300 ms 滑动。

最后按下的键优先发声，其他仍按住的键只作回退候选，不形成和弦。松开当前键但仍按着旧键，立即回到最近按下的仍保持键的**正常音高，不滑回**。全部松开后静音；下次单独触摸仍直接发音。若多键在同一个消抖事件中同时按下，编号较大的键优先。

滑动改变 DDS 相位步进（音高），并保持振荡器相位连续；没有音量包络。单声部正弦样本通过约 48.828 kHz、16 位双声道同音的标准 Philips I2S 发出。

## 接线

TTP226 设为直接输出、高有效（OPS1=1、OPS0=1、AHL=1），用 **3.3 V** 供电，与 FPGA 共地；上电约 1 秒后再触摸。P3 的 **DV 不连接**。P3 排针顺序不是 OUT1～OUT8 的自然顺序：P3-9=OUT1→Y21、P3-8=OUT2→Y22、P3-7=OUT3→AB21、P3-6=OUT4→AB22、P3-5=OUT5→AA20、P3-4=OUT6→AA21、P3-3=OUT7→AA19、P3-2=OUT8→AB20；P3-10=VCC 3.3 V，P3-11=GND。不要把 5 V 送入 FPGA 输入。

沿用原音频 DAC/功放：I2S_BCLK=Y17、I2S_LRCK=AB17、I2S_DIN=AA16、PA_EN=AB16。系统时钟 V22（50 MHz），低有效复位 Y12；`PA_EN` 与原工程相同，恒为低电平。I2S 是数字音频，不可直接驱动无源喇叭。

## 测试、构建与烧录

在此目录用 PowerShell 运行 `.\run_tests.ps1`。它只编译本工程 `src` 和 `sim`，默认调用本机 ModelSim；也可传入 `-ModelSimBin` 指定工具目录。预期逐键消抖、300 ms Legato 控制、单声部 DDS、I2S 帧解码及顶层音频五项仿真均 PASS。

在 Gowin GUI 中打开 `legato_glide_standalone.gprj` 后运行完整构建，或者执行：

```powershell
& 'E:\FPGA\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe' 'E:\FPGA\work\legato_glide_standalone\build.tcl'
```

构建成功后烧录 `impl/pnr/legato_glide_standalone.fs`，不要误用原滑音工程的 `.fs`。修改 RTL 或参数后须重新构建并检查时序。

本机验证（2026-10-21）：五项 ModelSim 仿真通过；Gowin 完整构建生成 `.fs`，`sys_clk` Fmax **51.012 MHz**（约束 50 MHz），Setup/Hold TNS 均为 0。当前 `.fs` SHA256：`1310B7071EF31526008728427426147604ABE5AAA8F4CA3F3D4617A83278CC7B`。构建有 `PR1014` 时钟布线提示，且频率裕量仅约 1 MHz；更改 RTL、参数或约束后必须重新检查时序，不要直接沿用本次结论。

ModelSim 仿真和 Gowin 构建不能代替实物听音；在板上接 DAC/功放分别验证上滑、下滑和松键回退。
