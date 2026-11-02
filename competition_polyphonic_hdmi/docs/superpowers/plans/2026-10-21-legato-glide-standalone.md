# Legato 上下滑音独立工程 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `E:\FPGA\work\legato_glide_standalone` 交付可单独仿真、Gowin 构建和烧录的 TTP226 单声部 Legato 上下滑音工程。

**Architecture:** 八路触摸各自消抖后，由按键顺序控制器选出最近按下的仍保持键；只在已有键保持时的新按键事件启动 14,648 个音频采样点的线性 DDS 步进滑动。一个相位连续的正弦 DDS 经标准 I2S 发出左右同音音频。

**Tech Stack:** Verilog-2001、PowerShell、ModelSim ASE 10.5b、Gowin V1.9.12.03，器件 `GW5AT-LV60PG484AC1/I0`。

**Spec:** `E:\FPGA\work\competition_polyphonic_hdmi\docs\superpowers\specs\2026-10-21-legato-glide-standalone-design.md`

## Global Constraints

- 原 `E:\FPGA\work\glide_standalone` 与 `E:\FPGA\work\competition_polyphonic_hdmi` 的 RTL 不变；不使用 Git 或 worktree，用户指定直接在 `E:\FPGA\work` 建新目录。
- 八键顺序 C4、D4、E4、F4、G4、A4、B4、C5，沿用现有 DDS 目标步进常数与 Y21、Y22、AB21、AB22、AA20、AA21、AA19、AB20 引脚。
- TTP226 直接、高有效、3.3 V、共地、DV 不接；50 MHz V22，复位 Y12；I2S Y17/AB17/AA16，PA_EN AB16 且低有效。
- 采样率 48,828.125 Hz，滑动默认 14,648 个采样点（约 299.991 ms），完成时精确锁定目标；无蓝牙、HDMI、颤音、音量包络或和弦多声部。
- `.gprj` 仅引用新目录的 RTL 与约束；使用现有滑音工程**已修正为 Philips I2S 时序**的 `i2s_tx.v`，不可复制旧 HDMI 工程中左对齐版本。

## File Map

以下路径均相对于 `E:\FPGA\work\legato_glide_standalone`：

- `src/key_filter_8.v`：逐键同步、消抖与上升沿事件。
- `src/legato_pitch.v`：按键顺序栈、C4～C5 步进查表、滑动/回退状态，输出 `active` 与 `step`。
- `src/legato_dds.v`：单声部连续相位与正弦 PCM。
- `src/i2s_tx.v`：本地独立的标准 I2S 发送器副本。
- `src/legato_top.v`：触摸、音高、DDS、I2S 接线。
- `src/legato_glide_standalone.cst`、`src/timing.sdc`：板级引脚和 50 MHz 时序。
- `sim/tb_key_filter_8.v`、`sim/tb_legato_pitch.v`、`sim/tb_legato_dds.v`、`sim/tb_i2s_framing.v`、`sim/tb_legato_top.v`：独立验证。
- `run_tests.ps1`、`build.tcl`、`legato_glide_standalone.gprj`、`README.md`：测试、构建、工程、接线和烧录。

## Review Focus

1. 某一触摸通道抖动时，另一通道的稳定触摸仍应按自己的 5 ms 窗口确认：Task 1 的逐键独立消抖测试。
2. 多个新键同拍按下时，编号最大的当前发声，其余依次成为回退候选：Task 2 的同时事件测试。
3. 当前键释放与新键按下同拍且没有别的旧键保持时，不应错误地触发滑音：Task 2 的无重叠切换测试。
4. 尚在滑动中又触摸第三键时，下一段必须从当前频率起步而非前一目标：Task 2 的重新触发测试。
5. 顶层 DIN 即使有时钟也可能发错位或恒静音：Task 3 的标准接收端逐位解码及非零 PCM 测试。

---

### Task 1: 独立触摸同步和消抖

**Files:** Create `src/key_filter_8.v`, `sim/tb_key_filter_8.v`, `run_tests.ps1` under `E:\FPGA\work\legato_glide_standalone`.

**Interfaces:** Produces `key_filter_8 #(DEBOUNCE_CYCLES=250000)` with `clk`, `rst_n`, `key_in[7:0]` inputs and `key_state[7:0]`, `key_pressed[7:0]` outputs. High-active TTP226; one pulse per confirmed 0→1 transition.

- [ ] **Step 1: Write failing `tb_key_filter_8`** — reset is all-zero; one key stays high for `DEBOUNCE_CYCLES` and emits one pulse; brief bounce emits none; while key 1 chatters, stable key 2 still confirms within its own window; simultaneous stable keys both confirm. Use a small test parameter (for example 4 cycles).
- [ ] **Step 2: Run RED** — create a local ModelSim `run_tests.ps1` that compiles local `src/*.v` and `sim/tb_*.v` and runs named tests. `./run_tests.ps1` must fail because `key_filter_8` is not yet implemented, not because of script syntax or missing tools.
- [ ] **Step 3: Implement minimal `key_filter_8`** — two-flop input sync, per-bit candidate and counter, synchronized stable state and one-cycle `key_pressed`; do not use one shared vector debounce counter.
- [ ] **Step 4: Run GREEN** — `./run_tests.ps1` reports `tb_key_filter_8 PASS`, zero compile/simulation errors and warnings. Record result in a plain-text progress ledger, not a Git commit.

### Task 2: 按键顺序与 300 ms 双向滑音控制器

**Files:** Create `src/legato_pitch.v`, `sim/tb_legato_pitch.v`; extend `run_tests.ps1` test list.

**Interfaces:** Consumes stable `key_state[7:0]` from Task 1. Produces `legato_pitch #(SLIDE_SAMPLES=14648)` with inputs `clk`, `rst_n`, `sample_tick`, `key_state[7:0]` and outputs `active`, `step[31:0]`. `step` is the current unsigned DDS phase increment; note lookup uses the eight exact constants in `glide_standalone/src/glide_dds.v`.

- [ ] **Step 1: Write failing `tb_legato_pitch`** — verify each one-hot key starts directly at its exact target step; C4→C5 strictly rises and C5→C4 strictly falls; at the 14,648th tick each reaches exact target; midpoint is approximately half the step interval. Assert a solo re-touch is direct. Include simultaneous two-key press from idle (higher key sounds directly), priority/release fallback, noncurrent release, all-release reset, same-event old release/new press with no overlap, and third-key press mid-slide with no step jump.
- [ ] **Step 2: Run RED** — `./run_tests.ps1` fails at compile due missing `legato_pitch`, not an invalid testbench.
- [ ] **Step 3: Implement minimal `legato_pitch`** — maintain the order of currently held key IDs; on each stable-state change, remove released IDs first, then append newly pressed IDs ascending so highest simultaneous key wins. If new press and retained old key exist, capture **current `step`** as slide start; otherwise jump to target. If current key released, select latest retained key and jump straight to its nominal step. Advance interpolation only on `sample_tick`, clamp at exact target on tick 14,648; clear on all-release. Avoid wraparound and signed underflow for downward slides.
- [ ] **Step 4: Run GREEN** — controller test and prior filter test PASS with zero errors/warnings. Log outcomes without Git.

### Task 3: 单声部 DDS、标准 I2S 与顶层音频

**Files:** Create `src/legato_dds.v`, `src/i2s_tx.v`, `src/legato_top.v`, `sim/tb_legato_dds.v`, `sim/tb_i2s_framing.v`, `sim/tb_legato_top.v`; extend test runner.

**Interfaces:** `legato_dds` consumes `clk`, `rst_n`, `sample_tick`, `active`, `step[31:0]` and produces signed `sample[15:0]`. `legato_top` exposes `sys_clk`, `rst_n`, `key_in[7:0]` and `I2S_BCLK`, `I2S_LRCK`, `I2S_DIN`, `PA_EN`; internally connects Tasks 1–2 and DDS to stereo I2S.

- [ ] **Step 1: Write failing audio tests** — DDS silent when inactive, makes nonzero sine PCM for a held note, and preserves phase across changing step; I2S decoder receives known distinct left/right 16-bit patterns with MSB one BCLK after LRCK transition; top test debounces OUT1/OUT8 and decodes actual DIN into nonzero PCM while held, then silence after release.
- [ ] **Step 2: Run RED** — tests fail due missing DDS/I2S/top modules.
- [ ] **Step 3: Implement minimal audio chain** — one DDS using the existing 32-entry sine table, no eight-voice mix; reset phase only when no keys are held. Copy the corrected I2S implementation from `glide_standalone/src/i2s_tx.v` into the new directory after framing test is red; connect one PCM sample to both channels, `PA_EN=0`.
- [ ] **Step 4: Run GREEN** — all five standalone tests PASS; no warnings/errors. Recheck that old and new projects have no source-file dependency.

### Task 4: 独立 Gowin 工程与交付验证

**Files:** Create `legato_glide_standalone.gprj`, `build.tcl`, `src/legato_glide_standalone.cst`, `src/timing.sdc`, `README.md`; final ledger update.

**Interfaces:** `.gprj` top is `legato_top` and lists only this directory's five RTL files plus CST/SDC. Device and pin names match Global Constraints.

- [ ] **Step 1: Check RED project validation** — before creating manifest/constraints, read-only checks must report missing `.gprj`, local CST/SDC or bitstream; distinguish expected absence from malformed paths.
- [ ] **Step 2: Add project files** — local-only relative paths, 50 MHz SDC, exact existing pin map and LVCMOS bank types; `build.tcl` opens its sibling `.gprj` and runs all. README states Legato trigger, 300 ms timing, fallback rule, TTP226 3.3 V/DV unconnected, test/build/burn commands, and no physical-listening claim.
- [ ] **Step 3: Verify** — `./run_tests.ps1` all PASS; run `gw_sh.exe build.tcl` using the user's Gowin V1.9.12.03; inspect `.fs`, pin report, sys_clk Fmax >=50 MHz, Setup/Hold TNS 0, warnings; hash the `.fs`; assert all `.gprj` references exist inside new folder and the `.fs` modification time is not older than the newest RTL source. If build fails, diagnose before modifying RTL; repeat tests and build after fixes.
- [ ] **Step 4: Handoff** — record measured numbers and `.fs` SHA256 in README/ledger. Tell user project and bitstream paths, explain implementation and physical hearing remains untested. Do not alter or delete original projects.
