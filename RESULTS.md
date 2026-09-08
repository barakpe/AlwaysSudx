# AlwaysSudx results — final v5

**Bitstream built. Full system meets its default 50 MHz clock. Hardware execution
has not yet been performed.** All production changes are Verilog; the course C
application, register protocol and 32+32+17-byte transactions are preserved.

## Measured milestones

Application score is the unmodified course app's reported cycles divided by
standalone `qsyn_xlr` Fmax. Its window includes setup, load, solve and store.

| Tag | Change | hard1 core cycles | hard1 app cycles | Standalone MHz | Mapped / fitted LEs | App score, us |
|---|---|---:|---:|---:|---:|---:|
| v0 | Course MRV baseline | 981 | 1,251 | 4.98 | 13,026 / 12,200 | 251.20 |
| v1 | Balanced MRV tournament | 981 | 1,251 | 25.57 | 13,408 / 12,645 | 48.92 |
| v2 | Naked-single batches; depth rollback | 334 | 603 | 72.81 | 23,949 / 23,691 | 8.28 |
| v3 | Fixed-burst wrapper datapath | 334 | 603 | not measured | 17,199 / — | — |
| v4 | Explicit cell write sources | 334 | not measured | not measured | see isolated test below | — |
| **v5** | **Add batched hidden singles** | **217** | **483** | **58.10** | **17,389 / 17,219** | **8.31** |

v5 improves the MRV baseline score **30.22x**. v2 remains 0.4% better on hard1
alone, but has excessive area and much poorer difficult-board search. v5 is the
recommended balanced result across boards, resource use and hardware readiness.
Intermediate v3/v4 experiments measured area and correctness without repeating
full timing runs; their frequencies and scores are deliberately not inferred.

The isolated v4 representation experiment, using the original course wrapper,
reduced mapped LEs from 23,949 to **21,322** with identical top95 cycles and grids.
Raw evidence: `logs/compact-draft/`. The v4 commit combines this change with v3.

## Final K5 application checks

| Board | Direct solver cycles | Reported application cycles | Application score at 58.10 MHz |
|---|---:|---:|---:|
| easy1 | 6 | 267 | 4.60 us |
| 20blanks | 6 | 267 | 4.60 us |
| 51blanks | 14 | 291 | 5.01 us |
| hard1 | 217 | 483 | 8.31 us |

All four course application final checkers PASS. Logs: `logs/v5/*.app.log` and
`*.sim.log`. Polling quantizes app cycles; direct solver cycles are a different
measurement window and must not be substituted for the reported app score.

## Comparison with the user's opus branch

Reference: AlwaysSud `explore/opus5-phases`, commit `5a227db`, `s2fastmrv`, MODE=2.
Its source is preserved under `bench/opus/` and was rerun with the exact same RTL
checker, falling-edge stimulus and cycle-count convention as the new solver.
Every result below passed givens, digit range, row, column and box checks.

| Set | Runs | Opus mean core cycles | v5 mean core cycles | Opus worst | v5 worst |
|---|---:|---:|---:|---:|---:|
| top95 | 95 | 792.01 | 628.51 | 4,329 | 3,895 |
| Generated classic | 400 | 89.32 | 50.61 | 663 | 373 |
| Difficult heldout | 11 | 209.82 | 112.18 | 473 | 242 |
| Published holdout | 3,191 | 561.81 | 387.55 | 17,116 | 15,786 |

Using each accelerator's measured standalone Fmax (opus **26.36 MHz**, v5
**58.10 MHz**), the published-set mean core time is **21.31 us → 6.67 us**, a
**3.20x improvement**. Its worst core time improves **649.32 us → 271.70 us**.
For hard1 the core comparison is **7.32 us → 3.73 us**, about **1.96x**.

These are **core-time comparisons**, not directly comparable whole-application
scores: the opus C driver has different split timing windows. Opus frequency
comes from its checked-in standalone report; its RTL cycles were remeasured here.
No new physical-board performance claim is made.

## Correctness coverage

The exact final source passes **3,704 solvable-board executions**: four course
boards, top95, 400 generated, 11 difficult holdouts, three corner cases, and 3,191
published holdouts. Sets can overlap; this is not a count of unique puzzles.
It also correctly rejects **35 invalid or unsatisfiable inputs**, including
nonconflicting givens requiring failed-search rollback. The 32 added contradictory
puzzles were independently proven unsatisfiable by Python MRV search before RTL
checking. Corners include an already solved board, an empty board and one blank.
All final per-board cycles and grids are in `logs/v5/{standard,published,unsat}/`.

## FPGA implementation

| Measurement | Final result |
|---|---:|
| Accelerator fitted LEs | 17,219 / 49,760 |
| Accelerator registers / RAM bits | 2,999 / 1,215 |
| Standalone Fmax used for scoring | 58.10 MHz |
| Full-system mapped / fitted LEs | 28,516 / 28,186 |
| Full-system RAM | 1,328,823 bits (79%) |
| Full-system Fmax | 52.11 MHz |
| Configured hardware clock | 50 MHz, course default |
| Worst reported setup slack | +0.809 ns |
| Worst reported hold slack across corners | +0.141 ns |
| Bitstreams | `.sof` and `.svf` generated |

All reported full-system timing-summary slacks are positive. The full build took
about **37 minutes**, including a roughly 27-minute fit. This is a completed build,
not an estimate of feasibility. Standalone fitting took 18m20s and logged
congestion/retry warnings before successful completion; routing time can vary.

Programming files are in `hw/gen_fpga/prog_files/`. Build source is commit
**f5a9e9a**; the final tag also contains reports/documentation without changing RTL.
`logs/v5/build_source.json` records SHA-256 hashes of all RTL/file-list inputs and
both programming artifacts. Raw standalone and system reports are archived in
`logs/v5/synthesis/` and `logs/v5/fpga/`.

## Tool-flow limitations and warning review

The installed course `qsyn_xlr` references missing `$QSYN/basic.sdc`; Quartus derives
a clock to report Fmax. The saved opus reports have the same issue. No course
constraints or scripts were altered. **Full-system timing independently passes the
actual 50 MHz constraints**, as shown above.

Course dummy-wrapper dangling/read-pulse inputs, constant pins and unused signals
remain visible in standalone reports. The course wrapper truncates its board
address to the 16-bit XMEM interface and burst sizes to six bits (bursts <=32).
The stack infers mixed-port RAM: read and write occur in mutually exclusive states
on the same clock, so the reported undefined read-during-write case is unreachable.
No inferred latch is reported. Remaining tool warnings are preserved in raw logs;
this report does not claim a warning-free build.
