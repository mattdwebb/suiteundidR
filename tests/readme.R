# Execute the installed-package example used in the README.
source(system.file("examples", "school_policy.R", package = "suiteundidR"))
expected <- read.csv(system.file("extdata", "readme_expected.csv", package = "suiteundidR"))
numeric_columns <- names(expected)[vapply(expected, is.numeric, logical(1))]
stopifnot(nrow(example_result) == nrow(expected),
          all(is.finite(as.matrix(example_result[numeric_columns]))),
          max(abs(as.matrix(example_result[numeric_columns]) - as.matrix(expected[numeric_columns]))) < 2e-6)
