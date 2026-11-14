# Metric functions. AUC is the Mann-Whitney form with average ranks for
# ties (identical to scikit-learn roc_auc_score). KS mirrors
# credit-risk-lab's ks_stat(): scores sorted descending, maximum gap
# between cumulative default and non-default shares.

auc_score <- function(y, p) {
  y <- as.integer(y)
  n1 <- sum(y == 1)
  n0 <- sum(y == 0)
  if (n1 == 0 || n0 == 0) stop("AUC needs both classes present")
  r <- rank(p, ties.method = "average")
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

ks_stat <- function(y, p) {
  o <- order(-p)
  ys <- as.integer(y)[o]
  tp <- cumsum(ys) / max(sum(ys), 1)
  fp <- cumsum(1 - ys) / max(sum(1 - ys), 1)
  max(tp - fp)
}

brier_score <- function(y, p) mean((as.numeric(y) - p)^2)

# Confusion counts at a threshold. Predicted positive (flagged) means
# predicted PD strictly greater than the threshold, as frozen in the
# pre-registration.
confusion_at <- function(y, p, threshold) {
  flag <- p > threshold
  c(
    tp = sum(flag & y == 1), fp = sum(flag & y == 0),
    tn = sum(!flag & y == 0), fn = sum(!flag & y == 1)
  )
}

tpr_at <- function(y, p, threshold) {
  cc <- confusion_at(y, p, threshold)
  unname(cc["tp"] / (cc["tp"] + cc["fn"]))
}

ppv_at <- function(y, p, threshold) {
  cc <- confusion_at(y, p, threshold)
  denom <- cc["tp"] + cc["fp"]
  if (denom == 0) return(NA_real_)
  unname(cc["tp"] / denom)
}
