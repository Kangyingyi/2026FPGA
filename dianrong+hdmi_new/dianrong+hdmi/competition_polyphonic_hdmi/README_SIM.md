# 仿真验证记录

ModelSim 使用 `D:\App_for_study\intelFPGA_lite\18.1\modelsim_ase\win32aloem`。

已验证：

- `tb_key_filter_8_touch.v`：验证 TTP226 高有效 OUT1/OUT2/OUT8 到 `key_state[0]/[1]/[7]` 的映射，以及释放清零，`TB_KEY_FILTER_8_TOUCH_PASS`
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
- Gowin V1.9.12.03 综合、布局布线和 bitstream 生成返回码：0
- 当前 TTP226 版 P&R 时序：`sys_clk` Fmax 50.870 MHz（要求 50 MHz），`clk_74_25` Fmax 75.380 MHz（要求 74.25 MHz）；两组 Setup/Hold TNS 均为 0
- 当前 TTP226 版 bitstream SHA256：`9E0F0B4E1697F752037FF59B16139F7B9D510C34C084920E2767DB0B6688092F`

## 手动重跑

在 PowerShell 中进入工程目录：

```powershell
cd E:\FPGA\work\competition_polyphonic_hdmi
$sim = 'D:\App_for_study\intelFPGA_lite\18.1\modelsim_ase\win32aloem'
vlib simlib_manual
& "$sim\vlog.exe" -work simlib_manual -vlog01compat (Get-ChildItem sim\tb_*.v).FullName (Get-ChildItem src\*.v).FullName
& "$sim\vsim.exe" -c -lib simlib_manual tb_key_filter_8_touch -do 'run -all; quit -f'
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

本次显示层更新后，以下回归通过：

- `TB_HDMI_DISPLAY_REGRESSION_PASS`
- `TB_WAVEFORM_INTERPOLATION_PASS`
- `TB_VIDEO_UI_PASS`
- `TB_VIDEO_TIMING_PASS`

波形测试现在验证曲线像素存在，不绑定某一个固定 RGB 值，以允许幅度配色和高亮描边变化。
