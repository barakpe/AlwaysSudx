# Extra propagation stage: measured benefit and limits

The v3 timing bottleneck moved from MRV counting to the path from registered
hidden-single information, through per-cell pruning, to the global state-machine
decision. This experiment starts from the triplet MRV alternative and separates
local pruning flags from their board-wide reduction.

```text
SCAN:    register unit summaries and triplet MRV winners
DOMAIN:  update candidate domains; register changed/dead/singleton flags
DECIDE:  reduce those registered flags; select repeat, guess, success, or failure
```

This deliberately adds **one cycle per propagation round**. The guess and
rollback sequence is unchanged. On all 4,347 RTL executions, outcomes match v2/v3; solved records also
preserve search choices; solved cycle counts increase by exactly the recorded number
of propagation rounds. Domain snapshots and the host interface are unchanged.

Standalone synthesis reaches **87.83 MHz**, using **22,289 fitted LEs** and
3,276 registers. The registered flags shorten the previous critical path, but
more clock cycles must be included when judging the result.

| Corpus | v3 mean core time at 73.09 MHz | Extra-stage mean core time at 87.83 MHz |
|---|---:|---:|
| 19 solvable official cases | 0.7619 us | 0.8689 us |
| 3,700 classic cases | 6.6815 us | 7.4885 us |
| 300 generated inequality cases | 3.9330 us | 4.3996 us |
| 285 difficult inequality cases | 1.0780 us | 1.2418 us |

These are solver-only times, **not full application scores**. The complete
application includes fixed overhead, which changes the tradeoff. The extra
stage can win the supplied short application tests while losing average core
time on broader puzzles. This is why v3 is retained as a separate candidate,
and why neither result proves a global optimum. Final selection on the official
benchmark requires the four named but currently unavailable unseen boards.

All computation still starts at SOLVE and remains inside the unchanged timer.
The course commands, constraints, C algorithm, and data encoding are unchanged.

## Completed application measurements

All 19 solvable cases pass both checkers. Mean application cycles are 347.8421;
normalized time is 3.9604 us at 87.83 MHz. The four available inequality
benchmark rows total 1596 cycles, or 18.1715 us. The four unseen files are
still unavailable. The full-system 50 MHz build is complete: 56.58 MHz Fmax,
34,627 fitted LEs, 173/182 M9Ks, and all reported timing slacks nonnegative.
Physical hardware execution remains pending.


## Intuition: shorter clock paths can justify more cycles

A register is a stopping point for combinational work. Before this change, one
clock period had to accommodate both each cell's deductions and the decision
about the entire board. The added register lets those two tasks use separate
clock periods. Each period can be shorter, but every round now needs three
periods instead of two.

```text
v3 round: SCAN -> DOMAIN -----------------> next round or search
v4 round: SCAN -> DOMAIN -> DECIDE --------> next round or search

v3 normalized application time = C / 73.09
v4 normalized application time = (C + extra application cycles) / 87.83

v4 wins when:
extra application cycles / C < 87.83 / 73.09 - 1
                            < 20.167%
```

The 19-case mean grows from 325.1053 to 347.8421 application cycles, about 6.99%.
That is below the 20.17% break-even increase, so normalized time falls by 10.96%.
For long puzzles dominated by repeated propagation, the extra cycle matters
more. The larger regression corpora demonstrate that cost. The actual course
application logs determine the application score; we do not derive application
counts by simply adding core rounds to an old application measurement.

At a fixed physical clock of 50 MHz, no shorter clock period is available:
those additional cycles increase the 19-case mean from 6.5021 to 6.9568 us.
The improved course-normalized score does not mean this 50 MHz bitstream solves
those boards faster in wall-clock time than the 50 MHz v3 bitstream.

## The actual RTL change

Inside each cell, sample the local facts at the same clock edge that updates
the domain. These are nonblocking assignments, so all facts describe the same
pre-edge board state and its proposed next domains.

```systemverilog
always_ff @(posedge clk) if (state == DOMAIN) begin
    changed_q[c] <= changed[c];
    cell_dead_q[c] <= cell_dead[c];
    singleton_q[c] <= singleton[c];
end
```

The control path consumes those facts in the following cycle:

```systemverilog
SCAN: state <= DOMAIN;
DOMAIN: state <= DECIDE;
DECIDE: begin
    if (invalid_input || (|unit_dead) || (|cell_dead_q)) state <= BACK_READ;
    else if (&singleton_q) state <= FINISH_OK;
    else if (!(|changed_q)) state <= PICK_ROWS;
    else state <= SCAN;
end
```

The ordering matters: a contradiction takes priority over a completed-looking
board. A changed board gets another propagation round. Only a stable,
incomplete board enters MRV search.

## Why the earlier MRV calculations remain valid

The triplet tree begins choosing a cell during SCAN, before DOMAIN potentially
changes candidates. We use that choice only if the later DECIDE finds no
changes. In that case, the domains used by MRV equal the current domains.
If any domain changed, the solver repeats SCAN and refreshes the MRV metadata.

```text
DOMAIN changed something -> discard old MRV choice; repeat propagation
DOMAIN changed nothing   -> earlier MRV choice still describes this board
```

The singleton flags intentionally describe the old DOMAIN input, matching the
previous solver's termination rule. Using new singleton flags could remove a
round, but would be a different semantic change needing separate validation.
Snapshot writes still occur in PICK_ROWS, PICK_CELL, and PLACE; DECIDE does not
write a snapshot or modify a domain. Thus rollback restores the same parent
and selects the same alternatives as before.

## What the evidence does and does not establish

All 4,347 direct RTL executions preserve the solved/rejected outcome.
Solved records also preserve the recorded search sequence. Every solved record's extra core cycles equal its propagation-round
count. The 19 full application runs separately confirm the real timer and both
course checkers. Two negative application runs confirm that contradictions
report non-solved rather than a false success.

These results support this implementation on the measured cases. They do not
prove optimality over all architectures or establish the unseen benchmark
winner. We keep v3 and v4 as separate branches and releases so the final cases
can decide between their different cycle/frequency tradeoffs.
