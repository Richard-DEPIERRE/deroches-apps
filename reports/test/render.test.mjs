import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { describe, test } from 'node:test';
import { blocks, inline } from '../lib/html.mjs';
import { cell } from '../lib/markdown.mjs';
import {
  effectOf,
  labelWidth,
  renderEpicsPage,
  renderIndex,
  renderResearchPage,
  ticks,
} from '../lib/render.mjs';
import { parseEpicsReport, parseResearchReport } from '../lib/reports.mjs';

const fixture = (name) => readFile(new URL(`./fixture/${name}`, import.meta.url), 'utf8');
const opts = {
  paperclipUrl: 'http://127.0.0.1:3100/',
  approvalId: 'a1 b',
  approvalStatus: 'pending',
  takenAt: '2026-11-01T09:00Z',
};
const research = async () =>
  renderResearchPage(parseResearchReport(await fixture('research-report.md')), opts);
const epics = async () => renderEpicsPage(parseEpicsReport(await fixture('epics-report.md')), opts);
const between = (html, from, to) => html.slice(html.indexOf(from), html.indexOf(to, html.indexOf(from)));

describe('research page', () => {
  test('a NOT ASSESSED score is hatched and labelled, never shaded as a low score', async () => {
    const heat = between(await research(), 'class="heat"', '</table>');
    const row = between(heat, 'Compteur Eau', '</tr>');
    assert.match(row, /<td class="na">not assessed<br><span class="meta">no price evidence<\/span><\/td>/);
    assert.equal(row.match(/class="na"/g).length, 2); // people pay, score
    assert.match(row, /<td class="h2">2<\/td>/);
  });

  test('an idea that cannot be sized is listed beside the chart; every plotted bubble has its numbers', async () => {
    const html = await research();
    assert.match(
      between(html, 'class="off"', '</div>'),
      /Compteur Eau<\/strong>: likely revenue not assessed/,
    );
    assert.equal(html.match(/<circle /g).length, 3);
    assert.match(html, /<circle class="mark hollow"[^>]*><title>Compteur Eau:/);
    assert.match(html, /<title>Frais Réels: demand FR [^<]*demand UK\/US 1,300 \/ 4,400/);
  });

  test('an idea without a position is not drawn, at zero or anywhere', () => {
    const report = {
      title: 'Research report — x',
      recommendation: '',
      scores: { columns: [], rows: [] },
      cards: [],
    };
    const na = { text: 'NOT ASSESSED', notAssessed: true, value: null };
    const n = (value) => ({ text: String(value), notAssessed: false, value });
    report.ideas = [{ idea: 'Gap', demandFr: na, demandUkUs: na, beatability: n(3), revenue: n(500) }];
    const html = renderResearchPage(report, opts);
    assert.doesNotMatch(html, /<circle/);
    assert.match(html, /<strong>Gap<\/strong>: demand FR not assessed/);
  });
});

describe('research charts with real-world names', () => {
  const labels = (html) =>
    [
      ...html.matchAll(/<text class="label" x="([\d.]+)" y="([\d.]+)" text-anchor="(\w+)">([^<]*)<\/text>/g),
    ].map(([, x, y, anchor, text]) => {
      const w = labelWidth(text.replace(/&#39;/g, "'"));
      return {
        text,
        y: Number(y),
        x0: anchor === 'start' ? Number(x) : Number(x) - w,
        x1: anchor === 'start' ? Number(x) + w : Number(x),
      };
    });

  test('labels are cut, stay inside the chart and never overlap, even with ties in beatability', async () => {
    const html = renderResearchPage(parseResearchReport(await fixture('research-report-long.md')), opts);
    const placed = labels(html);
    assert.equal(placed.length, 8);
    assert.ok(placed.some((l) => l.text === 'Calculateur indem…'));
    for (const [i, a] of placed.entries()) {
      assert.ok(a.x0 >= 0 && a.x1 <= 320, `${a.text} inside the chart`);
      for (const b of placed.slice(i + 1))
        assert.ok(!(a.x0 < b.x1 && b.x0 < a.x1 && Math.abs(a.y - b.y) < 16), `${a.text} / ${b.text} overlap`);
    }
    assert.match(html, /<line class="leader"/);
    assert.match(html, /<title>Calculateur indemnités kilométriques: /);
  });

  test('the heat strip shows Score and Recommended first, and marks a yes', async () => {
    const heat = between(await research(), 'class="heat"', '</thead>');
    assert.match(
      heat,
      /Idea<\/th><th scope="col">Score<\/th><th scope="col">Recommended<\/th><th scope="col">Demand/,
    );
    assert.match(await research(), /<td><strong class="v">yes<\/strong><\/td>/);
  });

  test('methods and sources, and the ideas not picked before, are kept, folded', async () => {
    const html = await research();
    assert.match(html, /<details><summary>Methods and sources<\/summary>/);
    assert.match(html, /<details><summary>Not picked before<\/summary>\n<p>None\.<\/p>/);
  });
});

describe('epics page', () => {
  const epic = (name, effect, size) => ({
    epic: name,
    app: 'app',
    why: 'why',
    newScreen: 'no',
    price: false,
    dataChange: false,
    dataChangeText: 'no',
    effect: cell(effect),
    size: cell(size),
  });
  const report = (epics) => ({
    title: 'Epics report — x',
    recommendation: '',
    epics,
    cards: [],
    price: { none: true, body: '' },
  });

  test('effects in different units get one row per epic and no shared effect scale', async () => {
    const html = await epics();
    const app = between(html, 'frais-reels</h3>', '</svg>');
    assert.doesNotMatch(app, /Expected effect/);
    assert.match(app, />PDF export · \+3 pts trial→paid</);
    assert.match(app, />Yearly plan at €19\.99 · \+12% revenue per…</);
  });

  test('effects in one unit share a scale named with the unit, and each label carries its figure', () => {
    const html = renderEpicsPage(
      report([epic('Export', '+3 pts', '2'), epic('Widget', '+1 point (read 2026-12)', '1')]),
      opts,
    );
    assert.match(html, />Expected effect \(pts\)</);
    assert.match(html, />Export · \+3 pts</);
    assert.match(html, />Widget · \+1 point</);
  });

  test('epics held back for a missing input are shown open after the epics, not folded', async () => {
    const html = await epics();
    const held = between(html, '<h2>Held back: not assessed this week</h2>', '</section>');
    assert.match(
      held,
      /<strong>Home-screen widget<\/strong> \(carnet-plantes\): held back, MISSING the day-30/,
    );
    assert.doesNotMatch(html, /<summary>Held back/);
    assert.ok(html.indexOf('Held back') > html.indexOf("This week's epics"));
    assert.ok(html.indexOf('Held back') < html.indexOf('Price changes'));
  });

  test('an effect written as a range keeps its unit, and is said to be plotted at its first figure', () => {
    assert.deepEqual(effectOf('+3–5 pts'), {
      clean: '+3–5 pts',
      figure: '+3–5 pts',
      unit: 'pts',
      range: true,
    });
    assert.deepEqual(effectOf('+2 to 4 pts (read 2026-11)'), {
      clean: '+2 to 4 pts',
      figure: '+2 to 4 pts',
      unit: 'pts',
      range: true,
    });
    assert.equal(effectOf('€200 MRR').figure, '€200 MRR');
    const html = renderEpicsPage(
      report([epic('Export', '+3–5 pts', '2'), epic('Widget', '+2 to 4 pts', '1')]),
      opts,
    );
    assert.match(html, />Expected effect \(pts\)</);
    assert.match(html, />Export · \+3–5 pts</);
    assert.match(html, />Widget · \+2 to 4 pts</);
    assert.match(html, /A range is plotted at its first figure/);
    assert.match(html, /<circle class="mark" cx="[\d.]+" cy="[\d.]+" r="5"><title>Export: 2 days/);
  });

  test('the epics table shows the evidence and the data change with its detail', async () => {
    const html = await epics();
    assert.match(html, /<th scope="row">PDF export<\/th><td>14 reviews ask for it<\/td>/);
    assert.match(html, /<td><span class="v v-concerns">yes: notification time<\/span><\/td>/);
    assert.match(html, /<details><summary>Last week<\/summary>/);
  });

  test('an epic with no effect is listed beside its app chart, not plotted', async () => {
    const html = await epics();
    assert.doesNotMatch(html, /<title>Reminders/);
    assert.match(
      between(html, 'carnet-plantes</h3>', '</div>'),
      /Reminders<\/strong>: expected effect not assessed/,
    );
    assert.equal(html.match(/<circle /g).length, 2);
  });

  test('the price block stands apart from the epics, after them', async () => {
    const html = await epics();
    const price = between(html, 'Price changes and price tests', '</section>');
    assert.match(price, /<li><strong>frais-reels · yearly · both stores<\/strong>: €24\.99 → €19\.99<\/li>/);
    assert.ok(html.indexOf('Price changes') > html.indexOf("This week's epics"));
    assert.ok(html.indexOf('Price changes') < html.indexOf('One card per epic'));
  });
});

describe('every page', () => {
  test('one "Decide in Paperclip" button linking to the approval', async () => {
    for (const html of [await research(), await epics()]) {
      assert.equal(html.match(/Decide in Paperclip/g).length, 1);
      assert.match(html, /<a class="button" href="http:\/\/127\.0\.0\.1:3100\/DAPP\/approvals\/a1%20b">/);
    }
    const report = parseEpicsReport(await fixture('epics-report.md'));
    assert.throws(() => renderEpicsPage(report, { ...opts, paperclipUrl: 'javascript:alert(1)' }), /http/);
    assert.throws(() => renderEpicsPage(report, { ...opts, approvalId: '' }), /approvalId/);
  });

  test('noindex, a CSP with no script, and nothing loaded from another host', async () => {
    for (const html of [await research(), await epics(), renderIndex([])]) {
      assert.match(html, /<meta name="robots" content="noindex, nofollow">/);
      assert.match(html, /default-src 'none'; style-src 'sha256-/);
      assert.doesNotMatch(html, /<script|<form|<img|<link |<iframe| src=| style="/i);
    }
  });

  test('report text is escaped', () => {
    assert.equal(inline('<script>x</script> & "q"'), '&lt;script&gt;x&lt;/script&gt; &amp; &quot;q&quot;');
    assert.equal(inline('**`MR-REPORT`**'), '<strong><code>MR-REPORT</code></strong>');
    assert.equal(
      inline('[a](https://x.fr/"onclick=1)'),
      '<a href="https://x.fr/&quot;onclick=1" rel="noreferrer">a</a>',
    );
    assert.equal(inline('[a](javascript:alert(1))'), 'a)');
    assert.match(blocks('| A |\n|---|\n| <b> |'), /<td>&lt;b&gt;<\/td>/);
  });

  test('lists with a nested table', () => {
    const html = blocks('- **Apps**: one table.\n\n  | App | Price |\n  |---|---|\n  | K | €4 |\n\n- next');
    assert.match(
      html,
      /^<ul><li><p><strong>Apps<\/strong>: one table\.<\/p>\n<div class="scroll"><table>.*<td>€4<\/td>.*<\/li><li><p>next<\/p><\/li><\/ul>$/s,
    );
  });

  test('the index lists reports newest first, with when each was taken and its status then', () => {
    const html = renderIndex([
      { href: 'a.html', title: 'Old', takenAt: '2026-10-01T08:00Z', approvalStatus: 'approved' },
      { href: 'b.html', title: 'New <1>', takenAt: '2026-11-01T08:00Z', approvalStatus: 'pending' },
    ]);
    assert.ok(html.indexOf('New &lt;1&gt;') < html.indexOf('Old'));
    assert.match(html, /Taken 2026-10-01 08:00 UTC\. Approval approved at that time\./);
  });

  test('axis ticks are clean steps that cover the data', () => {
    assert.deepEqual(ticks(0, 12100), [0, 5000, 10000, 15000]);
    assert.deepEqual(ticks(0, 2), [0, 0.5, 1, 1.5, 2]);
    assert.deepEqual(ticks(-3, 12), [-5, 0, 5, 10, 15]);
    assert.deepEqual(ticks(0, 0), [0, 1]);
  });
});
