# 仿真验证记录

ModelSim 使用 `D:\App_for_study\intelFPGA_lite\18.1\modelsim_ase\win32aloem`。

独立交付包另见 `packages/glide.zip` 和 `packages/vibrato.zip`；各自解压后运行包内 `run_test.ps1`，只编译该包的一个模块和一个测试，不调用本工程其他 RTL。

已验证：

- `tb_key_filter_8_touch.v`：验证 TTP226 高有效 OUT1/OUT2/OUT8 到 `key_state[0]/[1]/[7]` 的映射，以及释放清零，`TB_KEY_FILTER_8_TOUCH_PASS`
- `tb_pitch_glide.v`：验证滑音目标正负方向追踪、立即到达和回中，`TB_PITCH_GLIDE_PASS`
- `tb_pitch_vibrato.v`：验证颤音一个周期内的正峰、回中、负峰及关闭归零，`TB_PITCH_VIBRATO_PASS`
- `tb_polyphonic_effects.v`：验证两种效果真正进入八声部 DDS，双声部共同变音且关闭效果后恢复原相位步进，`TB_POLYPHONIC_EFFECTS_PASS`
- `tb_spectrum_detector.v`：真实采样 C4 单音及 C4+D4 复音频点检测通过，`TB_SPECTRUM_DETECTOR_PASS`
- `tb_spectrum_dft.v`：HTML 口径的 24 倍降采样连续 DFT，C4/D4 bin 高于无信号 bin，`TB_SPECTRUM_DFT_PASS`
- `tb_waveform_history.v`：循环缓存回绕后的 256 点时间顺序读取通过，`TB_WAVEFORM_HISTORY_PASS`
- `tb_ui_data.v`：`TB_UI_DATA_PASS`
- `tb_video_timing.v`：`TB_VIDEO_TIMING_PASS`
- `tb_video_ui.v`：`TB_VIDEO_UI_PASS`
- `tb_hdmi_display_regression.v`：逐字符像素检查四个顶部标签和 `Hz`，并验证 PCM 幅度变化与真实量级频谱峰值可见，`TB_HDMI_DISPLAY_REGRESSION_PASS`
- `tb_spectrum_real_level.v`：两路真实 DDS 量级的 C4/D4 音调在连续频谱出现明显峰值，`TB_SPECTRUM_REAL_LEVEL_PASS`
- `tb_spectrum_from_dds.v`：真实 DDS 经单周期采样脉冲、24:1 取样后产生 C4/D4 频谱峰值，`TB_SPECTRUM_FROM_DDS_PASS`
- `tb_spectrum_visibility.v`：连续两帧的 DFT 事件翻转后，HDMI 频谱仍保持可见；同时验证屏幕约 262 Hz 的列确实读取 DFT 第 33 个频点，`TB_SPECTRUM_VISIBILITY_PASS`
- `tb_waveform_interpolation.v`：验证相邻真实 PCM 样本间 1/4、1/2、3/4 和终点的 HDMI 波形像素；旧版断续短线会在首个插值点失败，`TB_WAVEFORM_INTERPOLATION_PASS`
- `tb_spectrum_peak_metric.v`：验证 DFT 最强非直流频点、无峰时清空和频率换算，`TB_SPECTRUM_PEAK_METRIC_PASS`
- `tb_ui_metrics.v`：验证 POLY 数字随输入变化、PEAK 字样和频率/无效峰字形，`TB_UI_METRICS_PASS`
- Verilog 编译错误数：0
- Verilog 编译警告数：0
- 17 项原工程回归均 PASS；其中 `tb_video_ui`、`tb_hdmi_display_regression`、`tb_waveform_interpolation` 在 ModelSim 展开阶段各有 3 条旧版 `hdmi_ui` 端口未连接警告（`peak_bcd`、`peak_valid`），错误数仍为 0。此警告与新交付包无关；两包独立编译和仿真各为 0 错误、0 警告。
- Gowin V1.9.12.03 综合、布局布线和 bitstream 生成返回码：0
- 当前顶层（效果控制常数关闭）P&R 时序：`sys_clk` Fmax 51.019 MHz（要求 50 MHz），`clk_74_25` Fmax 74.533 MHz（要求 74.25 MHz）；Setup/Hold TNS 均为 0
- 当前 bitstream SHA256：`8B33A11274D3B8E7AA4EAB7A93B8ADDAD0E932586BD54D121AD3711C0F48192B`
- 重要边界：Gowin 综合提示 `pitch_glide` 和 `pitch_vibrato` 因顶层常数控制而被优化。动态蓝牙参数接入后须重新跑时序；当前 P&R 结果不能代表动态版本。

## 手动重跑

在 PowerShell 中进入工程目录：

```powershell
cd E:\FPGA\work\competition_polyphonic_hdmi
$sim = 'D:\App_for_study\intelFPGA_lite\18.1\modelsim_ase\win32aloem'
vlib simlib_manual
& "$sim\vlog.exe" -work simlib_manual -vlog01compat (Get-ChildItem sim\tb_*.v).FullName (Get-ChildItem src\*.v).FullName
& "$sim\vsim.exe" -c -lib simlib_manual tb_key_filter_8_touch -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_pitch_glide -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_pitch_vibrato -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_polyphonic_effects -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_spectrum_detector -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_spectrum_dft -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_spectrum_real_level -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_spectrum_from_dds -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_waveform_history -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_ui_data -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_video_timing -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_video_ui -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_hdmi_display_regression -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_spectrum_visibility -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_waveform_interpolation -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_spectrum_peak_metric -do 'run -all; quit -f'
& "$sim\vsim.exe" -c -lib simlib_manual tb_ui_metrics -do 'run -all; quit -f'
```

HDMI 加密发送器由 Gowin 综合工具编译；ModelSim 回归不直接解析 Gowin 加密的 `DVI_TX_Top.v`，覆盖本工程新增的 UI、波形缓存、频谱检测和视频时序逻辑。
