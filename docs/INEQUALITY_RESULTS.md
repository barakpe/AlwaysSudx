# Inequality Sudoku results — ineq-v2

The selected implementation improves the unweighted mean application
cycles/Fmax by **24.76%** over the first working inequality baseline. All 19
supplied solvable application cases pass both course checkers. These are
simulation measurements; physical execution of the variant is pending.

## Milestone comparison

| Version | Mean app cycles, 19 cases | Standalone Fmax | Mean cycles/Fmax | Standalone fitted LEs |
|---|---:|---:|---:|---:|
| ineq-v0 | 321.3158 | 51.77 MHz | 6.2066 us | 24,875 |
| ineq-v1 | 304.8947 | 45.55 MHz | 6.6936 us | 24,517 |
| ineq-v2 | 325.1053 | 69.62 MHz | 4.6697 us | 22,580 |

This average is a development comparison, **not the official weighted hackathon
score**. Board-specific assessment weights were not available when these
measurements were recorded. The same 19 cases and unchanged application timer
are used for all three versions.

```text
baseline: 321.3158 / 51.77 = 6.2066 us
v2:       325.1053 / 69.62 = 4.6697 us
reduction = 1 - 4.6697 / 6.2066 = 24.76%
```

v1 saves cycles but loses frequency enough to worsen this score. v2 adds a
pipeline stage, increasing some cycle counts while shortening the critical
path. This selection does not impose a 50 MHz minimum on standalone Fmax.

## Exact application results

Each row is one separate invocation. Cycles include the course's setup, data
transfer, solving, and return protocol; they are not the solver-only counts.
Both the basic Sudoku and inequality checkers pass every row in every version.

| Board argument | v0 cycles | v1 cycles | v2 cycles | v2 cycles/Fmax |
|---|---:|---:|---:|---:|
| `20blanks` | 267 | 267 | 267 | 3.8351 us |
| `51blanks` | 291 | 291 | 291 | 4.1798 us |
| `easy1` | 267 | 267 | 267 | 3.8351 us |
| `hard1` | 483 | 483 | 579 | 8.3166 us |
| `ineq/dev/p5_presolved` | 267 | 267 | 267 | 3.8351 us |
| `ineq/set0/ascend` | 267 | 267 | 267 | 3.8351 us |
| `ineq/set0/plain` | 411 | 411 | 483 | 6.9377 us |
| `ineq/set0/single` | 315 | 291 | 291 | 4.1798 us |
| `ineq/set0/sparse1` | 267 | 267 | 267 | 3.8351 us |
| `ineq/set1/easy1` | 291 | 267 | 291 | 4.1798 us |
| `ineq/set1/easy2` | 291 | 291 | 291 | 4.1798 us |
| `ineq/set1/hard1` | 315 | 291 | 315 | 4.5246 us |
| `ineq/set1/hard2` | 363 | 315 | 339 | 4.8693 us |
| `ineq/set1/hard3` | 363 | 315 | 339 | 4.8693 us |
| `ineq/set1/hard4` | 315 | 291 | 291 | 4.1798 us |
| `ineq/set1/medium1` | 291 | 267 | 291 | 4.1798 us |
| `ineq/set1/medium2` | 315 | 291 | 315 | 4.5246 us |
| `ineq/set1/medium3` | 315 | 291 | 315 | 4.5246 us |
| `ineq/set1/sparse_ineq` | 411 | 363 | 411 | 5.9035 us |

The two impossible development cases are excluded from the performance mean.
Both also pass separate full K5 application tests, each reporting
`App reported non-solved.` at 267 cycles. Their expected result is rejection,
not a solved grid. Logs are under `logs/ineq-v2/app-rejects/`.

## Additional correctness coverage

| Set | Executions | Purpose |
|---|---:|---|
| Official | 21 | 19 solutions and two intentional contradictions |
| Classic | 3,700 | Wider Sudoku search and rollback coverage |
| Generated | 300 | Varying givens, inequality density, and encoding |
| Held out inequalities | 285 | Difficult classic puzzles augmented with valid signs |
| Rejections | 35 | Invalid givens and known unsatisfiable puzzles |
| Contract edge cases | 6 | Cyclic/impossible signs, completed wrong grids, code 3, boundaries |
| **Total** | **4,347** | **4,306 solved; 41 expected rejections** |

These are executions, not necessarily unique puzzles. The independent RTL
checker verifies original givens, digits, all rows/columns/boxes, and every
inequality. The full K5 application suite separately checks the host protocol
and supplied C checker. The additional sets are correctness evidence, not a
claim that v2 is faster on every puzzle. In particular, mean classic core cycles
increase from 356.25 in v0 to 488.35 in v2. The hardware-validated classic v5
remains a separate submission candidate on `main`.

## Physical build

Standalone synthesis, fitting, and timing completed on the exact v2 RTL.
Full-system synthesis, fitting, routing, timing analysis, assembly, and SVF
conversion have completed. The image is configured for **50 MHz**, with
**51.88 MHz full-system Fmax** under the unchanged course constraints.

| Physical measurement | Result |
|---|---:|
| Fitted logic | 35,152 / 49,760 LEs (71%) |
| Registers | 4,276 |
| Embedded RAM blocks | 173 / 182 M9Ks (95%) |
| Memory bits | 1,387,872 / 1,677,312 (83%) |
| Worst setup slack | +0.725 ns |
| Worst hold slack | +0.147 ns |
| Worst recovery slack | +11.916 ns |
| Worst removal slack | +0.072 ns |
| Worst minimum-pulse-width slack | +9.326 ns |
| Fitter elapsed time | 31 min 13 s, including one congestion retry |

All reported timing categories pass. The supplied constraints leave 12 external
input ports and 59 output ports without external delay constraints (switches,
key, UART GPIO, LEDs, and displays); the report has zero unconstrained clocks.
This is signoff under the **course's constraint coverage**, not a claim that
every external interface has separately specified board timing. Shared timing
scripts and constraints were not modified.

The SOF and SVF are ready for the user's DE10-Lite test. Physical execution of
this variant is still pending. RTL/application simulation and successful
routing do not replace that final board confirmation.

The reported 4.6697 us is the **competition-normalized measurement**. At a
physical 50 MHz clock, the mean measured cycle count corresponds to 6.5021 us.
A 69.62 MHz standalone report does not make the board run at 69.62 MHz.

v1 generated a 50 MHz image but achieved only 40.98 MHz full-system Fmax and
failed that clock's timing. That image is retained locally as failed-build
evidence and is not a programming release. The course supports rebuilding at
a lower clock with `comp_fpga ineqsudx_scan -mhz 40`; this does not change v1's
inferior standalone-normalized result in the table above.

## Evidence and reproduction

- `logs/ineq-v*/app/*.app.log`: original application output.
- `logs/ineq-v*/{official,classic,generated,heldout,rejects,contract}/cycles.txt`:
  independent RTL outcomes and core cycles, where run for that milestone.
- `logs/ineq-v*/synthesis/`: raw standalone tool reports.
- `logs/ineq-v*/fpga/`: full-system reports, once each build completes.
- `logs/ineq-v2/build_source.json`: exact source identities for the image.
- `logs/inequality_measurements.json`: machine-readable measured comparison.

```bash
python3 bench/ineq/report.py
bash bench/ineq/all_apps.sh logs/local/app
bash bench/ineq/sim.sh ineq/dev/p6_contradiction logs/local/app-rejects unsolved
bash bench/ineq/sim.sh ineq/dev/p7_impossible logs/local/app-rejects unsolved
```

See [the design explanation](INEQUALITY_DESIGN.md) for the motivation and
intuition behind each change, [the experiment ledger](INEQUALITY_PROGRESS.md)
for rejected alternatives, and [the hardware handoff](INEQUALITY_HARDWARE_HANDOFF.md)
for installation and board testing.
