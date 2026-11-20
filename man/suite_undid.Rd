\name{suite_undid}
\alias{suite_undid}
\title{Native assignment-explicit UNDID suite adapter}
\description{Native estimator for identified state-period comparisons with explicit failure statuses.}
\usage{
suite_undid(data, outcome, time, cluster, gvar = NULL,
  treatment = NULL, covariates = character(), unit = NULL,
  data_mode = "auto", inference = "point", assignments = NULL,
  reps = 999L, seed = 0L, exact = FALSE, null = 0,
  weights = NULL, control_group = "never",
  weighting = "both", aggregation_weights = "post")
}
\arguments{
\item{data}{A data frame, without missing required values.}
\item{outcome, time, cluster}{Column names. Time and outcome must be finite numeric.}
\item{gvar}{Cluster-constant first-treatment column; zero means never treated.}
\item{treatment}{Optional absorbing binary treatment column, instead of or consistent with gvar.}
\item{covariates}{Numeric column names; no freezing of time-varying values.}
\item{unit}{Individual identifier required in panel mode.}
\item{data_mode}{One of auto, panel, rcs. Auto uses panel if unit is supplied.}
\item{inference}{point, standard, full, or a vector drawn from native, jackknife, ri_beta, ri_t_native, , .}
\item{assignments}{Numeric matrix of alternative assignments, rows are draws and columns are sorted clusters.}
\item{reps}{Positive count of unique draws when assignments are not supplied.}
\item{seed}{Seed for unique random draws. Caller RNG state is preserved.}
\item{exact}{Enumerate all alternative assignments, at most 100000 total.}
\item{null}{Null for jackknife; randomization supports zero only.}
\item{weights}{Unsupported unless NULL; no observation weights.}
\item{control_group}{Only never is supported.}
\item{aggregation_weights}{Use post-period treated counts by default or comparison-period treated counts within each cohort-period. Both conventions weight across cohort-periods by treated post-period counts.}
\item{weighting}{Only both is supported: control pair-size and target-cell-size weights.}
}
\value{List with estimate, att_st, normalized weights, assignment metadata,
and requested inference lists. Native methods are explicitly unsupported.
Every jackknife deletion is retained, including failed deletions as NA.
Input/point failures signal a suite_error with reason.}
\details{See METHOD_SPECIFICATION.md and INFERENCE.md for exact target and supported scope.
This adapter does not claim full package parity or universal causal validity of supplied covariates.}
