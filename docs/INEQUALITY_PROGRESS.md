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
