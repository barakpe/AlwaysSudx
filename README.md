# AlwaysSudx

Classic 9x9 Sudoku accelerator for DDP26 K5-XBOX. **Final version: v5.**

- hard1 course score: **8.31 us**, versus **251.20 us** for our course MRV baseline.
- **3.20x better mean core cycles/Fmax than opus** on 3,191 published holdout runs.
- **17,219 accelerator LEs**, **58.10 MHz** standalone Fmax.
- Full-system `.sof` and `.svf` built; **50 MHz timing passes**.
- 3,704 solvable-board runs, 35 rejection tests, and all four course app checks pass.
- Physical FPGA testing is the remaining user-side validation.

[Measurements and caveats](RESULTS.md) · [Readable architecture](docs/BATCH_DESIGN.md)
· [Hardware handoff](docs/HARDWARE_HANDOFF.md)

## Algorithm

The solver applies naked and hidden singles to all forced cells in a batch.
When propagation stalls, a pipelined MRV tournament chooses a guess. Only guesses
enter a small RAM stack. Per-cell depth tags let rollback clear an entire failed
level in parallel. Balanced mask trees detect occupancy, duplicates, hidden singles
and missing-digit contradictions. Contradictions take priority over completion.

The wrapper retains the course register protocol and 32+32+17-byte transactions;
fixed slices replace expensive general indexing. Only production Verilog changed.
The C driver and shared library remain byte-for-byte course copies.

## Course commands

This repository is an isolated K5 tree. Accelerator and app names remain
`sudx_scan` so the C application needs no changes. Source this in each terminal:

```sh
source bench/env.sh
```

It loads the installed course environment, then selects this repository without
changing account setup. Synthesis:

```sh
cd "$MY_K5_XLRS/sudx_scan"
qsyn_xlr sudx_scan -all
```

Simulation, terminal one:

```sh
set_k5_terminal
launch_k5_sim sudx_scan
```

Terminal two:

```sh
set_k5_terminal
launch_k5_app sudx_scan -asl sud_shared -gpv hard1
```

`bash bench/fpga.sh` runs the course `comp_fpga sudx_scan` command and collects its
Desktop-linked output back into this repository. Existing artifacts are protected
from overwrite. Generated files live in `hw/gen_fpga/prog_files/`.

Regression automation uses the same Xcelium tool: `bench/rtl.sh`, plus the unchanged
K5 flow via `bench/sim.sh`. No substitute FPGA synthesis tool or puzzle-specific
hardware is used.

## Git history and provenance

`v0` is the verified course MRV baseline; `v1` balances selection; `v2` introduces
batch propagation; `v3` reduces wrapper area; `v4` simplifies cell writes; `v5` adds
hidden singles and is fully built. Each change is a separate commit. Intermediate
area-only milestones are explicitly marked in RESULTS.md.

Course source: local ex3.1 commit `7b86385457f066c5a1872778cacd5f64ab6415de`,
https://github.com/DDP26-summer/ex3.1 . Baseline adaptation only renamed the MRV
module and output port. Course documents were copied from the user's AlwaysSud
repositories. Comparison RTL and original puzzle sets come from AlwaysSud opus
commit `5a227db`. Puzzle data is used only by verification, never as hardware
constants. This repository is local; nothing was pushed to GitHub.
