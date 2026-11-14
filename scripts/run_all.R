# r-credit-fairness-lab: full pipeline, one scripted path.
# Run from the repo root:  Rscript scripts/run_all.R
# Fits the three pre-registered arms on the locked split, verifies the
# split identity against the Python reference hash, writes all results
# under results/. Stops hard if the data file or the split does not
# match the pre-registration.

suppressPackageStartupMessages({
  library(tidymodels)
  library(jsonlite)
})
source("R/sklearn_split.R")
source("R/data.R")
source("R/metrics.R")
source("R/fairness.R")

dir.create("results", showWarnings = FALSE)
t0 <- Sys.time()
note <- function(...) cat(sprintf(...), "\n")

## 1. Data file identity -------------------------------------------------
actual_hash <- file_sha256(DATA_FILE)
if (actual_hash != DATA_SHA256) {
  stop("data file SHA-256 mismatch: ", actual_hash, " != ", DATA_SHA256)
}
note("data file SHA-256 verified: %s", actual_hash)

raw <- load_credit_data()
stopifnot(nrow(raw) == 30000)
df <- add_features(raw)
y <- df$default
note("loaded %d rows; events %d; event rate %.4f",
     nrow(df), sum(y), mean(y))

## 2. Locked split, replicated in R, verified by hash --------------------
split <- sklearn_stratified_split(y, test_size = 0.30, seed = 42)
test_hash <- digest::digest(paste(split$test_sorted, collapse = ","),
                            algo = "sha256", serialize = FALSE)
REFERENCE_TEST_HASH <-
  "f2d688ab873deecc378b0212ae22bc297631f9833be82a856cd5fa4fd8f1598c"
split_check <- list(
  n_train = length(split$train_pos),
  n_test = length(split$test_pos),
  n_train_per_class = split$n_train_per_class,
  n_test_per_class = split$n_test_per_class,
  test_event_rate = mean(y[split$test_sorted + 1]),
  r_test_positions_sha256 = test_hash,
  reference_test_positions_sha256 = REFERENCE_TEST_HASH,
  identical = identical(test_hash, REFERENCE_TEST_HASH)
)
write_json(split_check, "results/split_verification.json",
           auto_unbox = TRUE, pretty = TRUE, digits = 8)
if (!split_check$identical) {
  stop("SPLIT IDENTITY FAILED: R test set hash ", test_hash,
       " != reference ", REFERENCE_TEST_HASH,
       ". Per PREREGISTRATION.md, amend before fitting anything.")
}
note("split identity verified: test n=%d, events=%d, hash matches reference",
     split_check$n_test, split$n_test_per_class[2])

train_df <- df[split$train_pos + 1, ]
test_df <- df[split$test_pos + 1, ]
y_test <- test_df$default

## 3. Arms ---------------------------------------------------------------
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

### Arm 1: regularized logistic regression (glmnet, ridge), penalty tuned
### by 5-fold CV on the training set only, rule frozen in the registration.
lr_spec <- logistic_reg(penalty = tune(), mixture = 0) |>
  set_engine("glmnet") |>
  set_mode("classification")
lr_wf <- workflow() |> add_recipe(rec) |> add_model(lr_spec)
set.seed(42)
folds <- vfold_cv(train_ml, v = 5)
pen_grid <- grid_regular(penalty(range = c(-4, 2)), levels = 30)
lr_tuned <- tune_grid(lr_wf, resamples = folds, grid = pen_grid,
                      metrics = metric_set(roc_auc))
best_pen <- select_best(lr_tuned, metric = "roc_auc")
lr_fit <- fit(finalize_workflow(lr_wf, best_pen), train_ml)
p_lr <- pred_pd(lr_fit, test_ml)
note("arm 1 (ridge logistic): chosen penalty %.6g", best_pen$penalty)

### Arm 2: gradient boosting, xgboost engine, champion hyperparameters.
gbm_spec <- boost_tree(trees = 300, learn_rate = 0.06, tree_depth = 3) |>
  set_engine("xgboost") |>
  set_mode("classification")
gbm_wf <- workflow() |> add_recipe(rec) |> add_model(gbm_spec)
set.seed(42)
gbm_fit <- fit(gbm_wf, train_ml)
p_gbm <- pred_pd(gbm_fit, test_ml)
auc_gbm_1 <- auc_score(y_test, p_gbm)
set.seed(42)
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

### Arm 3: GAM via direct mgcv (route frozen in the registration).
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

## 4. Metrics ------------------------------------------------------------
CHAMPION_AUC <- 0.7810
CHAMPION_KS <- 0.4196
metrics <- data.frame(
  arm = c("python_champion_histgbm", "r_ridge_logistic_glmnet",
          "r_gbm_xgboost", "r_gam_mgcv"),
  auc = c(CHAMPION_AUC,
          auc_score(y_test, p_lr),
          auc_gbm_1,
          auc_score(y_test, p_gam)),
  ks = c(CHAMPION_KS,
         ks_stat(y_test, p_lr),
         ks_stat(y_test, p_gbm),
         ks_stat(y_test, p_gam)),
  brier = c(0.1355,
            brier_score(y_test, p_lr),
            brier_score(y_test, p_gbm),
            brier_score(y_test, p_gam)),
  stringsAsFactors = FALSE
)
write.csv(metrics, "results/model_metrics.csv", row.names = FALSE)
print(metrics)

## 5. Fairness audit on the GBM arm --------------------------------------
fair_in <- data.frame(
  default = y_test, pred_pd = p_gbm,
  SEX = test_df$SEX, AGE = test_df$AGE, EDUCATION = test_df$EDUCATION
)
fair <- fairness_audit(fair_in)
write.csv(fair$table, "results/fairness_audit.csv", row.names = FALSE)
write.csv(fair$gaps, "results/fairness_gaps.csv", row.names = FALSE)
print(fair$gaps)

## 6. GAM interpretability record ----------------------------------------
gam_sum <- summary(gam_fit)
sink("results/gam_summary.txt")
print(gam_sum)
sink()
smooth_tab <- as.data.frame(gam_sum$s.table)
smooth_tab$term <- rownames(smooth_tab)
rownames(smooth_tab) <- NULL
write.csv(smooth_tab[, c("term", "edf", "Ref.df", "Chi.sq", "p-value")],
          "results/gam_terms.csv", row.names = FALSE)

## 7. Verdicts by the frozen rules ---------------------------------------
auc_of <- function(arm) metrics$auc[metrics$arm == arm]
verdicts <- list(
  H1 = list(
    rule = "|AUC_R_GBM - 0.7810| <= 0.01",
    r_gbm_auc = auc_of("r_gbm_xgboost"),
    difference = auc_of("r_gbm_xgboost") - CHAMPION_AUC,
    verdict = if (abs(auc_of("r_gbm_xgboost") - CHAMPION_AUC) <= 0.01)
      "CONFIRMED" else "REFUTED"
  ),
  H2 = list(
    rule = "AUC_R_GBM - AUC_R_GAM <= 0.02",
    r_gam_auc = auc_of("r_gam_mgcv"),
    difference = auc_of("r_gbm_xgboost") - auc_of("r_gam_mgcv"),
    verdict = if ((auc_of("r_gbm_xgboost") - auc_of("r_gam_mgcv")) <= 0.02)
      "CONFIRMED" else "REFUTED"
  ),
  H3 = list(
    rule = "largest equal-opportunity gap across sex, age bands, education > 5 pp",
    max_equal_opportunity_gap_pp =
      max(fair$gaps$equal_opportunity_gap_pp),
    verdict = if (max(fair$gaps$equal_opportunity_gap_pp) > 5)
      "CONFIRMED" else "REFUTED"
  )
)
write_json(verdicts, "results/verdicts.json", auto_unbox = TRUE,
           pretty = TRUE, digits = 8)
for (nm in names(verdicts)) note("%s: %s", nm, verdicts[[nm]]$verdict)

## 8. Run summary ----------------------------------------------------------
summary_out <- list(
  r_version = R.version.string,
  engine_gbm = "xgboost",
  seed = 42,
  chosen_penalty_glmnet = best_pen$penalty,
  gbm_determinism = list(auc_run1 = auc_gbm_1, auc_run2 = auc_gbm_2,
                         gap = determinism_gap),
  gam_deviance_explained = gam_sum$dev.expl,
  threshold = CHAMPION_THRESHOLD,
  runtime_seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")),
  packages = list(
    tidymodels = as.character(packageVersion("tidymodels")),
    glmnet = as.character(packageVersion("glmnet")),
    xgboost = as.character(packageVersion("xgboost")),
    mgcv = as.character(packageVersion("mgcv"))
  )
)
write_json(summary_out, "results/run_summary.json", auto_unbox = TRUE,
           pretty = TRUE, digits = 8)
note("run_all complete in %.1f s", summary_out$runtime_seconds)
