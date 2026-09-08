# MRV experiments after hardware-validated v2

v2 is physically validated on all 21 supplied application cases. Its standalone
worst-path report lists 20 critical paths, all ending at the MRV row-index
registers. These paths include candidate counting and multiple comparisons.
The next experiments target that measured bottleneck while preserving the
propagation algorithm, search order, interface, and measured cycle count.

## The scheduling opportunity

The solver already has these cycles before every new guess:

```text
SCAN -> DOMAIN -> PICK_ROWS -> PICK_CELL -> PLACE
```

SCAN reads the current domains. DOMAIN applies deductions. Only a DOMAIN cycle
that finds no changes proceeds to PICK_ROWS; otherwise propagation repeats.
Therefore, information calculated from the SCAN domains remains current when
MRV is actually used. We can calculate parts of MRV in SCAN and DOMAIN without
adding cycles. Calculations made during a changing round are simply unused.
All these operations occur after the SOLVE command, inside the original timer.

## A: register the candidate counts

`bench/ineq/experiments/mrv_registered_counts.sv` adds a four-bit count register
per cell, sampled during SCAN. A singleton receives sentinel count 15 so MRV
ignores it. The existing row tournament reads those registers in PICK_ROWS.

```text
v2 critical path:
    domain -> candidate count -> row tournament -> row-index register

A splits it:
    SCAN:       domain -> candidate-count register
    PICK_ROWS:  candidate-count register -> row tournament -> row-index register
```

No reset is needed for the added registers: SCAN always writes them before the
state machine can use them. All 4,347 RTL executions match v2 byte for byte in
the result logs, including cycles, solved grids, guesses, and rollback counts.
Frequency and physical area must still be measured; extra registers alone do
not establish a speed improvement.

## B: a triplet hierarchy across existing cycles

`bench/ineq/experiments/mrv_triplets.sv` replaces the row/global tournaments with
a uniform three-way hierarchy. A candidate is represented as `{count, index}`.
The smaller count wins; a tie keeps the earlier cell.

```text
81 cells
  SCAN:       count candidates and choose 27 triplet winners
  DOMAIN:     choose 9 row winners from those triplets
  PICK_ROWS:  choose 3 winners, each covering three rows
  PICK_CELL:  choose 1 global winner
  PLACE:      try its smallest remaining digit
```

Each reduction compares three entries, using two comparisons. The hierarchy
preserves raster-order ties because every group contains a contiguous ordered
range of cells, and equal counts always select the earlier entry. The result is
the same lexicographic minimum `(candidate count, cell index)` as v2.

The parent-domain snapshot still uses exactly the same three writes in
PICK_ROWS, PICK_CELL, and PLACE. Pipeline registers contain selection metadata;
they do not change the saved search state or its restore sequence.

## Selection rule

Compare actual standalone Fmax from the supplied `qsyn_xlr -all` flow. Exact
RTL cycle agreement makes unchanged application counts an expectation, but the
selected implementation must still pass the complete K5 application suite.
Then measure its actual application cycles/Fmax and complete a full-system
programming build with the provided `comp_fpga` utility. A lower configured
clock is acceptable if needed; timing must pass at the clock actually used.

The v2 bitstream is retained throughout. The experiments are on the
`hackathon/mrv-pipeline` branch until a measured winner is selected.
