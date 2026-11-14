// Generates src/data.json from the committed study artifacts in ../results/.
// Runs as the first step of `npm run build`, so the page can only ever show
// numbers that are in the repo's own results files. Fails loudly if an
// expected arm, attribute, or artifact is missing.
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const read = (p) => fs.readFileSync(fileURLToPath(new URL(`../../${p}`, import.meta.url)), 'utf8');
const json = (p) => JSON.parse(read(p));

// Minimal CSV reader: handles the quoted fields the R pipeline writes.
function parseCsv(text) {
  const rows = [];
  let row = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"') {
        if (text[i + 1] === '"') { field += '"'; i++; } else quoted = false;
      } else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else if (c !== '\r') field += c;
  }
  if (field !== '' || row.length) { row.push(field); rows.push(row); }
  const [head, ...body] = rows.filter((r) => r.length > 1);
  return body.map((r) => Object.fromEntries(head.map((h, i) => [h, r[i]])));
}

const ARM_LABELS = [
  ['python_champion_histgbm', 'Python champion (HistGradientBoosting, reference)'],
  ['r_gbm_xgboost', 'R GBM (xgboost engine in tidymodels)'],
  ['r_gam_mgcv', 'R GAM (mgcv, direct fit)'],
  ['r_ridge_logistic_glmnet', 'R ridge logistic regression (glmnet, tuned)'],
];
const ATTR_LABELS = { sex: 'Sex', age_band: 'Age band', education: 'Education' };

const metricsByArm = Object.fromEntries(
  parseCsv(read('results/model_metrics.csv')).map((r) => [r.arm, r]),
);
const metrics = ARM_LABELS.map(([arm, label]) => {
  const r = metricsByArm[arm];
  if (!r) throw new Error(`model_metrics.csv is missing arm ${arm}`);
  return { arm, label, auc: +r.auc, ks: +r.ks, brier: +r.brier };
});

const gaps = parseCsv(read('results/fairness_gaps.csv'))
  .map((r) => ({
    attribute: r.attribute,
    label: ATTR_LABELS[r.attribute] ?? r.attribute,
    eoGapPp: +r.equal_opportunity_gap_pp,
    ppGapPp: +r.predictive_parity_gap_pp,
  }))
  .sort((a, b) => b.eoGapPp - a.eoGapPp);
if (gaps.length !== 3) throw new Error(`fairness_gaps.csv should have 3 attributes, got ${gaps.length}`);

const audit = parseCsv(read('results/fairness_audit.csv')).map((r) => ({
  attribute: r.attribute,
  attributeLabel: ATTR_LABELS[r.attribute] ?? r.attribute,
  group: r.group,
  n: +r.n,
  defaults: +r.defaults,
  eventRate: +r.event_rate,
  tpr: +r.tpr,
  ppv: +r.ppv,
  selectionRate: +r.selection_rate,
}));

const v = json('results/verdicts.json');
const verdicts = {
  H1: { rule: v.H1.rule, rGbmAuc: v.H1.r_gbm_auc, difference: v.H1.difference, verdict: v.H1.verdict },
  H2: { rule: v.H2.rule, rGamAuc: v.H2.r_gam_auc, difference: v.H2.difference, verdict: v.H2.verdict },
  H3: { rule: v.H3.rule, maxGapPp: v.H3.max_equal_opportunity_gap_pp, verdict: v.H3.verdict },
};

const s = json('results/split_verification.json');
const split = {
  nTrain: s.n_train,
  nTest: s.n_test,
  nTrainPerClass: s.n_train_per_class,
  nTestPerClass: s.n_test_per_class,
  testEventRate: s.test_event_rate,
  rHash: s.r_test_positions_sha256,
  refHash: s.reference_test_positions_sha256,
  identical: s.identical,
};

const rs = json('results/run_summary.json');
const run = {
  rVersion: rs.r_version,
  engineGbm: rs.engine_gbm,
  seed: rs.seed,
  threshold: rs.threshold,
  gamDevianceExplained: rs.gam_deviance_explained,
  packages: rs.packages,
};

const out = fileURLToPath(new URL('./data.json', import.meta.url));
fs.writeFileSync(out, JSON.stringify({ metrics, gaps, audit, verdicts, split, run }, null, 2) + '\n');
console.log('data.json written from ../results/', {
  metrics: metrics.length, gaps: gaps.length, auditRows: audit.length,
});
