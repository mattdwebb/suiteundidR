# Release candidate — 20 November 2026

- Clarify that missing values in supplied rows are invalid, while absent cells
  can leave identified surviving comparisons; describe target-level estimability
  rather than automatically rejecting all redundant nuisance columns.

- Add a complete school-policy walkthrough with bundled data, executable code,
  verified numerical output and interpretation in outcome units.
- Check the installed-package README example against its documented output.
- Preserve the existing local surviving-aggregate jackknife corrections while
  integrating the current upstream changes; all required deletions remain required.
- Retain the exact short-bucket/full-key RI deduplication fix and its long-key,
  collision and seeded-inference regression coverage.
- Keep coverage tests mandatory and retain their report as an artifact. Skip only
  the optional Codecov upload when no upload token is configured.
- Preserve the original three-stage guide in README_ORIGINAL.md and distinguish
  it from the single-call suite adapter.

