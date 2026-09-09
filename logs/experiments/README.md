# Measured experiments that were not adopted

Each directory holds the exact solver source, its standalone `qsyn_xlr -all`
summaries and its worst-path report. All of them were first proven to produce
identical cycles and identical solved grids to the milestone they branch from,
so the only thing being compared is area and frequency.

| Experiment | Branches from | Standalone Fmax | Fitted LEs | Kept? |
|---|---|---:|---:|---|
| `hidden_inference` | v2 | — | — | yes, became v5 |
| `mrv_registered_counts` | v6 | 70.84 MHz | 17,590 | no |
| `popcount_borrow` | v7 | 63.10 MHz | 19,164 | no |

## mrv_registered_counts

Adds a four-bit candidate count register per cell, written during SCAN, so the
MRV row tournament reads registered counts instead of recomputing `count9` from
`candidate`. This removed the tournament from the worst-path list, but the 323
extra registers and 448 extra logic elements cost more frequency than the
shorter path gained. Cycle counts are identical to v7, which reaches the same
cycle count without the added registers.

## popcount_borrow

Replaces the `first_digit` comparisons that test "at most one bit set" and "two
or more bits set" with the `v & (v - 1)` idiom. The two forms are the same
function and the regression confirms identical results, but on this MAX 10
device the nine-bit borrow chain is both slower and larger than the prefix-OR
logic Quartus infers from `first_digit`. Clearly rejected: 63.10 MHz against
70.84 MHz for the identical design without it.
