# Run from the package root: Rscript tests/suite_tests.R
kind <- "undid"
if (file.exists("R/suite_engine.R")) {
  source("R/ri_keys.R")
  source("R/suite_engine.R")
  source(paste0("R/suite_", kind, ".R"))
  fit <- get(paste0("suite_", kind))
} else fit <- getExportedValue(if(kind=="undid") "suiteundidR" else "suitedidintR", paste0("suite_", kind))
fixture_dir <- if (dir.exists("tests/fixtures")) "tests/fixtures" else "fixtures"
checks <- 0L; maximum_error <- 0
ok <- function(x) { stopifnot(isTRUE(x)); checks <<- checks + 1L }
equal <- function(x, y, tolerance = 1e-9) {
  error <- max(abs(as.numeric(x) - as.numeric(y)))
  ok(is.finite(error) && error <= tolerance)
  maximum_error <<- max(maximum_error, error)
}
fails <- function(expr, reason) {
  error <- tryCatch({ force(expr); NULL }, suite_error = identity)
  ok(inherits(error, "suite_error") && error$reason == reason)
}
assignments <- as.matrix(read.csv(file.path(fixture_dir, "assignments.csv")))
for (label in c("balanced", "unequal", "covariates", "strings")) {
  d <- read.csv(file.path(fixture_dir, paste0(label, ".csv")))
  covs <- if (label == "covariates") c("x", "x2") else character()
  call_fit <- function(data = d, ...) fit(data, "y", "t", "s", gvar = "g",
                                          covariates = covs, ...)
  r <- call_fit(inference = "full", assignments = assignments)
  expected <- read.csv(file.path(fixture_dir, paste0(label, "_summary.csv")))
  del <- read.csv(file.path(fixture_dir, paste0(label, "_deleted.csv")))$deleted
  draws <- read.csv(file.path(fixture_dir, paste0(label, "_draws.csv")))
  equal(r$estimate, expected$estimate)
  equal(r$jackknife$standard_error, expected$se)
  equal(r$jackknife$statistic, expected$statistic)
  equal(r$jackknife$p_value, expected$p)
  equal(r$jackknife$delete_estimates, del)
  equal(r$ri_beta$statistics, draws$beta)
  equal(r$ri_beta$p_value, expected$ri_beta_p)
  equal(r$ri_beta$hits, expected$ri_beta_hits)
  ok(r$native$status == "UNSUPPORTED" && is.na(r$native$standard_error))
  ok(r$ri_t_native$status == "UNSUPPORTED")
  ok(r$jackknife$df == length(unique(d$s))-1)
  equal(sum(r$att_st$normalized_weight), 1)
  equal(sum(r$att_st$normalized_weight*r$att_st$estimate), r$estimate)
  equal(call_fit(d[nrow(d):1, ])$estimate, r$estimate)
  d2 <- d; d2$y <- 2.3*d$y
  equal(call_fit(d2)$estimate, 2.3*r$estimate)
  d3 <- d; d3$y <- sin(d$x*2)
  r3 <- call_fit(d3)
  mix <- d; mix$y <- .4*d$y + 1.7*d3$y
  equal(call_fit(mix)$estimate, .4*r$estimate + 1.7*r3$estimate)
}
d <- read.csv(file.path(fixture_dir, "unequal.csv"))
run <- function(data = d, ...) fit(data, "y", "t", "s", gvar = "g", ...)
base <- run()
d$D <- as.numeric(d$g > 0 & d$t >= d$g)
equal(fit(d, "y", "t", "s", treatment = "D")$estimate, base$estimate)
d$id <- paste(d$s, d$j, sep = "_")
equal(run(unit = "id", data_mode = "panel")$estimate, base$estimate)
ok(run(data_mode = "rcs")$data_mode == "rcs")
fails(run(data_mode = "panel"), "UNSUPPORTED")
bad <- d; bad$g[1] <- 8
fails(run(bad), "INVALID_INPUT")
bad <- d; bad$D[bad$s == 1 & bad$t == 6] <- 0
fails(fit(bad, "y", "t", "s", treatment = "D"), "INVALID_INPUT")
bad <- d; bad$y[1] <- NA_real_
fails(run(bad), "INVALID_INPUT")
bad <- d; bad$x2 <- bad$x
equal(run(bad, covariates=c("x","x2"))$estimate,run(bad,covariates="x")$estimate)
ok(is.finite(run(d[!(d$s == 1 & d$t == 1), ])$estimate))
fails(run(weights = "x"), "UNSUPPORTED")
fails(run(control_group = "notyet"), "UNSUPPORTED")
fails(run(weighting = "none"), "UNSUPPORTED")
fails(run(inference = "ri_beta", null = 1), "UNSUPPORTED")
fails(run(inference = "banana"), "UNSUPPORTED")
fails(run(inference = "ri_beta", assignments = rbind(assignments[1, ], assignments[1, ])), "INVALID_INPUT")
fails(run(inference = "ri_beta", assignments = matrix(base$assignment, nrow=1)), "INVALID_INPUT")
badassign <- assignments; badassign[1, 1] <- 999
fails(run(inference = "ri_beta", assignments = badassign), "INVALID_INPUT")
set.seed(291)
before <- .Random.seed
x <- run(inference = c("ri_beta"), reps = 4, seed = 18)
ok(identical(before, .Random.seed))
y <- run(inference = c("ri_beta"), reps = 4, seed = 18)
equal(x$assignments, y$assignments)
small <- d[d$s <= 4, ]; small$g <- ifelse(small$s <= 2, 3, 0)
e <- run(small, inference = "ri_beta", exact = TRUE)
ok(e$assignment_space == 6 && e$ri_beta$draws == 5)
ok(!anyDuplicated(as.data.frame(e$assignments)))
single <- d; single$g[single$s == 2] <- 0
sj <- run(single, inference = "jackknife")$jackknife
ok(sj$status=="PASS" && sj$df==7 && is.finite(sj$p_value))
physical <- vapply(sort(unique(single$s)),function(i) run(single[single$s!=i,])$estimate,numeric(1))
equal(unname(sj$delete_estimates),physical)
single$g <- ifelse(single$s==1,3,0)
only <- run(single,inference="jackknife")$jackknife
ok(only$status=="IDENTIFICATION_FAILURE" && sum(is.na(only$delete_estimates))==1 && is.na(only$p_value))
zero <- d; zero$y <- zero$s + zero$t
zj <- run(zero, inference = "jackknife")$jackknife
ok(zj$status == "NUMERICAL_FAILURE" && is.na(zj$p_value))
if (kind == "didint") {
  d <- read.csv(file.path(fixture_dir, "covariates.csv"))
  expected <- read.csv(file.path(fixture_dir, "ccc.csv"))
  for (i in seq_len(nrow(expected)))
    equal(run(covariates = c("x", "x2"), ccc = expected$ccc[i])$estimate, expected$estimate[i])
}
cat(sprintf("PASS: %d assertion groups; maximum numerical discrepancy %.17g\n", checks, maximum_error))
