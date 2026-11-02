# 独立颤音工程 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking。 本工作区没有 Git 仓库，所有提交步骤省略。

**Goal:** 在 `E:\FPGA\work\vibrato_standalone` 生成可单独打开、仿真、构建和烧录的颤音 I2S 乐器工程。

**Architecture:** TTP226 八键 → 同步消抖 → 八声部正弦 DDS；一个三角波 LFO 给所有按下的声部周期性调频。16 位 PCM 复制到 I2S 左右声道，不包含滑音、蓝牙、HDMI。

**Tech Stack:** Verilog-2001，Gowin V1.9.12.03 (`GW5AT-LV60PG484AC1/I0`)，ModelSim 10.5b，PowerShell。

**Spec:** `E:\FPGA\work\competition_polyphonic_hdmi\docs\superpowers\specs\2026-10-21-standalone-pitch-effects-design.md`

## Global Constraints

- 项目根目录必须是 `E:\FPGA\work\vibrato_standalone`，源文件只引用此目录内部；不碰原 HDMI 工程及之前的 ZIP。
- TTP226 仍为高有效、OUT1～OUT8 对应 C4～C5；同一组 8 个 FPGA 管脚。50 MHz V22、复位 Y12；I2S BCLK Y17、LRCK AB17、DIN AA16、PA_EN AB16，PA_EN 固定 0。
- 复用原项目 `key_filter_8`、`i2s_tx` 的行为；无键静音，最多 8 声部，双声道相同。只在 `sample_tick` 更新音频状态。
- 颤音为所有活动声部共用的约 5 Hz 三角波音高偏移，深度默认 Q15 1024（约 ±50 音分）；全键松开后复位相位。不得把滑音模块加入本工程。
- 工程无 Git；不写提交命令。没有板级听音时只报告仿真/构建结果。

## File Structure

- `src/key_filter_8.v`、`src/i2s_tx.v`：原工程功能等价的独立副本。
- `src/pitch_vibrato.v`：颤音 Q15 偏移，沿用已验证的独立模块。
- `src/vibrato_dds.v`：八声部相位、正弦查表、混音及全局颤音步进。
- `src/vibrato_top.v`：八键消抖、DDS、I2S 连线，速度/深度可在顶层调整。
- `src/vibrato_standalone.cst`、`src/timing.sdc`：仅顶层存在的管脚与 50 MHz 约束。
- `sim/tb_pitch_vibrato.v`、`sim/tb_vibrato_audio.v`：模块与音频链路行为测试；`run_tests.ps1` 独立运行。
- `vibrato_standalone.gprj`、`build.tcl`、`README.md`：Gowin 项目、构建、接线/听音说明；构建生成 `impl/pnr/vibrato_standalone.fs`。

## Review Focus

- 全键松开再按：LFO 应从零偏移重新开始 → `tb_vibrato_audio` 验证。
- 改变/清零深度：输出必须跟随深度，零深度无偏移 → `tb_pitch_vibrato` 验证。
- 高有效触摸输入与消抖：OUT1/OUT8 应对应 C4/C5 → `tb_vibrato_audio` 用缩短消抖参数验证。
- 无键静音与双声部：PCM 必须静音/混音 → `tb_vibrato_audio` 验证。
- I2S 帧/样本：约 48.828 kHz、左右同 PCM → `tb_vibrato_audio` 验证。

---

### Task 1: 颤音周期与八声部 DDS

**Files:** Create `src/pitch_vibrato.v`, `src/vibrato_dds.v`, `sim/tb_pitch_vibrato.v`, `sim/tb_vibrato_audio.v`。

**Interfaces:** `pitch_vibrato(clk,rst_n,sample_tick,enable,rate_hz[3:0],depth_q15[10:0],delta_q15[15:0])`；`vibrato_dds #(RATE_HZ=5, DEPTH_Q15=1024)(clk,rst_n,sample_tick,key_state,sample)`。C4～C5 步进常量沿用原项目；八声部共享 `delta_q15`，`step = base_step * (32768 + delta_q15) >> 15`。

- [ ] 先写/移入本工程测试：10 Hz 下 1/4、1/2、3/4 周期分别接近正峰、0、负峰；关闭和零深度输出零；DDS 单键实际相位步进随 LFO 正负变化，双键仍各自发声；松开全部键后重新按下相位复位。
- [ ] 只编译测试运行，确认因缺少本目录效果/DDS 模块而失败。
- [ ] 加入包中已验证的 `pitch_vibrato` RTL，完成 `vibrato_dds` 与原项目正弦查表/1⁄8 混音；确认独立测试全绿、0 error，检查 warning。

### Task 2: 顶层 I2S 与 Gowin 项目

**Files:** Create `src/key_filter_8.v`, `src/i2s_tx.v`, `src/vibrato_top.v`, `sim/tb_vibrato_top.v`, `run_tests.ps1`, `vibrato_standalone.gprj`, `src/vibrato_standalone.cst`, `src/timing.sdc`, `build.tcl`, `README.md`。

**Interfaces:** `vibrato_top(sys_clk,rst_n,key_in,I2S_BCLK,I2S_LRCK,I2S_DIN,PA_EN)`，内部 `key_filter_8` → `vibrato_dds` → `i2s_tx`，左右相同；顶层参数可覆盖 5 Hz/1024 深度。

- [ ] 先写顶层测试：缩短消抖周期后的 OUT1/OUT8 输入传到正确声部，无键 PCM=0，I2S BCLK/LRCK/tick 正常、左右采样相同，PA_EN=0。
- [ ] 编译运行测试，确认因缺少顶层/音频传输模块而失败。
- [ ] 实现顶层并放入原项目 `key_filter_8`、`i2s_tx` 的独立副本；`run_tests.ps1` 只编译本工程；确认所有本工程仿真 PASS。
- [ ] `.gprj` 只指向本目录 5 个 Verilog 模块、CST/SDC；CST 只留时钟、复位、八键、四个音频端口；SDC 只约束 50 MHz `sys_clk`。
- [ ] 跑 `gw_sh.exe build.tcl`，检查 `.fs`、管脚报告、50 MHz setup/hold 时序；若失败先查关键路径再优化并重跑测试。
- [ ] README 写明 TTP226/I2S 接线、Gowin 打开/烧录步骤、颤音听感和参数位置；注明实物听音是否已验证。
