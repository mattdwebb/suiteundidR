library(suiteundidR)
d <- expand.grid(s = 1:8, t = 1:6, j = 1:10)
d$g <- c(3, 3, 5, 5, 0, 0, 0, 0)[d$s]
d$y <- d$s + d$t + 2*(d$g > 0 & d$t >= d$g) + sin(d$s*d$t)/10
r <- suite_undid(d, "y", "t", "s", gvar = "g", inference = "standard")
stopifnot(is.finite(r$estimate), r$jackknife$status == "PASS")
cat("INSTALLED_PACKAGE_PASS undidR\n")
