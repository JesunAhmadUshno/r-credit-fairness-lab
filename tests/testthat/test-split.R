test_that("R split reproduces the locked Python split exactly", {
  df <- load_credit_data()
  split <- sklearn_stratified_split(df$default, test_size = 0.30,
                                    seed = 42)
  expect_equal(length(split$train_pos), 21000)
  expect_equal(length(split$test_pos), 9000)
  expect_equal(split$n_train_per_class, c(16355L, 4645L))
  expect_equal(split$n_test_per_class, c(7009L, 1991L))
  expect_equal(mean(df$default[split$test_sorted + 1]), 1991 / 9000)
  hash <- digest::digest(paste(split$test_sorted, collapse = ","),
                         algo = "sha256", serialize = FALSE)
  expect_identical(
    hash,
    "f2d688ab873deecc378b0212ae22bc297631f9833be82a856cd5fa4fd8f1598c"
  )
})

test_that("split replication is deterministic and seed-sensitive", {
  y <- c(rep(0, 200), rep(1, 80))
  a <- sklearn_stratified_split(y, seed = 42)
  b <- sklearn_stratified_split(y, seed = 42)
  c2 <- sklearn_stratified_split(y, seed = 7)
  expect_identical(a$test_sorted, b$test_sorted)
  expect_false(identical(a$test_sorted, c2$test_sorted))
  expect_equal(length(a$test_pos), 84)
})
