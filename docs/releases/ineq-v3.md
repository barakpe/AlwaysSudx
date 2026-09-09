Registered-count MRV pipeline, ready for DE10-Lite hardware testing.

- **4.75% lower normalized time than v2**, with identical application cycles: 4.6697 -> 4.4480 us across 19 supplied solvable boards. This is an unweighted development comparison, not the complete official benchmark total.
- **73.09 MHz standalone Fmax**, **21,968 standalone fitted LEs** (612 fewer than v2).
- Full system: **50 MHz configured clock**, **57.46 MHz Fmax**, **34,571 fitted LEs**, **173/182 M9Ks**. Worst setup slack +2.596 ns; all reported timing categories pass under the unchanged course constraints.
- All **4,347 direct RTL records match v2 exactly**, including cycles, grids, guesses, and rollbacks. All 19 solvable application cases pass both course checkers; both impossible development cases report non-solved at 267 cycles.
- **v3 hardware execution is pending.** v2's hardware confirmation is preserved in its release and repository record. Actual execution time at this image's physical 50 MHz clock is unchanged from v2: 6.5021 us mean. The improvement is in the course-normalized cycles/Fmax metric.

Candidate counts are captured in SCAN. MRV runs only after DOMAIN finds no changes, so those earlier counts remain valid. This removes counting from the MRV tournament's critical path without adding cycles. A separate triplet hierarchy was also tested; it reached 72.47 MHz and was not selected.

Download the SOF/SVF, exact course-generated TGZ, matching LF source ZIP, detailed design and MRV explanations, results, handoff, and provenance. The attached benchmark workbook is explicitly **partial**: the course spreadsheet names four unseen puzzle files that are not yet in the repository, so their cells remain blank.

Build-source tag `ineq-v3` identifies commit `87822a64f9b4ce90bdf57405dfb68d066fac8d10`. The source ZIP also contains completed reports and documentation from the later documentation commit identified in `RELEASE_MANIFEST.json`; its hardware/software inputs match the build commit. `SHA256SUMS` covers all original attached release assets.

[Design and motivation](https://github.com/barakpe/AlwaysSudx/blob/hackathon/ineq/docs/MRV_PIPELINE_EXPERIMENTS.md) · [Results](https://github.com/barakpe/AlwaysSudx/blob/hackathon/ineq/docs/INEQUALITY_RESULTS.md) · [Hardware handoff](https://github.com/barakpe/AlwaysSudx/blob/hackathon/ineq/docs/INEQUALITY_HARDWARE_HANDOFF.md)

```text
SOF SHA-256
26b6c7b175fb2cbf00d1ecc2aee249142a3be5f567892209cb9ef0a48173efbe
```
