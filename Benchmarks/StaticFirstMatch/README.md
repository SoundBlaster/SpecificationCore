# Static first-match benchmark

This separate SwiftPM client compares a nine-rule right-growing `BinaryFirstMatch` composition with `StaticFirstMatch` from the built SpecificationCore package. Each rule uses a successively growing generic leaf built with the real library’s `.or`, `.and`, `.not`, and `.returning` APIs. Inputs include both matches and misses. Both strategies use the real library across a module boundary. The program checks result parity before timing, runs an explicit warm-up, alternates measurement order for 32 rounds, and prints every round as CSV. It intentionally sets no absolute timing threshold.

Run from this directory in Release mode:

```sh
swift run -c release
```

Set `SPECIFICATIONCORE_PACKAGE` to select a different local SpecificationCore checkout. The default path points to the repository root.

CI runs five fresh processes and applies a coarse regression gate to the balanced strategy relative to the right-growing chain. The gate accounts for noise using the nested median, a 1.5 multiplier, a 5 ns floor, and six times the combined median absolute deviation. CI retains raw CSV, the build log, toolchain, revision, harness digest, dirty state, and gate settings as a workflow artifact.
