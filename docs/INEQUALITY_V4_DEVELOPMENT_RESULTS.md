# Inequality Sudoku results — ineq-v4

**Benchmark update:** all eight course rows are now measured. See [complete
benchmark results](BENCHMARK_RESULTS.md) and `benchmark-ineq-v4-complete.xlsx`.
Earlier development averages and partial workbooks below are historical.

v4 adds a registered DECIDE stage after local domain pruning. It reaches
**87.83 MHz standalone Fmax**, at the cost of one extra core cycle per propagation
round. On the 19 supplied solvable application cases, normalized mean time is
**3.9604 us**, 10.96% lower than v3 and 15.19% lower than hardware-validated v2.
This is an unweighted development comparison, not the full competition score.

v4 is the best measured candidate for the available short application tests.
v3 remains available because its mean solver-only time is better on the larger
regression corpora. Neither design is proven globally optimal.

## Measured milestones

| Version | Mean app cycles (19 cases) | Standalone Fmax | Mean cycles/Fmax | Standalone fitted LEs |
|---|---:|---:|---:|---:|
| ineq-v0 | 321.3158 | 51.77 MHz | 6.2066 us | 24,875 |
| ineq-v1 | 304.8947 | 45.55 MHz | 6.6936 us | 24,517 |
| ineq-v2 | 325.1053 | 69.62 MHz | 4.6697 us | 22,580 |
| ineq-v3 | 325.1053 | 73.09 MHz | 4.4480 us | 21,968 |
| ineq-v4 | 347.8421 | 87.83 MHz | 3.9604 us | 22,289 |

## Application reference counts

All 19 v4 simulations pass both supplied checkers. Physical execution of **v4
is pending**. v2's hardware results do not establish v4 hardware execution.

| Board | v3 app cycles | v4 app cycles | v4 normalized time |
|---|---:|---:|---:|
| `20blanks` | 267 | 291 | 3.3132 us |
| `51blanks` | 291 | 291 | 3.3132 us |
| `easy1` | 267 | 291 | 3.3132 us |
| `hard1` | 579 | 675 | 7.6853 us |
| `ineq/dev/p5_presolved` | 267 | 267 | 3.0400 us |
| `ineq/set0/ascend` | 267 | 267 | 3.0400 us |
| `ineq/set0/plain` | 483 | 555 | 6.3190 us |
| `ineq/set0/single` | 291 | 315 | 3.5865 us |
| `ineq/set0/sparse1` | 267 | 291 | 3.3132 us |
| `ineq/set1/easy1` | 291 | 291 | 3.3132 us |
| `ineq/set1/easy2` | 291 | 315 | 3.5865 us |
| `ineq/set1/hard1` | 315 | 315 | 3.5865 us |
| `ineq/set1/hard2` | 339 | 363 | 4.1330 us |
| `ineq/set1/hard3` | 339 | 363 | 4.1330 us |
| `ineq/set1/hard4` | 291 | 315 | 3.5865 us |
| `ineq/set1/medium1` | 291 | 291 | 3.3132 us |
| `ineq/set1/medium2` | 315 | 339 | 3.8597 us |
| `ineq/set1/medium3` | 315 | 315 | 3.5865 us |
| `ineq/set1/sparse_ineq` | 411 | 459 | 5.2260 us |

The two impossible cases, `ineq/dev/p6_contradiction` and
`ineq/dev/p7_impossible`, both report `App reported non-solved.` at 267 cycles.
They are excluded from the performance mean.

## Correctness and broader performance

All **4,347 direct RTL executions** pass: 21 official, 3,700 classic,
300 generated inequality, 285 difficult inequality, 35 rejection, and six
contract cases. These comprise **4,306 solved and 41 expected rejections**;
executions need not be distinct puzzles. Outcomes match v3. Solved grids,
propagation rounds, guesses, and rollback counts match, and each solved record
adds exactly one core cycle per propagation round. Rejection logs record the
outcome and cycles, not full search counters.

Mean solver-only time on the 3,700-case classic corpus rises from 6.6815 us
(v3) to 7.4885 us (v4), about 12.08% worse. The other larger corpora show the
same direction. These core measurements exclude application overhead and
must not be substituted for a complete application benchmark. Read the
[experiment walkthrough](PROPAGATION_PIPELINE_EXPERIMENT.md) for the intuition,
actual RTL, correctness invariant, and break-even calculation.

## Completed physical build

| Measurement | v4 result |
|---|---:|
| Configured physical clock | 50 MHz |
| Full-system Fmax | 56.58 MHz |
| Full-system fitted LEs | 34,627 / 49,760 (70%) |
| Registers | 4,705 |
| M9Ks | 173 / 182 (95%) |
| Memory bits | 1,387,872 / 1,677,312 (83%) |
| Worst setup slack | +2.326 ns |
| Worst hold slack | +0.102 ns |
| Worst recovery slack | +12.754 ns |
| Worst removal slack | +0.536 ns |
| Worst minimum pulse width slack | +9.329 ns |
| Fitter elapsed time | 28 min 38 s |

The fitter retried after congestion, then completed successfully. Synthesis,
fitting, timing analysis, assembly, and SVF conversion pass. All reported timing
categories pass under the unmodified course constraints. Those constraints leave
12 external input ports and 59 output ports without external delay constraints;
there are zero unconstrained clocks. Raw reports are in `logs/ineq-v4/fpga/`.
Programming-file generation finished on 9 September 2026 at 08:03:14 UTC.

**Physical mean latency at 50 MHz is 6.9568 us**, compared with 6.5021 us for
v3 and v2. The improvement is in the course-normalized metric using standalone
Fmax. Neither 87.83 MHz standalone Fmax nor 56.58 MHz full-system headroom is
this image's programmed clock. Hardware execution still needs the user's test.

## Official benchmark status

The available inequality benchmark rows are single, ascend, plain, and
sparse_ineq. They total **1,596 cycles / 87.83 MHz = 18.1715 us**, 8.53% lower
than v3's 19.8659 us subtotal. Four named unseen files remain unavailable:
`std/hard5`, `std/hard8`, `ineq/set2/superhardA`, and `ineq/set2/xsparse2`.
The subtotal is not a final score. See [benchmark status](BENCHMARK_STATUS.md)
and `benchmark-ineq-v4-partial.xlsx`, which leaves the missing cells blank.

## Reproducible evidence

`logs/ineq-v4/build_source.json` records the build commit, all nine source
fingerprints, timing, resources, configured clock, and programming hashes.
`BUILD_AUDIT.txt` verifies the actual source identities and successful build
stages. `comparison.json` records the checked regression comparison.
`app/` and `app-rejects/` contain the course application logs and source hashes.
`logs/inequality_measurements.json` is generated by `bench/ineq/report.py`.
[The v3 results](INEQUALITY_V3_RESULTS.md) and its separate release are preserved.
