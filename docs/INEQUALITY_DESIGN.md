# How the inequality solver works

This document explains the new variant and the architectural experiments.
Measured results and the selected release are recorded separately in
`INEQUALITY_PROGRESS.md`; an experimental idea is not a speed claim.

## What stays the same

The puzzle is still a 9 by 9 Sudoku: every row, column, and 3 by 3 box must
contain each digit from 1 to 9 exactly once. The host still transfers 81 bytes
through the course interface, in bursts of 32, 32, and 17 bytes. The application
still measures setup, loading, solving, and storing using its original timer.
All puzzle deductions and search happen in Verilog. The supplied C checker
verifies the returned solution after timing has finished.

The classic v5 accelerator is preserved on the main branch. The new application
and accelerator are named `ineqsudx_scan`, and development is isolated in a
separate Git worktree. A variant experiment therefore cannot replace the
classic bitstream or its software by sharing an accelerator name.

## What an input byte means

```text
bits       7 6     5 4     3 2 1 0
meaning    right  below   digit

relation code 00 or 11: no constraint
relation code 01: current cell < neighbor
relation code 10: current cell > neighbor

0x65 = 01 10 0101
       right <, below >, digit 5
```

Only right and below relations are stored. A cell also receives constraints
from its left and upper neighbors. For example, if the cell above says it is
less than this cell, this cell must be greater than the cell above. Swapping
the two relation bits exchanges 01 and 10, while keeping both no-edge codes
unchanged. Boundary fields pointing outside the board are ignored.

The wrapper now preserves the upper nibble separately from the digit and
returns it with the solved digit. The official checker actually reads the
relations from its saved original board. Preserving them nevertheless makes
the returned bytes a complete, reusable representation of the solved puzzle.

## Candidate masks: nine possibilities in nine bits

Each cell has a nine-bit mask, called its domain. Bit zero represents digit 1,
bit one represents digit 2, and so on. A set bit means the digit is still
possible.

```text
domain = {2,5,8}
       = 9'b010010010

all digits possible: 9'b111111111
digit 5 assigned:    9'b000010000
no possible digit:  9'b000000000   -> contradiction
```

Masks make intersection cheap: a bitwise AND keeps only candidates allowed by
both constraints. They also make parallel processing natural: all 81 cells
can narrow their possibilities in the same clock cycle.

## Inequalities can help before either digit is known

Checking a relation only after both cells are filled misses much of its value.
For a strict less-than relation, each candidate in the left domain must have
at least one larger candidate in the right domain.

```text
A < B
A = {2,5,8}, B = {3,6}

8 cannot remain in A: B has no candidate greater than 8.
A becomes {2,5}.
```

There is a useful shortcut specific to ordering:

```text
For A < B:
    keep a in A exactly when a < max(B)
    keep b in B exactly when b > min(A)
```

An FPGA does not need a general comparator for all 81 pairs of candidate
digits. For each bit position, a reduction OR asks whether any higher or
lower bit is set in the neighbor's mask. The bounds are implemented through
these prefix and suffix masks rather than computing integer minima/maxima.

```systemverilog
// Candidate d+1 has support if the neighbor can take any larger digit.
for (int d=0; d<9; d++)
    less_than_some[d] = |(neighbor_mask >> (d+1));
```

This enforces arc consistency for each individual inequality. It does not
prove that all constraints together have a solution; search is still needed.
The conceptual foundation is constraint propagation interleaved with search:
[Mackworth, Consistency in Networks of Relations](https://www.cs.ubc.ca/~mack/Publications/AI77.pdf).

## Why propagation takes multiple rounds

All combinational deductions in a round use the same registered domains.
Updates become visible together at the clock edge. This avoids a long
combinational path extending across an entire chain of inequalities.

```text
A < B < C, each initially {1,...,9}

Round 1: A <= 8, B in 2..8, C >= 2
Round 2: A <= 7, B in 2..8, C >= 3
```

A later round can use information learned by a neighboring cell in the
previous round. Within a search branch, every update only removes candidates.
Because there are finitely many candidate bits, this process eventually
stabilizes or discovers a contradiction. Backtracking deliberately restores
earlier domains, allowing different possibilities to be tried.

## First baseline: extend classic v5

The initial variant keeps v5's separate assigned values and candidate masks.
It reconstructs candidates from placed Sudoku digits, narrows them through
inequalities until stable, applies naked and hidden singles, and guesses if
those deductions do not make progress.

```text
SCAN -> DOMAIN -> DOMAIN -> ... -> APPLY
  ^                                  |
  +----------- new assignments ------+
```

This was the simplest way to extend the proven implementation. It also kept
v5's depth labels: assignments made under a guess are cleared when that guess
is undone. Reconstructing candidate masks after rollback ensures that no
deduction from a failed branch survives accidentally.

The cost is repeated work. Even valid candidate eliminations are thrown away
after an assignment and derived again. This motivated the next experiment.

## Experiment: retain candidate deductions

The persistent-candidate experiment keeps the baseline's separate values but
intersects new restrictions with the previous candidate masks. Before every
guess it saves the entire parent candidate state in synchronous RAM.
Rollback restores that state before trying another digit.

This reduces repeated inequality rounds. However, it still maintains two
representations of each cell: its assigned value and its possible values.
That observation motivated a more substantial redesign.

## Domain-only architecture

An assigned value needs no separate representation: it is simply a domain
with one bit set. This removes the separate value registers and per-cell
assignment-depth bookkeeping. Every propagation round now combines:

1. Sudoku peer elimination from singleton cells.
2. Hidden-single deductions in all 27 units.
3. Inequality restrictions from up to four neighbors.

```text
next_domain = current_domain
            AND Sudoku_allowed
            AND inequalities_allowed
            AND hidden_single_restriction
```

A naked single is automatic: when a domain has one candidate, that cell is
assigned. On the next round its digit is removed from its peers.

For hidden singles, each row, column, and box combines nine domain masks in a
balanced tree. The tree tracks which digits occur at least once and which
occur more than once. Their difference identifies digits with exactly one
possible location. If two different digits each require the same cell, the
branch is contradictory.

Singleton peer elimination leaves the singleton's own domain intact. Duplicate
singletons are detected separately per unit. This avoids removing a cell's
own assigned digit merely because it is present in the row occupancy mask.

## Guessing and rollback

When a round makes no changes, the solver selects an unresolved cell with the
fewest candidates. This is minimum remaining values, or MRV. A balanced
tournament chooses the best cell in each row, registers those nine winners,
then chooses the overall winner. Ties have a deterministic order.

```text
parent domains
    |
    +-- save parent snapshot and remaining alternatives
    |
    +-- try smallest candidate
           |
           +-- propagate; perhaps make deeper guesses
           |
           +-- contradiction:
                   restore parent snapshot
                   try next saved alternative
```

Only guesses consume stack entries; forced deductions do not. Each entry
contains a cell index and remaining candidate bits, plus a full snapshot of
the 81 domains. A snapshot has 81 * 9 = 729 meaningful bits. The 81-entry
snapshot memory holds 59,049 meaningful bits before FPGA block allocation
overhead. Actual M9K utilization must be read from the fitter, since raw bit
counts alone do not predict the number of memory blocks consumed.

The deployable implementation packs a snapshot into three 243-bit beats.
The first two writes overlap the MRV stages and the third overlaps the guess.
Thus packing adds no guess cycles. Retry restoration reads the three beats
through one synchronous RAM port, adding two cycles for a successful retry.
Exhausted stack frames skip the unnecessary remainder of the read sequence.
A separate small RAM holds decisions, using explicit mutually exclusive writes.

The RAM uses synchronous read and write, with no reset of its contents.
Resetting the stack depth invalidates old entries. A separate read cycle
fetches a parent snapshot before the restore cycle uses it. These access
patterns allow ordinary inferred FPGA RAM through the course flow.

## Why the result is safe to accept

Every pruning operation removes only candidates that cannot participate in a
solution under the current branch. Each guess partitions the remaining choices
of one cell. If it fails, its parent state is restored and the next alternative
is tried. Exhausting all alternatives returns to an earlier parent.

Success requires all domains to be singletons, with no duplicate digit in any
unit, no missing digit support, and no violated inequality. Contradiction checks
take precedence over completion. The testbench independently checks the output
digits, original givens, all 27 Sudoku units, and all input inequalities.

## What performance numbers mean

```text
core cycles: clocks inside the solver (useful for explaining its behavior)
app cycles:  clocks reported by the unmodified course timing window
score time:  app cycles / standalone qsyn_xlr Fmax in MHz
```

The host's polling makes application counts change in steps. Saving ten core
cycles may therefore leave the application count unchanged on a particular
board. A frequency improvement can still improve the competition score.
Conversely, a design with fewer cycles can lose if its added logic lowers Fmax.

The full-system clock remains the course default. Its timing reports answer
whether that actual FPGA system meets its clock requirement. Standalone Fmax
answers a different question and is the frequency used in the competition.

## Testing strategy

The official boards are the main optimization set. Additional tests cover
zero givens, varying inequality densities, no-edge codes 0 and 3, ignored
boundary fields, completed boards, known contradictions, and difficult classic
puzzles augmented with consistent inequalities. Generated signs are derived
from the actual generated solution; arbitrary digit permutations do not
preserve ordering relations.

The course application must report both the basic Sudoku and inequality
checkers as passing. A single occurrence of PASSED in a log is insufficient.
Solutions need not match a predetermined grid when a puzzle has multiple
solutions; they must satisfy the original givens and every constraint.

Source snapshots, result logs, synthesis reports, and final artifact hashes
provide the link from an experiment to its measurements and bitstream.
