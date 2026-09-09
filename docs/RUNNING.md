# Running the full batch — classic v5 (`main`)

Everything below runs from the repo root on the course RC machine.
Accelerator name is `sudx_scan`; app name is `sudx_scan` with library `sud_shared`.

## 0. Per terminal, once

```sh
source bench/env.sh
```

Loads the course environment, then points `MY_K5_PROJ` / `MY_K5_XLRS` / `K5_SW_APPS`
at *this* tree instead of `~/ws/my_k5_proj`. Every script below sources it itself,
so you only need this for manual `launch_k5_*` / `qsyn_xlr` commands.

## 1. RTL regression (fastest check — do this first)

```sh
bash bench/rtl.sh bench/puzzles/standard.txt      logs/local/standard
bash bench/rtl.sh bench/puzzles/ho_published.txt  logs/local/published
bash bench/rtl.sh bench/puzzles/unsat.txt         logs/local/unsat "" 1
```

Writes `<out>/cycles.txt` as `index cycles PASS <81-digit grid>`. The testbench
checks givens, digit range, and all 27 units, and `$fatal`s on any failure — so
"no error + `REGRESSION PASS`" is the pass condition. The 4th argument `1` means
*expect unsatisfiable* (`PASS_UNSAT`).

Sets: `standard` (513 — the 4 course boards, top95, 400 generated, 11 difficult
holdouts and 3 corner cases), `top95`,
`gen_classic_min` (400), `ho_hardest` (11), `ho_published` (3191),
`corners` (3), `unsat` (35), `repo4` (the 4 course boards).

## 2. K5 application in simulation

Two terminals, the course way:

```sh
# terminal 1                    # terminal 2
source bench/env.sh             source bench/env.sh
set_k5_terminal                 set_k5_terminal
launch_k5_sim sudx_scan         launch_k5_app sudx_scan -asl sud_shared -gpv hard1
```

Or one command per board, which starts both and asserts the checker passed:

```sh
for b in easy1 20blanks 51blanks hard1; do bash bench/sim.sh $b logs/local/app; done
```

The simulator uses a per-user socket — run boards **sequentially**, not in parallel.
Reference application cycles: `267 / 267 / 291 / 483` in that board order.

## 3. Standalone synthesis (area + the Fmax used for scoring)

```sh
bash bench/synth.sh                 # ≈ 20 min (fit dominates)
```

Runs `qsyn_xlr sudx_scan -all` in `hw/xlrs/sudx_scan/` and greps the three logs for
success, because the course wrapper can exit 0 after a Quartus failure.
Reports land in `hw/xlrs/sudx_scan/qsyn_output_files/` — take Fmax from
`sudx_scan.sta.rpt` (Slow 1200mV 85C) and LEs from `sudx_scan.fit.summary`.
Score = application cycles ÷ this standalone Fmax.

## 4. Full-system build → `.sof` / `.svf`

```sh
bash bench/fpga.sh                  # ≈ 37 min
```

Runs `comp_fpga sudx_scan` in `hw/gen_fpga/`, then moves the artifacts out of the
Desktop link into `hw/gen_fpga/prog_files/`. It **refuses to run** if a file of
that name is already sitting in the Desktop drop, so clear it first if you rebuilt.
Full-system Fmax is printed at the end of the run and in
`hw/gen_fpga/output_files/k5_xbox_rc3.sta.rpt`; the configured clock is 50 MHz.
For another clock: `comp_fpga sudx_scan -mhz 40` (integer MHz). Timing must pass
at the clock you actually configure.

## 5. On the physical board (your laptop, not RC)

Copy `hw/gen_fpga/prog_files/k5_xbox_sudx_scan.sof` into your laptop's
`$MY_K5_PROJ/fpga_prog_files/`, plus `sw/apps/sudx_scan/` and `sw/apps/sud_shared/`.

```sh
set_k5_terminal
prog_fpga sudx_scan
launch_k5_app sudx_scan -asl sud_shared -gpv hard1
```

Details and the artifact checksums: [HARDWARE_HANDOFF.md](HARDWARE_HANDOFF.md).

## Shortcut scripts — what each one is

| Script | Does |
|---|---|
| `bench/env.sh` | Sources the course env, then repoints it at this tree. Sourced by all others. |
| `bench/rtl.sh <set> <out> [solver] [expect_fail]` | Xcelium run of `bench/tb_solver.sv` over a puzzle file → `cycles.txt`. Optional 3rd arg points at an alternative solver `.sv`, so an experiment runs without touching `hw/`. |
| `bench/sim.sh <board> <out>` | Launches `launch_k5_sim` + `launch_k5_app` together, saves both logs, asserts the final checker passed. |
| `bench/synth.sh` | `qsyn_xlr sudx_scan -all` + real success checks on map/fit/sta logs. |
| `bench/synth_snapshot.sh <solver.sv> <out> [-syn\|-all]` | Same synthesis on a *copied* source tree, so an experiment can run while `hw/` stays on the current milestone. Records `source.sha256`, copies reports to `<out>/synthesis/`. |
| `bench/fpga.sh` | `comp_fpga sudx_scan`, collects `.sof`/`.svf` into `hw/gen_fpga/prog_files/`, refuses to overwrite. |
| `bench/compare_opus.sh <set> <out>` | Same testbench and cycle convention against `bench/opus/` (the AlwaysSud reference), for apples-to-apples cycle comparison. |

There is no single "run all" script on `main`; steps 1–4 are separate on purpose
because 3 and 4 are long and licence-bound.

## Does this apply to the inequality variant?

**The flow is identical; the names are not.** `hackathon/ineq` is a different
accelerator (`ineqsudx_scan`) with an extra `relations` port and a different puzzle
file format, so `bench/rtl.sh`, `bench/tb_solver.sv` and `bench/sim.sh` from `main`
do **not** work there. Use the parallel wrappers under `bench/ineq/`:

| main | `hackathon/ineq` |
|---|---|
| `bench/rtl.sh` | `bench/ineq/rtl.sh` (+ `bench/ineq/regress.sh <solver> <out>` runs all six sets) |
| `bench/sim.sh <board> <out>` | `bench/ineq/sim.sh <board> <out> [solved\|unsolved] [alt_xlrs]` (+ `bench/ineq/all_apps.sh <out>` runs all 19 boards) |
| `bench/synth.sh` | `bench/ineq/synth.sh` |
| `bench/synth_snapshot.sh` | `bench/ineq/snapshot.sh` |
| `bench/fpga.sh` | `bench/ineq/fpga.sh` |
| `-gpv hard1` | `-gpv ineq/set1/hard1` (course boards `easy1` … still work) |

`bench/env.sh` is byte-identical on both branches, so step 0 is the same, and
steps 3–5 are the same commands with `sudx_scan` → `ineqsudx_scan`.
See [INEQUALITY_HARDWARE_HANDOFF.md](INEQUALITY_HARDWARE_HANDOFF.md) on that branch.

The other `hackathon/*` and `improve/*` branches are experiment snapshots on one of
these two solvers and use whichever wrapper set their accelerator name matches.
