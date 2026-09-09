# AlwaysSudx — inequality Sudoku on FPGA

The complete eight-board course benchmark selects **ineq-v4**:
**3,120 cycles / 87.83 MHz = 35.5232 us**, 8.32% lower normalized time than
v3's **2,832 cycles / 73.09 MHz = 38.7468 us**. Both versions pass both course
checkers on all eight boards. [Results and exact rows](docs/BENCHMARK_RESULTS.md).

This branch retains v3. The selected v4 is on `hackathon/propagation-pipeline`
and release `ineq-v4`.

Both images meet full-system timing at their configured 50 MHz. v4 uses
34,627 full-system LEs, with 56.58 MHz full-system Fmax. Its eight-board physical
time at 50 MHz is 62.40 us versus v3's 56.64 us. The improvement is in the course
score using standalone Fmax. v3/v4 hardware testing is pending; the user's full
hardware validation applies to v2. The classic v5 remains on `main`.

Use the complete workbook for the selected release. Only the eight inequality
rows contribute; the unrelated project column is blank. Earlier partial sheets
and 19-case development averages are retained as historical evidence.

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
