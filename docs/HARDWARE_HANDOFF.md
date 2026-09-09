# Hardware handoff — v7

The full K5-XBOX build completed and passes its reported setup/hold checks.
v7 has not yet run on the physical board. The accelerator now fits at
**72.05 MHz** standalone, up from 58.10 MHz at v5, so a clock above the course
default may also be worth trying; see "Trying a faster clock" below.

Read [the complete design explanation](DESIGN_WALKTHROUGH.md) for the
reasoning, code examples, and measured tradeoffs behind each version.

## Files to download

- `hw/gen_fpga/prog_files/k5_xbox_sudx_scan.sof`
- `hw/gen_fpga/prog_files/k5_xbox_sudx_scan.svf` if your programmer needs SVF
- `sw/apps/sudx_scan/` and `sw/apps/sud_shared/` (the unchanged course app/library)
- `logs/v7/build_source.json` for source and artifact SHA-256 fingerprints

The GitHub v7 release provides `AlwaysSudx-v7.zip`, the standalone `.sof` and
`.svf`, the design walkthrough, and SHA-256 checksums. The bundle contains the
tracked project files and programming artifacts. Intermediate releases preserve
source/measurement milestones; v5 and v7 have verified bitstreams from this work.

Put the programming file in your laptop's `$MY_K5_PROJ/fpga_prog_files/` and the two
application folders under `$MY_K5_PROJ/sw/apps/`, following the course guide.

```sh
set_k5_terminal
prog_fpga sudx_scan
launch_k5_app sudx_scan -asl sud_shared -gpv hard1
```

Repeat with `easy1`, `20blanks`, and `51blanks`. Require the final checker to PASS
and preserve the reported cycles and complete output. RTL application reference
counts are **267 / 267 / 291 / 483** in that board order, unchanged from v5:
v7's solver is faster on hard1 (202 cycles rather than 217) but the application
polls the done register, so a saving that small does not reach the reported
count. Hardware counts remain to be measured; compare identical timing windows
when evaluating the score.

## Trying a faster clock

v5's full system was limited by the accelerator, the only clock domain with
tight slack; every other domain had more than 16 ns to spare. v7's accelerator
fits 24% faster standalone, so the system may now close above 50 MHz:

```sh
cd "$MY_K5_PROJ/hw/gen_fpga"
comp_fpga sudx_scan -mhz 55
```

Only use a clock whose full-system timing report actually passes, and re-run all
four boards on it. The shipped `.sof` is built for the clock stated in the
release notes.

The accelerator name intentionally remains `sudx_scan`; the repository is named
AlwaysSudx. The RTL compiled into these programming files is commit `5d93fab`.
Original AlwaysSud and AlwaysSudAgent repositories were not modified.
