# Course benchmark status

All eight inequality rows are now measured using course commit
`f430fcffd5321bfe35a32c2cf1f997356e8285b1`. No benchmark input is missing.
See [the complete results](BENCHMARK_RESULTS.md).

v4 totals **3,120 cycles / 87.83 MHz = 35.5232 us**, versus v3's
**2,832 cycles / 73.09 MHz = 38.7468 us**. v4 is 8.32% lower on this metric.
All eight application tests pass both supplied checkers in both versions.

The `benchmark-ineq-v3-complete.xlsx` and `benchmark-ineq-v4-complete.xlsx`
files fill only the inequality column; project values are blank. The original
course template remains in `course/sud_benchmark.xlsx`. Older partial workbooks
are historical and should not be submitted in place of the complete workbook.

The user list repeated `plain`; the workbooks follow the official spreadsheet,
whose fourth seen inequality row is `ineq/set1/sparse_ineq`.
