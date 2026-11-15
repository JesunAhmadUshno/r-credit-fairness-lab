import data from './data.json';

const REPO = 'https://github.com/JesunAhmadUshno/r-credit-fairness-lab';
const blob = (p) => `${REPO}/blob/main/${p}`;
const fmt = (n, d = 0) => Number(n).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
const f5 = (n) => n.toFixed(5);
const num = (n) => String(parseFloat(n.toFixed(5))); // RESULTS.md precision, trailing zeros dropped
const f2 = (n) => n.toFixed(2);
const pct = (n) => `${(n * 100).toFixed(1)}%`;

// ---- everything below is generated from results/ at build time (see src/make-data.mjs)
const { metrics, gaps, audit, verdicts, split, run } = data;
const byArm = Object.fromEntries(metrics.map((m) => [m.arm, m]));
const gbm = byArm.r_gbm_xgboost;
const champ = byArm.python_champion_histgbm;
const gap = Object.fromEntries(gaps.map((g) => [g.attribute, g]));
const others = audit.find((r) => r.attribute === 'education' && r.group === 'others');
const age5059 = audit.find((r) => r.attribute === 'age_band' && r.group === '50-59');
const age3039 = audit.find((r) => r.attribute === 'age_band' && r.group === '30-39');
const eduLarge = audit.filter((r) => r.attribute === 'education' && r.group !== 'others');
const eduSpread = Math.max(...eduLarge.map((r) => r.tpr)) - Math.min(...eduLarge.map((r) => r.tpr));
const BAR_MAX = 40; // pp, just above the largest recorded gap

function Pill({ verdict }) {
  return <span className={`pill ${verdict === 'CONFIRMED' ? 'good' : 'bad'}`}>{verdict}</span>;
}

function VerdictCard({ id, title, v, children }) {
  return (
    <article className="card vcard">
      <div className="vhead">
        <h3>{id} · {title}</h3>
        <Pill verdict={v.verdict} />
      </div>
      <p className="rule mono">{v.rule}</p>
      {children}
    </article>
  );
}


function StructureDiagram() {
  const rows = [
    { y: 16, boxes: [[20, 'UCI Taiwan data', 'credit card clients'], [240, 'Locked split', 'stratified 70/30'], [460, 'Hash check', 'test positions, SHA-256']] },
    { y: 112, boxes: [[20, 'Ridge logistic', 'glmnet'], [180, 'GBM', 'xgboost engine'], [340, 'GAM', 'mgcv'], [500, 'Python champion', 'HistGBM']] },
    { y: 208, boxes: [[20, 'Test metrics', 'AUC, KS, Brier'], [240, 'Fairness audit', 'TPR and PPV by group'], [460, 'Verdicts', 'H1, H2, H3, frozen rules']] },
  ];
  return (
    <svg className="diagram" viewBox="0 0 680 288" role="img" aria-label="Structure diagram of the study: UCI Taiwan data and the locked, hash-checked split feed four model arms, whose test metrics and fairness audit produce the three verdicts">
      {rows.map((row) => row.boxes.map(([x, title, sub]) => {
        const w = row.boxes.length === 4 ? 160 : 200;
        return (
          <g key={title}>
            <rect className={row.y === 112 ? 'box-accent' : 'box'} x={x} y={row.y} width={w} height="56" rx="14" />
            <text className="box-title" x={x + w / 2} y={row.y + 24} textAnchor="middle">{title}</text>
            <text x={x + w / 2} y={row.y + 42} textAnchor="middle">{sub}</text>
          </g>
        );
      }))}
      <line className="arrow" x1="340" y1="72" x2="340" y2="112" />
      <line className="arrow" x1="340" y1="168" x2="340" y2="208" />
    </svg>
  );
}

function FlowDiagram() {
  const steps = [
    [2, 'Freeze', 'hypotheses first'],
    [118, 'Split in R', 'hash matched'],
    [234, 'Fit arms', 'four arms'],
    [350, 'Score', 'locked test split'],
    [466, 'Audit', 'TPR, PPV gaps'],
    [582, 'Verdicts', 'frozen lines'],
  ];
  return (
    <svg className="diagram" viewBox="0 0 680 104" role="img" aria-label="Flow diagram of the study: hypotheses frozen, split replicated in R and hash matched, four arms fit and scored on the locked test split, fairness audited, verdicts read against the frozen lines">
      {steps.map(([x, title, sub], i) => (
        <g key={title}>
          <rect className={i === 0 || i === 5 ? 'box-accent' : 'box'} x={x} y="24" width="96" height="56" rx="14" />
          <text className="box-title" x={x + 48} y="48" textAnchor="middle">{title}</text>
          <text x={x + 48} y="66" textAnchor="middle">{sub}</text>
          {i < steps.length - 1 && <line className="arrow" x1={x + 96} y1="52" x2={x + 116} y2="52" />}
        </g>
      ))}
    </svg>
  );
}

function GapBars() {
  return (
    <div className="bars">
      {gaps.map((g) => (
        <div key={g.attribute} className="bar-group">
          <div className="bar-row">
            <div className="lab"><span>{g.label}, equal opportunity</span><b>{f2(g.eoGapPp)} pp</b></div>
            <div className="track"><div className="fill eo" style={{ width: `${Math.min(100, (g.eoGapPp / BAR_MAX) * 100)}%` }} /></div>
          </div>
          <div className="bar-row">
            <div className="lab"><span>{g.label}, predictive parity</span><b>{f2(g.ppGapPp)} pp</b></div>
            <div className="track"><div className="fill pp" style={{ width: `${Math.min(100, (g.ppGapPp / BAR_MAX) * 100)}%` }} /></div>
          </div>
        </div>
      ))}
      <div className="legend">
        <span><i style={{ background: 'var(--primary)' }} />Equal-opportunity gap (TPR, max minus min across groups)</span>
        <span><i style={{ background: 'var(--warn)' }} />Predictive-parity gap (PPV, max minus min across groups)</span>
      </div>
    </div>
  );
}

export default function App() {
  return (
    <div className="wrap">
      <nav className="top">
        <a className="brand" href="#top">r-credit-fairness-lab</a>
        <div className="links">
          <a href="#verdicts">Verdicts</a>
          <a href="#performance">Performance</a>
          <a href="#fairness">Fairness</a>
          <a href="#split">Split integrity</a>
          <a href="#method">Method</a>
          <a href={blob('RESULTS.md')}>RESULTS.md</a>
          <a href={REPO}>GitHub</a>
        </div>
      </nav>

      <header className="card hero" id="top">
        <p className="eyebrow">Measured study · R · Pre-registered</p>
        <h1>R Credit Fairness Lab</h1>
        <p className="sub">
          Does an R-native rebuild of the credit-risk champion from the Python lab credit-risk-lab
          (tidymodels: regularized logistic regression, gradient boosting through the xgboost engine,
          plus a GAM arm) reproduce the Python champion's discrimination on the same UCI Taiwan credit
          data and the same locked split, and where do group fairness gaps (equal opportunity,
          predictive parity) sit across sex, age bands, and education?
        </p>
        <p className="sub">
          The societal stake is fair access to credit in Canada: a champion model whose errors fall
          unevenly on protected groups is a finding about the model, and it matters most exactly
          where credit decisions gate people's lives.
        </p>
        <div className="tiles">
          <div className="tile"><div className="num">{fmt(split.nTest)}</div><div className="cap">Locked test rows (of {fmt(split.nTrain + split.nTest)} total)</div></div>
          <div className="tile"><div className="num">{run.threshold}</div><div className="cap">Champion threshold the fairness audit is read at</div></div>
          <div className="tile"><div className="num">{f5(gbm.auc)}</div><div className="cap">R GBM test AUC, against the champion's {champ.auc.toFixed(4)}</div></div>
          <div className="tile"><div className="num">{f2(verdicts.H3.maxGapPp)} pp</div><div className="cap">Largest equal-opportunity gap (education; caveat below)</div></div>
        </div>
        <div className="actions">
          <a className="btn primary" href={REPO}>View the repo on GitHub</a>
          <a className="btn ghost" href={blob('report/report.html')}>Read the rendered report</a>
        </div>
      </header>

      <section id="verdicts">
        <div className="head">
          <div>
            <p className="eyebrow">Pre-registered verdicts</p>
            <h2>Frozen before any model was fit</h2>
          </div>
          <a className="hint" href={blob('PREREGISTRATION.md')}>PREREGISTRATION.md</a>
        </div>
        <div className="grid3">
          <VerdictCard id="H1" title="Reproduction" v={verdicts.H1}>
            <p className="big">{f5(verdicts.H1.rGbmAuc)} <span className="vs">vs {champ.auc.toFixed(4)}</span></p>
            <p>
              R GBM AUC lands {f5(verdicts.H1.difference)} above the Python champion, inside the frozen
              0.01 band, with a slightly higher KS ({f5(gbm.ks)} against {champ.ks.toFixed(4)}) and a
              slightly lower Brier score ({f5(gbm.brier)} against {champ.brier.toFixed(4)}). The rebuild
              reproduces the champion's discrimination on the identical split.
            </p>
          </VerdictCard>
          <VerdictCard id="H2" title="The interpretability price" v={verdicts.H2}>
            <p className="big">{f5(verdicts.H2.difference)} <span className="vs">vs a 0.02 line</span></p>
            <p>
              The GAM (deviance explained {(run.gamDevianceExplained * 100).toFixed(1)} percent) gives back{' '}
              {f5(verdicts.H2.difference)} AUC against the GBM arm, over the frozen allowance by 0.00090.
              The verdict is published as REFUTED per the frozen rule; the near miss is reported, not rounded.
            </p>
          </VerdictCard>
          <VerdictCard id="H3" title="Fairness gaps" v={verdicts.H3}>
            <p className="big">{f2(verdicts.H3.maxGapPp)} pp <span className="vs">education</span></p>
            <p>
              The largest equal-opportunity gap is on education. Age bands show {f2(gap.age_band.eoGapPp)} pp
              and sex {f2(gap.sex.eoGapPp)} pp. The education headline carries a small-group caveat, printed
              in full in the fairness section below.
            </p>
          </VerdictCard>
        </div>
      </section>

      <section id="performance">
        <div className="card">
          <div className="head">
            <div>
              <p className="eyebrow">Performance</p>
              <h2>Four arms, one locked test split</h2>
            </div>
            <a className="hint" href={blob('results/model_metrics.csv')}>results/model_metrics.csv</a>
          </div>
          <table>
            <thead><tr><th>Arm</th><th>AUC</th><th>KS</th><th>Brier</th></tr></thead>
            <tbody>
              {metrics.map((m) => (
                <tr key={m.arm}>
                  <td>{m.label}</td>
                  <td>{num(m.auc)}</td>
                  <td>{num(m.ks)}</td>
                  <td>{num(m.brier)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="hint">
            Determinism: the GBM arm was fit twice under seed {run.seed}; test AUC was identical both
            times, so no variance is reported for it. One named limitation from RESULTS.md: the ridge
            arm's chosen glmnet penalty sits at the lower edge of the frozen tuning grid, so that arm
            is effectively near unregularized. No hypothesis depends on it.
          </p>
        </div>
      </section>

      <section id="fairness">
        <div className="card">
          <div className="head">
            <div>
              <p className="eyebrow">Fairness audit</p>
              <h2>Gaps at the champion threshold, {run.threshold}</h2>
            </div>
            <a className="hint" href={blob('results/fairness_audit.csv')}>results/fairness_audit.csv</a>
          </div>
          <GapBars />
          <div className="caveat">
            <h3>Read the education headline with its caveat</h3>
            <p>
              The {f2(gap.education.eoGapPp)} pp education gap is set by the "others" group: TPR{' '}
              {others.tpr.toFixed(4)} against the university group's{' '}
              {audit.find((r) => r.attribute === 'education' && r.group === 'university').tpr.toFixed(4)}.
              "Others" is small (n = {others.n}, {others.defaults} defaults), so its TPR rests on{' '}
              {others.defaults} events. Among the three large education groups (graduate school,
              university, high school) the TPR spread is much narrower: {(eduSpread * 100).toFixed(2)} pp.
            </p>
            <p>
              The age-band gap does not rest on a tiny group: it is set by the 50-59 band (TPR{' '}
              {age5059.tpr.toFixed(4)}, {age5059.defaults} defaults) against the 30-39 band (TPR{' '}
              {age3039.tpr.toFixed(4)}, {age3039.defaults} defaults), a {f2(gap.age_band.eoGapPp)} pp gap
              that alone clears the 5 pp line.
            </p>
            <p>
              One inherited caveat, frozen in the pre-registration: the {run.threshold} threshold is the
              champion study cut-off recorded in credit-risk-lab, derived there on the same test set it
              audited. This study inherits the number without re-deriving it; the gaps are read at that
              operating point only.
            </p>
          </div>
          <h3 className="tbl-title">Per-group audit, R GBM arm</h3>
          <table>
            <thead>
              <tr><th>Attribute</th><th>Group</th><th>n</th><th>Defaults</th><th>Event rate</th><th>TPR</th><th>PPV</th><th>Selection rate</th></tr>
            </thead>
            <tbody>
              {audit.map((r) => (
                <tr key={`${r.attribute}-${r.group}`}>
                  <td>{r.attributeLabel}</td>
                  <td>{r.group}</td>
                  <td>{fmt(r.n)}</td>
                  <td>{fmt(r.defaults)}</td>
                  <td>{pct(r.eventRate)}</td>
                  <td>{pct(r.tpr)}</td>
                  <td>{pct(r.ppv)}</td>
                  <td>{pct(r.selectionRate)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section id="split">
        <div className="card">
          <div className="head">
            <div>
              <p className="eyebrow">Split integrity</p>
              <h2>The same split, proven by hash</h2>
            </div>
            <span className="pill good">Identical: TRUE</span>
          </div>
          <p>
            The split is the Python lab's split (stratified 70/30, train_test_split with random_state{' '}
            {run.seed}, sklearn 1.9.1), replicated in pure R and compared by hash, not by summary
            statistics. The pipeline stops hard if this hash ever mismatches, and the test suite asserts
            the same identity, so the comparison to the Python champion is a same-split comparison.
          </p>
          <p className="hash mono">SHA-256 of sorted 0-based test positions<br />{split.rHash}</p>
          <table>
            <tbody>
              <tr><td>Train rows</td><td>{fmt(split.nTrain)} ({fmt(split.nTrainPerClass[0])} non-default, {fmt(split.nTrainPerClass[1])} default)</td></tr>
              <tr><td>Test rows</td><td>{fmt(split.nTest)} ({fmt(split.nTestPerClass[0])} non-default, {fmt(split.nTestPerClass[1])} default)</td></tr>
              <tr><td>Test event rate</td><td>{split.testEventRate.toFixed(5)}</td></tr>
              <tr><td>Python reference hash</td><td className="mono">{split.refHash}</td></tr>
              <tr><td>R replication hash</td><td className="mono">{split.rHash}</td></tr>
            </tbody>
          </table>
          <p className="hint">
            Run record: {run.rVersion}; tidymodels {run.packages.tidymodels}, xgboost {run.packages.xgboost},
            mgcv {run.packages.mgcv}, glmnet {run.packages.glmnet}; seed set {run.seed} only. Every number
            on this page is generated at build time from the committed files in results/.
          </p>
        </div>
      </section>


      <section id="method">
        <div className="card">
          <div className="head">
            <div>
              <p className="eyebrow">Method</p>
              <h2>How the study is put together</h2>
            </div>
            <span className="pill good">Same split, same threshold</span>
          </div>
          <p className="sub">
            Three layers: the data and its locked split, the four model arms fit in R with the
            Python champion alongside, and the audit layer that reads test metrics and group
            fairness at the champion threshold, {run.threshold}.
          </p>
          <h3 className="diagram-title">Structure diagram</h3>
          <StructureDiagram />
          <h3 className="diagram-title">Study flow</h3>
          <FlowDiagram />
        </div>
      </section>

      <section>
        <div className="docs">
          <a href={blob('RESULTS.md')}><h3>RESULTS.md</h3><p>The full written record: verdicts, tables, limitations.</p></a>
          <a href={blob('report/report.html')}><h3>Rendered report</h3><p>The Quarto report with the fairness audit tables.</p></a>
          <a href={blob('PREREGISTRATION.md')}><h3>PREREGISTRATION.md</h3><p>The frozen hypotheses and rules, committed before any model was fit.</p></a>
        </div>
      </section>

      <footer>
        <p>
          Claims ceiling: this study evidences method only. It reproduces a published Python pipeline
          in R on public Taiwan 2005 data and audits the rebuilt model's group fairness on the locked
          split. It is study scope only: not production experience, not a Canadian portfolio result,
          and not evidence about any real lender's decisions.
        </p>
        <p className="hint">
          <a href={REPO}>github.com/JesunAhmadUshno/r-credit-fairness-lab</a>
        </p>
        <div className="support">
          <a className="support-pill" href="https://github.com/sponsors/JesunAhmadUshno">Sponsor this work</a>
          <a className="support-pill" href="https://github.com/sponsors/JesunAhmadUshno">Donate</a>
          <a className="support-pill" href="https://buymeacoffee.com/jesun">Buy Me a Coffee</a>
          <a className="support-pill" href="https://calendly.com/jesunahmadushno/30min">Work with me</a>
        </div>
      </footer>
    </div>
  );
}
