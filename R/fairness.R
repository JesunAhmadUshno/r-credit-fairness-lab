# Fairness audit at the frozen champion threshold (0.2293), on one arm's
# test-set predictions. Definitions are frozen in PREREGISTRATION.md:
# flagged = predicted PD above threshold; TPR = share of actual
# defaulters flagged; PPV = share of flagged who default; selection
# rate = share approved (PD at or below threshold).

CHAMPION_THRESHOLD <- 0.2293

age_band <- function(age) {
  dplyr::case_when(
    age < 30 ~ "under 30",
    age < 40 ~ "30-39",
    age < 50 ~ "40-49",
    age < 60 ~ "50-59",
    TRUE ~ "60 and over"
  )
}

AGE_BAND_LEVELS <- c("under 30", "30-39", "40-49", "50-59", "60 and over")
SEX_LABELS <- c("1" = "male", "2" = "female")
EDU_LABELS <- c("1" = "graduate school", "2" = "university",
                "3" = "high school", "4" = "others")

group_fairness <- function(df, attribute, group) {
  flag <- df$pred_pd > CHAMPION_THRESHOLD
  rows <- lapply(sort(unique(group)), function(g) {
    idx <- group == g
    yy <- df$default[idx]
    ff <- flag[idx]
    n <- sum(idx)
    events <- sum(yy == 1)
    tp <- sum(ff & yy == 1)
    fp <- sum(ff & yy == 0)
    data.frame(
      attribute = attribute,
      group = as.character(g),
      n = n,
      defaults = events,
      event_rate = events / n,
      tpr = if (events > 0) tp / events else NA_real_,
      ppv = if ((tp + fp) > 0) tp / (tp + fp) else NA_real_,
      selection_rate = mean(!ff),
      flagged = sum(ff),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

# df must carry columns: default, pred_pd, SEX, AGE, EDUCATION.
fairness_audit <- function(df) {
  groups <- list(
    sex = unname(SEX_LABELS[as.character(df$SEX)]),
    age_band = factor(age_band(df$AGE), levels = AGE_BAND_LEVELS,
                      ordered = TRUE) |> as.character(),
    education = unname(EDU_LABELS[as.character(df$EDUCATION)])
  )
  tbl <- do.call(rbind, Map(
    function(att, grp) group_fairness(df, att, grp),
    names(groups), groups
  ))
  rownames(tbl) <- NULL
  gaps <- do.call(rbind, lapply(split(tbl, tbl$attribute), function(sub) {
    data.frame(
      attribute = sub$attribute[1],
      equal_opportunity_gap_pp = 100 * (max(sub$tpr, na.rm = TRUE) -
                                          min(sub$tpr, na.rm = TRUE)),
      predictive_parity_gap_pp = 100 * (max(sub$ppv, na.rm = TRUE) -
                                          min(sub$ppv, na.rm = TRUE)),
      stringsAsFactors = FALSE
    )
  }))
  rownames(gaps) <- NULL
  list(table = tbl, gaps = gaps)
}
