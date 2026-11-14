# r-credit-fairness-lab

An R-native rebuild of a credit-risk champion, with a pre-registered
group fairness audit.

## Research question

Does an R-native rebuild of the credit-risk champion from the Python
lab `credit-risk-lab` (tidymodels: regularized logistic regression,
gradient boosting through the xgboost engine, plus a GAM arm) reproduce
the Python champion's discrimination on the same UCI Taiwan credit
data and the same locked split, and where do group fairness gaps
(equal opportunity, predictive parity) sit across sex, age bands, and
education?

The societal stake is fair access to credit in Canada: a champion
model whose errors fall unevenly on protected groups is a finding
about the model, and it matters most exactly where credit decisions
gate people's lives.

## Pre-registered verdicts

Frozen in `PREREGISTRATION.md` before any model was fit (the commit
timestamp is the receipt). Full detail in `RESULTS.md` and in the
rendered report, `report/report.html`.

| Hypothesis | Verdict | Headline |
| --- | --- | --- |
| H1: R GBM AUC within 0.01 of the Python champion (0.7810) | CONFIRMED | R GBM AUC 0.78237, difference 0.00137 |
| H2: GAM loses at most 0.02 AUC against the GBM | REFUTED | Gap 0.02090, over the line by 0.00090 |
| H3: Some protected attribute shows an equal-opportunity gap above 5 pp | CONFIRMED | Education 39.16 pp (small-group caveat in RESULTS.md); age 5.78 pp; sex 1.21 pp |

## Method

- Data: UCI dataset 350, "default of credit card clients" (Taiwan,
  2005), 30,000 rows, committed byte-identical under `data/`; the
  pipeline verifies its SHA-256 before loading. Loading, recodes, and
  feature engineering mirror `credit-risk-lab` line for line.
- Split: the Python lab's split (stratified 70/30,
  `train_test_split(random_state = 42)`) replicated exactly in pure R
  (`R/sklearn_split.R`, a numpy-compatible MT19937 plus the sklearn
  StratifiedShuffleSplit steps) and proven identical by hash:
  SHA-256 of the sorted 0-based test positions matches the Python
  reference (`f2d688ab`...), test n 9,000, event rate 0.22122. The
  pipeline and the tests stop if the hash ever mismatches.
- Arms: (1) ridge logistic regression, glmnet via tidymodels, penalty
  tuned by 5-fold cross-validation on the training set only; (2)
  gradient boosting, xgboost engine in tidymodels at the champion's
  hyperparameters (300 trees, learning rate 0.06, depth 3), fit twice
  under seed 42 with a determinism check (gap exactly 0); (3) GAM fit
  directly with mgcv (the route stated in advance), with the full
  smooth-term table in `results/gam_terms.csv`.
- Fairness audit at the frozen champion threshold 0.2293, recorded in
  `credit-risk-lab`: per group, TPR, PPV, selection rate, group size,
  event rate, in `results/fairness_audit.csv`; gap summary in
  `results/fairness_gaps.csv`.

## Reproduce

Requirements: R 4.5.1 (pinned; `renv.lock` records it), Quarto for the
report.

Install route used for this build: R 4.5.1 from the official Posit
binary tarball for Ubuntu 24.04 (`cdn.posit.co/r/ubuntu-2404`),
packages as prebuilt Linux binaries from Posit Package Manager. On a
fresh machine, `rig add 4.5.1` or the same tarball gives the same R.

```sh
Rscript -e 'renv::restore()'     # restore the locked package set
Rscript tests/run_tests.R        # testthat suite (33 expectations)
Rscript scripts/run_all.R        # full pipeline, about 30 seconds
quarto render report/report.qmd  # rebuild the HTML report
```

CI (GitHub Actions, ubuntu-24.04) restores renv, runs the tests, runs
the pipeline end to end, and asserts the split verification file
reports the split identical.

## Layout

- `PREREGISTRATION.md`: frozen hypotheses, split, threshold, rules.
- `RESULTS.md`: verdicts, verification, limitations, claims ceiling.
- `R/`: split replication, data loading, metrics, fairness audit.
- `scripts/run_all.R`: the one scripted pipeline path.
- `results/`: machine-readable outputs of the run of record.
- `report/`: Quarto source and the committed rendered HTML.
- `tests/`: testthat suite (schema, metrics, exact split identity).

## Claims ceiling

A study on public Taiwan 2005 data. It evidences method only: it is
not production experience, not a Canadian portfolio result, and not
evidence about any real lender.

License: Apache-2.0.
