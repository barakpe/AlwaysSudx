# AlwaysSudx — inequality Sudoku on FPGA

This branch contains the hackathon inequality variant, `ineqsudx_scan`.
The hardware-validated classic v5 remains on `main` and tag `v5`.

This branch contains **ineq-v4**, a propagation pipeline candidate. It passes
**4,347 RTL executions**, all 19 solvable course application cases, and both
impossible application cases. Standalone Fmax is **87.83 MHz**, with **22,289 LEs**.
The full system fits **34,627 LEs** and meets its configured **50 MHz** timing.

Mean course-normalized time is **3.9604 us**, 10.96% lower than v3 on the 19-case
development set. The four available benchmark rows improve by 8.53%. The extra
cycle per propagation round makes larger solver-only workloads slower on average,
so **v3 remains on `hackathon/ineq` and its own release**. At the same physical
50 MHz, v4's mean is 6.9568 us versus v3's 6.5021 us. v4 hardware testing is pending;
the user's complete hardware validation applies to v2.

The course has published a benchmark spreadsheet but not the four unseen puzzle
files it names. See [benchmark status](docs/BENCHMARK_STATUS.md); partial totals
are explicitly marked and do not claim a complete competition score.

## Read the design

- [v4 explanation with RTL and intuition](docs/PROPAGATION_PIPELINE_EXPERIMENT.md):
  motivation, register placement, correctness, and when the tradeoff wins.

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
MRV counts without additional cycles; `ineq-v4` adds a propagation decision stage. Experimental sources
and measurements remain under `bench/ineq/experiments` and `logs/experiment-*`.

Use the GitHub release assets for programming files, the course submission TGZ,
source ZIP, explanation, and SHA-256 provenance. A release's notes identify its
configured hardware clock and whether execution on a physical board was tested.
