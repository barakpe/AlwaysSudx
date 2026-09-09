Propagation decision pipeline, ready for DE10-Lite hardware testing.

- **87.83 MHz standalone Fmax**, **22,289 standalone fitted LEs**.
- Mean normalized time: **3.9604 us** across 19 supplied solvable boards, **10.96% lower than v3** and **15.19% lower than v2**. This development mean is not the complete competition score.
- Four available variant benchmark rows: **18.1715 us**, **8.53% lower than v3**. The four unavailable unseen cases are blank in the partial workbook.
- Full system: **50 MHz configured**, **56.58 MHz Fmax**, **34,627 LEs**, **173/182 M9Ks**. Setup +2.326 ns; every reported timing category passes under the unchanged course constraints. Routing completed after one congestion retry.
- **4,347 direct RTL executions pass**. Solved records preserve grids and search decisions, with one extra cycle per propagation round. All 19 solvable application tests pass both checkers; both impossible boards report non-solved at 267 cycles.
- **Hardware execution is pending.** Actual mean time at this image's physical 50 MHz is **6.9568 us**, slower than v3's 6.5021 us. Larger regression corpora also have worse mean solver-only time. v3 remains available as a separate release and on `hackathon/ineq`; v4 is the measured winner for the available short application score, not a universal winner.

Download the SOF/SVF, exact course TGZ, matching LF source ZIPs, detailed explanations with code, named-board results, handoff, partial workbook, and provenance checks. Start with `PROPAGATION_PIPELINE_EXPERIMENT.md` for the motivation and intuition, then `INEQUALITY_DESIGN.md` for the base solver.

Build-source tag `ineq-v4` identifies commit `fe873baef82bd15b7de963415be563fbc2970c10`. The ZIP includes later completed documentation and reports; `RELEASE_MANIFEST.json` records that documentation commit. All hardware/software input fingerprints match the build commit. `SHA256SUMS` covers the attached assets.

```text
SOF SHA-256
4b314fe4b63bbf681aad6f24318f02ea9cc091137472427cc767bd019b8a51e1
```

[Explanation](https://github.com/barakpe/AlwaysSudx/blob/hackathon/propagation-pipeline/docs/PROPAGATION_PIPELINE_EXPERIMENT.md) · [Results](https://github.com/barakpe/AlwaysSudx/blob/hackathon/propagation-pipeline/docs/INEQUALITY_RESULTS.md) · [Hardware handoff](https://github.com/barakpe/AlwaysSudx/blob/hackathon/propagation-pipeline/docs/INEQUALITY_HARDWARE_HANDOFF.md)
