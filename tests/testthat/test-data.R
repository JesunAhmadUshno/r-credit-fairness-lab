test_that("data file hash matches the pre-registration", {
  expect_identical(file_sha256(DATA_ABS), DATA_SHA256)
})

test_that("loaded data matches the frozen schema", {
  df <- load_credit_data(DATA_ABS)
  expect_equal(nrow(df), 30000)
  expect_true(all(c("ID", "LIMIT_BAL", "SEX", "EDUCATION", "MARRIAGE",
                    "AGE", PAY_COLS, "BILL_AMT1", "BILL_AMT6",
                    "PAY_AMT1", "default") %in% names(df)))
  expect_true(all(df$default %in% c(0L, 1L)))
  expect_equal(sum(df$default), 6636)
  expect_equal(mean(df$default), 0.2212, tolerance = 1e-4)
  # Recodes from the Python loader: no 0/5/6 left in EDUCATION, no 0 in
  # MARRIAGE.
  expect_false(any(df$EDUCATION %in% c(0, 5, 6)))
  expect_false(any(df$MARRIAGE == 0))
})

test_that("feature engineering mirrors the Python formulas", {
  df <- add_features(load_credit_data(DATA_ABS))
  expect_true(all(c("utilization", "pay_ratio", "delinq_mean",
                    "delinq_max", "bill_trend") %in% names(df)))
  expect_true(all(df$pay_ratio >= -1 & df$pay_ratio <= 5))
  expect_true(all(df$delinq_max >= df$delinq_mean - 1e-12))
  row1 <- df[1, ]
  expect_equal(row1$utilization, row1$BILL_AMT1 / row1$LIMIT_BAL)
  expect_equal(row1$delinq_mean,
               mean(pmax(as.numeric(row1[PAY_COLS]), 0)))
})
