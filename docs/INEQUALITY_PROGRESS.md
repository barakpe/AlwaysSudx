# Inequality variant development

Branch `hackathon/ineq`, separate worktree `AlwaysSudxIneq`, application and
accelerator `ineqsudx_scan`. Standard v5 remains on `main` unchanged.
Course reference: DDP26-summer/hackathon commit a9573fc7c554776876bfd1677d1d285be646b321.

## ineq-v0 baseline

Start from v5's batched singles, balanced MRV, and depth-based rollback.
Preserve each input byte's upper nibble in the wrapper and on output.
Add a clocked loop that filters all 144 possible neighboring inequalities.
For A<B, retain A candidates below max(B) and B candidates above min(A).
Continue until stable, then apply Sudoku singles or branch. Rebuild candidate
sets after every placement and rollback, so failed-branch cuts cannot persist.
No-inequality boards bypass the new loop. Codes 0 and 3 mean no edge; boundary
fields are ignored. All solving stays in RTL.

The only C behavior change is the course-required `verify(board)` call, using
the supplied, unmodified updated shared library. The timer is unchanged.

## Course issues noticed

* README's 0x50 example misstates the vertical direction and binary expansion.
  Actual 0x50 encodes right < and below <. Right < and below > is 0x60.
* `verify_inequalities()` prints `FAIL vert ineq` for horizontal failures too.
  The actual indexing/comparison is correct; only its diagnostic is mislabeled.
* The input and solved example diagrams reverse some vertical signs, including
  the border between 3 and 7. Follow the byte encoding and supplied checker.
* `dev/p6_contradiction` and `dev/p7_impossible` are intentionally unsatisfiable,
  despite the README's general solvability guarantee. Tests expect rejection.

Baseline validation: all 21 official RTL cases (19 solved, 2 rejected), 300
generated cases, and 3,700 classic cases pass. The complete K5 application
passes both checkers on `ineq/set0/sparse1` at 267 reported cycles. Standalone
synthesis subsequently completed at 51.77 MHz; all 19 solvable application
cases pass both course checkers. No full-system v0 image was requested.

## Measurements

Results will be recorded per immutable tag. Core cycles are diagnostic only;
competition score uses the course application's cycles / standalone Fmax.
Timing, area, routing, and correctness decide which experiment is retained.

## Architectural experiments

The persistent-value architecture passes all official cases and reduces some
inequality rounds, but maps to 25,552 LEs and uses a 729-bit-wide snapshot RAM.
The domain-only redesign passes 4,341 RTL executions (21 official, 3,700 classic,
300 generated, 285 difficult inequality, 35 known unsatisfiable). It reduces
mean core cycles on the 19 solvable official boards from 54.00 to 33.37, and on
285 difficult inequality holdouts from 91.89 to 45.08. Its initial wide-memory
mapping uses 26,455 LEs. These are cycle/area measurements, not timed score wins.

Descending digit order and inequality-degree MRV ties were tested on all 21
boards. Both hurt the overall supplied set, so the simple ascending/raster
policy remains. Population-count sharing was simulated with identical official
results, but its initial synthesis was stopped with the other wide-RAM designs.

The physical memory constraint matters: classic full-system reports show
166/182 M9Ks already allocated despite only 79% of raw memory bits being used.
A 729-bit-wide simple dual-port snapshot costs at least 21 more blocks. Wide
snapshot experiments were stopped before timing signoff; their partial build
logs do not establish a usable bitstream or Fmax.

The revised snapshot is 243 bits wide and 243 words deep. Three beats save the
same 59,049 meaningful bits, occupying seven M9Ks in the fitted domain engine. Writes overlap the
two MRV selection cycles and the guess cycle. Restoring a nonempty alternative
costs two extra cycles; exhausted frames skip unnecessary reads. Decision-stack
writes now use an explicit if/else-if to infer a single RAM write port.

A separate build worktree preserves v0's source during physical experiments. All source snapshots remain immutable during their builds.

## Completed synthesis comparison and selected v2

| Version | Standalone Fmax | Fitted LEs | Full-system status |
|---|---:|---:|---|
| ineq-v0: value-based baseline | 51.77 MHz | 24,875 | No full build requested for this baseline |
| ineq-v1: packed domain engine | 45.55 MHz | 24,517 | Bitstream generated; 40.98 MHz, does not meet its configured 50 MHz timing |
| ineq-v2: pipelined domain engine | 69.62 MHz | 22,580 | 50 MHz timing passes; 51.88 MHz full-system Fmax |

v1 is preserved as an instructive failed physical-design direction. Its SOF/SVF
are archived locally under artifacts/ineq-v1-timing-failed, not recommended for
programming. Its raw full-system timing reports are checked in.

v2 splits each logical propagation round into SCAN (register unit reductions)
and DOMAIN (apply local cuts and decide progress). Its 4,341 main regression
executions pass, plus six targeted edge cases: 4,347 total executions, consisting
of 4,306 solved cases and 41 expected rejections. All 19 solvable official application cases pass both checkers on this exact
production source. Mean cycles/Fmax is 4.6697 us, 24.76% lower than v0. Hardware execution is pending.
The solver still starts on the SOLVE command; computation and the official
measurement window retain their original relationship.

User clarification: frequencies below 50 MHz are welcome if cycles/Fmax improves.
The installed course utility supports `comp_fpga ineqsudx_scan -mhz <integer>`;
no shared-source edits are necessary. A negative timing slack only disqualifies
that image at its configured clock, not the underlying solver architecture.
v1's 19-case unweighted mean score is 6.6936 us versus v0's 6.2066 us, so reducing
its configured clock would not reverse this standalone-score comparison.

## Completed v2 programming build

The default 50 MHz full-system build completed on 8 September at 18:50 UTC.
It fits in 35,152 LEs and 173/182 M9Ks. The fitter retried once after regional
congestion and finished in 31 minutes 13 seconds. Full-system Fmax is 51.88 MHz;
setup slack is +0.725 ns and every reported timing category is nonnegative.
The supplied external-port timing coverage is documented in the results file.
SOF/SVF hashes and all source fingerprints are in `logs/ineq-v2/build_source.json`.
The course TGZ's archived RTL matches the tagged build source byte for byte.

The standalone course tool retains its `src_ref` source snapshots inside the
TGZ and removes the temporary source directory afterward. For the final audit,
those exact three files were recovered from the TGZ into the tracked standalone
report directory and checked against the build commit; they were not recreated
from the current working tree.

All 19 solvable K5 application tests pass both checkers. The two impossible
application tests correctly report non-solved, both at 267 cycles. Physical
execution of the inequality image is pending the user's laptop/board test.
