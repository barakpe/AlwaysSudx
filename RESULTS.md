# Measured results

No hardware execution has been performed for AlwaysSudx.

| Version | Architecture | Core cycles easy / 20 / 51 / hard1 | Standalone MHz | Mapped / fitted LEs | top95 mean / worst core cycles |
|---|---|---|---|---|---|
| v0 | Course MRV, serial minimum chain | 86 / 103 / 134 / 981 | 4.98 | 13,026 / 12,200 | 35,957.46 / 596,919 |
| v1 | Balanced MRV tournament | 86 / 103 / 134 / 981 | 25.57 | 13,408 / 12,645 | 35,957.46 / 596,919 |

Application cycle counts are stored in each version's `*.app.log`. These include
setup/load and the course polling granularity; they are not the direct core cycles
in the table. Compare like timing windows when using cycles / standalone MHz.

## v0 evidence and warnings

All 95 top95 boards and the four course boards pass the independent RTL checker.
Raw per-board cycles and complete solutions are in `logs/v0/{repo4,top95}/cycles.txt`.
Synthesis, fit, STA and critical paths are in `logs/v0/synthesis/`.

The course `qsyn_xlr` installation references missing `$QSYN/basic.sdc`. Quartus
therefore derives a clock and reports Fmax; **this does not demonstrate closure at
50 MHz**. The same warning is present in the saved opus synthesis reports. We keep
the course command and constraints unchanged for comparability. Full-system timing
must be evaluated with `comp_fpga` before selecting an operating clock.

Other baseline warnings: course wrapper truncates its 32-bit board address to the
16-bit XMEM address and burst sizes to six bits (all bursts are <=32). Dummy wrapper
read-pulse inputs are undriven, and unused/dangling ports and constant output bits
are reported. These belong to the supplied wrapper/harness. The retained course
MRV `busy` output is intentionally unconnected. No inferred latch is reported.

## Comparison target

AlwaysSud `explore/opus5-phases` (`5a227db`) promotes `s2fastmrv`: 26.36 MHz,
28,396 mapped / 27,714 fitted LEs. Its published direct-RTL counts are
6 / 23 / 54 / 193 using its original testbench edge convention. We will re-run
that solver with this repository's checker before claiming a performance win.

Baseline K5 application: all four final checkers PASS. Whole-window cycles
(easy1 / 20blanks / 51blanks / hard1): **363 / 363 / 411 / 1,251**.
The hard1 assignment score is **251.20 us** (1,251 / 4.98).

## v1: balanced tournament

Seven comparison levels replace the serial 81-cell chain. Raster tie-breaking
and all 95 cycle counts/solutions are unchanged. Standalone frequency rises
from 4.98 to 25.57 MHz (**5.13x**). The K5 hard1 window remains 1,251 cycles,
so its score falls from 251.20 to **48.92 us**. Quartus required explicit
generate blocks and separately declared genvars; the failed syntax logs are
retained. Course harness/constraint warnings remain as described above.
