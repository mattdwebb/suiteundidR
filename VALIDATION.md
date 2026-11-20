# Validation

Initial run: 106 assertion groups; max discrepancy 5.240252676230739e-14. Fresh official three-stage UN-DID runs on unequal and covariate fixtures: 2 comparisons, max 2.220446049250313e-15.
Repository-local R CMD INSTALL and exported-function smoke tests passed.
Two independent native R worker processes produced identical full-inference
results (with three generated assignments each).

These are scoped test results, not exhaustive certification. Paired native
Stata adapters also passed the pinned fixtures, including all deletions.
Official Julia DID-INT was not executed. The inherited Windows LANG/LC_ALL
C.UTF-8 setting is unavailable in this R installation; LC_ALL=C and LANG=C
remove startup warnings without changing system settings.

R CMD build and R CMD check completed with zero errors, 2 warnings and 1 note, all concerning unavailable knitr/rmarkdown or skipped vignette building. All 208 preserved upstream testthat expectations passed (0 fail/warn/skip).
GitHub R regression workflow passed on Windows and Ubuntu for the
initial tested milestone. No cloud Stata runner was invoked.
