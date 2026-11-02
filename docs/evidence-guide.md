# Evidence interpretation and record scope

## Current technical entry points

| Question | Maintained reference |
| --- | --- |
| Implemented software and unresolved limitations | [Current technical state](project-state.md) |
| Computational model and numerical acceptance | [Acceptance criteria](acceptance-source.md) |
| Stable FR/NFR criteria and evidence coverage | [Requirements audit](requirements-audit.md) |
| Primary engine performance | [CPU/GPU benchmark](cpu-gpu-benchmark.md) |
| CPU bottleneck and isolated selection | [Stage diagnosis](cpu-stage-diagnostics.md), [selection experiment](quantile-selection-experiment.md) |
| Current software builds and selected historical integrity | [Reproducibility](reproducibility.md) |
| Portable application and bounded GUI checks | [Windows distribution](windows-portable.md), [browser adapter](local-browser.md) |

## Original experiment records

Each evidence package is associated with its recorded source revision, input
identity, procedure and measurement boundary. Its README, logs and manifests
describe that checkpoint. A preparation-time publication failure does not
describe the present delivery state when a later published commit is documented.
Updated summaries do not replace original measurements or reset acceptance criteria.

The full-device/hybrid benchmark, stage diagnostics and convergence figures
retain exact-byte inventories. The portfolio studies also retain frozen protocols,
invalidated attempts and complete replacement-attempt provenance. Changes to
measured conditions or source identities would require explicit versioned evidence.

`historical-documents` contains document snapshots used to audit earlier figure
derivation. Those snapshots are not current implementation or deployment instructions.
The [public integrity checker](../scripts/check-reproducibility.py) verifies
selected records against their historical Git objects rather than assuming every
current document has the original snapshot bytes.

## Environment and provenance

Original logs may contain observed local usernames, absolute build paths and
tool output. These are capture values, not public-download inputs or requirements
to recreate a particular user's directory structure. Current reproduction commands
use repository-relative paths where supported. Private provider observations,
mailbox exports, local process archives and unrestricted research data are not
included in the public checkout.

Common-input agreement, native-RNG analytical checks, memory/race tools and
performance campaigns establish different properties. An ordinary CI build is
not a historical timing reproduction or independent CUDA validation. Stage-only
speedups cannot be substituted for total-engine comparisons.

Software limitations and unsuccessful targets remain part of the technical record.
The portable release asset and its checksum identify a frozen distribution;
later documentation commits do not imply a rebuilt or signed package.

## Historical document navigation

Copied document snapshots retain repository-relative links from their original
layout. Those links may not resolve inside the copied folder. The original
Git views preserve the source directory context:

- [Historical project state](https://github.com/rahmancelik74-cmd/vaR-hpc/blob/390ffa670960f83a0de4fb0b9cd595cb03cdbc8e/docs/project-state.md).
- [Historical convergence procedure](https://github.com/rahmancelik74-cmd/vaR-hpc/blob/390ffa670960f83a0de4fb0b9cd595cb03cdbc8e/docs/convergence.md).

The copied bytes remain unchanged for integrity verification; current software
behavior is described by the maintained references above.
