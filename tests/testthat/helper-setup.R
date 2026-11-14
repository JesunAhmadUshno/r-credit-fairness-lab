# Locate the repo root (the directory holding PREREGISTRATION.md) from
# wherever the tests are invoked.
find_root <- function() {
  d <- normalizePath(getwd())
  repeat {
    if (file.exists(file.path(d, "PREREGISTRATION.md"))) return(d)
    parent <- dirname(d)
    if (parent == d) stop("repo root not found")
    d <- parent
  }
}
ROOT <- find_root()
old_wd <- setwd(ROOT)
source(file.path(ROOT, "R", "sklearn_split.R"))
source(file.path(ROOT, "R", "data.R"))
source(file.path(ROOT, "R", "metrics.R"))
source(file.path(ROOT, "R", "fairness.R"))
# testthat may run test files from the tests/testthat directory and the
# function's relative default path would break; tests pass DATA_ABS
# explicitly instead.
DATA_ABS <- file.path(ROOT, "data", "default of credit card clients.xls")
