# ineq-v2 physical hardware validation

The user supplied a complete laptop-agent hardware validation report: all 21
runs pass their expected outcomes on the DE10-Lite at 50 MHz. This document
records that report; raw hardware log files were not attached to this session.

```text
Build commit: c91d5985ea680edba047db4333e969ba43738f01
SOF SHA-256: 79b39f50f2c760e94aaf8bedc81ee28e2e3cd6a727d711dced1c6cde31178b3e
Board: DE10-Lite 10M50DA
Programmer: USB-Blaster [USB-1]
UART: COM3
Detected clock: 50 MHz
```

| Board | Hardware cycles | Basic checker | Inequality checker |
|---|---:|---|---|
| `20blanks` | 267 | PASSED | PASSED |
| `51blanks` | 291 | PASSED | PASSED |
| `easy1` | 267 | PASSED | PASSED |
| `hard1` | 579 | PASSED | PASSED |
| `ineq/dev/p5_presolved` | 267 | PASSED | PASSED |
| `ineq/set0/ascend` | 267 | PASSED | PASSED |
| `ineq/set0/plain` | 483 | PASSED | PASSED |
| `ineq/set0/single` | 291 | PASSED | PASSED |
| `ineq/set0/sparse1` | 267 | PASSED | PASSED |
| `ineq/set1/easy1` | 291 | PASSED | PASSED |
| `ineq/set1/easy2` | 291 | PASSED | PASSED |
| `ineq/set1/hard1` | 315 | PASSED | PASSED |
| `ineq/set1/hard2` | 339 | PASSED | PASSED |
| `ineq/set1/hard3` | 339 | PASSED | PASSED |
| `ineq/set1/hard4` | 291 | PASSED | PASSED |
| `ineq/set1/medium1` | 291 | PASSED | PASSED |
| `ineq/set1/medium2` | 315 | PASSED | PASSED |
| `ineq/set1/medium3` | 315 | PASSED | PASSED |
| `ineq/set1/sparse_ineq` | 411 | PASSED | PASSED |

Both `ineq/dev/p6_contradiction` and `ineq/dev/p7_impossible` report
`App reported non-solved.` at 267 cycles, with no false PASS. The report states
zero errors or warnings across all 21 hardware logs.

Every solvable-board count matches v2 simulation exactly. The mean is
325.1053 cycles: 4.6697 us normalized by the standalone 69.62 MHz report, or
6.5021 us at the actual 50 MHz board clock. The laptop report also confirms
the SOF hash and all nine source fingerprints, including installed files.

The original release assets and their checksums are preserved. Their manifests
recorded hardware testing as pending at build/release time. This subsequent
validation record supersedes that historical testing status; it does not
change the bitstream, build-source identity, or measured frequency.

The v0 and v1 inequality milestones have no programming release and were not
hardware-tested. v1's failed 50 MHz image remains excluded from programming
downloads. Only ineq-v2 has this physical validation.
