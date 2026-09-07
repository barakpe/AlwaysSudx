# AlwaysSudx

Independent classic 9x9 Sudoku accelerator experiments for DDP26 K5-XBOX.
The baseline is the course `claude_mrv` solver behind the **unchanged, corrected
course `sudx_scan` wrapper and C application**. Accelerator/app name stays
`sudx_scan`; this repository is an isolated K5 project tree.

Only synthesizable Verilog changes between algorithm milestones. The C driver,
host protocol, clock constraints, course commands and timing window remain fixed.
Scripts and testbench in `bench/` automate measurement and validate every given,
row, column and box. There is no puzzle-specific logic in the accelerator.

## Course flow

From this repository, source `bench/env.sh` to select this K5 project. It uses the
installed course environment; no global setup files are changed.

```
source bench/env.sh
cd "$MY_K5_XLRS/sudx_scan"
qsyn_xlr sudx_scan -all
```

Two terminals, each with the same environment:

```
set_k5_terminal
launch_k5_sim sudx_scan
```

```
set_k5_terminal
launch_k5_app sudx_scan -asl sud_shared -gpv hard1
```

Full bitstream:

```
cd "$MY_K5_PROJ/hw/gen_fpga"
comp_fpga sudx_scan
```

The expected output is `hw/gen_fpga/prog_files/k5_xbox_sudx_scan.sof`.
Hardware programming and measurements require the laptop and physical FPGA.

## Measurement

Assignment score: **reported application cycles / standalone qsyn_xlr Fmax MHz**.
Our course application times setup, load, solve and store together. The existing
AlwaysSud opus branch uses split timers, so its solve-window numbers must not be
compared directly with our whole-window numbers. Direct solver cycles offer an
additional consistent comparison, explicitly separate from the course score.

`v0` identifies the verified course MRV baseline. Each later milestone has a
separate commit, raw logs and a result entry. A simulation pass does not establish
timing closure or successful FPGA execution.

## Provenance

- Course baseline: local `ex3.1`, commit
  `7b86385457f066c5a1872778cacd5f64ab6415de`,
  https://github.com/DDP26-summer/ex3.1 .
- `v0` solver changes are only the module name and output port name needed by
  the course wrapper. The unused `busy` output is retained.
- Assignment and FPGA guides copied from the user's AlwaysSud repositories.
- Regression puzzles copied from AlwaysSud `explore/opus5-phases` at
  `5a227db`. `repo4`: four course boards; `top95`: published difficult boards;
  `ho_hardest`: existing held-out difficult boards; `gen_classic_min`: existing
  generated classic boards. These are test inputs, never hardware constants.
- Existing performance comparison target: `s2fastmrv`, standalone **26.36 MHz**,
  **28,396 mapped / 27,714 fitted LEs**, per its checked-in synthesis result.
