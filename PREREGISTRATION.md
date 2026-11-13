# Pre-registration: r-credit-fairness-lab

Registered 2026-11-13. This file is committed to the repository BEFORE any
model in this study is fit. The commit that introduces this file is the
receipt. No arm is fit, tuned, or evaluated before that commit exists.

## Research question

Does an R-native rebuild of the credit-risk champion from the Python lab
`credit-risk-lab` (tidymodels: regularized logistic regression, gradient
boosting through the xgboost engine inside tidymodels, plus a GAM arm)
reproduce the Python champion's discrimination on the same UCI Taiwan
credit data and the same locked split, and where do group fairness gaps
(equal opportunity, predictive parity) sit across sex, age bands, and
education?

## Data (frozen)

- Source: UCI Machine Learning Repository, dataset 350, "default of credit
  card clients" (Taiwan, 2005), 30,000 accounts.
- File: `data/default of credit card clients.xls`, the file distributed by
  UCI and held byte-identical in credit-risk-lab.
- SHA-256 of the file: 30c6be3abd8dcfd3e6096c828bad8c2f011238620f5369220bd60cfc82700933
- Load rule (identical to credit-risk-lab `load()`): read with the second
  row as header; rename the target column "default payment next month" to
  `default`; recode EDUCATION values 0, 5, 6 to 4; recode MARRIAGE value
  0 to 3. No rows are dropped.
- Features (identical to credit-risk-lab): engineered features
  utilization = BILL_AMT1 / LIMIT_BAL, pay_ratio = PAY_AMT1 / BILL_AMT1
  (missing filled with 0, clipped to [-1, 5]), delinq_mean and delinq_max
  over PAY_0, PAY_2, PAY_3, PAY_4, PAY_5, PAY_6 clipped at 0, bill_trend =
  (BILL_AMT1 - BILL_AMT6) / LIMIT_BAL. Model matrix columns: LIMIT_BAL,
  AGE, BILL_AMT1, PAY_AMT1, utilization, pay_ratio, delinq_mean,
  delinq_max, bill_trend, PAY_0, PAY_2, PAY_3, PAY_4, PAY_5, PAY_6, plus
  categorical SEX, EDUCATION, MARRIAGE.

## Locked split (frozen, with identity check)

- Rule, copied from credit-risk-lab: `train_test_split(test_size = 0.30,
  stratify = y, random_state = 42)` from scikit-learn. credit-risk-lab
  pins scikit-learn 1.9.1 in its requirements.txt.
- Expected composition: train 21,000 rows (16,355 non-default, 4,645
  default); test 9,000 rows (7,009 non-default, 1,991 default); test event
  rate 0.22122; full-data events 6,636 of 30,000.
- Reference identity: SHA-256 of the sorted 0-based test row positions
  joined by commas is
  f2d688ab873deecc378b0212ae22bc297631f9833be82a856cd5fa4fd8f1598c,
  computed on 2026-11-13 by running credit-risk-lab's own pinned stack
  (scikit-learn 1.9.1, pandas 3.1.1, numpy 2.5.4) before any R model was
  fit. That same run recomputed the Python champion at AUC 0.78103 and
  KS 0.41961, matching the published 0.7810 and 0.4196.
- R replication: the split is reimplemented in pure R
  (`R/sklearn_split.R`): a numpy-compatible MT19937 generator (legacy
  scalar seeding, rk_interval rejection sampling, Fisher-Yates
  permutation) driving the same StratifiedShuffleSplit steps
  (approximate-mode class allocation, per-class permutations, class order
  0 then 1).
- Verification rule: the R test set must reproduce the reference SHA-256
  exactly, plus the counts and event rate above. If it does not, work
  stops and this file is amended BEFORE any fitting, with the mismatch
  stated openly. No silent approximation is permitted.

## Reference champion and threshold (frozen)

- Python champion (credit-risk-lab, results/results.json):
  HistGradientBoosting gradient boosting, AUC 0.7810, KS 0.4196,
  Brier 0.1355, on the locked test set.
- Champion threshold: 0.2293. This is the study cut-off recorded in
  credit-risk-lab (STUDY.md and HYPOTHESES.md: approve if and only if
  champion PD is at or below 0.2293). It is used as a frozen constant for
  every threshold-based metric and for the fairness audit. Stated openly:
  credit-risk-lab derived that cut-off on the same test set it audited;
  this study inherits the number, it does not re-derive it.
- Threshold semantics: predicted positive (flagged) means predicted PD
  strictly greater than 0.2293; approved means predicted PD at or below
  0.2293.

## Arms (frozen)

All arms train on the locked training set only and are evaluated once on
the locked test set.

1. Regularized logistic regression (tidymodels): `logistic_reg(penalty =
   tune(), mixture = 0)` with the glmnet engine (ridge, the L2 form used
   by the Python baseline). Preprocessing mirrors credit-risk-lab:
   median imputation then standardization for numeric columns, one-hot
   encoding for SEX, EDUCATION, MARRIAGE. Tuning rule: penalty chosen by
   5-fold cross-validation on the training set only (folds seeded 42),
   maximizing AUC over a 30-point log grid from 1e-4 to 1e2. The chosen
   penalty is reported.
2. Gradient boosting (tidymodels): `boost_tree(trees = 300, learn_rate =
   0.06, tree_depth = 3)` with the xgboost engine, mirroring the Python
   champion hyperparameters (max_iter 300, learning rate 0.06, max depth
   3). Same preprocessing recipe as arm 1 so the design matrix matches
   the Python pipeline's. Seed 42. Engine note: xgboost is the primary
   engine; lightgbm is used only if xgboost cannot be installed, and the
   engine actually used is stated in RESULTS.md.
3. GAM (mgcv): `mgcv::gam` fit directly (the direct mgcv route, stated
   here in advance): smooth terms s() with k = 10 for LIMIT_BAL, AGE,
   BILL_AMT1, PAY_AMT1, utilization, pay_ratio, bill_trend; parametric
   terms for delinq_mean, delinq_max, PAY_0, PAY_2, PAY_3, PAY_4, PAY_5,
   PAY_6; SEX, EDUCATION, MARRIAGE as factors. Binomial family, logit
   link, REML. No scaling (GAM does not need it). Full coefficient and
   smooth interpretability is the point of this arm.

Determinism: the GBM arm is refit a second time with the same seed and
the two test AUCs must agree to 1e-6; both values are reported. Seed set
for the study: 42 only.

## Metrics (frozen)

- Per arm on the locked test set: AUC (primary), KS statistic, Brier
  score, plus AUC for the Python champion alongside.
- KS definition matches credit-risk-lab: maximum separation between the
  cumulative default and non-default shares when scores are sorted
  descending.

## Hypotheses and verdict rules (frozen)

- H1: the R GBM test AUC lies within 0.01 of 0.7810.
  CONFIRMED if |AUC_R_GBM - 0.7810| <= 0.01. REFUTED otherwise.
  INCONCLUSIVE only if the GBM arm cannot be fit at all (reason stated).
- H2: the GAM arm loses no more than 0.02 AUC against the GBM arm while
  giving full interpretability.
  CONFIRMED if AUC_R_GBM - AUC_R_GAM <= 0.02. REFUTED if the difference
  is greater than 0.02. INCONCLUSIVE only if either arm cannot be fit.
- H3: at least one protected attribute shows an equal-opportunity gap
  above 5 percentage points at the champion threshold, on the R GBM arm.
  CONFIRMED if the largest equal-opportunity gap across sex, age bands,
  and education exceeds 5.00 percentage points. REFUTED if all three
  attributes show gaps at or below 5.00 points. Directional: the verdict
  is reported either way, with the full tables.

## Fairness audit (frozen)

- Arm audited: the R GBM arm (arm 2), at the champion threshold 0.2293.
- Protected attributes and groups:
  - Sex: 1 = male, 2 = female.
  - Age bands: under 30, 30 to 39, 40 to 49, 50 to 59, 60 and over.
  - Education (after recode): 1 = graduate school, 2 = university,
    3 = high school, 4 = others.
- Per group: group size n, number of defaults, event rate, true positive
  rate (share of actual defaulters flagged), positive predictive value
  (share of flagged who default), selection rate (share approved).
- Equal-opportunity gap for an attribute: max group TPR minus min group
  TPR, in percentage points. Predictive-parity gap: max group PPV minus
  min group PPV, in percentage points.
- Full tables appear in the report and in machine-readable form at
  `results/fairness_audit.csv`. Small groups are flagged, never
  suppressed or merged after the fact.

## Claims ceiling

This is a study on public Taiwan 2005 data. It evidences method only:
reproducing a published pipeline in a second language and auditing its
group fairness on the same split. It is not production experience, not a
Canadian portfolio result, and not a claim about any real lender. The
societal stake it speaks to is fair access to credit in Canada, the
flagship line of credit-risk-lab: if a champion model cannot be
reproduced exactly, or if its errors fall unevenly on protected groups,
that is a finding about the model, stated at study scope.

## Pipeline discipline

Spec, plan, build, test, review, ship, in that order. This registration
precedes all fitting. Verdicts are published either way, including
REFUTED and INCONCLUSIVE.
