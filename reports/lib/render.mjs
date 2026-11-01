// The report pages as HTML strings, from the parsed reports (`reports.mjs`). Charts are inline SVG drawn here,
// at build time: no client JavaScript, no cookies, no forms, no request to another host (ADR 0004).
// A value that is NOT ASSESSED or not a number is never placed on a chart: it is listed beside it.
import { blocks, esc, inline, page, tableHtml } from './html.mjs';

const W = 360;
const H = 240;
const M = { l: 48, r: 16, t: 16, b: 44 };
const compact = new Intl.NumberFormat('en', { notation: 'compact', maximumFractionDigits: 1 });

/** Clean axis ticks from `lo` to `hi`, steps of 1, 2 or 5 times a power of ten. */
export function ticks(lo, hi, count = 4) {
  const raw = (hi - lo) / count || Math.abs(hi) / count || 1;
  const mag = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 2, 5, 10].map((m) => m * mag).find((s) => s >= raw - 1e-12);
  const out = [];
  for (let v = Math.floor(lo / step) * step; v <= Math.ceil(hi / step) * step + step / 2; v += step)
    out.push(Number(v.toPrecision(12)));
  if (out.length < 2) out.push(Number((out[0] + step).toPrecision(12))); // a flat series still needs a scale
  return out;
}

/** One-series scatter: points { x, y, r, label, title, hollow }, direct labels, a hairline grid. */
function scatter({ points, name, xLabel, yLabel, xTicks, xDomain }) {
  const xt = xTicks ?? ticks(Math.min(0, ...points.map((p) => p.x)), Math.max(...points.map((p) => p.x)));
  const [x0, x1] = xDomain ?? [xt[0], xt.at(-1)];
  const yt = ticks(Math.min(0, ...points.map((p) => p.y)), Math.max(...points.map((p) => p.y)));
  const sx = (v) => M.l + ((v - x0) / (x1 - x0)) * (W - M.l - M.r);
  const sy = (v) => H - M.b - ((v - yt[0]) / (yt.at(-1) - yt[0])) * (H - M.t - M.b);
  const grid = [
    ...yt.map(
      (
        v,
      ) => `<line class="${v === 0 ? 'axis' : 'grid'}" x1="${M.l}" x2="${W - M.r}" y1="${sy(v)}" y2="${sy(v)}"/>
<text x="${M.l - 6}" y="${sy(v) + 4}" text-anchor="end">${compact.format(v)}</text>`,
    ),
    ...xt.map(
      (v) => `<text x="${sx(v)}" y="${H - M.b + 18}" text-anchor="middle">${compact.format(v)}</text>`,
    ),
    `<text x="${(M.l + W - M.r) / 2}" y="${H - 6}" text-anchor="middle">${esc(xLabel)}</text>`,
    `<text x="12" y="${(M.t + H - M.b) / 2}" text-anchor="middle" transform="rotate(-90 12 ${(M.t + H - M.b) / 2})">${esc(yLabel)}</text>`,
  ];
  // Biggest first, so a small bubble is never hidden under a big one.
  const marks = [...points]
    .sort((a, b) => b.r - a.r)
    .map((p) => {
      const [cx, cy] = [sx(p.x), sy(p.y)];
      const end = cx > W / 2;
      return `<circle class="mark${p.hollow ? ' hollow' : ''}" cx="${cx}" cy="${cy}" r="${p.r}"><title>${esc(p.title)}</title></circle>
<text class="label" x="${cx + (end ? -1 : 1) * (p.r + 4)}" y="${cy + 4}" text-anchor="${end ? 'end' : 'start'}">${esc(p.label)}</text>`;
    });
  return `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(name)}">${[...grid, ...marks].join('\n')}</svg>`;
}

const plain = (text) =>
  text
    .replace(/NOT ASSESSED/i, '')
    .replace(/[`*()]/g, '')
    .trim();
const why = (name, c) => (c.notAssessed ? `${name} not assessed` : `${name} has no number`);
/** Why a point is off the chart: each named cell without a value. */
const missing = (named) =>
  Object.entries(named)
    .filter(([, c]) => c.value === null)
    .map(([name, c]) => why(name, c))
    .join(', ');

/** The list beside a chart: what could not be placed on it, and why. */
function offChart(items) {
  if (!items.length) return '';
  const list = items
    .map(([name, reason]) => `<li><strong>${esc(name)}</strong>: ${esc(reason)}</li>`)
    .join('');
  return `<div class="off"><p class="meta">Not on the chart</p><ul>${list}</ul></div>`;
}

const naCell = (c) => {
  const reason = plain(c.text);
  return `<td class="na">not assessed${reason ? `<br><span class="meta">${esc(reason)}</span>` : ''}</td>`;
};
const valueCell = (c) => (c.notAssessed ? naCell(c) : `<td>${inline(c.text)}</td>`);

function scoreCell(c) {
  if (c.notAssessed) return naCell(c);
  const verdict = /^(PASS|CONCERNS|FAIL)$/.exec(c.text.replace(/[`*]/g, '').trim());
  if (verdict) return `<td><span class="v v-${verdict[1].toLowerCase()}">${verdict[1]}</span></td>`;
  // Only a plain 1–5 score is shaded; anything else is shown as written, unshaded.
  if (c.value >= 1 && c.value <= 5 && /^[\d\s.,]+$/.test(c.text))
    return `<td class="h${Math.round(c.value)}">${esc(c.text)}</td>`;
  return `<td>${inline(c.text)}</td>`;
}

function approvalUrl({ paperclipUrl, approvalId }) {
  const base = new URL(paperclipUrl);
  if (!/^https?:$/.test(base.protocol)) throw new Error(`paperclipUrl must be http(s): ${paperclipUrl}`);
  if (!approvalId) throw new Error('approvalId is required');
  return `${base.href.replace(/\/+$/, '')}/DAPP/approvals/${encodeURIComponent(approvalId)}`;
}

function when(takenAt) {
  const date = new Date(takenAt);
  if (Number.isNaN(date.getTime())) throw new Error(`takenAt is not a date: ${takenAt}`);
  return `${date.toISOString().slice(0, 16).replace('T', ' ')} UTC`;
}

function header(report, opts) {
  return `<header><h1>${esc(report.title)}</h1>
<p class="meta">Taken ${when(opts.takenAt)}. Approval ${esc(opts.approvalStatus ?? 'unknown')} at that time.</p>
<a class="button" href="${esc(approvalUrl(opts))}">Decide in Paperclip</a></header>`;
}

const section = (title, body) => `<section><h2>${esc(title)}</h2>\n${body}\n</section>`;
const cardsHtml = (cards) =>
  cards
    .map(
      (
        c,
      ) => `<article><h3>${esc(c.name)}</h3>${c.description ? `<p class="meta">${inline(c.description)}</p>` : ''}
${blocks(c.body)}</article>`,
    )
    .join('\n');

/** The research report: recommendation, the demand bubble chart, the scores heat strip, one card per idea. */
export function renderResearchPage(report, opts) {
  const placed = report.ideas.filter((i) => i.beatability.value !== null && i.demandFr.value !== null);
  const maxRevenue = Math.max(0, ...placed.map((i) => i.revenue.value ?? 0));
  const points = placed.map((i) => ({
    x: i.beatability.value,
    y: i.demandFr.value,
    r:
      i.revenue.value === null || !maxRevenue ? 6 : Math.max(4, Math.sqrt(i.revenue.value / maxRevenue) * 22),
    hollow: i.revenue.value === null,
    label: i.idea,
    title: `${i.idea}: demand FR ${i.demandFr.text}; demand UK/US ${i.demandUkUs.text}; beatability ${i.beatability.text}; likely revenue at 6 months ${i.revenue.text}`,
  }));
  const off = [
    ...report.ideas
      .filter((i) => !placed.includes(i))
      .map((i) => [i.idea, missing({ beatability: i.beatability, 'demand FR': i.demandFr })]),
    ...placed
      .filter((i) => i.revenue.value === null)
      .map((i) => [i.idea, `${why('likely revenue', i.revenue)} (drawn as an empty ring)`]),
  ];
  const demandTable = tableHtml(
    {
      headers: ['Idea', 'Demand FR', 'Demand UK/US', 'Beatability', 'Likely revenue at 6 months'],
      rows: report.ideas.map((i) => [i.idea, i.demandFr, i.demandUkUs, i.beatability, i.revenue]),
    },
    (c) => (typeof c === 'string' ? `<th scope="row">${esc(c)}</th>` : valueCell(c)),
  );
  const heat = `<div class="scroll"><table class="heat"><thead><tr><th scope="col">Idea</th>${report.scores.columns
    .map((h) => `<th scope="col">${inline(h)}</th>`)
    .join('')}</tr></thead><tbody>${report.scores.rows
    .map((r) => `<tr><th scope="row">${esc(r.idea)}</th>${r.cells.map(scoreCell).join('')}</tr>`)
    .join('')}</tbody></table></div>`;
  return page(
    report.title,
    [
      header(report, opts),
      section('Recommendation', blocks(report.recommendation)),
      section(
        'Demand against competition',
        `<p class="hint">Right is easier to beat, higher is more searched in France; a bigger bubble is more likely revenue at 6 months (an estimate).</p>
${points.length ? scatter({ points, name: 'Ideas: beatability against French demand', xLabel: 'Beatability (1–5)', yLabel: 'Demand FR (monthly searches)', xTicks: [1, 2, 3, 4, 5], xDomain: [0.5, 5.5] }) : ''}
${offChart(off)}${demandTable}`,
      ),
      section(
        'Scores side by side',
        `<p class="hint">Scores 1 to 5, darker is higher. Hatched cells are not assessed: a gap in the data, not a low score.</p>\n${heat}`,
      ),
      section('One card per idea', cardsHtml(report.cards)),
    ].join('\n'),
  );
}

/** The epics report: recommendation, size against effect per app, the price block apart, one card per epic. */
export function renderEpicsPage(report, opts) {
  const apps = [...new Set(report.epics.map((e) => e.app))];
  const charts = apps.map((app) => {
    const epics = report.epics.filter((e) => e.app === app);
    const placed = epics.filter((e) => e.size.value !== null && e.effect.value !== null);
    const points = placed.map((e) => ({
      x: e.size.value,
      y: e.effect.value,
      r: 5,
      label: e.epic,
      title: `${e.epic}: ${e.size.text} days; expected effect ${e.effect.text}`,
    }));
    const off = epics
      .filter((e) => !placed.includes(e))
      .map((e) => [e.epic, missing({ 'expected effect': e.effect, size: e.size })]);
    return `<h3>${esc(app)}</h3>${points.length ? scatter({ points, name: `${app}: size against expected effect`, xLabel: 'Size (days)', yLabel: 'Expected effect' }) : ''}${offChart(off)}`;
  });
  const rows = report.epics.map((e) => [
    e.epic,
    e.app,
    e.effect,
    e.size,
    e.newScreen,
    e.price ? 'yes' : 'no',
    e.dataChange ? 'yes' : 'no',
  ]);
  const epicTable = tableHtml(
    {
      headers: ['Epic', 'App', 'Expected effect', 'Size (days)', 'New screen', '`PRICE`', 'Data change'],
      rows,
    },
    (c) => (typeof c === 'string' ? `<td>${inline(c)}</td>` : valueCell(c)),
  );
  const price =
    report.price.none || !report.price.body
      ? '<p>No price change or price test this week.</p>'
      : report.price.table.headers.length
        ? tableHtml(report.price.table)
        : blocks(report.price.body);
  return page(
    report.title,
    [
      header(report, opts),
      section('Recommendation', blocks(report.recommendation)),
      section(
        "This week's epics",
        `<p class="hint">Right is more work, higher is a bigger expected effect. Effects keep their own units (points, %): read the label as well as the height.</p>\n${charts.join('\n')}${epicTable}`,
      ),
      section('Price changes and price tests (PRICE)', price),
      section('One card per epic', cardsHtml(report.cards)),
    ].join('\n'),
  );
}

/** The index: every published report, newest first, each with when it was taken and its approval status then. */
export function renderIndex(entries) {
  const list = [...entries]
    .sort((a, b) => new Date(b.takenAt) - new Date(a.takenAt))
    .map(
      (e) =>
        `<li><a href="${esc(e.href)}">${esc(e.title)}</a><br><span class="meta">Taken ${when(e.takenAt)}. Approval ${esc(e.approvalStatus ?? 'unknown')} at that time.</span></li>`,
    )
    .join('\n');
  return page(
    'Reports',
    `<h1>Reports</h1>\n<ul class="reports">${list || '<li>No report published yet.</li>'}</ul>`,
  );
}
