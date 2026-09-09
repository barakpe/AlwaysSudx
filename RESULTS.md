# AlwaysSudx results — final v7

**Bitstream built. Full system meets its clock. Hardware execution of v7 has not
yet been performed.** All production changes are Verilog; the course C
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
| v5 | Add batched hidden singles | 217 | 483 | 58.10 | 17,389 / 17,219 | 8.31 |
| v6 | Contradiction reduction off write enables | 217 | 483 | 72.30 | 17,372 / 17,142 | 6.68 |
| **v7** | **MRV row stage folded into APPLY** | **202** | **483** | **72.05** | **17,375 / 17,148** | **6.70** |

v7 improves the MRV baseline score **37.47x** and v5 **1.24x**. The v6 and v7
scores are equal within fitter noise on hard1 only, because hard1's reported
application count is polling-limited; see the caveat below. Across the 3,191
published holdouts, v7 is **4.9% faster than v6** in core time.

The v6 row was measured with `bench/synth_snapshot.sh` on the same solver source
that was later committed, differing only in comments, which the parser discards;
the v7 row is the committed tree's own `bench/synth.sh` run.
Intermediate v3/v4 experiments measured area and correctness without repeating
full timing runs; their frequencies and scores are deliberately not inferred.
The isolated v4 representation experiment, using the original course wrapper,
reduced mapped LEs from 23,949 to **21,322** with identical top95 cycles and
grids. Raw evidence: `logs/compact-draft/`. The v4 commit combines it with v3.

## What v6 and v7 changed

**v6.** All twenty worst paths in the v5 report ran from a candidate register,
through the hidden-single union tree and the per-cell forced terms, into an
81-input OR of `dead_cell` and a 27-input OR of `no_home`, and from there into
the write enable of every cell register. Of that 16.85 ns data path, 5.77 ns was
the reduction and a further 4.17 ns was the resulting ~1300-bit enable fanout.

That reduction only has to choose the next state. Applying forced digits during
a contradicted round cannot corrupt anything: `forced[c]` is nonzero only for
empty cells, so no given or parent assignment is overwritten; each such write
carries the current decision depth; and a contradiction always routes to
`BACK_APPLY`, which clears exactly that depth before the board is read again.
Cycles and grids are therefore byte-identical to v5, which the regression below
confirms on all 3,739 runs.

**v7.** The row stage of the MRV tournament no longer has a cycle to itself. The
candidates it reads are written by SCAN and untouched until the guess is placed,
so it is registered during APPLY and a round that ends in propagation discards
the result. A guess costs two cycles instead of three. The tournament's
combinational path is unchanged, so the cycle is bought without moving the
critical path.

Two variants were measured and rejected. Source, reports and reasoning are in
`logs/experiments/`: registering per-cell candidate counts during SCAN reaches
the same cycle count but costs 323 registers and 1.2 MHz; replacing the
`first_digit` popcount tests with `v & (v-1)` is the same function but fits at
63.10 MHz and 19,164 LEs.

## Final K5 application checks

| Board | Direct solver cycles | Reported application cycles | Application score at 72.05 MHz |
|---|---:|---:|---:|
| easy1 | 6 | 267 | 3.71 us |
| 20blanks | 6 | 267 | 3.71 us |
| 51blanks | 14 | 291 | 4.04 us |
| hard1 | 202 | 483 | 6.70 us |

All four course application final checkers PASS. Logs: `logs/v7/*.app.log` and
`*.sim.log`.

**The reported application count is quantised.** The application polls
`HOST_REG(XLR_DONE_RI)` in a busy loop, so a saving smaller than one poll
interval does not appear. v7 cuts hard1's solver time from 217 to 202 cycles and
the reported count stays at 483. The saving is real and shows up on boards whose
solve time exceeds that granularity, which the published-holdout means below
demonstrate. Direct solver cycles are a different measurement window and must
not be substituted for the reported app score.

## Unseen hackathon benchmark boards

The nine `sudoku_input_std` boards published in the DDP26 hackathon repository
(commit `f430fcf`, "added more test cases") were copied unchanged into
`sw/apps/sud_shared/sudoku_input_std/`. There is no `hard4`.

| Board | Direct solver cycles | Reported application cycles | Score at 72.05 MHz |
|---|---:|---:|---:|
| std/hard1 … std/hard10 (all nine) | 34 | 315 | **4.37 us** |

All nine pass the course final checker. Logs: `logs/v7/unseen_app/`, and direct
RTL cycles and grids in `logs/v7/unseen/`.

Every one of these boards has exactly **17 givens**, the theoretical minimum, but
they are easy for a batching engine: **the solver never guesses on any of them.**
Fifteen rounds of batched naked and hidden singles fill the grid and a sixteenth
round detects completion, so the cost is 2 + 2x16 = 34 cycles, identical on all
nine. They are nine genuinely distinct puzzles with distinct clue patterns and
distinct solutions, so the identical cost reflects a shared construction depth,
not duplicate inputs.

Because nothing is guessed, v7's saving of one cycle per guess does not apply:
v5 produces byte-identical cycles and grids on this set, which is itself a useful
independent confirmation that no search occurs. The gain over v5 here is entirely
the v6 frequency improvement, 315 / 58.10 = 5.42 us against 315 / 72.05 = 4.37 us.

This result was checked three ways before being reported: the RTL testbench's own
givens/row/column/box checker, an independent Python validator over the recorded
grids, and an independent Python singles-only propagator that reproduces the
fifteen-round count exactly.

## Comparison with the user's opus branch

Reference: AlwaysSud `explore/opus5-phases`, commit `5a227db`, `s2fastmrv`,
MODE=2. Its source is preserved under `bench/opus/` and was rerun with the exact
same RTL checker, falling-edge stimulus and cycle-count convention.
Every result below passed givens, digit range, row, column and box checks.

| Set | Runs | Opus mean | v5 mean | v7 mean | Opus worst | v5 worst | v7 worst |
|---|---:|---:|---:|---:|---:|---:|---:|
| top95 | 95 | 792.01 | 628.51 | 594.95 | 4,329 | 3,895 | 3,670 |
| Generated classic | 400 | 89.32 | 50.61 | 49.02 | 663 | 373 | 354 |
| Difficult heldout | 11 | 209.82 | 112.18 | 106.73 | 473 | 242 | 230 |
| Published holdout | 3,191 | 561.81 | 387.55 | 367.29 | 17,116 | 15,786 | 14,936 |

Using each accelerator's measured standalone Fmax (opus **26.36 MHz**, v7
**72.05 MHz**), the published-set mean core time is **21.31 us → 5.10 us**, a
**4.18x improvement**, up from 3.20x at v5. Its worst core time improves
**649.32 us → 207.30 us**, a **3.13x improvement**. For hard1 the core
comparison is **7.32 us → 2.80 us**, about **2.61x**.

These are **core-time comparisons**, not directly comparable whole-application
scores: the opus C driver has different split timing windows. Opus frequency
comes from its checked-in standalone report; its RTL cycles were remeasured here.
No new physical-board performance claim is made.

## Correctness coverage

The exact final source passes **3,704 solvable-board executions**: the 513-board
`standard` set (four course boards, top95, 400 generated, 11 difficult holdouts
and three corner cases) plus 3,191 published holdouts. Sets can overlap; this is
not a count of unique puzzles. It also correctly rejects **35 invalid or
unsatisfiable inputs**, including nonconflicting givens requiring failed-search
rollback. The 32 added contradictory puzzles were independently proven
unsatisfiable by Python MRV search before RTL checking. Corners include an
already solved board, an empty board and one blank.

v6 is byte-identical to v5 on all 3,739 runs, cycles and grids. v7 produces
identical grids on all 3,739 runs, with cycles reduced by exactly one per guess.
All final per-board cycles and grids are in `logs/v7/`.

## FPGA implementation

| Measurement | v5 | Final v7 |
|---|---:|---:|
| Accelerator fitted LEs | 17,219 | 17,148 / 49,760 |
| Accelerator registers / RAM bits | 2,999 / 1,215 | 2,998 / 1,215 |
| Standalone Fmax used for scoring | 58.10 MHz | **72.05 MHz** |
| Full-system fitted LEs | 28,186 | 28,115 / 49,760 |
| Full-system registers | 4,572 | 4,571 |
| Full-system RAM | 1,328,823 bits (79%) | 1,328,823 bits (79%) |
| Full-system Fmax | 52.11 MHz | **56.06 MHz** |
| Configured hardware clock | 50 MHz, course default | 50 MHz, course default |
| Worst reported setup slack | +0.809 ns | **+2.162 ns** |
| Worst reported hold slack across corners | +0.141 ns | +0.133 ns |
| Bitstreams | `.sof` and `.svf` | `.sof` and `.svf` |

All reported full-system timing-summary slacks are positive, and the fitter and
timing analyzer both report zero errors and zero non-justified warnings. The
whole v7 build took about **10 minutes**, with a 5m40s fit; v5's fit alone took
about 27 minutes and logged congestion retries. Removing the wide contradiction
fanout evidently made the design substantially easier to route as well as
faster. Routing time can still vary between runs.

At 50 MHz the system now has 2.162 ns of setup slack, so a faster configured
clock is plausible; `comp_fpga sudx_scan -mhz 55` is the obvious next
experiment. The shipped bitstream is built for the 50 MHz course default, and no
clock above that has been built or verified here.

Programming files are in `hw/gen_fpga/prog_files/`.
`logs/v7/build_source.json` records SHA-256 hashes of all RTL/file-list inputs
and both programming artifacts. Raw standalone and system reports are archived
in `logs/v7/synthesis/` and `logs/v7/fpga/`.

## Tool-flow limitations and warning review

The installed course `qsyn_xlr` references missing `$QSYN/basic.sdc`; Quartus
derives a clock to report Fmax. The saved opus reports have the same issue. No
course constraints or scripts were altered. Full-system timing independently
passes the actual constraints of the clock it is configured for.

Course dummy-wrapper dangling/read-pulse inputs, constant pins and unused signals
remain visible in standalone reports. The course wrapper truncates its board
address to the 16-bit XMEM interface and burst sizes to six bits (bursts <=32).
The stack infers mixed-port RAM: read and write occur in mutually exclusive states
on the same clock, so the reported undefined read-during-write case is unreachable.
No inferred latch is reported. Remaining tool warnings are preserved in raw logs;
this report does not claim a warning-free build.
