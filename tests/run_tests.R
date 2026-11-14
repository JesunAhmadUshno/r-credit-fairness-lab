# Test runner for the script-based project (not an R package).
# Run from the repo root: Rscript tests/run_tests.R
library(testthat)
res <- test_dir("tests/testthat", reporter = "summary",
                stop_on_failure = TRUE)
