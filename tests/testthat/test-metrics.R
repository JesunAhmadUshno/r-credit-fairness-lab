test_that("AUC matches known values", {
  y <- c(0, 0, 1, 1)
  expect_equal(auc_score(y, c(0.1, 0.2, 0.8, 0.9)), 1)
  expect_equal(auc_score(y, c(0.9, 0.8, 0.2, 0.1)), 0)
  expect_equal(auc_score(y, c(0.5, 0.5, 0.5, 0.5)), 0.5)
  # Ties: one tied pair across classes gives 0.75 here.
  expect_equal(auc_score(y, c(0.1, 0.4, 0.4, 0.9)), 0.875)
})

test_that("KS matches a hand-computed example", {
  y <- c(1, 0, 1, 0)
  p <- c(0.9, 0.8, 0.3, 0.1)
  # Sorted desc: (1, .9), (0, .8), (1, .3), (0, .1).
  # Cumulative TPR: .5, .5, 1, 1. FPR: 0, .5, .5, 1. Max gap = .5.
  expect_equal(ks_stat(y, p), 0.5)
  # All scores tied: order falls back to row order (the Python ks_stat
  # has the same order dependence under ties), giving the same 0.5.
  expect_equal(ks_stat(y, rep(0.5, 4)), 0.5)
})

test_that("threshold metrics match hand counts", {
  y <- c(1, 1, 0, 0)
  p <- c(0.9, 0.2, 0.8, 0.1)
  cc <- confusion_at(y, p, 0.2293)
  expect_equal(unname(cc["tp"]), 1)
  expect_equal(unname(cc["fp"]), 1)
  expect_equal(tpr_at(y, p, 0.2293), 0.5)
  expect_equal(ppv_at(y, p, 0.2293), 0.5)
  expect_equal(brier_score(y, p), mean((y - p)^2))
})
