# Course benchmark status

The spreadsheet at course commit `0db0f3f99e65735f4b991ba02489dd4967cd86e3` lists the assessment cases.
The only repository change since the prior reference is the spreadsheet;
no unseen puzzle files accompany it yet.

| Submission | Seen cases | Unseen cases still missing |
|---|---|---|
| Project | easy1, 20blanks, 51blanks, hard1 | std/hard5, std/hard8 |
| Inequality variant | ineq/set0/single, ineq/set0/ascend, ineq/set0/plain, ineq/set1/sparse_ineq | std/hard5, std/hard8, ineq/set2/superhardA, ineq/set2/xsparse2 |

The template sums the listed cycle counts and divides by standalone Fmax.
Its existing large cycle values and Y/N flags are examples, not course results.

`course/sud_benchmark.xlsx` preserves the original template.
`benchmark-ineq-v3-partial.xlsx` replaces examples with measured results for
classic v5 and inequality v3, leaves missing cases blank, and explicitly labels
the totals as measured-case subtotals. It is not a complete competition score.
The project seen subtotal is 1,308 cycles / 58.10 MHz = 22.5129 us.
The inequality seen subtotal is 1,452 cycles / 73.09 MHz = 19.8659 us.
The 19-board unweighted development average is a separate comparison.

v3 also supports and has passed the four original classic cases, even though
the template does not require those four in the inequality column. The user
has been asked for a path/link if the missing puzzles were supplied elsewhere.


The separate `benchmark-ineq-v4-partial.xlsx` uses v4's measured variant values:
315 / 267 / 555 / 459 cycles for single / ascend / plain / sparse_ineq.
Its known subtotal is **1,596 cycles / 87.83 MHz = 18.1715 us**, 8.53% lower
than v3's known subtotal. Classic v5's project column is unchanged. Missing
values stay blank. v4 is a candidate for this supplied-case metric; v3 retains
better mean solver-only time on the larger regression corpora. Neither partial
workbook establishes a winner on the unavailable complete benchmark.
