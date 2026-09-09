# AlwaysSudx — inequality Sudoku on FPGA

This branch contains the hackathon inequality variant, `ineqsudx_scan`.
The hardware-validated classic v5 remains on `main` and tag `v5`.

The selected variant is **ineq-v3**, which registers MRV candidate counts during
an existing propagation cycle. It matches v2 across **4,347 RTL executions**
and all 19 solvable course application cases, while raising standalone Fmax
from **69.62 to 73.09 MHz** and lowering standalone area to **21,968 fitted LEs**.

Mean normalized time is **4.4480 us**, 4.75% lower than v2 and 28.34% lower than
the first inequality baseline on the unweighted 19-case development set.
The full system fits **34,571 LEs** and passes timing at its configured **50 MHz**.
At that physical clock, cycle counts and execution time are unchanged from v2.
The user has hardware-validated v2; **v3 hardware execution is pending**.

The course has published a benchmark spreadsheet but not the four unseen puzzle
files it names. See [benchmark status](docs/BENCHMARK_STATUS.md); partial totals
are explicitly marked and do not claim a complete competition score.

## Read the design

- [Simple, detailed design explanation](docs/INEQUALITY_DESIGN.md): masks,
  inequalities, propagation, hidden singles, MRV, rollback, RAM packing, and why
  adding a pipeline stage improved the result.
- [MRV pipeline experiments](docs/MRV_PIPELINE_EXPERIMENTS.md): the scheduling
  invariant, the two tested selection circuits, and measured outcomes.
- [Results](docs/INEQUALITY_RESULTS.md): named-board application counts and
  cycles/Fmax comparisons, with measured timing and resources.
- [Experiment history](docs/INEQUALITY_PROGRESS.md): what was tried, retained,
  or rejected, including the slower-clock v1 experiment.
- [Hardware handoff](docs/INEQUALITY_HARDWARE_HANDOFF.md): installation, exact
  application commands, checker expectations, and artifact verification.
- [Classic v5 results](RESULTS.md): the separate original solver's historical
  measurements. The user subsequently reported exact hardware/simulation cycle
  agreement on all four course boards: hard1 483, easy1 267, 20blanks 267,
  and 51blanks 291.

## Implementation

```text
hw/xlrs/ineqsudx_scan/
    ineqsudx_scan_solver.sv    domain engine and balanced reduction helper
    ineqsudx_scan.sv           unchanged host protocol; retains inequality bits
    ineqsudx_def_pkg.sv        hardware/software register definitions
    ineqsudx_scan.f            course source list

sw/apps/ineqsudx_scan/         application, header, and enum contract
sw/apps/sud_shared/           supplied hackathon library and official boards
bench/ineq/                  course-command wrappers and RTL regressions
logs/ineq-v0/                functional baseline and standalone measurements
logs/ineq-v1/                packed engine; includes failed 50 MHz timing report
logs/ineq-v2/                pipelined engine and release evidence
```

All solving is in Verilog. The only application behavior change is the
course-required `verify(board)` call. The supplied shared C library is unmodified.
The original timing window and SETUP/SOLVE commands are retained.

## Reproduce on the cloud

Source the helper to select this checkout as the course project:

```bash
source bench/env.sh
set_k5_terminal
launch_k5_app ineqsudx_scan -asl sud_shared -gpv ineq/set0/single
```

In a second terminal, select the same project and start the simulator:

```bash
source bench/env.sh
set_k5_terminal
launch_k5_sim ineqsudx_scan
```

The direct RTL regression supplements the official application checker:

```bash
bash bench/ineq/rtl.sh bench/ineq/puzzles/official.txt logs/local/official
bash bench/ineq/rtl.sh bench/ineq/puzzles/heldout.txt logs/local/heldout
```

Synthesis and bitstream generation use the provided course utilities:

```bash
cd "$MY_K5_XLRS/ineqsudx_scan"
qsyn_xlr ineqsudx_scan -all

cd "$MY_K5_PROJ/hw/gen_fpga"
comp_fpga ineqsudx_scan
```

The course also supports `comp_fpga ineqsudx_scan -mhz 40` for a 40 MHz system.
Choose a physical clock that meets the full-system timing report. Solver
selection uses application cycles divided by **standalone** Fmax; a frequency
below 50 MHz is acceptable when that ratio improves.

## Versions and releases

`ineq-v0` preserves the first verified baseline; `ineq-v1` records the packed
domain redesign; `ineq-v2` records domain propagation pipelining; `ineq-v3` records registered
MRV counts without additional cycles. Experimental sources
and measurements remain under `bench/ineq/experiments` and `logs/experiment-*`.

Use the GitHub release assets for programming files, the course submission TGZ,
source ZIP, explanation, and SHA-256 provenance. A release's notes identify its
configured hardware clock and whether execution on a physical board was tested.
