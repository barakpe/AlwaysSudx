# Complete inequality benchmark results

These are the **eight inequality rows in the course spreadsheet**, using puzzle
files from course commit `f430fcffd5321bfe35a32c2cf1f997356e8285b1`. The repeated `plain`
in the user message is interpreted as the spreadsheet's `ineq/set1/sparse_ineq`
row. No other development cases contribute to these totals.

| Board | v3 application cycles | v4 application cycles | Basic / inequality checkers |
|---|---:|---:|---|
| `std/hard5` | 315 | 339 | PASS / PASS |
| `std/hard8` | 315 | 339 | PASS / PASS |
| `ineq/set0/single` | 291 | 315 | PASS / PASS |
| `ineq/set0/ascend` | 267 | 267 | PASS / PASS |
| `ineq/set0/plain` | 483 | 555 | PASS / PASS |
| `ineq/set1/sparse_ineq` | 411 | 459 | PASS / PASS |
| `ineq/set2/superhardA` | 315 | 339 | PASS / PASS |
| `ineq/set2/xsparse2` | 435 | 507 | PASS / PASS |

| Version | Total cycles | Standalone Fmax | Total cycles/Fmax |
|---|---:|---:|---:|
| ineq-v3 | 2832 | 73.09 MHz | 38.7468 us |
| ineq-v4 | 3120 | 87.83 MHz | 35.5232 us |

**ineq-v4 has the lower normalized total on this complete eight-board benchmark.**
v4 reduces normalized total time by 8.32% versus v3.

Both bitstreams are configured for 50 MHz. Their physical total times are
56.6400 us (v3) and 62.4000 us (v4); those physical times are separate
from the course score. These new results are from simulation; hardware testing
of v3/v4 remains pending. The previous v2 hardware record is unchanged.

## Spreadsheet and evidence

`benchmark-ineq-v3-complete.xlsx` and `benchmark-ineq-v4-complete.xlsx` fill
only the inequality column. The unrelated project results are blank. All eight
inequality checker flags are Y. Formula totals and cached values agree.

`logs/benchmark_measurements.json` records counts, input hashes, source build
commits, SOF hashes, and the calculation. Each version's `benchmark-app` logs
come from the official course application and include both checker messages;
`benchmark-rtl` contains an independent solution/givens/inequality check.
All eight RTL results match in grids and search decisions between versions.

The source RTL, C application, shared C library, and bitstreams are unchanged
by this benchmark update. Only new puzzle inputs, measured logs, and reporting
are added. The original release assets retain their original checksums. The
benchmark supplement contains the exact eight puzzle files under
`sw/apps/sud_shared/` for installation alongside the original source ZIP.

## Hardware commands

```bash
set_k5_terminal
launch_k5_app ineqsudx_scan -asl sud_shared -gpv std/hard5
launch_k5_app ineqsudx_scan -asl sud_shared -gpv std/hard8
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/set0/single
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/set0/ascend
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/set0/plain
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/set1/sparse_ineq
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/set2/superhardA
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/set2/xsparse2
```

Use the reference counts in the table for the selected release. Save both
checker outputs on every row. See the release handoff for programming and
source provenance checks.
