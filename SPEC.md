# SPEC: r-credit-fairness-lab

## Purpose

An R-native rebuild of the Python credit-risk champion in `credit-risk-lab`,
on identical data and an identical locked split, with a group fairness audit
the Python lab did not run. Built to the Gap-Closure Research Programme
standard: pre-registered hypotheses, measured results only, verdicts either
way.

## Research question

See PREREGISTRATION.md (frozen). Short form: does the R rebuild reproduce
the Python champion's discrimination (GBM AUC 0.7810, KS 0.4196), and where
do equal-opportunity and predictive-parity gaps sit across sex, age bands,
and education at the champion threshold 0.2293?

## Deliverables

- Reproducible R project, renv lockfile committed, R version pinned in the
  README.
- Three arms (regularized logistic regression, xgboost GBM, mgcv GAM) fit by
  one scripted path: `Rscript scripts/run_all.R`.
- Split identity verification against the Python reference hash, in code and
  in RESULTS.md.
- Fairness audit tables in the rendered report and in
  `results/fairness_audit.csv`.
- Quarto report rendered to HTML, committed.
- testthat tests: data schema, split size and identity, metric functions.
- GitHub Actions CI: restore renv, run the tests and the full pipeline,
  green on the results commit.

## Non-goals

- No production claim, no real portfolio, no employment claim. Study scope
  only (claims ceiling in PREREGISTRATION.md).
- No new data collection; the UCI file is committed byte-identical so the
  pipeline runs offline and in CI without downloads.

## Environment

- R 4.5.1 (installed user-space from the Posit R binary build for Ubuntu
  24.04; the apt CRAN route failed through the local proxy, the Posit
  tarball route worked). Packages from Posit Package Manager Linux binaries
  for Ubuntu noble, frozen by renv.
