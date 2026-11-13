# PLAN: r-credit-fairness-lab

1. Extract the Python record: data file and hash, load and recode rules,
   feature formulas, split rule, champion metrics, champion threshold.
   (Done from credit-risk-lab source and results, before registration.)
2. Derive the reference split identity with credit-risk-lab's own pinned
   stack (scikit-learn 1.9.1): test counts, event rate, SHA-256 of the
   sorted test row positions; recompute the champion as a sanity check.
   (Done before registration; AUC 0.78103 vs published 0.7810.)
3. Register: commit LICENSE, data file, PREREGISTRATION.md, SPEC.md, and
   this plan before any model is fit.
4. Build R code: numpy-compatible MT19937 and sklearn split replication,
   data loading and features mirroring the Python lab, metric functions,
   arm fitting, fairness audit, run_all entry point.
5. Verify the R split hash equals the reference hash. Stop and amend the
   registration if it does not.
6. Run the pipeline end to end; write results CSVs and the summary JSON.
7. Tests (testthat) and local test run.
8. Render the Quarto report to HTML.
9. Draft RESULTS.md; run the Jev claim_check gate on its claims; fix what
   it flags; re-check.
10. renv snapshot; CI workflow; push; confirm CI green on the results
    commit.
11. Grade the repo on the 10,000-point house standard (grade reported to
    the coordinator only, never committed).
