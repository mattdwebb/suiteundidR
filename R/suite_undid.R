#' Native assignment-explicit UNDID suite adapter
#' @export
suite_undid <- function(data, outcome, time, cluster, gvar = NULL,
                         treatment = NULL, covariates = character(), unit = NULL,
                         data_mode = "auto", inference = "point",
                         assignments = NULL, reps = 999L, seed = 0L, exact = FALSE,
                         null = 0, weights = NULL,
                         control_group = "never", weighting = "both", aggregation_weights = "post") {
  .suite_fit(data = data, outcome = outcome, time = time, cluster = cluster,
             gvar = gvar, treatment = treatment, covariates = covariates,
             unit = unit, data_mode = data_mode, inference = inference,
             assignments = assignments, reps = reps, seed = seed, exact = exact,
             null = null, kind = "undid", ccc = "int",
             weights = weights, control_group = control_group, weighting = weighting, aggregation_weights = aggregation_weights)
}
