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
* `dev/p6_contradiction` and `dev/p7_impossible` are intentionally unsatisfiable,
  despite the README's general solvability guarantee. Tests expect rejection.

Baseline validation: all 21 official RTL cases (19 solved, 2 rejected), 300
generated cases, and 3,700 classic cases pass. The complete K5 application
passes both checkers on `ineq/set0/sparse1` at 267 reported cycles. Standalone
synthesis is in progress; no frequency or bitstream claim is made yet.

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
same 59,049 meaningful bits, expected to occupy seven M9Ks. Writes overlap the
two MRV selection cycles and the guess cycle. Restoring a nonempty alternative
costs two extra cycles; exhausted frames skip unnecessary reads. Decision-stack
writes now use an explicit if/else-if to infer a single RAM write port.

A separate build worktree will preserve v0's source while its standalone fitter
runs. All source snapshots remain immutable during their builds.
