# Inequality Sudoku hardware handoff

Hardware execution of this variant is pending. Use a release only after its
notes explicitly report a completed build with passing full-system timing.
The previously validated classic v5 bitstream is a separate accelerator.

## Install the variant

Use the release's ZIP to retain the source file line endings. Its bitstream,
source fingerprints, and application must come from the same release.

The course requires updating the laptop environment:

```bash
cd "$K5X_WIN/k5_xbox_fpga_win"
git pull
```

Install the release's `sw/apps/ineqsudx_scan` directory as a new application.
It contains exactly three application sources: the C file, its header, and
`ineqsudx_scan_enums.svh`. Preserve LF line endings. Install the provided updated
`sw/apps/sud_shared` library and puzzle files, keeping a backup of the laptop's
previous shared directory first. The new shared library is required to check
inequalities; a classic-only checker is insufficient.

Install `k5_xbox_ineqsudx_scan.sof` in the laptop's FPGA programming-files folder.
The release also provides its SVF. Use the course's normal programming flow for
the DE10-Lite and confirm the selected image has `ineqsudx_scan` in its name.

Before programming, verify SHA256SUMS. The release manifest identifies the build
commit and source SHA-256 fingerprints, including the generated enum contract.
When checking a Windows Git clone, hash canonical Git blobs rather than CRLF
working files, or use the LF files from the release ZIP.

## Run the official application

```bash
set_k5_terminal
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/set0/single
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/set1/sparse_ineq
launch_k5_app ineqsudx_scan -asl sud_shared -gpv hard1
```

Each board runs as a separate invocation. There must be two passing results:

```text
Solved board PASSED basic Sudoku checker
Solved board PASSED inequalities checker
```

Record the reported `Sudoku solve` cycles. Exact expected counts are listed by
board name in the release results table and in `logs/<version>/app/*.app.log`.
Avoid copying an unlabeled sequence of counts; names prevent ordering errors.

The optional seven-segment cycle display follows the course command:

```bash
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/set0/single -ccd1 DISP7S
```

The two impossible development boards should report non-solved, not PASS:

```bash
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/dev/p6_contradiction
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/dev/p7_impossible
```

Test all `set0` and `set1` boards and the four original classic boards. A valid
grid may differ from another solver's grid when the puzzle has multiple
solutions. Preserve the application logs as the hardware validation record.

## Interpreting speed

The physical board uses the course's default 50 MHz clock. Competition score
uses application cycles divided by the standalone `qsyn_xlr` Fmax. These are
different measurements: a standalone Fmax above 50 MHz does not mean this SOF
runs the board above 50 MHz.
