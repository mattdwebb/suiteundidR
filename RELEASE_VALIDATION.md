# Validation record: 20 November 2026

The current candidate was checked in isolated Windows environments after the
publication audit corrections. The synthetic school-policy example retains its
recorded estimates and standard errors. Agreement across all nine estimator
families refers to that matched teaching example, not arbitrary empirical data.
UN-DID and DID-INT do not report a separate native analytical variance for their
supported aggregates. All required deletion estimates must exist for a reported
jackknife; unsupported samples are reported explicitly.

R 4.5.3 source builds and `R CMD check --no-manual --no-build-vignettes`
passed locally with Status: OK. Checks used an isolated library. The suite's local
checks included all nine backends, including canonical public Fast CSDID 1.0.1.
Hosted suite CI tests the wrapper without optional backends; its result alone
does not certify the full estimator integration. Exact short-key bucket tests
and collision/long-label coverage concern R environment caches. Python and Stata
do not use those R caches. Linearized jackknife options are R-specific and are
distinct from exact refits used for the cross-language comparison.

Across this release, new targeted checks cover weighted, unbalanced stacked samples with singleton
cohorts; suite FLEX nonzero-null Student references; and CSDID cohort and
comparison-period aggregation with regression adjustment and DRIPW, both control
rules, and every cluster deletion. These checks complement each package's
retained reference tests. They do not imply that every estimator supports every
panel structure, overlap pattern, or covariate specification.

The source checkouts under review remain separate from the original development
directories. Earlier preservation hashes cover the 32 software worktrees, not
all research simulations. Only the UN-DID pkgdown configuration was repaired;
the author's main website was not updated. Separate panel README examples are
provided for LP-DiD and the suite; other introductory examples use repeated cross
sections. CCC testing is outside this release's inference validation.
