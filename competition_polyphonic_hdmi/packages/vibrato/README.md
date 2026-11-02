# 颤音独立代码包

此包只包含 `pitch_vibrato` 模块及其独立测试，不依赖滑音、蓝牙、DDS 或 HDMI 代码。工程里的同名模块仍在 `src/pitch_vibrato.v`；两份文件内容相同。**在同一个 Gowin/ModelSim 项目里只添加其中一份**，避免重复定义模块。

## 文件与测试

- `src/pitch_vibrato.v`：可直接交给蓝牙/音频集成同学的 RTL。
- `sim/tb_pitch_vibrato.v`：独立行为测试。
- `run_test.ps1`：只编译本包两个 Verilog 文件并运行测试。

在 PowerShell 中进入解压后的本包目录，执行：

```powershell
.\run_test.ps1
```

若 ModelSim 不在脚本的默认安装位置，用 `-ModelSimBin '你的ModelSim\win32aloem目录'` 指定。脚本会在本包内生成 `simlib` 仿真工作库；出现 `VIBRATO_PACKAGE_PASS` 表示测试通过。

## 实现与接口

`clk` 为系统时钟；`rst_n` 低有效复位；`sample_tick` 为单周期音频采样使能。该模块按当前工程的约 48.828 kHz 采样率计算周期；若移植到不同音频采样率，须重新计算 `STEP_PER_HZ`。

`enable` 控制开关；`rate_hz` 取 1～12 Hz（0 为静止，13～15 按 12 Hz）；`depth_q15` 取 0～2047。输出 `delta_q15` 是有符号频率偏移。32 位相位累加器按 `rate_hz` 增长，取相位高位生成一个三角波，再乘深度，得到周期性升高、回中、降低、回中的音高变化。`enable=0` 时输出立即为 0，下一次 `sample_tick` 清零相位，使重新开启从中间音高开始。

模块本身只产生音高偏移，不能单独输出声音。接入 DDS 时，对各声部的基础相位步进值使用 `实际步进 = 基础步进 × (32768 + delta_q15) / 32768`。如与滑音叠加，则两个偏移相加后再换算步进。音头、音尾的音量包络不在本包内。

独立测试检查关闭为零、10 Hz 周期内的正峰/回中/负峰、深度为零，以及关闭再开启的复位行为。包不含蓝牙接收代码，也不占用 FPGA 管脚。
