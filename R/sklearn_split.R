# Pure R replication of the scikit-learn stratified shuffle split used by
# credit-risk-lab: train_test_split(test_size = 0.30, stratify = y,
# random_state = 42) under scikit-learn 1.9.1 and numpy legacy RandomState.
#
# numpy's legacy RandomState is MT19937 with scalar seeding, rk_interval
# rejection sampling, and Fisher-Yates permutation. All uint32 arithmetic
# is done on doubles (exact for values below 2^53) with 16-bit split
# helpers for AND, XOR, and modular multiplication.
#
# This file exists so the locked Python split can be reproduced in R
# exactly, and proven identical by hash (see scripts/run_all.R).

u32 <- function(x) x %% 4294967296

xor32 <- function(a, b) {
  ah <- floor(a / 65536); al <- a %% 65536
  bh <- floor(b / 65536); bl <- b %% 65536
  bitwXor(as.integer(ah), as.integer(bh)) * 65536 +
    bitwXor(as.integer(al), as.integer(bl))
}

and32 <- function(a, b) {
  ah <- floor(a / 65536); al <- a %% 65536
  bh <- floor(b / 65536); bl <- b %% 65536
  bitwAnd(as.integer(ah), as.integer(bh)) * 65536 +
    bitwAnd(as.integer(al), as.integer(bl))
}

# (a * b) mod 2^32 with exact double arithmetic.
mul32 <- function(a, b) {
  al <- a %% 65536; ah <- floor(a / 65536)
  bl <- b %% 65536; bh <- floor(b / 65536)
  u32(al * bl + ((al * bh + ah * bl) %% 65536) * 65536)
}

# MT19937 generator compatible with numpy legacy RandomState.
# Returns an environment with functions uint32(n) and interval(max).
mt19937_numpy <- function(seed) {
  N <- 624L
  state <- numeric(N)
  state[1] <- u32(seed)
  for (i in 2:N) {
    prev <- state[i - 1]
    state[i] <- u32(mul32(1812433253, xor32(prev, floor(prev / 1073741824))) + (i - 1))
  }
  pool <- numeric(0)
  pos <- 0

  refill <- function() {
    # The reference MT19937 twist runs in place: for 0-based index i >= 227
    # the source word mt[(i + 397) mod 624] is the ALREADY UPDATED word,
    # and the last word's y uses the NEW first word. Reproduced here in
    # three segments (offsets of 227) so vector operations stay exact.
    mt <- state
    upper <- floor(mt / 2147483648) * 2147483648       # mt & 0x80000000
    lower_next <- mt[c(2:N, 1)] %% 2147483648           # next & 0x7fffffff
    y <- upper + lower_next                             # word N corrected below
    xa <- floor(y / 2)
    odd <- (y %% 2) == 1
    if (any(odd)) xa[odd] <- xor32(xa[odd], 2567483615) # 0x9908b0df
    new_state <- numeric(N)
    new_state[1:227] <- xor32(mt[398:N], xa[1:227])
    # Last word: y from old mt[N] upper bits and the NEW mt[1] lower bits.
    y_last <- upper[N] + (new_state[1] %% 2147483648)
    xa_last <- floor(y_last / 2)
    if (y_last %% 2 == 1) xa_last <- xor32(xa_last, 2567483615)
    xa[N] <- xa_last
    new_state[228:454] <- xor32(new_state[1:227], xa[228:454])
    new_state[455:N] <- xor32(new_state[228:397], xa[455:N])
    # Tempering.
    z <- new_state
    z <- xor32(z, floor(z / 2048))                      # >> 11
    z <- xor32(z, and32(u32(z * 128), 2636928640))      # << 7 & 0x9d2c5680
    z <- xor32(z, and32(u32(z * 32768), 4022730752))    # << 15 & 0xefc60000
    z <- xor32(z, floor(z / 262144))                    # >> 18
    state <<- new_state
    pool <<- z
    pos <<- 0
  }

  uint32 <- function(n = 1) {
    out <- numeric(n)
    filled <- 0
    while (filled < n) {
      if (pos >= length(pool)) refill()
      take <- min(n - filled, length(pool) - pos)
      out[(filled + 1):(filled + take)] <- pool[(pos + 1):(pos + take)]
      pos <<- pos + take
      filled <- filled + take
    }
    out
  }

  # numpy rk_interval: uniform integer in [0, max] by masked rejection.
  interval <- function(max) {
    if (max == 0) return(0)
    mask <- max
    mask <- bitwOr(mask, floor(mask / 2))
    mask <- bitwOr(mask, floor(mask / 4))
    mask <- bitwOr(mask, floor(mask / 16))
    mask <- bitwOr(mask, floor(mask / 256))
    mask <- bitwOr(mask, floor(mask / 65536))
    repeat {
      val <- and32(uint32(1), mask)
      if (val <= max) return(val)
    }
  }

  environment()
}

# numpy RandomState.permutation(n): Fisher-Yates over 0..n-1.
numpy_permutation <- function(rng, n) {
  arr <- as.numeric(0:(n - 1))
  if (n <= 1) return(arr)
  for (i in (n - 1):1) {
    j <- rng$interval(i)
    tmp <- arr[i + 1]
    arr[i + 1] <- arr[j + 1]
    arr[j + 1] <- tmp
  }
  arr
}

# numpy RandomState.choice(x, size, replace = FALSE) without probabilities:
# a permutation of x, first `size` elements. Consumes no draws when
# length(x) == 1 (the only case this study's split hits).
numpy_choice_no_replace <- function(rng, x, size) {
  perm <- numpy_permutation(rng, length(x))
  x[perm[seq_len(size)] + 1]
}

# scikit-learn _approximate_mode (1.9.1), draws only for remainder ties.
approximate_mode <- function(rng, class_counts, n_draws) {
  continuous <- class_counts / sum(class_counts) * n_draws
  floored <- floor(continuous)
  need_to_add <- as.integer(n_draws - sum(floored))
  if (need_to_add > 0) {
    remainder <- continuous - floored
    values <- sort(unique(remainder), decreasing = TRUE)
    for (value in values) {
      inds <- which(remainder == value) - 1  # 0-based positions
      add_now <- min(length(inds), need_to_add)
      chosen <- numpy_choice_no_replace(rng, inds, add_now)
      floored[chosen + 1] <- floored[chosen + 1] + 1
      need_to_add <- need_to_add - add_now
      if (need_to_add == 0) break
    }
  }
  as.integer(floored)
}

# The stratified split itself. y is a 0/1 (or general class) vector in
# file order. Returns 0-based row positions for train and test, as sets
# (sorted) plus the raw sklearn order.
sklearn_stratified_split <- function(y, test_size = 0.30, seed = 42) {
  n <- length(y)
  classes <- sort(unique(y))
  class_counts <- as.numeric(table(factor(y, levels = classes)))
  class_indices <- lapply(classes, function(cl) which(y == cl) - 1)
  n_test <- ceiling(test_size * n)
  n_train <- n - n_test
  rng <- mt19937_numpy(seed)
  n_i <- approximate_mode(rng, class_counts, n_train)
  remaining <- class_counts - n_i
  t_i <- approximate_mode(rng, remaining, n_test)
  train <- c()
  test <- c()
  for (i in seq_along(classes)) {
    perm <- numpy_permutation(rng, class_counts[i])
    permuted <- class_indices[[i]][perm + 1]
    train <- c(train, permuted[seq_len(n_i[i])])
    if (t_i[i] > 0) {
      test <- c(test, permuted[n_i[i] + seq_len(t_i[i])])
    }
  }
  list(
    train_pos = train, test_pos = test,
    train_sorted = sort(train), test_sorted = sort(test),
    n_train_per_class = n_i, n_test_per_class = t_i
  )
}
