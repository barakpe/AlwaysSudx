# Measured results

No hardware execution has been performed for AlwaysSudx.

| Version | Architecture | Core cycles easy / 20 / 51 / hard1 | Standalone MHz | Mapped / fitted LEs | top95 mean / worst core cycles |
|---|---|---|---|---|---|
| v0 | Course MRV, serial minimum chain | 86 / 103 / 134 / 981 | 4.98 | 13,026 / 12,200 | 35,957.46 / 596,919 |
| v1 | Balanced MRV tournament | 86 / 103 / 134 / 981 | 25.57 | 13,408 / 12,645 | 35,957.46 / 596,919 |
| v2 | Naked-single batches, depth rollback | 8 / 8 / 24 / 334 | 72.81 | 23,949 / 23,691 | 18,852.95 / 350,711 |

Application cycle counts are stored in each version's `*.app.log`. These include
setup/load and the course polling granularity; they are not the direct core cycles
in the table. Compare like timing windows when using cycles / standalone MHz.

## v0 evidence and warnings

All 95 top95 boards and the four course boards pass the independent RTL checker.
Raw per-board cycles and complete solutions are in `logs/v0/{repo4,top95}/cycles.txt`.
Synthesis, fit, STA and critical paths are in `logs/v0/synthesis/`.

The course `qsyn_xlr` installation references missing `$QSYN/basic.sdc`. Quartus
therefore derives a clock and reports Fmax; **this does not demonstrate closure at
50 MHz**. The same warning is present in the saved opus synthesis reports. We keep
the course command and constraints unchanged for comparability. Full-system timing
must be evaluated with `comp_fpga` before selecting an operating clock.

Other baseline warnings: course wrapper truncates its 32-bit board address to the
16-bit XMEM address and burst sizes to six bits (all bursts are <=32). Dummy wrapper
read-pulse inputs are undriven, and unused/dangling ports and constant output bits
are reported. These belong to the supplied wrapper/harness. The retained course
MRV `busy` output is intentionally unconnected. No inferred latch is reported.

## Comparison target

AlwaysSud `explore/opus5-phases` (`5a227db`) promotes `s2fastmrv`: 26.36 MHz,
28,396 mapped / 27,714 fitted LEs. Its published direct-RTL counts are
6 / 23 / 54 / 193 using its original testbench edge convention. We will re-run
that solver with this repository's checker before claiming a performance win.

Baseline K5 application: all four final checkers PASS. Whole-window cycles
(easy1 / 20blanks / 51blanks / hard1): **363 / 363 / 411 / 1,251**.
The hard1 assignment score is **251.20 us** (1,251 / 4.98).

## v1: balanced tournament

Seven comparison levels replace the serial 81-cell chain. Raster tie-breaking
and all 95 cycle counts/solutions are unchanged. Standalone frequency rises
from 4.98 to 25.57 MHz (**5.13x**). The K5 hard1 window remains 1,251 cycles,
so its score falls from 251.20 to **48.92 us**. Quartus required explicit
generate blocks and separately declared genvars; the failed syntax logs are
retained. Course harness/constraint warnings remain as described above.

## Algorithm-only batch experiments (frequency pending)

The batch design passes the same 510 puzzles. Adding hidden singles changes only
its `HIDDEN_SINGLES` parameter; it reduces search work considerably:

| Core cycles | Naked batch | Hidden batch | Opus, identical checker |
|---|---:|---:|---:|
| hard1 | 334 | 217 | 193 |
| top95 mean | 18,852.95 | 628.51 | 792.01 |
| top95 worst | 350,711 | 3,895 | 4,329 |
| Generated 400 mean | 454.74 | 50.61 | 89.32 |
| Held-out 11 mean | 552.27 | 112.18 | 209.82 |
| Published holdout 3,191 mean | not run | 387.55 | 561.81 |
| Published holdout 3,191 p95 | not run | 1,210 | 1,672 |
| Published holdout 3,191 worst | not run | 15,786 | 17,116 |

All these are RTL measurements, not software algorithm predictions. Sets may
overlap, so 510 + 3,191 is a count of test executions, not distinct puzzles.
The published holdout comes from the pre-existing AlwaysSud set; it was not
regenerated to favor this implementation. The hidden draft also passes solved,
empty, single-blank boards and 35 invalid/unsatisfiable inputs. Thirty-two added
UNSAT inputs have nonconflicting givens and were independently checked by a
Python MRV backtracking solver before RTL testing.

The initial naked batch maps to 23,949 LEs and 1,215 RAM bits. This motivates an
isolated representation change: fixed-index cell registers with explicit
mutually exclusive write sources, replacing the inferred large cell-write muxes.

## v2: batch architecture

K5 hard1 passes at **603 application cycles / 72.81 MHz = 8.28 us**, a 5.91x
improvement over v1. Standalone fitting completes in 9m49s. Area is above the
course's approximately 20K accelerator guidance, so this is an experimental
milestone, not the recommended hardware version. The hierarchy report attributes
7,108 combinational functions to the supplied wrapper alone, chiefly general
variable-index loading and storing despite the fixed three-burst protocol.

The resetless decision stack infers 1,215 useful RAM bits. Its mixed-port RAM
warning is reviewed: read and write happen in different FSM states, with the
same clock, so no read-during-write collision is reachable.

## v3: fixed-burst wrapper

The unchanged three-transaction protocol now uses fixed 0/32/64 slices. Synthesis
maps to **17,027 LEs**, down from 23,949. K5 hard1 still passes at **603 cycles**.
This milestone is area-checked only; no standalone Fmax is claimed for v3.

## v4: explicit cell write sources

The separately tested cell-register rewrite preserves all 95 naked-batch cycle
counts and solutions. With the original wrapper it maps to **21,322 LEs**, versus
23,949 before the rewrite. It is now combined with v3's fixed-burst wrapper.
Final frequency and bitstream validation are performed on the next milestone.
