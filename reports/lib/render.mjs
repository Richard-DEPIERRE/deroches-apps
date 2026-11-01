// The report pages as HTML strings, from the parsed reports (`reports.mjs`). Charts are inline SVG drawn here,
// at build time: no client JavaScript, no cookies, no forms, no request to another host (ADR 0004).
// A value that is NOT ASSESSED or not a number is never placed on a chart: it is listed beside it.
import { blocks, esc, inline, page, tableHtml } from './html.mjs';

const W = 320;
const H = 250;
const M = { l: 44, r: 12, t: 12, b: 42 };
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

/** A label cut to `n` characters; the full text stays in the mark's `<title>` and in the table. */
export const short = (text, n = 18) => (text.length > n ? `${text.slice(0, n - 1).trimEnd()}…` : text);
/** About how wide a 14 px label is, in chart units. */
export const labelWidth = (text) => text.length * 7.2;

/**
 * Each label beside its mark: to the right when it fits inside the chart, else to the left; moved down (or up) in
 * 16-unit steps while it would overlap a label already placed.
 */
export function placeLabels(marks) {
  const placed = [];
  for (const m of [...marks].sort((a, b) => a.cy - b.cy)) {
    const w = labelWidth(m.text);
    const right = m.cx + m.r + 4 + w <= W;
    const x = right ? m.cx + m.r + 4 : Math.max(w, m.cx - m.r - 4);
    const [x0, x1] = right ? [x, x + w] : [x - w, x];
    const free = (y) =>
      y >= M.t + 10 &&
      y <= H - M.b - 2 &&
      !placed.some((p) => p.x0 < x1 && x0 < p.x1 && Math.abs(p.y - y) < 16);
    const steps = [
      0,
      ...Array.from({ length: 24 }, (_, k) => (k % 2 ? -1 : 1) * 16 * Math.ceil((k + 1) / 2)),
    ];
    const y = m.cy + 4 + (steps.find((d) => free(m.cy + 4 + d)) ?? 0);
    placed.push({ ...m, x, y, x0, x1, anchor: right ? 'start' : 'end' });
  }
  return placed;
}

/** A label, with a hairline leader back to its mark when it had to move off the mark's line. */
const label = (p) => {
  const moved = p.y !== p.cy + 4;
  const edge = p.anchor === 'start' ? p.cx + p.r : p.cx - p.r;
  return `${moved ? `<line class="leader" x1="${edge}" y1="${p.cy}" x2="${p.x}" y2="${p.y - 4}"/>` : ''}<text class="label" x="${p.x}" y="${p.y}" text-anchor="${p.anchor}">${esc(p.text)}</text>`;
};

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
  const at = points.map((p) => ({ ...p, cx: sx(p.x), cy: sy(p.y), text: p.label }));
  // Biggest first, so a small bubble is never hidden under a big one.
  const marks = [...at]
    .sort((a, b) => b.r - a.r)
    .map(
      (p) =>
        `<circle class="mark${p.hollow ? ' hollow' : ''}" cx="${p.cx}" cy="${p.cy}" r="${p.r}"><title>${esc(p.title)}</title></circle>`,
    );
  return `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(name)}">${[...grid, ...marks, ...placeLabels(at).map(label)].join('\n')}</svg>`;
}

/** One row per point, on a shared x scale only: for effects written in different units, which share no y scale. */
function strip({ points, name, xLabel }) {
  const xt = ticks(0, Math.max(...points.map((p) => p.x)));
  const sx = (v) => 16 + ((v - xt[0]) / (xt.at(-1) - xt[0])) * (W - 32);
  const h = 8 + points.length * 40 + 40;
  const rows = points.map((p, i) => {
    const y = 8 + i * 40;
    return `<text class="label" x="${sx(xt[0])}" y="${y + 14}">${esc(short(p.label, 42))}</text>
<line class="grid" x1="${sx(xt[0])}" x2="${sx(xt.at(-1))}" y1="${y + 28}" y2="${y + 28}"/>
<circle class="mark" cx="${sx(p.x)}" cy="${y + 28}" r="5"><title>${esc(p.title)}</title></circle>`;
  });
  const axis = [
    ...xt.map((v) => `<text x="${sx(v)}" y="${h - 22}" text-anchor="middle">${compact.format(v)}</text>`),
    `<text x="${W / 2}" y="${h - 4}" text-anchor="middle">${esc(xLabel)}</text>`,
  ];
  return `<svg viewBox="0 0 ${W} ${h}" role="img" aria-label="${esc(name)}">${[...rows, ...axis].join('\n')}</svg>`;
}

/** An expected effect without its source: its figure with the unit ("+3 pts"), and the unit alone ("pts", "%"). */
export function effectOf(text) {
  const clean = text
    .replace(/\([^)]*\)/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const match = /[+\-\u2212]?\d(?:[\d\s.,]*\d)?\s*(%|[^\s\d()]+)?/.exec(clean);
  const unit = (match?.[1] ?? '').toLowerCase();
  return { clean, figure: (match?.[0] ?? clean).trim(), unit: /^(pts?|points?)$/.test(unit) ? 'pts' : unit };
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

/** A list beside a chart: what is not on it (or drawn differently), and why. */
function offChart(items, heading = 'Not on the chart') {
  if (!items.length) return '';
  const list = items
    .map(([name, reason]) => `<li><strong>${esc(name)}</strong>: ${esc(reason)}</li>`)
    .join('');
  return `<div class="off"><p class="meta">${esc(heading)}</p><ul>${list}</ul></div>`;
}

const naCell = (c) => {
  const reason = plain(c.text);
  return `<td class="na">not assessed${reason ? `<br><span class="meta">${esc(reason)}</span>` : ''}</td>`;
};
const valueCell = (c) => (c.notAssessed ? naCell(c) : `<td>${inline(c.text)}</td>`);
/** A row of a built table: a string is Markdown, `{ html }` is ready, anything else is a parsed cell. */
const anyCell = (c) => (typeof c === 'string' ? `<td>${inline(c)}</td>` : (c.html ?? valueCell(c)));

function scoreCell(c) {
  if (c.notAssessed) return naCell(c);
  const text = c.text.replace(/[`*]/g, '').trim();
  const verdict = /^(PASS|CONCERNS|FAIL)$/.exec(text);
  if (verdict) return `<td><span class="v v-${verdict[1].toLowerCase()}">${verdict[1]}</span></td>`;
  if (/^(yes|oui)$/i.test(text)) return `<td><strong class="v">${esc(text)}</strong></td>`;
  // Only a plain 1–5 score is shaded; anything else is shown as written, unshaded.
  if (c.value >= 1 && c.value <= 5 && /^[\d\s.,]+$/.test(c.text))
    return `<td class="h${Math.round(c.value)}">${esc(c.text)}</td>`;
  return `<td>${inline(c.text)}</td>`;
}

const colName = (text) => text.replace(/[`*_]/g, '').trim().toLowerCase();

/** The scores in the report's order, except Score and Recommended, which come right after the idea. */
function heatStrip({ columns, rows }) {
  const first = [
    columns.findIndex((c) => colName(c) === 'score'),
    columns.findIndex((c) => colName(c).startsWith('recommended')),
  ].filter((i) => i >= 0);
  const order = [...first, ...[...columns.keys()].filter((i) => !first.includes(i))];
  const head = order.map((i) => `<th scope="col">${inline(columns[i])}</th>`).join('');
  const body = rows
    .map(
      (r) =>
        `<tr><th scope="row">${esc(r.idea)}</th>${order.map((i) => scoreCell(r.cells[i])).join('')}</tr>`,
    )
    .join('');
  return `<div class="scroll"><table class="heat"><thead><tr><th scope="col">Idea</th>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

/** One line per price row, so the change itself reads on a phone without scrolling the table. */
function priceLines({ headers, rows }) {
  const at = ['app', 'plan', 'store', 'current', 'proposed'].map((n) =>
    headers.findIndex((h) => colName(h).startsWith(n)),
  );
  if (at.some((i) => i < 0)) return '';
  const [app, plan, store, current, proposed] = at;
  const lines = rows.map(
    (r) =>
      `<li><strong>${inline(r[app])} · ${inline(r[plan])} · ${inline(/^both$/i.test(r[store]) ? 'both stores' : r[store])}</strong>: ${inline(r[current])} → ${inline(r[proposed])}</li>`,
  );
  return `<ul>${lines.join('')}</ul>`;
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

const section = (title, body, cls = '') =>
  `<section${cls ? ` class="${cls}"` : ''}><h2>${esc(title)}</h2>\n${body}\n</section>`;
const cardsHtml = (cards) =>
  cards
    .map(
      (
        c,
      ) => `<article><h3>${esc(c.name)}</h3>${c.description ? `<p class="meta">${inline(c.description)}</p>` : ''}
${blocks(c.body)}</article>`,
    )
    .join('\n');
/** A report section kept for reference, folded: no JavaScript needed. */
const folded = (title, md) =>
  md?.trim() ? `<details><summary>${esc(title)}</summary>\n${blocks(md)}</details>` : '';

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
    label: short(i.idea),
    title: `${i.idea}: demand FR ${i.demandFr.text}; demand UK/US ${i.demandUkUs.text}; beatability ${i.beatability.text}; likely revenue at 6 months ${i.revenue.text}`,
  }));
  const off = report.ideas
    .filter((i) => !placed.includes(i))
    .map((i) => [i.idea, missing({ beatability: i.beatability, 'demand FR': i.demandFr })]);
  const rings = placed
    .filter((i) => i.revenue.value === null)
    .map((i) => [i.idea, why('likely revenue', i.revenue)]);
  const demandTable = tableHtml(
    {
      headers: ['Idea', 'Demand FR', 'Demand UK/US', 'Beatability', 'Likely revenue at 6 months'],
      rows: report.ideas.map((i) => [
        { html: `<th scope="row">${esc(i.idea)}</th>` },
        i.demandFr,
        i.demandUkUs,
        i.beatability,
        i.revenue,
      ]),
    },
    anyCell,
  );
  const chart = points.length
    ? scatter({
        points,
        name: 'Ideas: beatability against French demand',
        xLabel: 'Beatability (1–5)',
        yLabel: 'Demand FR (monthly searches)',
        xTicks: [1, 2, 3, 4, 5],
        xDomain: [0.5, 5.5],
      })
    : '';
  return page(
    report.title,
    [
      header(report, opts),
      section('Recommendation', blocks(report.recommendation)),
      section(
        'Demand against competition',
        `<p class="hint">Right is easier to beat, higher is more searched in France; a bigger bubble is more likely revenue at 6 months (an estimate).</p>
${chart}${offChart(off)}${offChart(rings, 'Drawn as an empty ring (no revenue estimate)')}${demandTable}`,
      ),
      section(
        'Scores side by side',
        `<p class="hint">Scores 1 to 5: the stronger the colour, the higher. Hatched cells are not assessed: a gap in the data, not a low score.</p>\n${heatStrip(report.scores)}`,
      ),
      section('One card per idea', cardsHtml(report.cards), 'bare'),
      folded('Methods and sources', report.methods),
    ].join('\n'),
  );
}

/** One app's epics: a scatter when every plotted effect is in one unit, else one row per epic on the size scale. */
function appChart(app, epics) {
  const placed = epics.filter((e) => e.size.value !== null && e.effect.value !== null);
  const units = new Set(placed.map((e) => effectOf(e.effect.text).unit));
  const shared = units.size === 1 && !units.has('') ? [...units][0] : null;
  const points = placed.map((e) => {
    const effect = effectOf(e.effect.text);
    return {
      x: e.size.value,
      y: e.effect.value,
      r: 5,
      label: shared ? `${short(e.epic, 14)} · ${effect.figure}` : `${e.epic} · ${effect.clean}`,
      title: `${e.epic}: ${e.size.text} days; expected effect ${e.effect.text}`,
    };
  });
  const name = `${app}: size against expected effect`;
  const chart = !points.length
    ? ''
    : shared
      ? scatter({ points, name, xLabel: 'Size (days)', yLabel: `Expected effect (${shared})` })
      : strip({ points, name, xLabel: 'Size (days)' });
  const off = epics
    .filter((e) => !placed.includes(e))
    .map((e) => [e.epic, missing({ 'expected effect': e.effect, size: e.size })]);
  return `<h3>${esc(app)}</h3>${chart}${offChart(off)}`;
}

/** The epics report: recommendation, size against effect per app, the price block apart, one card per epic. */
export function renderEpicsPage(report, opts) {
  const apps = [...new Set(report.epics.map((e) => e.app))];
  const rows = report.epics.map((e) => [
    { html: `<th scope="row">${esc(e.epic)}</th>` },
    e.why,
    e.app,
    e.effect,
    e.size,
    e.newScreen,
    e.price ? 'yes' : 'no',
    {
      html: e.dataChange
        ? `<td><span class="v v-concerns">${inline(e.dataChangeText)}</span></td>`
        : '<td>no</td>',
    },
  ]);
  const epicTable = tableHtml(
    {
      headers: [
        'Epic',
        'Why (main evidence)',
        'App',
        'Expected effect',
        'Size (days)',
        'New screen',
        '`PRICE`',
        'Data change',
      ],
      rows,
    },
    anyCell,
  );
  const price =
    report.price.none || !report.price.body
      ? '<p>No price change or price test this week.</p>'
      : report.price.table.headers.length
        ? `${priceLines(report.price.table)}${tableHtml(report.price.table)}`
        : blocks(report.price.body);
  return page(
    report.title,
    [
      header(report, opts),
      section('Recommendation', blocks(report.recommendation)),
      section(
        "This week's epics",
        `<p class="hint">Right is more work, higher is a bigger expected effect. An app whose effects are in different units gets one row per epic, with no shared effect scale.</p>\n${apps
          .map((app) =>
            appChart(
              app,
              report.epics.filter((e) => e.app === app),
            ),
          )
          .join('\n')}${epicTable}`,
      ),
      section('Price changes and price tests (PRICE)', price),
      section('One card per epic', cardsHtml(report.cards), 'bare'),
      folded('Last week', report.lastWeek),
      folded('Methods and sources', report.methods),
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
