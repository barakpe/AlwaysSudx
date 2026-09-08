# AlwaysSudx — inequality Sudoku on FPGA

This branch contains the hackathon inequality variant, `ineqsudx_scan`.
The hardware-validated classic v5 remains on `main` and tag `v5`.

The selected variant is **ineq-v2**, a pipelined domain-propagation solver with
packed RAM snapshots. It passes **4,347 RTL executions**, including classic
Sudoku, inequality Sudoku, encoding corner cases, and expected rejections.
Standalone synthesis achieves **69.62 MHz** using **22,580 fitted LEs**.
The full-system image meets its configured **50 MHz** clock, using **35,152
fitted LEs**. Across the 19 supplied solvable cases, mean application cycles/Fmax
falls from **6.2066 to 4.6697 us (24.76%)** versus the inequality baseline.
This is an unweighted development comparison; physical execution of the variant
is pending. Standalone Fmax is not the programmed board clock.

## Read the design

- [Simple, detailed design explanation](docs/INEQUALITY_DESIGN.md): masks,
  inequalities, propagation, hidden singles, MRV, rollback, RAM packing, and why
  adding a pipeline stage improved the result.
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
domain redesign; `ineq-v2` records the pipeline improvement. Experimental sources
and measurements remain under `bench/ineq/experiments` and `logs/experiment-*`.

Use the GitHub release assets for programming files, the course submission TGZ,
source ZIP, explanation, and SHA-256 provenance. A release's notes identify its
configured hardware clock and whether execution on a physical board was tested.
