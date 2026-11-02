# 独立滑音工程 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 本工作区没有 Git 仓库，所有提交步骤省略。

**Goal:** 在 `E:\FPGA\work\glide_standalone` 生成可单独打开、仿真、构建和烧录的滑音 I2S 乐器工程。

**Architecture:** TTP226 八键 → 同步消抖 → 八声部正弦 DDS；每个声部各有触发一次的低音高到标准音高滑音状态。16 位 PCM 复制到 I2S 左右声道，不包含颤音、蓝牙、HDMI。

**Tech Stack:** Verilog-2001，Gowin V1.9.12.03 (`GW5AT-LV60PG484AC1/I0`)，ModelSim 10.5b，PowerShell。

**Spec:** `E:\FPGA\work\competition_polyphonic_hdmi\docs\superpowers\specs\2026-10-21-standalone-pitch-effects-design.md`

## Global Constraints

- 项目根目录必须是 `E:\FPGA\work\glide_standalone`，源文件只引用此目录内部；不碰原 HDMI 工程及之前的 ZIP。
- TTP226 仍为高有效、OUT1～OUT8 对应 C4～C5；同一组 8 个 FPGA 管脚。50 MHz V22、复位 Y12；I2S BCLK Y17、LRCK AB17、DIN AA16、PA_EN AB16，PA_EN 固定 0。
- 复用原项目 `key_filter_8`、`i2s_tx` 的行为；无键静音，最多 8 声部，双声道相同。只在 `sample_tick` 更新音频状态。
- 滑音每个新按下的声部独立从约 -200 音分滑到 0 偏移，最终保持原目标音高；不得把颤音模块加入本工程。
- 工程无 Git；不写提交命令。没有板级听音时只报告仿真/构建结果。

## File Structure

- `src/key_filter_8.v`、`src/i2s_tx.v`：原工程功能等价的独立副本。
- `src/glide_voice_pitch.v`：单声部音高偏移状态，输入 `clk,rst_n,sample_tick,key_active`，输出有符号 `offset_q15[15:0]`。
- `src/glide_dds.v`：八声部相位、正弦查表、按键静音及混音；消耗各声部偏移，输出 signed 16 位 `sample`。
- `src/glide_top.v`：八键消抖、DDS、I2S 连线及可调参数，不引用工程外模块。
- `src/glide_standalone.cst`、`src/timing.sdc`：仅上述顶层存在的管脚与 50 MHz 约束。
- `sim/tb_glide_voice_pitch.v`、`sim/tb_glide_audio.v`：模块与音频链路行为测试；`run_tests.ps1` 独立运行。
- `glide_standalone.gprj`、`build.tcl`、`README.md`：Gowin 项目、构建、接线/听音说明；构建生成 `impl/pnr/glide_standalone.fs`。

## Review Focus

- 新键按下前原声部已保持：新键只触发自身滑音 → `tb_glide_audio` 同时按两键检查第一个偏移不重置。
- 短暂松键再按：应重新从低偏移开始 → `tb_glide_voice_pitch` 验证释放/重触发。
- 高有效触摸输入与消抖：OUT1/OUT8 应对应 C4/C5 → `tb_glide_audio` 用缩短消抖参数验证。
- 声部结束与全键释放：PCM 必须回零 → `tb_glide_audio` 验证。
- I2S 采样周期/左右声道：约 48.828 kHz 与相同样本 → `tb_glide_audio` 验证 BCLK/LRCK/tick 和采样保持。

---

### Task 1: 单声部滑音状态

**Files:** Create `src/glide_voice_pitch.v`, `sim/tb_glide_voice_pitch.v`。

**Interfaces:** `glide_voice_pitch #(START_OFFSET_Q15=-3577, RAMP_STEP_Q8=153)(clk,rst_n,sample_tick,key_active,offset_q15)`。每采样从 -3577 Q15 以 153/256 Q15 的固定斜率向 0 移动，约 5985 次采样（123 ms）；使用内部 Q8 小数状态，不依赖另外一个音效模块。

- [ ] 测试先写：第一次有效采样偏移为 -3577；约第 3000 次偏移介于 -1900 和 -1600；第 6500 次精确为 0；无 `sample_tick` 不变化；松键归零、重按回 -3577。
- [ ] 只编译测试运行，确认因缺少 `glide_voice_pitch` 失败。
- [ ] 实现模块，仿真得到 `TB_GLIDE_VOICE_PITCH_PASS`、0 error；检查 0 warning。

### Task 2: 八声部声音与顶层 I2S

**Files:** Create `src/glide_dds.v`, `src/glide_top.v`, `src/key_filter_8.v`, `src/i2s_tx.v`, `sim/tb_glide_audio.v`, `run_tests.ps1`。

**Interfaces:** `glide_dds(clk,rst_n,sample_tick,key_state,sample)`；`glide_top(sys_clk,rst_n,key_in,I2S_BCLK,I2S_LRCK,I2S_DIN,PA_EN)`。每声部基础步进沿用原项目 C4～C5 八个 32 位常量，`step = base_step * (32768 + offset_q15) >> 15`；原项目 32 项正弦表、1/8 混音，左右声道同 PCM。

- [ ] 先写 `tb_glide_audio`：未触摸静音；OUT1/OUT8 正确映射；单键滑音的相位增量从低于原值恢复到原值；双键时两个相位独立，后按键不重启先按键；I2S tick/BCLK/LRCK 工作、左右一致。
- [ ] 编译运行测试，确认因缺少 DDS/顶层而失败。
- [ ] 实现 DDS/顶层，并放入原工程 `key_filter_8`、`i2s_tx` 的独立副本；`run_tests.ps1` 只从本工程 `src`、`sim` 编译；确认模块及链路测试全绿。

### Task 3: Gowin 项目与交付验证

**Files:** Create `glide_standalone.gprj`, `src/glide_standalone.cst`, `src/timing.sdc`, `build.tcl`, `README.md`。

- [ ] `.gprj` 指向本目录 5 个 Verilog 模块、CST/SDC；检查无外部路径、无颤音引用。CST 只保留时钟、复位、八键和四个音频端口；SDC 只约束 50 MHz `sys_clk`。
- [ ] 跑 `run_tests.ps1`，ModelSim 全部 PASS；跑 `gw_sh.exe build.tcl`，检查 `impl/pnr/glide_standalone.fs` 存在、管脚报告正确、50 MHz setup/hold 时序闭合。若不闭合，先定位关键路径再做针对性优化和回归。
- [ ] README 写明 TTP226/I2S 接线、Gowin 打开/烧录步骤、滑音听感与参数位置；注明尚无实物听音验证时的边界。
