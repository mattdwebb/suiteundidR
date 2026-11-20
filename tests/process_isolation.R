library(parallel)
library(suiteundidR)
d <- expand.grid(s = 1:8, t = 1:6, j = 1:10)
d$g <- c(3, 3, 5, 5, 0, 0, 0, 0)[d$s]
d$y <- d$s + d$t + 2*(d$g > 0 & d$t >= d$g) + sin(d$s*d$t)/10
cl <- makePSOCKcluster(2L)
tryCatch({
  clusterExport(cl, "d")
  result <- clusterCall(cl, function() {
    f <- getExportedValue("suiteundidR", "suite_undid")
    f(d, "y", "t", "s", gvar = "g", inference = "full", reps = 3, seed = 24)
  })
  stopifnot(identical(result[[1]], result[[2]]))
  cat("PROCESS_ISOLATION_PASS: 2 native R workers\n")
}, finally = stopCluster(cl))
