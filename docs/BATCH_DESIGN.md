# Final batch solver architecture

The new architecture stores one nine-bit digit mask per cell (zero means empty).
A propagation round has two clock cycles: recompute row/column/box occupancy and
register each cell's candidates; then detect contradictions and apply all forced
assignments. A contradiction takes priority over completion.

The contradiction reduction chooses the next state and nothing else. It is kept
out of the cell write enables on purpose, because gating 81 cells with it placed
an 81-input OR and its wide fanout in series with the hidden-single tree. Forced
digits may therefore be written during a contradicted round; this is harmless,
since only empty cells are ever forced, every such write carries the current
decision depth, and the rollback that a contradiction always triggers clears
exactly that depth before the board is read again.

Naked singles have one candidate. Hidden singles are the sole remaining home for
a digit in a row, column or box. A balanced union tree tracks which digits occur
at least once and which occur more than once; the difference identifies hidden
singles without 81 separate searches through all peers.

When a round has no forced assignments, MRV chooses a cell through two small
tournaments separated by registers: first within each row, then between rows.
Neither tournament has a cycle of its own. Per-cell candidate counts are
registered in the same SCAN that produces the candidates, and the row tournament
is registered during APPLY, where the candidates it reads stay valid until the
guess is placed; a round that ends in propagation simply discards the result.
Only the between-rows tournament and the placement remain, so a guess costs two
cycles rather than three, and MRV is off the critical path entirely.

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

## Implementation steps

The git tags preserve the measured progression: v0 course MRV, v1 balanced MRV,
v2 naked-single batching with depth rollback, v3 fixed wrapper burst slices,
v4 explicit cell write sources, v5 hidden-single batching, v6 the contradiction
reduction off the write enables, and v7 registered candidate counts with the row
tournament folded into APPLY. Details and evidence are in RESULTS.md. The final
source is built into a full-system bitstream.

Each fixed-index cell register has explicit load, forced-placement, guess, retry
and clear enables. Their input sources are mutually exclusive by FSM state and
combined with AND/OR logic. Initial digits are decoded by equality, avoiding a
variable shifter. The algorithm and cycle counts are unchanged by this rewrite.
