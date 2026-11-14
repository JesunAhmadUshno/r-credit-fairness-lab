# Data loading and feature engineering, mirroring credit-risk-lab's
# load() and add_features() line for line (src/credit_risk_lab.py).

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
})

DATA_FILE <- file.path("data", "default of credit card clients.xls")
DATA_SHA256 <- "30c6be3abd8dcfd3e6096c828bad8c2f011238620f5369220bd60cfc82700933"
TARGET_RAW <- "default payment next month"

NUMERIC_FEATURES <- c("LIMIT_BAL", "AGE", "BILL_AMT1", "PAY_AMT1",
                      "utilization", "pay_ratio", "delinq_mean",
                      "delinq_max", "bill_trend",
                      "PAY_0", "PAY_2", "PAY_3", "PAY_4", "PAY_5", "PAY_6")
CAT_FEATURES <- c("SEX", "EDUCATION", "MARRIAGE")
MODEL_FEATURES <- c(NUMERIC_FEATURES, CAT_FEATURES)
PAY_COLS <- c("PAY_0", "PAY_2", "PAY_3", "PAY_4", "PAY_5", "PAY_6")

file_sha256 <- function(path) {
  digest::digest(path, algo = "sha256", file = TRUE)
}

# Mirrors the Python loader: second row is the header (pandas header=1),
# target renamed, EDUCATION 0/5/6 recoded to 4, MARRIAGE 0 recoded to 3.
load_credit_data <- function(path = DATA_FILE) {
  df <- readxl::read_excel(path, skip = 1)
  if (!TARGET_RAW %in% names(df)) {
    stop("target column '", TARGET_RAW, "' not found in ", path)
  }
  df <- dplyr::rename(df, default = dplyr::all_of(TARGET_RAW))
  df$EDUCATION[df$EDUCATION %in% c(0, 5, 6)] <- 4
  df$MARRIAGE[df$MARRIAGE == 0] <- 3
  df$default <- as.integer(df$default)
  tibble::as_tibble(df)
}

# Mirrors add_features() exactly, including division-by-zero handling:
# LIMIT_BAL of 0 yields NA (kept, later median-imputed); BILL_AMT1 of 0
# yields NA in pay_ratio, which the Python code fills with 0 before
# clipping to [-1, 5]. Delinquency summaries clip PAY values at 0.
add_features <- function(df) {
  safe_div <- function(a, b) ifelse(b == 0, NA_real_, a / b)
  pay_mat <- as.matrix(df[, PAY_COLS])
  pay_clip <- pmax(pay_mat, 0)
  df$utilization <- safe_div(df$BILL_AMT1, df$LIMIT_BAL)
  pr <- safe_div(df$PAY_AMT1, df$BILL_AMT1)
  pr[is.na(pr)] <- 0
  df$pay_ratio <- pmin(pmax(pr, -1), 5)
  df$delinq_mean <- rowMeans(pay_clip)
  df$delinq_max <- apply(pay_clip, 1, max)
  df$bill_trend <- safe_div(df$BILL_AMT1 - df$BILL_AMT6, df$LIMIT_BAL)
  df
}
