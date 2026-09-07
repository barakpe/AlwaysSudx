# Batch solver hypothesis

The new architecture stores one nine-bit digit mask per cell (zero means empty).
A propagation round has two clock cycles: recompute row/column/box occupancy and
register each cell's candidates; then detect contradictions and apply all forced
assignments. A contradiction takes priority over completion.

Naked singles have one candidate. Hidden singles are the sole remaining home for
a digit in a row, column or box. A balanced union tree tracks which digits occur
at least once and which occur more than once; the difference identifies hidden
singles without 81 separate searches through all peers.

When a round has no forced assignments, MRV chooses a cell through two small
tournaments separated by registers: first within each row, then between rows.
The following cycle places its lowest candidate. Selection costs extra cycles
only when a guess is necessary.

## Rollback invariant

Only guesses are pushed. Each entry contains a seven-bit cell index and nine bits
of remaining alternatives. Each assigned cell carries the decision depth that
created it. Givens and root deductions have depth zero.

On contradiction, the solver reads the top decision from synchronous memory and
clears every assignment at that depth in one cycle. If an alternative remains,
it retries the saved cell; otherwise it pops and repeats. All deeper levels have
already been cleared, so equality with the current depth is sufficient. Parent
assignments remain unchanged, which makes the saved alternatives valid on retry.
Occupancy is recomputed after rollback; there is no incremental mask state to
repair. Maximum stack depth is bounded by the 81 cells.

Multiple forced assignments can expose a contradiction in a speculative branch.
The next occupancy pass detects duplicate digits explicitly. A cell forced to
two different digits and a missing unit digit with no available home are also
contradictions. An apparently full grid is accepted only after these checks.

## Measurement sequence

1. v0: unmodified course MRV algorithm, interface names adapted.
2. v1: balanced minimum tree, identical search and cycle counts.
3. v2 hypothesis: batched naked singles, decision-depth rollback, pipelined MRV.
4. v3 hypothesis: enable hidden singles on the same batch architecture.

The drafts are hypotheses until their exact source passes synthesis, regression
and the course K5 integration test. Frequency and cycle reductions are reported
separately, then combined using the assignment's score.
