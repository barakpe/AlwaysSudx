# AlwaysSudx: how it works, why we changed it, and how to explain it

This guide explains the actual v5 implementation, starting from ordinary Sudoku
and ending with the FPGA bitstream. It is meant to help you explain the design in
your own words, rather than memorize a list of optimizations.

Code blocks marked **simplified** explain an idea; they are not extra source files.
Blocks marked **actual RTL** are excerpts from the implementation. The complete
files are linked at the end. All measurements come from this repository's logs.

## 1. What we built, in one minute

A computer sends a Sudoku board to the FPGA. The FPGA solves it and writes the
answer back. The C program does the communication, prints the board and checks it.
The search and deductions happen in Verilog hardware.

Our main idea is:

```text
First, make every deduction that is currently forced.
Do many independent deductions together.
If deductions stop, make one carefully chosen guess.
If that guess leads to a contradiction, erase everything that depended on it.
Try another possibility.
```

Three different kinds of improvement work together:

```text
Search improvement:       do less unnecessary guessing.
Parallelism improvement:  perform multiple deductions in the same round.
Circuit improvement:      make each clock cycle fast and the hardware small.
```

We started a separate repository, AlwaysSudx. We did not modify AlwaysSud or
AlwaysSudAgent. The course C application and shared library stayed unchanged.
Production changes are in the Verilog solver and wrapper; additional scripts,
testbenches and documents provide verification and measurement.

The final version is **v7**, with its RTL built from commit **5d93fab**. Later
commits add reports and explanation without changing those hardware inputs.
Sections 7 to 12 describe v0 to v5 in the order they were built; section 21
covers v6 and v7, which came from reading v5's own timing report.

## 2. Are we finished optimizing?

**This optimization round is finished and has a built, timing-checked release.
We have not proved that v7 is the fastest possible design.**

```text
Finished:
    Verified baseline and a sequence of understandable commits.
    A different solver architecture from the existing opus implementation.
    Thousands of RTL tests and the course K5 application tests.
    Standalone synthesis, placement, routing and timing analysis.
    Full-system bitstream generation and 50 MHz timing checks.

Still needed:
    Program the physical FPGA and verify results and cycle counts there.

Done since, in v6 and v7:
    Target the measured critical path.          (+24.4% Fmax, zero cycle cost)
    Reduce guess overhead if timing permits.    (-4.83% cycles, zero Fmax cost)

Possible later work:
    Try stronger deductions with separate measurements.
    Re-examine the propagation round now that the reduction is off the writes.
```

It makes sense to validate the hardware now. Continuing to change the source
before testing the existing bitstream would keep moving the target. Section 20
explains the opportunities as they stood at v5; section 21 reports what
happened when the first two were actually attempted.

## 3. The score: both cycles and frequency matter

A cycle is one tick of the clock. Frequency tells us how many ticks occur each
second. Reducing the number of ticks helps, but making a tick take longer hurts.

The assignment's score is:

```text
score in microseconds = reported application cycles / standalone Fmax in MHz

Example:
    Design A: 1,000 cycles / 100 MHz = 10 microseconds
    Design B:   600 cycles /  40 MHz = 15 microseconds

B uses fewer cycles, but A has the better time.
```

The word **standalone** matters: the course explicitly scores with the
accelerator's `qsyn_xlr` Fmax, rather than the complete K5 system's Fmax.

We keep three measurements separate:

```text
Direct solver cycles:
    start the solver -> solver asserts done
    Measured by our RTL testbench.

Course application cycles:
    the C application's existing timed solve() call
    Includes setup, loading, solving, storing and software/interface overhead.

Actual hardware clock:
    50 MHz in the final bitstream, using the course default.
```

For v7 on hard1:

```text
Core cycles                        = 202
Course application cycles          = 483
Standalone accelerator Fmax         = 72.05 MHz
Configured physical hardware clock  = 50 MHz

Assignment score = 483 / 72.05 = 6.70 microseconds
(v5 scored 483 / 58.10 = 8.31 microseconds)

If physical hardware also reports 483 cycles:
    those 483 cycles at 50 MHz would take 9.66 microseconds.
    That is a hardware-time calculation, not the assignment's scoring formula.
```

The difference `483 - 217 = 266` is overhead in these measurement windows. It is
not a universal constant: other boards show slightly different overhead because
polling observes completion at discrete intervals. We did not change C timers to
make the score look better.

## 4. A little FPGA intuition before reading the Verilog

A software loop normally repeats work on a processor. A fixed-size combinational
Verilog loop can instead describe many pieces of hardware that exist together.

```systemverilog
// Simplified: these can be 81 parallel pieces of logic.
for (int c = 0; c < 81; c++) begin
    candidate[c] = calculate_candidates(c);
end
```

This does **not** automatically mean 81 clock cycles. Conversely, a short loop
whose next iteration depends on the previous result can create a long chain of
combinational hardware:

```systemverilog
// Simplified: each new best depends on the previous best.
best = count[0];
for (int c = 1; c < 81; c++) begin
    if (count[c] < best) best = count[c];
end
```

That distinction motivates v1.

Registers divide work into clock cycles:

```text
register -> combinational gates -> register
             must settle before the next clock edge
```

A longer gate-and-routing path generally requires a longer clock period. Adding a
register can shorten that path, but it can also add a cycle to the algorithm.
We must measure the resulting cycles/Fmax, not assume that pipelining wins.

In a clocked block, nonblocking assignments (`<=`) update together at the edge:

```systemverilog
// Simplified: new a gets old b, and new b gets old a.
a <= b;
b <= a;
```

Our batch calculations use one consistent snapshot of the board. A forced digit
written in one cell does not secretly change another cell's candidates halfway
through the same round. Its effect appears in the following SCAN.

## 5. The platform: how a board reaches the solver

There are two important hardware files:

```text
hw/xlrs/sudx_scan/sudx_scan.sv
    Wrapper: registers, memory transfers, solver start/done.

hw/xlrs/sudx_scan/sudx_scan_solver.sv
    Sudoku algorithm and its helper mask-tree module.
```

The repository is called AlwaysSudx, but the accelerator and application names
remain `sudx_scan`. This lets the original course driver keep working.

The normal course application sequence is:

```text
C program allocates and fills 81 board bytes in XMEM
        |
        v
SETUP command -> wrapper LOAD state
        |
        +-- read 32 bytes: cells  0..31
        +-- read 32 bytes: cells 32..63
        +-- read 17 bytes: cells 64..80
        |
        v
C program issues SOLVE
        |
        v
wrapper starts solver and waits for done
        |
        v
wrapper STORE state writes 32 + 32 + 17 bytes back
        |
        v
C program observes completion, prints and checks the solution
```

The legal input values are 0 for empty and 1..9 for a digit. The wrapper uses the
low four bits of each board byte. The solver itself receives an entire packed
81-cell board; it does not issue the memory transactions.

The tested pattern uses a reset for each independent invocation/test. The solver
holds `done` in its final state; it does not support arbitrary repeated `start`
pulses without reset. The wrapper's burst cursors also follow that course pattern.
Thousands of tests therefore do not mean thousands of commands without reset.

## 6. Representing Sudoku with bits

The final solver uses nine bits to represent a set of digits:

```text
Bit position:   8 7 6 5 4 3 2 1 0
Digit:          9 8 7 6 5 4 3 2 1

Digit 5:        0 0 0 0 1 0 0 0 0  = 9'b000010000
Set {2,5,7}:    0 0 1 0 1 0 0 1 0  = 9'b001010010
Empty set:      0 0 0 0 0 0 0 0 0
All digits:     1 1 1 1 1 1 1 1 1  = 9'h1ff
```

For an assigned cell, `value[c]` is one-hot: exactly one bit is set. For an empty
cell, it is zero. A candidate mask can have several bits set.

This makes set operations cheap:

```systemverilog
// Simplified, all masks are nine bits.
used = row_used | column_used | box_used;
allowed = ~used;
```

For example:

```text
Used in row:     {1,4}
Used in column:  {2,8}
Used in box:     {4,9}
Union:           {1,2,4,8,9}
Allowed:         {3,5,6,7}
```

There are **27 units**: nine rows, nine columns and nine boxes. The final code
numbers them like this:

```text
Units  0..8:   rows
Units  9..17:  columns
Units 18..26:  boxes

For flat cell c:
    row = c / 9
    col = c % 9
    box = (row / 3)*3 + col / 3
```

The mapping loops are fixed-size and unrolled. In generate blocks, these indices
are elaboration-time constants; this geometry does not require a variable divider
for every Sudoku operation.

The main stored information is:

| Signal | Meaning |
|---|---|
| `value[c]` | The placed digit, or zero for empty |
| `candidate[c]` | Registered possible digits for an empty cell |
| `empty_q[c]` | Whether that cell was empty in the SCAN snapshot |
| `used_q[u]` | Digits already placed in a unit in that snapshot |
| `assigned_depth[c]` | Which guess level created the assignment |
| `depth` | Number of active guesses |
| `decisions[]` | Guess cell and its untried alternatives |

The course MRV baseline uses a different convention: ten mask bits with bit zero
unused. Do not mix that convention with v5's nine-bit, digit-minus-one encoding.

## 7. v0: establish a baseline we can trust

### Motivation

We needed a working reference before optimizing. Otherwise a fast but incorrect
solver, or a changed timing window, could look like an improvement.

We selected the course `claude_mrv` implementation and connected it to the
corrected course `sudx_scan` wrapper. The baseline changes only the module name and
output port name needed for that connection.

MRV means **minimum remaining values**:

```text
Cell A allows {1,2,3,4}
Cell B allows {2,7}
Cell C allows {5,6,9}

Choose B: it has only two possibilities.
```

The intuition is to resolve the most constrained uncertainty first. If a choice
is bad, constraints are more likely to expose it early. MRV is a heuristic, not a
proof that this cell ordering is always optimal.

The baseline essentially does this:

```text
Load cells and build row/column/box masks.
Repeat:
    Find the empty cell with the fewest candidates.
    If no empty cell remains: success.
    If the selected cell has no candidate: backtrack.
    Otherwise place its smallest candidate and push that placement.
When backtracking:
    Undo or retry the most recent placement.
```

The baseline initializes one cell per cycle. It also pushes deductions with only
one candidate, not just genuine guesses.

### Evidence

```text
hard1 core cycles:         981
hard1 application cycles:  1,251
Standalone Fmax:           4.98 MHz
hard1 score:               251.20 us
Mapped / fitted LEs:       13,026 / 12,200
```

All four course boards passed K5 application checks. Direct RTL checks passed the
four course boards and top95. We committed and tagged this as `v0` before changing
the algorithm.

## 8. v1: turn a long minimum chain into a tournament

### Motivation and intuition

The baseline's timing report showed a very long path through MRV's minimum
selection. The algorithm was reasonable, but its circuit organization was slow.

Imagine selecting the smallest of eight numbers:

```text
Serial comparison chain:
    min(a,b) -> compare with c -> compare with d -> ... -> compare with h
    Seven dependent comparisons.

Tournament:
    a --\
         min --\
    b --/       \
                 min --\
    c --\       /       \
         min --/         \
    d --/                 min -> answer
    e --\                /
         min --\        /
    f --/       \      /
                 min --/
    g --\       /
         min --/
    h --/

    Three comparison levels.
```

For 81 cells, we used 128 padded leaves, giving seven tree levels. Padding entries
have an impossible candidate count, so they cannot beat a real eligible cell.
The comparator chooses the left child on ties, preserving raster-order behavior.

**Actual v1 RTL excerpt:**

```systemverilog
wire left_wins = min_count[2*n] <= min_count[2*n+1];
assign min_count[n] = left_wins ? min_count[2*n] : min_count[2*n+1];
assign min_row[n] = left_wins ? min_row[2*n] : min_row[2*n+1];
assign min_col[n] = left_wins ? min_col[2*n] : min_col[2*n+1];
```

We changed how the minimum was calculated, not which minimum won. This is why
preserving ties matters: another tie rule could change search length and obscure
whether the improvement came from the circuit or the search order.

### Result

```text
Before: 1,251 app cycles /  4.98 MHz = 251.20 us
After:  1,251 app cycles / 25.57 MHz =  48.92 us

Frequency and score improvement: 5.13x
All 95 top95 cycle counts and complete solutions remained identical.
```

The first syntax forms worked in Xcelium but were rejected by Quartus. Explicit
`generate` blocks and separately declared `genvar`s solved that compatibility
issue. Simulation acceptance alone was not enough to establish synthesizability.

## 9. v2: make deductions in batches

### Motivation

The earlier solver filled one selected cell at a time. An FPGA can examine many
cells in parallel. If several cells are already forced, it is unnecessary to
spend a separate selection step on each of them.

A **naked single** is a cell with exactly one possible digit:

```text
A: {2}      -> forced to 2
B: {5}      -> forced to 5
C: {2,7}    -> not forced yet

One batch writes A=2 and B=5.
The next candidate scan can discover C={7}.
```

The last detail is important. We do not claim to solve all consequences in one
combinational cycle. A batch uses the current snapshot; the next round sees the
new assignments.

### The two-cycle propagation round

```text
SCAN:
    Recompute each unit's occupied digits from the current board.
    Calculate and register every empty cell's candidates.
    Register empty flags and board-conflict status.

APPLY:
    Check contradictions.
    If the board is complete and consistent, finish.
    Otherwise write all forced cells together.
    Return to SCAN.
```

**Actual RTL excerpt from SCAN:**

```systemverilog
candidate[c] <= value[c] != 0 ? 9'd0 :
    ~(occupied[c/9] | occupied[9+c%9] | occupied[18+(c/27)*3+(c%9)/3]);
empty_q[c] <= value[c] == 0;
```

A filled cell has no candidate entries. That prevents an already filled cell from
being mistaken for another possible home of a digit.

When propagation stops, the final architecture uses MRV in three states:

```text
PICK_ROWS: select and register the best cell in each row.
PICK_CELL: select and register the best of the nine row winners.
PLACE:    assign its smallest digit, push the guess and increase depth.
```

This adds cycles to a guess, but keeps the selection hardware in smaller stages.
It also avoids putting the entire guess selection into every propagation round.
The tournaments are combinational circuits and can still toggle in other states;
we are describing their algorithmic use, not claiming clock or power gating.

### A different stack: remember guesses, not every deduction

If a guess forces 20 cells, the old approach would need placement history for
those cells. Instead, we give each assigned cell a **decision depth**.

```text
Depth 0: original clues and deductions made without guessing
Depth 1: first active guess, and all deductions that depend on it
Depth 2: second active guess, and its deductions
...
```

Only guesses enter the stack. An entry contains:

```text
7 bits: which of the 81 cells was guessed
9 bits: candidate digits that have not been tried yet
```

For example:

```text
Guess cell A, candidates {2,7,9}:
    put 2 in A
    store (A, alternatives={7,9})
    increase depth from 0 to 1

Deductions P=4 and Q=8 now become forced:
    tag A, P and Q with depth 1
```

### Walk through a rollback

```text
Root:    original clues and root deductions             depth 0
Guess A: A=2, alternatives {7,9}; deductions P and Q      depth 1
Guess B: B=5, no alternatives left; deduction R          depth 2
Contradiction appears.

1. Read the top decision: B, alternatives={}
2. Clear every assigned cell tagged depth 2: B and R
3. No retry exists, so reduce depth to 1
4. Read A, alternatives={7,9}
5. Clear every assignment tagged depth 1: A, P and Q
6. Write A=7; update alternatives to {9}
7. Recompute candidates and continue at depth 1
```

Clearing a whole level is cheap in this architecture: all cells compare their tag
against the current depth in parallel.

Why does equality, rather than `>=`, work?

```text
When we process level d:
    Every deeper level has already been erased while unwinding.
    Shallower levels belong to the parent search state and must survive.
    Therefore erase exactly level d.
```

Root-level assignments are safe because depth zero goes directly to failure;
`BACK_APPLY` is not executed at depth zero. Stale depth tags on empty cells do no
harm: clearing an already empty cell just writes zero again.

Why are saved alternatives still valid? On a retry, we restore the same parent
board that existed before the guess. We erase its dependent deductions, not its
parents. Each saved alternative was legal against those parents.

### Why recompute occupancy?

Clearing a batch is awkward if every row/column/box mask must also be incrementally
undone. We instead recompute occupancy from the remaining placed cells in SCAN:

```text
board is the source of truth
    -> OR its placed digit masks for each unit
    -> derive candidates
```

This costs combinational logic, but avoids storing a history of mask changes or
copying the entire board at every decision level.

### Why a synchronous RAM stack?

The actual storage code uses a clocked read and has no reset loop over the RAM:

```systemverilog
if (state == PLACE)
    decisions[depth] <= {chosen_cell, chosen_mask & ~chosen_digit};
else if (state == BACK_APPLY && alternatives != 0)
    decisions[depth-7'd1] <= {top_cell, alternatives & ~retry_digit};
if (state == BACK_READ && depth != 0)
    top <= decisions[depth-7'd1];
```

Reset clears `depth`, so stale memory entries are not read as valid decisions.
Every live entry was written by a PLACE after reset. BACK_READ gives the RAM a
cycle to return its entry; BACK_APPLY uses that registered result.

The declared storage is `81 * 16 = 1,296` bits. Synthesis reports **1,215 useful RAM
bits**, or 81 times 15. The lowest alternative bit can never remain set after the
smallest candidate has been removed, allowing one bit per entry to optimize away.
Read and write are in different states on the same clock; the RAM warning about
simultaneous mixed-port access refers to a case the FSM does not exercise.

### What v2 measured, and what it did not isolate

v2 is a new architecture combining batching, parallel initialization, a guess-only
stack, depth rollback, candidate registers and pipelined MRV. Its result measures
that package. We did not measure a separate speedup for every internal component.

```text
hard1 core cycles:         981 -> 334
hard1 application cycles:  1,251 -> 603
Standalone Fmax:           25.57 -> 72.81 MHz
hard1 score:               48.92 -> 8.28 us

But fitted area:           23,691 LEs
```

This was fast, but above the course's approximately 20K-LE accelerator guidance.
The next steps addressed area rather than adding more search logic immediately.

## 10. v3: remove flexibility that the transfer protocol never uses

### Motivation

The synthesis hierarchy attributed about 7,100 combinational functions to the
wrapper alone. Its general variable-index loading and storing was expensive.
But the course transaction starts are always 0, 32 and 64 for an 81-byte board.

A general expression is convenient to write:

```systemverilog
// Simplified form of the original data selection.
mem_data[i] = solved_board[next_start + i];
```

Hardware must implement the choices expressed by variable indexing. We made the
three legal choices explicit instead:

```systemverilog
// Actual RTL excerpt.
case (next_store_start_idx)
  7'd0:  for (int i=0; i<32; i++) mem_intf_write.mem_data[i][3:0] = solver_puzzle_out_flat[i];
  7'd32: for (int i=0; i<32; i++) mem_intf_write.mem_data[i][3:0] = solver_puzzle_out_flat[32+i];
  7'd64: for (int i=0; i<17; i++) mem_intf_write.mem_data[i][3:0] = solver_puzzle_out_flat[64+i];
  default: ;
endcase
```

LOAD uses the corresponding fixed destinations. Data movement still takes exactly
three transactions. Address handshakes and the C API do not change.

The intuition is like replacing a switchboard that can connect any of 81 sources
to an output with one that has only the three positions actually required.

The `next_store_start_idx` name is significant. It retains the course's corrected
STORE behavior: use the index of the next requested burst, not the previous one.
Changing it back would reintroduce a known transfer bug.

This optimization is not based on a particular puzzle. It applies to every board
supported by this fixed 9x9 protocol; no answer or clue pattern is in the hardware.

### Result

```text
Mapped LEs:          23,949 -> 17,199
hard1 app cycles:    603 -> 603
K5 final checker:    PASS
Standalone Fmax:     not measured for this intermediate tag
```

The mapping improvement is measured. A frequency improvement for v3 is not claimed
because we deliberately did not repeat full timing at this area-only milestone.

## 11. v4: express each cell's write circuit clearly

### Motivation

The first batch implementation wrote the board from several branches of a large
clocked case statement. The synthesis report showed expensive inferred selection
logic on cell writes. We made those sources and their enables explicit.

For one fixed cell, ask:

```text
Are we loading the puzzle?
Are we applying a forced digit to this cell?
Are we placing a new guess here?
Are we retrying this cell after rollback?
Are we just clearing this level?
```

**Actual RTL excerpt:**

```systemverilog
wire [8:0] next_digit = ({9{load_cell}} & input_digit)
                     | ({9{force_cell}} & forced[c])
                     | ({9{guess_cell}} & chosen_digit)
                     | ({9{retry_cell}} & retry_digit);
```

`{9{load_cell}}` repeats the enable bit nine times:

```text
load_cell = 0 -> 000000000 -> contribution is zero
load_cell = 1 -> 111111111 -> input_digit passes through
```

The nonzero data sources are mutually exclusive by state. `clear_cell` may be
true at the same time as `retry_cell`; that is intentional. Clear enables the
write, while the retry source supplies the new digit. Clear has no nonzero source
of its own. The guessed cell is therefore replaced while its deductions disappear.

The next register state is straightforward:

```systemverilog
// Actual RTL excerpt.
if (write_cell) value[c] <= next_digit;
if (load_cell) assigned_depth[c] <= 0;
else if (guess_cell) assigned_depth[c] <= depth+7'd1;
else if (force_cell) assigned_depth[c] <= depth;
```

We also replaced a shifted-one expression for initial digit encoding with direct
equality checks:

```systemverilog
// Actual RTL inside a generate loop.
assign input_digit[k] = input_flat[c] == 4'(k+1);
```

Each output bit asks a simple question: "Does this input equal my digit?" This
spells out the intended decoder rather than relying on synthesis to simplify a
variable shift and subtraction. `4'(k+1)` sizes the constant to four bits.

### Evidence and limits of attribution

The isolated rewrite was tested with the original wrapper:

```text
Original batch representation: 23,949 mapped LEs
Explicit cell write sources:   21,322 mapped LEs
Reduction:                     2,627 LEs
All 95 top95 cycles and full solutions: identical
```

The v4 commit combines that rewrite with v3's wrapper. We did not measure v4's
combined Fmax separately. Nor should the isolated LE saving simply be added to
another experiment's saving: synthesis can share and restructure logic differently
when changes are combined. Final v5 was synthesized and fitted as a complete design.

## 12. v5: add hidden singles to the same batch architecture

### Motivation

Naked singles look at one cell and ask which digits it can contain. Hidden singles
look at one digit in a unit and ask which cell can contain it.

```text
Three empty cells in a unit; missing digits are {2,5,7}:

    A: {2,5,7}
    B: {2,7}
    C: {2,7}

No cell has only one candidate.
But digit 5 has only one possible home: A.
Therefore A=5 is forced.
```

That deduction can avoid guessing entirely. The word "hidden" means the single
is hidden in a cell with several apparent candidates.

### Detecting unique homes with a reusable tree

For each digit in a unit, we want to know:

```text
present:  Does at least one cell offer this digit?
repeated: Do at least two cells offer this digit?
unique:   present AND NOT repeated
```

The helper `sudx_union9` combines two child groups at a time:

```systemverilog
// Actual RTL.
assign any_digit[n] = any_digit[2*n] | any_digit[2*n+1];
assign many_digit[n] = many_digit[2*n] | many_digit[2*n+1]
                        | (any_digit[2*n] & any_digit[2*n+1]);
```

Why the last term? A digit repeats if it appears in both children, even if neither
child contains an internal repetition.

```text
Left group:  digit 5 appears once
Right group: digit 5 appears once

Neither child says "repeated".
But together there are two copies, detected by left.present AND right.present.
```

These operations run on all nine digit bits together. Nine leaves are padded to
16 and merged through a balanced tree. We use the same helper for two jobs:

```text
Feed it placed cell values:
    present  -> occupied digits
    repeated -> duplicate placements, which are illegal

Feed it candidate masks:
    present  -> digits with at least one available home
    repeated -> digits with at least two available homes
```

**Actual RTL excerpts:**

```systemverilog
assign unique_digit[u] = support[u] & ~multiple[u];

wire [8:0] hidden = HIDDEN_SINGLES
    ? candidate[c] & (unique_digit[R] | unique_digit[9+C] | unique_digit[18+B])
    : 9'd0;

assign forced[c] = naked | hidden;
```

A unique digit only contributes to a cell if that cell actually contains it in
its candidate mask. The test covers that cell's row, column and box.

The final v5 algorithm change is deliberately small:

```systemverilog
parameter bit HIDDEN_SINGLES = 1'b1
```

The infrastructure already supported the experiment. Turning on the parameter
makes the hidden-single logic affect the solver and survive synthesis.

### Why this is a better broad-board result

The isolated algorithm comparison was:

| Set | Naked batch mean core cycles | Hidden batch mean core cycles |
|---|---:|---:|
| top95 | 18,852.95 | 628.51 |
| Generated classic, 400 runs | 454.74 | 50.61 |
| Difficult heldout, 11 runs | 552.27 | 112.18 |

The final hardware, including the wrapper and cell-write improvements, reports:

```text
Standalone Fmax:       58.10 MHz
Mapped / fitted LEs:   17,389 / 17,219
hard1 core cycles:     217
hard1 app cycles:      483
hard1 app score:       8.31 us
```

v2 scored 8.28 us on hard1, so v5 is actually about 0.4% worse on that one score.
We chose v5 for its smaller area, far stronger broad-board behavior and completed
full-system build. Optimizing only hard1 would favor the wrong overall tradeoff.

The 72.81-to-58.10 MHz difference is measured between v2 and v5, with the v3 and
v4 circuit changes also present. It is not an isolated measurement of the hidden
singles logic's frequency cost.

## 13. Correctness: a filled board is not automatically a solution

Batching makes consistency checks essential. In a speculative branch, apparently
forced assignments can reveal that the branch was impossible.

We check these cases:

```text
1. A placed digit is duplicated within a row, column or box.
2. An empty cell has zero candidates.
3. A missing digit has no possible home in a unit.
4. One cell is forced to two different digits.
5. An input nibble is outside the legal 0..9 range.
```

The no-home check is compact:

```systemverilog
// Actual RTL: each bit describes one digit.
assign no_home[u] = |(~(used_q[u] | support[u]));
```

A digit is accounted for if it is already used or has a candidate home. If neither
is true, the unit cannot be completed.

Contradictions must beat completion:

```systemverilog
// Actual RTL excerpt.
if (conflict_q || (|dead_cell) || (|no_home)) state <= BACK_READ;
else if (!(|empty_q)) state <= FINISH_OK;
else if (|forced_cell) begin
    state <= SCAN;
end else state <= PICK_ROWS;
```

If a batch creates duplicate placements, the next SCAN detects them before a full
board can be accepted. If there are no guesses to undo, the solver reports failure.
It does not treat illegal completion as success.

The independent testbench also verifies the output rather than trusting `success`:

```text
Every output digit is in 1..9.
Every original nonzero clue is unchanged.
Every row contains digits 1..9.
Every column contains digits 1..9.
Every 3x3 box contains digits 1..9.
The solver completes within the test's cycle limit.
```

In a nine-cell unit with all values in 1..9, checking that the OR of its digit bits
contains all nine digits establishes that none is missing or repeated.

## 14. The complete solver state machine

```text
IDLE --start--> INIT --> SCAN --> APPLY
                            ^      |
                            |      +-- contradiction --> BACK_READ
                            |      |                         |
                            |      |       depth == 0 -------+--> FINISH_FAIL
                            |      |                         |
                            |      |       depth > 0 --------+--> BACK_APPLY
                            |      |                               |
                            |      |    retry exists --------------+--> SCAN
                            |      |    no retry -> depth-- -------+--> BACK_READ
                            |      |
                            |      +-- complete ----------------------> FINISH_OK
                            |      |
                            +------+- forced cells: apply a batch
                                   |
                                   +-- no forced cells --> PICK_ROWS
                                                              |
                                                          PICK_CELL
                                                              |
                                                            PLACE
                                                              |
                                                             SCAN
```

INIT loads the whole solver board in parallel; the wrapper has already done the
external transfers. FINISH_OK and FINISH_FAIL hold status until reset.

A simple case illustrates the extra completion check:

```text
INIT:       load the initial board
SCAN:       derive candidates
APPLY:      fill the last forced cells
SCAN:       check the resulting complete board
APPLY:      recognize consistent completion
FINISH_OK:  assert done and success
```

That is why even a tiny puzzle has a few solver cycles rather than zero. The final
check is useful work, not a timing counter trick.

## 15. What the testing actually established

The exact final source passed:

```text
4       course boards
95      top95 boards
400     generated classic boards
11      difficult heldout boards
3       corner boards: solved, empty, one blank
3,191   published holdout boards
---------------------------------
3,704   solvable-board executions

35      invalid/unsatisfiable executions, all correctly rejected
---------------------------------
3,739   total direct RTL test executions

Plus all four boards through the actual K5 application and wrapper.
```

Sets can overlap. These numbers count executions, not distinct puzzles. An empty
board has many solutions; the checker accepts any valid completion preserving the
clues, rather than insisting on one arbitrary golden solution.

The 32 added contradictory puzzles had nonconflicting givens and were independently
checked as unsatisfiable by a Python MRV solver before testing RTL. They include
cases that exercise failed-search rollback. The other rejection cases cover simple
invalid/contradictory inputs.

The testbench drives inputs on falling clock edges and observes registered outputs
after the rising edge. This avoids a race where the testbench and DUT disagree
about whether the current clock edge has already updated state.

Tests give strong evidence, not a proof over every possible Sudoku. They do not
replace running the bitstream on the actual board.

## 16. How the opus comparison was made

We preserved the existing opus solver from `explore/opus5-phases`, commit
`5a227db`, and ran it with the same direct RTL testbench and puzzles. It uses MODE=2.
Its reported standalone frequency is 26.36 MHz from its saved synthesis report.

```text
Published holdout: 3,191 runs

Opus:
    Mean core cycles = 561.8129
    Core time estimate = 561.8129 / 26.36 = 21.31 us

AlwaysSudx v7:
    Mean core cycles = 367.2911
    Core time estimate = 367.2911 / 72.05 = 5.10 us

Ratio = 21.31 / 5.10 = 4.18x
(at v5 the same calculation gave 387.5459 / 58.10 = 6.67 us, a 3.20x ratio)
```

For hard1 alone:

```text
Opus: 193 core cycles / 26.36 MHz = 7.32 us
v5:   217 core cycles / 58.10 MHz = 3.73 us
v7:   202 core cycles / 72.05 MHz = 2.80 us
```

Again, fewer cycles is not sufficient to win. Opus uses fewer core cycles on hard1
than v5 did, but the higher measured frequency gives a lower core-time estimate.

This comparison does **not** claim that the two C programs have the same timing
window. Opus has split timers; our C application remains the original course
version. The 3.20x result compares core cycles/Fmax, not unmatched app windows or
new physical-board measurements.

The architectural difference is concrete: opus generally chooses and places one
forced cell per step, keeping placement history. Our solver applies a whole batch
and only stacks guesses, with depth tags to undo dependent work together.

## 17. From legal Verilog to a usable bitstream

Simulation and FPGA implementation answer different questions:

```text
RTL simulation:  Does the described logic behave correctly on the tests?
Synthesis:       Can it be mapped to the FPGA's resources, and at what area?
Placement:       Where do the resources go on the device?
Routing:         Can the wires connect them with acceptable delay?
Timing analysis: Do paths meet the clock requirements?
Bitstream:       The programming data for the FPGA.
Hardware test:   Does that programmed system behave correctly on the board?
```

We used the course commands:

```sh
source bench/env.sh
cd "$MY_K5_XLRS/sudx_scan"
qsyn_xlr sudx_scan -all
```

For the complete system, the helper invokes `comp_fpga sudx_scan` and collects the
course tool's Desktop-linked output back into AlwaysSudx:

```sh
# Run from the repository root.
bash bench/fpga.sh
```

No fitter settings, clocks or C timing windows were changed to improve the score.

Final implementation results:

```text
Accelerator:
    17,148 fitted LEs
    2,998 registers
    1,215 useful RAM bits
    72.05 MHz standalone Fmax

Full K5 system:
    28,186 fitted LEs out of 49,760
    1,328,823 memory bits, about 79%
    52.11 MHz reported Fmax
    Configured clock: 50 MHz
    Worst reported setup slack: +0.809 ns
    Worst reported hold slack across corners: +0.141 ns
```

Positive slack means the reported path has time to spare under the applied
constraints. The full-system timing summaries are positive across their reported
checks. Both `.sof` and `.svf` files were generated.

The full build took about 37 minutes, including approximately 27 minutes fitting.
Standalone fitting took 18m20s and reported congestion/retry warnings before
completion. Lower area helped make a build practical, but does not guarantee every
future build has the same runtime or timing.

### The timing-flow caveat you should know

The installed `qsyn_xlr` flow references missing `$QSYN/basic.sdc`; Quartus derives
a clock to report Fmax. The saved opus reports show the same issue. We preserved
the course command and disclosed this limitation instead of silently changing
constraints. The complete system independently passes its actual default 50 MHz
constraints.

Remaining course-wrapper and RAM warnings are documented in RESULTS.md and retained
in the raw reports. We claim successful builds and the reported timing checks;
we do not claim a warning-free flow or physical-board validation.

## 18. What each tag means

| Tag | Main motivation | Measured takeaway |
|---|---|---|
| v0 | Establish a trusted course MRV baseline | 251.20 us hard1 app score |
| v1 | Shorten MRV's serial selection path | 5.13x better score; identical search |
| v2 | Batch deductions and roll back whole decision levels | 8.28 us hard1; area too large |
| v3 | Match the wrapper circuit to its three legal bursts | 23,949 → 17,199 mapped LEs |
| v4 | Simplify per-cell write logic | Isolated rewrite saves 2,627 mapped LEs |
| v5 | Reduce guessing through hidden singles | Broad-board winner; built 50 MHz system |
| v6 | Take the contradiction reduction off the write enables | 58.10 → 72.30 MHz; cycles byte-identical |
| v7 | Fold the MRV row stage into APPLY | One cycle off every guess; 72.05 MHz |

v3 and v4 were area/correctness checkpoints rather than fully timed bitstream
releases. v6 is a timed milestone with no bitstream of its own. v5 and v7 have
complete bitstreams from this work. A bitstream must never be labeled with a tag
it was not built from.

You can examine the actual changes:

```sh
git show v0:hw/xlrs/sudx_scan/sudx_scan_solver.sv
git diff v0 v1 -- hw/xlrs/sudx_scan/sudx_scan_solver.sv
git diff v1 v2 -- hw/xlrs/sudx_scan/sudx_scan_solver.sv
git diff v2 v3 -- hw/xlrs/sudx_scan/sudx_scan.sv
git diff v3 v4 -- hw/xlrs/sudx_scan/sudx_scan_solver.sv
git diff v4 v5 -- hw/xlrs/sudx_scan/sudx_scan_solver.sv
git diff v5 v6 -- hw/xlrs/sudx_scan/sudx_scan_solver.sv
git diff v6 v7 -- hw/xlrs/sudx_scan/sudx_scan_solver.sv
```

## 19. How to explain the project aloud

### A short explanation

> I started from the course MRV solver and first fixed its long combinational
> minimum-selection chain. Then I changed the architecture to apply all forced
> Sudoku deductions in batches. Only guesses are stored on a stack; every cell
> records which guess level created it, so rollback erases a whole failed level
> in parallel. I reduced wrapper and cell-write logic to keep area manageable,
> then added hidden singles to reduce search on difficult boards. I measured both
> cycles and frequency, tested thousands of boards, and built a full system that
> meets 50 MHz timing. Physical-board validation is the next step.

### Questions you should be able to answer

**Why use MRV?** It chooses a cell with few choices, which often exposes a bad guess
earlier. It is a heuristic, and the exact tie order affects the search.

**Why does a tree help?** Comparisons at the same level run in parallel. The longest
dependency chain is much shorter than scanning all candidates through one running
minimum.

**What is the difference between naked and hidden singles?** A naked single has one
digit available for a cell. A hidden single has one cell available for a digit in
a unit.

**What makes batching safe?** All deductions use one snapshot. Contradictions are
checked before completion, including duplicate placements exposed by the next
scan. The testbench independently validates the resulting board.

**How can you undo many deductions without saving the whole board?** Tag each
assignment with the active decision depth. Erase that depth when its guess fails.
Parent assignments remain, and deeper assignments were already erased.

**Why not reset every stack entry?** Depth determines which entries are valid.
After reset, no entry is valid until a new guess writes it. Avoiding a reset loop
also enables memory inference.

**Why was the wrapper worth optimizing?** General indexing expressed far more
routing choices than the fixed three-burst protocol needed. Explicit slices saved
thousands of LEs without changing transfers or application cycles.

**Why is v5 not the best hard1 score in the table?** v2 is marginally better on that
one board but has too much area and much worse broad-board search. We selected the
version with a better overall result and a completed, timing-checked system build.

**Is 72.05 MHz the physical clock?** No. It is standalone Fmax used by the assignment
score. The bitstream runs at the clock `comp_fpga` was configured for.

**Has it been tested on the FPGA?** Not yet. Simulation, implementation and bitstream
generation passed; the physical test remains necessary.

## 20. What could improve next, and why it was not changed in the v5 release

These are hypotheses, not measured gains.

### A. Target the measured propagation critical path

The final standalone worst-path report includes:

```text
From: candidate[66][0]
To:   assigned_depth[20][2]
```

This crosses from a candidate register through inference/control logic to an
assignment-depth register. The detailed path should guide any next circuit change.
The endpoint alone does not prove which one gate or wire is the bottleneck.

Possible experiments include restructuring shared validity signals or inserting a
pipeline stage. But another propagation cycle has a real cost:

```text
Suppose a workload is dominated by two-cycle rounds.
Changing each round to three cycles adds about 50% to that portion of the work.

To break even on that portion:
    new_Fmax > old_Fmax * 3/2
             > 58.10 * 1.5
             > 87.15 MHz

Actual whole-board behavior must be measured; guesses and overhead also matter.
```

### B. Reduce cycles spent choosing a guess

A guess currently uses PICK_ROWS, PICK_CELL and PLACE after the deduction check.
An experiment could combine some work with APPLY. It might save cycles, but could
lengthen the critical path and reduce Fmax. Preserve MRV ties to isolate the effect.

### C. Try stronger Sudoku deductions

Locked candidates and pairs could reduce some search trees. They also need more
logic and careful treatment of candidate eliminations during rollback. Our current
candidates are rebuilt from placed digits; extra eliminations cannot simply be
assumed to survive that rebuild. A stronger design would need an explicit plan
for recomputation or storage/undo of those eliminations.

### D. Investigate wrapper overhead after measuring on hardware

On easy boards the app overhead dominates the core. Any further wrapper change
must preserve the course protocol and permitted timing window. Changing C timers
or moving work outside the timed region would undermine comparability and is not
part of this release.

### E. Extend validation if the invocation contract changes

Back-to-back commands without reset, other board dimensions, and the hackathon
variant are not supported claims of this design. They need their own changes and
tests, not just a parameter rename. No work on the unknown variant was attempted.

## 21. v6 and v7: acting on the measured critical path

Section 20 listed targeting the measured critical path (A) and reducing guess
overhead (B) as the two most promising next steps. Both were done, and the
result is worth reading together with section 20, because the outcome differed
from what the arithmetic there predicted.

### Reading the v5 report properly

All twenty of v5's worst paths shared one endpoint pattern: they started at a
`candidate` register and ended at an `assigned_depth` register. Adding up the
increments in the report splits the 16.85 ns data path like this:

```text
    2.7 ns   candidate -> candidate_union -> unique_digit   (hidden singles)
    4.2 ns   per-cell forced[] and dead_cell[] terms
    5.8 ns   81-input OR of dead_cell, 27-input OR of no_home -> propagate
    4.2 ns   propagate -> the write enable of every cell register
```

Nearly 60% of the period was spent deciding whether the board had become
contradictory, and then broadcasting that decision to roughly 1300 register
enable inputs. Only the first two lines are Sudoku.

### v6: the reduction does not need to gate the writes

`propagate` gated the cell writes so that a contradicted round could not corrupt
the board. It turns out it cannot corrupt the board anyway:

```text
forced[c] is derived only from candidate[c], and SCAN sets candidate[c] to zero
for every filled cell. So a forced write can only ever land on an empty cell:
no given and no parent assignment is at risk.

Every forced write sets assigned_depth[c] to the current depth.
A contradiction always goes to BACK_READ and then BACK_APPLY.
BACK_APPLY clears every cell whose assigned_depth equals the current depth.

So the extra writes are erased before any later cycle reads the board.
```

The change is three lines: a separate `contradiction` wire for the state
machine, and `propagate` reduced to `state == APPLY`. The 5.8 ns reduction and
the 4.2 ns fanout both leave the write path; the reduction still exists, but it
now drives a four-bit state register instead of 1300 enables.

Because the search is untouched, the regression is an equality check. Cycles and
grids are byte-identical to v5 on all 3,739 runs. Fmax went from 58.10 to
**72.30 MHz**, and fitted area went *down* slightly, from 17,219 to 17,142 LEs.

### v7: the row tournament does not need a cycle

After v6 the worst paths split between the MRV row tournament and the
contradiction reduction. Section 20B worried that folding selection into APPLY
would lengthen the critical path. It does not, provided you fold only the
scheduling and not the logic:

```text
The row tournament reads candidate[] and empty_q[], both written by SCAN.
Nothing writes them again until the guess is placed.
So the tournament's inputs are already valid during APPLY.
```

Registering the row winners during APPLY therefore removes the `PICK_ROWS`
state without changing one gate of the tournament: it is the same combinational
path from the same registers to the same destination, merely enabled in a
different state. A round that ends in propagation computes winners and discards
them. A guess costs two cycles instead of three.

That is 3,949 cycles removed from the 513-board set, 4.83% of its total, and
5.23% off the published-holdout mean. Grids are identical everywhere; each
puzzle simply loses exactly one cycle per guess it made. Fmax measured
**72.05 MHz**, unchanged from v6 within fitter noise.

### Two variants that were measured and rejected

Both are preserved with their reports in `logs/experiments/`.

**Registering candidate counts in SCAN.** The obvious way to shorten the MRV
path is to store a four-bit count per cell during SCAN so the tournament reads
registers instead of recomputing `count9`. It works, and it does remove the
tournament from the worst-path list — but 323 extra registers and 448 extra
logic elements cost 1.2 MHz, and it reaches exactly the cycle count that v7
reaches for free. Shortening a path is not the same as raising the clock.

**`v & (v - 1)` instead of `first_digit`.** The tests for "at most one bit set"
and "two or more bits set" can be written with the classic borrow trick instead
of building the priority mask and comparing nine bits. The two forms are the
same function, and the regression confirms identical results. On this MAX 10
device it is much worse: 63.10 MHz and 19,164 LEs, against 70.84 MHz and 17,590
for the identical design without it. A nine-bit borrow chain is not cheaper than
the prefix-OR logic Quartus infers from the explicit form.

### A measurement caveat worth knowing

v7 cuts hard1's solver time from 217 cycles to 202, and the reported application
count stays at 483. The application polls `HOST_REG(XLR_DONE_RI)` in a busy
loop, so any saving smaller than one poll interval is invisible to it. The
saving is real — it shows plainly in the direct RTL counts and in the
published-holdout mean — but on the four course boards the score improves only
through frequency. Do not read an unchanged application count as an unchanged
solver.

## 22. Read, reproduce, and program

Start with these files:

```text
README.md                              How to run the course flow
RESULTS.md                             Measurements and caveats
docs/DESIGN_WALKTHROUGH.md             This explanation
docs/BATCH_DESIGN.md                    Short architecture description
docs/HARDWARE_HANDOFF.md                Programming instructions
hw/xlrs/sudx_scan/sudx_scan_solver.sv    Complete final solver
hw/xlrs/sudx_scan/sudx_scan.sv           Wrapper
bench/tb_solver.sv                      Independent RTL checker
docs/RUNNING.md                         Short guide to running the full batch
logs/v7/build_source.json               RTL and bitstream SHA-256 hashes
logs/v7/synthesis/                      Standalone reports
logs/v7/fpga/                           Complete-system reports
logs/experiments/                       Measured variants that were rejected
```

For a direct RTL regression on the course boards, from the repository root:

```sh
bash bench/rtl.sh bench/puzzles/repo4.txt logs/local-check/repo4
```

For the course integrated simulation, use separate terminals with the same setup:

```sh
# Terminal 1, starting in the repository root:
source bench/env.sh
set_k5_terminal
launch_k5_sim sudx_scan
```

```sh
# Terminal 2, starting in the repository root:
source bench/env.sh
set_k5_terminal
launch_k5_app sudx_scan -asl sud_shared -gpv hard1
```

For physical-board testing, follow the course laptop setup and handoff instructions:

```sh
set_k5_terminal
prog_fpga sudx_scan
launch_k5_app sudx_scan -asl sud_shared -gpv hard1
```

Use the release's fingerprints to ensure that the source and bitstream correspond.
If you edit Verilog later, rebuild and revalidate before associating the old
programming files with the new source. Keep the v5 and v7 releases as reproducible
references while exploring the next hypothesis.
