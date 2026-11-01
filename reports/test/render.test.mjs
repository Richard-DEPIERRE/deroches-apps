import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { describe, test } from 'node:test';
import { blocks, inline } from '../lib/html.mjs';
import { renderEpicsPage, renderIndex, renderResearchPage, ticks } from '../lib/render.mjs';
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

describe('epics page', () => {
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
    assert.match(price, /€24\.99.*€19\.99/s);
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
