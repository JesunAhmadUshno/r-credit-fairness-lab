// Known-answer check, run by `npm run build` after make-data.mjs and before vite.
// Fails the build if the generated page data drifts from RESULTS.md, the study's
// own written record, or if the split-integrity facts stop holding.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const read = (p) => fs.readFileSync(fileURLToPath(new URL(`../../${p}`, import.meta.url)), 'utf8');
const data = JSON.parse(fs.readFileSync(fileURLToPath(new URL('./data.json', import.meta.url)), 'utf8'));
const results = read('RESULTS.md');
const f5 = (n) => n.toFixed(5);
const f2 = (n) => n.toFixed(2);

// 1. Verdicts and headline numbers match RESULTS.md exactly, at page precision.
assert.equal(data.verdicts.H1.verdict, 'CONFIRMED');
assert.equal(data.verdicts.H2.verdict, 'REFUTED');
assert.equal(data.verdicts.H3.verdict, 'CONFIRMED');
assert.equal(f5(data.verdicts.H1.rGbmAuc), '0.78237');
assert.ok(results.includes('0.78237'), 'RESULTS.md H1 AUC');
assert.equal(f5(data.verdicts.H1.difference), '0.00137');
assert.ok(results.includes('0.00137'), 'RESULTS.md H1 difference');
assert.equal(f5(data.verdicts.H2.difference), '0.02090');
assert.ok(results.includes('0.02090'), 'RESULTS.md H2 gap');
assert.ok(results.includes('0.00090'), 'RESULTS.md H2 overshoot');
assert.equal(f2(data.verdicts.H3.maxGapPp), '39.16');
assert.ok(results.includes('39.16 pp'), 'RESULTS.md H3 gap');

// 2. Performance table values are the RESULTS.md table values.
const byArm = Object.fromEntries(data.metrics.map((m) => [m.arm, m]));
assert.equal(f5(byArm.r_gbm_xgboost.ks), '0.42429');
assert.equal(f5(byArm.r_gam_mgcv.auc), '0.76147');
assert.equal(f5(byArm.r_ridge_logistic_glmnet.auc), '0.74702');
assert.equal(byArm.python_champion_histgbm.auc, 0.781);
for (const s of ['0.42429', '0.76147', '0.74702', '0.4196']) assert.ok(results.includes(s), `RESULTS.md metric ${s}`);

// 3. Fairness gaps and the small-group caveat facts.
const gap = Object.fromEntries(data.gaps.map((g) => [g.attribute, g]));
assert.equal(f2(gap.education.eoGapPp), '39.16');
assert.equal(f2(gap.age_band.eoGapPp), '5.78');
assert.equal(f2(gap.sex.eoGapPp), '1.21');
assert.equal(f2(gap.education.ppGapPp), '19.46');
const others = data.audit.find((r) => r.attribute === 'education' && r.group === 'others');
assert.equal(others.n, 120);
assert.equal(others.defaults, 8);
assert.ok(results.includes('n = 120, 8 defaults'), 'RESULTS.md small-group caveat');

// 4. Split integrity: the two hashes are equal, the flag holds, RESULTS.md prints the hash.
assert.equal(data.split.identical, true);
assert.equal(data.split.rHash, data.split.refHash);
assert.ok(results.includes(data.split.rHash), 'RESULTS.md split hash');
assert.equal(data.split.nTest, 9000);
assert.equal(data.split.nTrain, 21000);

// 5. The frozen operating point the audit is read at.
assert.equal(data.run.threshold, 0.2293);
assert.ok(results.includes('0.2293'), 'RESULTS.md threshold');
assert.equal(data.run.seed, 42);

console.log('check ok', {
  h1: data.verdicts.H1.verdict, h2: data.verdicts.H2.verdict, h3: data.verdicts.H3.verdict,
  gbmAuc: f5(data.verdicts.H1.rGbmAuc), maxGapPp: f2(data.verdicts.H3.maxGapPp),
});
