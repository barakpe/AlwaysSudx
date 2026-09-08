Pipelined inequality Sudoku solver, ready for DE10-Lite hardware testing.

- **24.76% lower mean cycles/Fmax** than the first working inequality baseline: 6.2066 -> 4.6697 us across the 19 supplied solvable cases (unweighted; not the final competition score).
- **69.62 MHz standalone Fmax**, 22,580 standalone fitted LEs.
- Full system: **50 MHz configured clock**, **51.88 MHz Fmax**, **35,152 fitted LEs**, **173/182 M9Ks**.
- Worst setup slack **+0.725 ns**; every reported timing category passes under the unmodified course constraints. External-port constraint coverage is described in the results document.
- **4,347 RTL executions pass**: 4,306 solved cases and 41 expected rejections. All 19 solvable full-application cases pass both course checkers; both impossible development applications correctly report non-solved.
- **Physical hardware execution is pending**. Classic v5's prior hardware confirmation applies to the separate classic release.

Download the SOF for programming and the source ZIP for the matching application, updated shared checker, boards, and LF source files. The SVF, actual course-generated synthesis TGZ, compact submission-source ZIP, detailed explanation, results, handoff, and provenance are also attached. The final weighted unseen-case report must be completed when the course releases those cases and weights.

Read [the detailed design explanation](https://github.com/barakpe/AlwaysSudx/blob/hackathon/ineq/docs/INEQUALITY_DESIGN.md), [named-board results](https://github.com/barakpe/AlwaysSudx/blob/hackathon/ineq/docs/INEQUALITY_RESULTS.md), and [hardware handoff](https://github.com/barakpe/AlwaysSudx/blob/hackathon/ineq/docs/INEQUALITY_HARDWARE_HANDOFF.md).

`ineq-v2` identifies build-source commit `c91d5985ea680edba047db4333e969ba43738f01`. The attached source ZIP additionally includes completed reports and documentation from the later documentation commit recorded in `RELEASE_MANIFEST.json`; its hardware/software inputs are unchanged from the build commit. `SHA256SUMS` covers all attached assets, and source fingerprints cover RTL, the enum contract, application, and supplied checker.

```text
SOF SHA-256
79b39f50f2c760e94aaf8bedc81ee28e2e3cd6a727d711dced1c6cde31178b3e
```
