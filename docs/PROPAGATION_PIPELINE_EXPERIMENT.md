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
rollback sequence is unchanged. On all 4,347 RTL executions, outcomes and search
choices match v2/v3; solved cycle counts increase by exactly the recorded number
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
still unavailable. The next step is a full-system 50 MHz build.
