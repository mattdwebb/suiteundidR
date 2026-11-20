# Fresh black-box run of the preserved official three-stage UN-DID pipeline.
if (dir.exists("R")) {
  for (f in list.files("R", pattern = "\\.[rR]$", full.names = TRUE)) source(f)
  .populate_undid_env(.undid_env)
} else library(suiteundidR)
fixture_dir <- if (dir.exists("tests/fixtures")) "tests/fixtures" else "fixtures"
errors <- numeric()
for (label in c("unequal", "covariates")) {
  d <- read.csv(file.path(fixture_dir, paste0(label, ".csv")))
  covs <- if (label == "covariates") c("x", "x2") else character()
  expected <- suite_undid(d, "y", "t", "s", gvar = "g", covariates = covs)
  d$t <- d$t + 2000
  a <- c(2003, 2003, 2005, 2005, 0, 0, 0, 0)
  folder <- tempfile("official_undid_")
  dir.create(folder)
  suite_undid_create_init_csv(as.character(1:8), "2001", "2006",
                  ifelse(a == 0, "control", as.character(a)),
                  covariates = covs, filepath = folder)
  suite_undid_create_diff_df(file.path(folder, "init.csv"), "yyyy", "yearly",
                 filepath = folder)
  for (i in 1:8) suite_undid_stage_two(file.path(folder, "empty_diff_df.csv"),
    as.character(i), d[d$s == i, ], "t", "y", filepath = folder)
  set.seed(118)
  official <- suppressWarnings(suite_undid_stage_three(folder, agg = "sgt",
    weights = "both", covariates = length(covs) > 0, nperm = 1, verbose = NULL))
  error <- abs(official$agg$att[1] - expected$estimate)
  stopifnot(is.finite(error), error < 1e-9)
  errors <- c(errors, error)
}
cat(sprintf("PASS: 2 official full-pipeline point comparisons; max error %.17g\n", max(errors)))
