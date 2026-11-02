# SDD ledger — plan: E:\FPGA\work\competition_polyphonic_hdmi\docs\superpowers\plans\2026-10-21-glide-standalone.md

Pre-flight: Task 1 produces `offset_q15` for Task 2 `glide_dds` — names and signed Q15 width match.
Pre-flight: Task 2 produces `glide_top` for Task 3 `.gprj`/CST — ports match the spec's 8 inputs and 4 audio outputs.
Ruling: No Git/worktree/task-start scripts — user explicitly requests ordinary `E:\FPGA\work` folders and has no Git repository — progress recorded here manually; cost if wrong: no commit-based recovery or automated task slicing.
Task 1: complete — `tb_glide_voice_pitch` RED (missing module) → GREEN; `vlog`/`vsim` 0 errors, 0 warnings.
Task 2: complete — `tb_glide_audio` RED (missing DDS/top) → GREEN; `run_tests.ps1` reports 2/2 PASS, compile and simulations 0 errors, 0 warnings.
Task 3: complete — `run_tests.ps1` 2/2 PASS; `gw_sh.exe build.tcl` exit 0; bitstream SHA256 `56EC65E4040F72554DFFFF7E1EB468BDE9D9F7ADDEEAF54075E671A6D783C2E5`; Fmax 94.122 MHz vs 50 MHz; Setup/Hold TNS 0; checked pin report.
Final review: independent reviewer found inherited left-justified I2S timing and missing serial/note-map tests. Added tests (framing RED with old transmitter, then GREEN after fixing both copies), validated all 8 nominal note steps. Final `run_tests.ps1` 4/4 PASS; Gowin build exit 0; bitstream SHA256 `9DE5F50F3CE9CB5820F2D831109728F80F130AA4F94673C98D0214B729AC0ADE`; Fmax 114.335 MHz vs 50 MHz; Setup/Hold TNS 0. Shared debounce counter is an inherited minor latency limitation.
