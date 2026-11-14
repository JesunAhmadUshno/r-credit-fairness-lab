# Results: r-credit-fairness-lab

Study run 2026-11-13 to 2026-11-14 under PREREGISTRATION.md (committed
and pushed before any model was fit). All figures below come from one
scripted run, `Rscript scripts/run_all.R`, on R 4.5.1; artifacts are in
`results/`. Seed set used: 42 only.

## Verdicts

| Hypothesis | Frozen rule | Measured | Verdict |
| --- | --- | --- | --- |
| H1 | R GBM AUC within 0.01 of 0.7810 | AUC 0.78237, difference 0.00137 | CONFIRMED |
| H2 | GBM AUC minus GAM AUC at most 0.02 | 0.78237 - 0.76147 = 0.02090 | REFUTED |
| H3 | Largest equal-opportunity gap above 5 pp | 39.16 pp (education) | CONFIRMED |

## Performance on the locked test split

| Arm | AUC | KS | Brier |
| --- | --- | --- | --- |
| Python champion (HistGradientBoosting, reference) | 0.7810 | 0.4196 | 0.1355 |
| R GBM (xgboost engine in tidymodels) | 0.78237 | 0.42429 | 0.13502 |
| R GAM (mgcv, direct fit) | 0.76147 | 0.40376 | 0.14108 |
| R ridge logistic regression (glmnet, tuned) | 0.74702 | 0.39726 | 0.14203 |

H1 detail: the R GBM lands 0.00137 AUC above the Python champion, well
inside the frozen 0.01 band, with a slightly higher KS (0.42429 against
0.4196) and a slightly lower Brier score (0.13502 against 0.1355). The
R rebuild reproduces the champion's discrimination on the identical
split.

H2 detail: REFUTED, by 0.00090 AUC. The GAM (deviance explained 16.7
percent, full smooth-term table in `results/gam_terms.csv`) gives back
0.02090 AUC against the GBM arm, just over the frozen 0.02 allowance.
The interpretability price is real and slightly larger than the
pre-registered tolerance. The verdict is published as REFUTED per the
frozen rule; the near miss is reported, not rounded.

Determinism: the GBM arm was fit twice under seed 42 during the run.
Test AUC was 0.78237323 both times, gap exactly 0, so no variance is
reported for it. The glmnet penalty was chosen by 5-fold
cross-validation on the training set only (folds seeded 42): 0.0001.

Named limitation: the chosen glmnet penalty sits at the lower edge of
the frozen grid (1e-4 to 1e2), so the ridge arm is effectively near
unregularized and its grid should have extended lower. No hypothesis
depends on this arm; the observation is recorded because the frozen
grid, not the data, bounded the tuning result.

## Split identity verification

The split is the Python lab's split (stratified 70/30,
`train_test_split(random_state = 42)`, sklearn 1.9.1), replicated in
pure R (`R/sklearn_split.R`: numpy MT19937 plus the
StratifiedShuffleSplit steps) and compared by hash, not by summary
statistics:

| Quantity | Value |
| --- | --- |
| Train rows | 21,000 (16,355 non-default, 4,645 default) |
| Test rows | 9,000 (7,009 non-default, 1,991 default) |
| Test event rate | 0.22122 |
| SHA-256 of sorted 0-based test positions, Python reference | f2d688ab873deecc378b0212ae22bc297631f9833be82a856cd5fa4fd8f1598c |
| SHA-256 of sorted 0-based test positions, R replication | f2d688ab873deecc378b0212ae22bc297631f9833be82a856cd5fa4fd8f1598c |
| Identical | TRUE |

The pipeline stops hard if this hash ever mismatches, and the test
suite asserts the same identity. The comparison to the Python champion
is therefore a same-split comparison.

## Fairness audit (R GBM arm, champion threshold 0.2293)

Full per-group tables are in `results/fairness_audit.csv` and in the
report. Gap summary, percentage points:

| Attribute | Equal-opportunity gap (TPR) | Predictive-parity gap (PPV) |
| --- | --- | --- |
| Sex | 1.21 | 0.21 |
| Age band | 5.78 | 5.33 |
| Education | 39.16 | 19.46 |

H3 detail: CONFIRMED. The largest equal-opportunity gap is on
education: the "others" group has TPR 0.2500 against the university
group's 0.6416, a 39.16 pp gap. Two cautions ride with that headline,
as the pre-registration required small groups to be flagged, never
suppressed: "others" is small (n = 120, 8 defaults, so its TPR rests
on 8 events), and among the three large education groups (graduate
school, university, high school) the TPR spread is much narrower
(0.5943 to 0.6416, 4.73 pp). The age gap does not rest on a tiny group:
it is set by the 50-59 band (TPR 0.6554, 177 defaults) against the
30-39 band (TPR 0.5976, 661 defaults), a 5.78 pp gap that alone clears
the 5 pp line. Selection rates (share approved) run from 0.5983 (age
60 and over) to 0.9417 (education "others").

One inherited caveat, frozen in the pre-registration: the 0.2293
threshold is the champion study cut-off recorded in credit-risk-lab,
derived there on the same test set it audited. This study inherits the
number without re-deriving it; the gaps are read at that operating
point only.

## Claims ceiling

This study evidences method only. It reproduces a published Python
pipeline in R on public Taiwan 2005 data and audits the rebuilt model's
group fairness on the locked split. It is not production experience,
not a Canadian portfolio result, and not evidence about any real
lender's decisions. Any stronger reading goes beyond the evidence.
