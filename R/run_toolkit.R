# run_toolkit.R: the study pipeline as a runnable toolkit.
#
# Takes a dataset (CSV, or the study's .xls) with the study schema
# (the UCI Taiwan credit columns: LIMIT_BAL, SEX, AGE, EDUCATION,
# MARRIAGE, PAY_0..PAY_6, BILL_AMT1..6, PAY_AMT1..6, and a binary
# target), a small JSON config, and produces the same tables the
# study produces: model_metrics.csv, fairness_audit.csv,
# fairness_gaps.csv, plus toolkit_summary.json.
#
# It reuses the study's own functions (R/data.R, R/metrics.R,
# R/fairness.R, R/sklearn_split.R) and mirrors scripts/run_all.R's
# arm code with the same seeds, so the study configuration
# reproduces the published numbers. It writes only to --out-dir;
# the frozen study (scripts/run_all.R, results/) is untouched.
#
# Usage, from the repo root:
#   Rscript R/run_toolkit.R --data PATH [--config PATH] [--out-dir DIR]
#
# Config (JSON, every key optional):
#   target_column        name of the binary target column ("default")
#   threshold            fairness audit threshold (0.2293)
#   protected_attributes subset of c("SEX", "AGE", "EDUCATION")
#   seed                 split seed (42)
#   test_size            test fraction (0.30)
#   expected_gbm_auc     if set, stop loudly when the GBM test AUC
#                        differs from it by more than 0.0005
#   reference_arm        optional list(arm, auc, ks, brier) prepended
#                        to the metrics table (the study config uses
#                        it for the Python champion row)
#
# scripts/toolkit_config_study.json is the study configuration: with
# the study's frozen dataset it reproduces RESULTS.md (GBM AUC
# 0.78237) and asserts that it did.

suppressPackageStartupMessages({
  library(tidymodels)
  library(jsonlite)
})
source("R/sklearn_split.R")
source("R/data.R")
source("R/metrics.R")
source("R/fairness.R")

args <- commandArgs(trailingOnly = TRUE)
get_opt <- function(name, default = NULL) {
  hit <- match(name, args)
  if (is.na(hit) || hit == length(args)) default else args[hit + 1]
}
data_path <- get_opt("--data")
config_path <- get_opt("--config")
out_dir <- get_opt("--out-dir", "toolkit_out")
if (is.null(data_path)) {
  stop("usage: Rscript R/run_toolkit.R --data PATH [--config PATH] ",
       "[--out-dir DIR]")
}
note <- function(...) cat(sprintf(...), "\n")

cfg <- list(
  target_column = "default",
  threshold = 0.2293,
  protected_attributes = c("SEX", "AGE", "EDUCATION"),
  seed = 42,
  test_size = 0.30,
  expected_gbm_auc = NULL,
  reference_arm = NULL
)
if (!is.null(config_path)) {
  from_file <- jsonlite::read_json(config_path, simplifyVector = TRUE)
  for (nm in names(from_file)) cfg[[nm]] <- from_file[[nm]]
}
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
t0 <- Sys.time()

## 1. Load ---------------------------------------------------------------
if (grepl("\\.xls[x]?$", data_path)) {
  raw <- load_credit_data(data_path)
} else {
  raw <- utils::read.csv(data_path, check.names = FALSE,
                         stringsAsFactors = FALSE)
  if (!(cfg$target_column %in% names(raw)) && TARGET_RAW %in% names(raw)) {
    names(raw)[names(raw) == TARGET_RAW] <- cfg$target_column
  }
  if (!(cfg$target_column %in% names(raw))) {
    stop("target column '", cfg$target_column, "' not found in ", data_path)
  }
  raw$EDUCATION[raw$EDUCATION %in% c(0, 5, 6)] <- 4
  raw$MARRIAGE[raw$MARRIAGE == 0] <- 3
  raw[[cfg$target_column]] <- as.integer(raw[[cfg$target_column]])
  raw <- tibble::as_tibble(raw)
}
if (cfg$target_column != "default") {
  raw$default <- raw[[cfg$target_column]]
}
df <- add_features(raw)
y <- df$default
note("loaded %d rows from %s; events %d; event rate %.4f",
     nrow(df), data_path, sum(y), mean(y))

## 2. Split (same replication as the study) -------------------------------
split <- sklearn_stratified_split(y, test_size = cfg$test_size,
                                  seed = cfg$seed)
train_df <- df[split$train_pos + 1, ]
test_df <- df[split$test_pos + 1, ]
y_test <- test_df$default
note("split: train n=%d, test n=%d (seed %d, test_size %.2f)",
     length(split$train_pos), length(split$test_pos),
     cfg$seed, cfg$test_size)

## 3. Arms (mirrors scripts/run_all.R, same seeds) -------------------------
train_ml <- train_df[, c(MODEL_FEATURES, "default")]
test_ml <- test_df[, c(MODEL_FEATURES, "default")]
for (nm in CAT_FEATURES) {
  train_ml[[nm]] <- factor(train_ml[[nm]])
  test_ml[[nm]] <- factor(test_ml[[nm]], levels = levels(train_ml[[nm]]))
}
train_ml$default <- factor(train_ml$default, levels = c(0, 1),
                           labels = c("repaid", "defaulted"))
test_ml$default <- factor(test_ml$default, levels = c(0, 1),
                          labels = c("repaid", "defaulted"))

rec <- recipe(default ~ ., data = train_ml) |>
  step_impute_median(all_numeric_predictors()) |>
  step_normalize(all_numeric_predictors()) |>
  step_dummy(all_nominal_predictors())

pred_pd <- function(fit, new_data) {
  predict(fit, new_data, type = "prob")$.pred_defaulted
}

lr_spec <- logistic_reg(penalty = tune(), mixture = 0) |>
  set_engine("glmnet") |>
  set_mode("classification")
lr_wf <- workflow() |> add_recipe(rec) |> add_model(lr_spec)
set.seed(cfg$seed)
folds <- vfold_cv(train_ml, v = 5)
pen_grid <- grid_regular(penalty(range = c(-4, 2)), levels = 30)
lr_tuned <- tune_grid(lr_wf, resamples = folds, grid = pen_grid,
                      metrics = metric_set(roc_auc))
best_pen <- select_best(lr_tuned, metric = "roc_auc")
lr_fit <- fit(finalize_workflow(lr_wf, best_pen), train_ml)
p_lr <- pred_pd(lr_fit, test_ml)
note("arm 1 (ridge logistic): chosen penalty %.6g", best_pen$penalty)

gbm_spec <- boost_tree(trees = 300, learn_rate = 0.06, tree_depth = 3) |>
  set_engine("xgboost") |>
  set_mode("classification")
gbm_wf <- workflow() |> add_recipe(rec) |> add_model(gbm_spec)
set.seed(cfg$seed)
gbm_fit <- fit(gbm_wf, train_ml)
p_gbm <- pred_pd(gbm_fit, test_ml)
auc_gbm_1 <- auc_score(y_test, p_gbm)
set.seed(cfg$seed)
gbm_fit2 <- fit(gbm_wf, train_ml)
p_gbm2 <- pred_pd(gbm_fit2, test_ml)
auc_gbm_2 <- auc_score(y_test, p_gbm2)
determinism_gap <- abs(auc_gbm_1 - auc_gbm_2)
note("arm 2 (xgboost GBM): AUC run1 %.6f run2 %.6f gap %.2g",
     auc_gbm_1, auc_gbm_2, determinism_gap)
if (determinism_gap > 1e-6) {
  stop("GBM determinism check failed: refit AUC differs by ",
       determinism_gap)
}

gam_train <- train_df[, c(NUMERIC_FEATURES, CAT_FEATURES, "default")]
gam_test <- test_df[, c(NUMERIC_FEATURES, CAT_FEATURES, "default")]
for (nm in NUMERIC_FEATURES) {
  med <- median(gam_train[[nm]], na.rm = TRUE)
  gam_train[[nm]][is.na(gam_train[[nm]])] <- med
  gam_test[[nm]][is.na(gam_test[[nm]])] <- med
}
for (nm in CAT_FEATURES) {
  gam_train[[nm]] <- factor(gam_train[[nm]])
  gam_test[[nm]] <- factor(gam_test[[nm]], levels = levels(gam_train[[nm]]))
}
gam_formula <- default ~ s(LIMIT_BAL, k = 10) + s(AGE, k = 10) +
  s(BILL_AMT1, k = 10) + s(PAY_AMT1, k = 10) + s(utilization, k = 10) +
  s(pay_ratio, k = 10) + s(bill_trend, k = 10) +
  delinq_mean + delinq_max +
  PAY_0 + PAY_2 + PAY_3 + PAY_4 + PAY_5 + PAY_6 +
  SEX + EDUCATION + MARRIAGE
gam_fit <- mgcv::gam(gam_formula, data = gam_train,
                     family = binomial(), method = "REML")
p_gam <- as.numeric(predict(gam_fit, newdata = gam_test, type = "response"))
note("arm 3 (mgcv GAM): fitted, deviance explained %.3f",
     summary(gam_fit)$dev.expl)

## 4. Metrics table ---------------------------------------------------------
metrics <- data.frame(
  arm = c("r_ridge_logistic_glmnet", "r_gbm_xgboost", "r_gam_mgcv"),
  auc = c(auc_score(y_test, p_lr), auc_gbm_1, auc_score(y_test, p_gam)),
  ks = c(ks_stat(y_test, p_lr), ks_stat(y_test, p_gbm),
         ks_stat(y_test, p_gam)),
  brier = c(brier_score(y_test, p_lr), brier_score(y_test, p_gbm),
            brier_score(y_test, p_gam)),
  stringsAsFactors = FALSE
)
if (!is.null(cfg$reference_arm)) {
  metrics <- rbind(
    data.frame(arm = cfg$reference_arm$arm, auc = cfg$reference_arm$auc,
               ks = cfg$reference_arm$ks, brier = cfg$reference_arm$brier,
               stringsAsFactors = FALSE),
    metrics
  )
}
write.csv(metrics, file.path(out_dir, "model_metrics.csv"),
          row.names = FALSE)
print(metrics)

## 5. Fairness audit (config threshold and attributes) ----------------------
CHAMPION_THRESHOLD <- cfg$threshold
groupings <- list(
  SEX = list(attribute = "sex",
             group = unname(SEX_LABELS[as.character(test_df$SEX)])),
  AGE = list(attribute = "age_band",
             group = as.character(factor(age_band(test_df$AGE),
                                         levels = AGE_BAND_LEVELS,
                                         ordered = TRUE))),
  EDUCATION = list(attribute = "education",
                   group = unname(EDU_LABELS[as.character(test_df$EDUCATION)]))
)
fair_in <- data.frame(default = y_test, pred_pd = p_gbm)
tbl_parts <- list()
for (att in cfg$protected_attributes) {
  g <- groupings[[att]]
  if (is.null(g)) stop("unsupported protected attribute: ", att)
  tbl_parts[[length(tbl_parts) + 1]] <-
    group_fairness(fair_in, g$attribute, g$group)
}
fair_table <- do.call(rbind, tbl_parts)
rownames(fair_table) <- NULL
gap_rows <- lapply(split(fair_table, fair_table$attribute), function(sub) {
  data.frame(
    attribute = sub$attribute[1],
    equal_opportunity_gap_pp = 100 * (max(sub$tpr, na.rm = TRUE) -
                                        min(sub$tpr, na.rm = TRUE)),
    predictive_parity_gap_pp = 100 * (max(sub$ppv, na.rm = TRUE) -
                                        min(sub$ppv, na.rm = TRUE)),
    stringsAsFactors = FALSE
  )
})
fair_gaps <- do.call(rbind, gap_rows)
rownames(fair_gaps) <- NULL
write.csv(fair_table, file.path(out_dir, "fairness_audit.csv"),
          row.names = FALSE)
write.csv(fair_gaps, file.path(out_dir, "fairness_gaps.csv"),
          row.names = FALSE)
print(fair_gaps)

## 6. Summary and the reproduction assertion --------------------------------
summary_out <- list(
  data = data_path,
  config = cfg,
  n_rows = nrow(df),
  n_train = length(split$train_pos),
  n_test = length(split$test_pos),
  gbm_auc = auc_gbm_1,
  gbm_determinism_gap = determinism_gap,
  chosen_penalty_glmnet = best_pen$penalty,
  threshold = cfg$threshold,
  runtime_seconds = as.numeric(difftime(Sys.time(), t0, units = "secs"))
)
write_json(summary_out, file.path(out_dir, "toolkit_summary.json"),
           auto_unbox = TRUE, pretty = TRUE, digits = 8)

if (!is.null(cfg$expected_gbm_auc)) {
  delta <- abs(auc_gbm_1 - cfg$expected_gbm_auc)
  if (delta > 0.0005) {
    stop(sprintf(
      paste0("REPRODUCTION FAILED: GBM AUC %.5f differs from the ",
             "expected %.5f by %.5f (tolerance 0.0005)"),
      auc_gbm_1, cfg$expected_gbm_auc, delta))
  }
  note("reproduction check PASSED: GBM AUC %.5f within 0.0005 of %.5f",
       auc_gbm_1, cfg$expected_gbm_auc)
}
note("toolkit run complete in %.1f s; tables in %s",
     summary_out$runtime_seconds, out_dir)
