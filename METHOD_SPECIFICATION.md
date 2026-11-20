# UN-DID suite adapter: method specification

`suite_undid()` uses absorbing cluster-level adoption and never-treated controls.
First-treatment dates are constant within cluster; zero means never treated.
For a cohort adopting at g, its baseline is the last observed calendar period
before g. A candidate state-time effect needs observations for the treated state
at both that baseline and the post-treatment period.

## Missing values and absent cells

Required values in supplied rows must be finite and nonmissing. A missing outcome
or covariate is not silently removed. This differs from an entirely absent
state-period cell: absent cells make their particular comparisons unavailable,
but do not automatically invalidate the whole dataset. The estimator continues
with identified comparisons and normalizes weights over the surviving effects.
It fails if no treated-state comparison remains identified.

## Adjusted changes

Without additional covariates, each state's change is its post-period outcome
mean minus its baseline mean. With covariates, fit outcome on an intercept, a
post indicator and the supplied covariates separately within each state and
baseline/post pair. The post-indicator coefficient is that state's adjusted
change. This allows state-specific slopes for each pair; it is not one pooled
residualization regression.

The requested post-indicator contrast must be identified. Redundant nuisance
columns do not automatically invalidate an identified contrast. An unidentified
state change is unavailable; it is never replaced by an unadjusted change.

## Comparisons and aggregation

For treated state s at post period t, subtract the average change among eligible
never-treated states. A control c is eligible when it has the required two cells
and an identified change or standardized prediction. Its comparison weight is
N[c,t] + N[c,b], normalized over eligible controls. Retain ATT(s,t) only when
the treated change and at least one eligible control change exist.

The default final scalar averages surviving ATT(s,t) values with weights N[s,t],
normalized over those effects. With `aggregation_weights = "comparison"`, weights within each cohort-time
group are instead proportional to N[s,b] + N[s,t]; the total weight of that group
retains its surviving treated post-period mass. This is an explicitly selected
aggregation rule, not a fallback when a fit fails.

## Deletion, reassignment and scope

Every deletion and reassignment rebuilds fits, comparisons and normalized weights.
A disappeared cohort is permitted when a supported aggregate remains estimable.
All scalar deletions still must exist to form the jackknife standard error;
unavailable deletions are not discarded. See [INFERENCE.md](INFERENCE.md).

Observation weights, not-yet-treated controls and alternatives to `weighting =
"both"` are unsupported in this adapter. Panel mode validates unit-period
uniqueness and cluster membership; the estimator remains cell-based and does not
construct individual fixed effects or fabricated individual differences.

For a fixed assignment, covariates and identified support, fits and contrasts
are linear in the outcomes and weights depend on counts and covariates. Deletion
or reassignment can change the relevant support and weights, which are recomputed.
