# SDD ledger — plan: E:\FPGA\work\competition_polyphonic_hdmi\docs\superpowers\plans\2026-10-21-vibrato-standalone.md

Pre-flight: Task 1 produces `vibrato_dds` for Task 2 `vibrato_top` — ports and 5 Hz / 1024 Q15 parameters match.
Ruling: No Git/worktree/task-start scripts — user explicitly requests ordinary `E:\FPGA\work` folders and has no Git repository — progress recorded here manually; cost if wrong: no commit-based recovery or automated task slicing.
Task 1: complete — `tb_vibrato_audio` RED (missing DDS) → GREEN, copied independent `tb_pitch_vibrato` also PASS; `vlog`/`vsim` 0 errors, 0 warnings.
Task 2: complete — `tb_vibrato_top` RED (missing top) → GREEN; `run_tests.ps1` 3/3 PASS; `gw_sh.exe build.tcl` exit 0; bitstream SHA256 `3AEBF7D715F0CACCB2C6DB9B13954D84996A61182AD90B3053590478AC7B3F9E`; Fmax 75.129 MHz vs 50 MHz; Setup/Hold TNS 0; checked pin report.
Final review: independent reviewer found inherited left-justified I2S timing and missing serial/note-map tests. Added tests (framing RED with old transmitter, then GREEN after fixing both copies), validated all 8 nominal note steps. Final `run_tests.ps1` 5/5 PASS; Gowin build exit 0; bitstream SHA256 `56171769AB08683E8794E87E4995DA693823DC42B1A56FD1A0AA9E8AB1577699`; Fmax 82.794 MHz vs 50 MHz; Setup/Hold TNS 0. Shared debounce counter is an inherited minor latency limitation.
