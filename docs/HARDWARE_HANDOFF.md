# Hardware handoff — v5

The full K5-XBOX build completed at the default **50 MHz** and passes reported
setup/hold checks. It has not yet run on the physical board.

## Files to download

- `hw/gen_fpga/prog_files/k5_xbox_sudx_scan.sof`
- `hw/gen_fpga/prog_files/k5_xbox_sudx_scan.svf` if your programmer needs SVF
- `sw/apps/sudx_scan/` and `sw/apps/sud_shared/` (the unchanged course app/library)
- `logs/v5/build_source.json` for source and artifact SHA-256 fingerprints

The convenience bundle `artifacts/AlwaysSudx-v5.zip` contains the programming
files, source, course application, documentation and fingerprints.

Put the programming file in your laptop's `$MY_K5_PROJ/fpga_prog_files/` and the two
application folders under `$MY_K5_PROJ/sw/apps/`, following the course guide.

```sh
set_k5_terminal
prog_fpga sudx_scan
launch_k5_app sudx_scan -asl sud_shared -gpv hard1
```

Repeat with `easy1`, `20blanks`, and `51blanks`. Require the final checker to PASS
and preserve the reported cycles and complete output. RTL application reference
counts are **267 / 267 / 291 / 483** in that board order. Hardware counts remain to
be measured; compare identical timing windows when evaluating the score.

The accelerator name intentionally remains `sudx_scan`; the repository is named
AlwaysSudx. The RTL compiled into these programming files is commit `f5a9e9a`.
The v5 tag adds final reports but contains the same hardware. Original AlwaysSud
and AlwaysSudAgent repositories were not modified.
