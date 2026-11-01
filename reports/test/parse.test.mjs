import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { describe, test } from 'node:test';
import { cards, cell, likely, numbers, sections, table } from '../lib/markdown.mjs';
import { parseEpicsReport, parseReport, parseResearchReport } from '../lib/reports.mjs';

const fixture = (name) => readFile(new URL(`./fixture/${name}`, import.meta.url), 'utf8');
// The Studio clone's templates, to catch a template that drifted from the parser.
const studio = process.env.STUDIO_CLONE ?? '/Volumes/Hermes/Studio/repos/deroches-studio';
const templates = new URL(`file://${studio}/apps/handbook/templates/`);

describe('cells', () => {
  test('reads the number formats reports use', () => {
    assert.deepEqual(numbers('12 100'), [12100]);
    assert.deepEqual(numbers('12 100 and 12 100'), [12100, 12100]);
    assert.deepEqual(numbers('1,300 / 4,400'), [1300, 4400]);
    assert.deepEqual(numbers('4,2'), [4.2]);
    assert.deepEqual(numbers('2,9k'), [2900]);
    assert.deepEqual(numbers('+3 pts, −2 %, -1'), [3, -2, -1]);
    assert.deepEqual(numbers('€300-€900'), [300, 900]);
  });

  test('a NOT ASSESSED cell is not assessed, never zero', () => {
    for (const text of ['NOT ASSESSED', 'NOT ASSESSED (n=64)', '`NOT ASSESSED` (people pay)']) {
      const value = cell(text);
      assert.equal(value.notAssessed, true, text);
      assert.equal(value.value, null, text);
    }
  });

  test('a cell without a number has no value, not zero', () => {
    assert.deepEqual(cell('PASS'), { text: 'PASS', notAssessed: false, value: null });
    assert.equal(cell('').value, null);
  });

  test('a source in brackets is not read as the value', () => {
    assert.equal(cell('12 100 (Keyword Planner, 2026-10-28)').value, 12100);
  });

  test('the likely revenue: named, the middle of three, the middle of a range', () => {
    assert.equal(cell('€300–€1 500 (likely €700), estimate', likely).value, 700);
    assert.equal(cell('€200 / €450 / €900', likely).value, 450);
    assert.equal(cell('€200–€600', likely).value, 400);
    assert.equal(cell('€500', likely).value, 500);
  });
});

describe('markdown', () => {
  test('sections by number, and the text before them', () => {
    const parts = sections('# T\nintro\n## 1. One\na\n## 2. Two\nb\n');
    assert.equal(parts[1].title, 'One');
    assert.equal(parts[2].body, 'b');
    assert.match(parts.preamble, /intro/);
  });

  test('a table with an escaped pipe, a short row and a blank row', () => {
    const { headers, rows } = table('| A | B |\n|---|:---:|\n| x \\| y | z |\n| | |\n| only |\nafter');
    assert.deepEqual(headers, ['A', 'B']);
    assert.deepEqual(rows, [
      ['x | y', 'z'],
      ['only', ''],
    ]);
  });

  test('no table gives no rows', () => {
    assert.deepEqual(table('just text'), { headers: [], rows: [] });
  });

  test('cards keep multi-line items', () => {
    const [card] = cards('### Name — what it does\n- **Label**: first\n  second\n- **`Gate`**: PASS\n');
    assert.equal(card.name, 'Name');
    assert.equal(card.description, 'what it does');
    assert.deepEqual(card.items, [
      { label: 'Label', text: 'first\nsecond' },
      { label: 'Gate', text: 'PASS' },
    ]);
  });
});

describe('research report', async () => {
  const report = parseResearchReport(await fixture('research-report.md'));

  test('title, period and recommendation', () => {
    assert.equal(report.period, '2026-11');
    assert.match(report.recommendation, /Frais Réels/);
  });

  test('section 2: the bubble chart rows', () => {
    assert.equal(report.ideas.length, 3);
    const [frais, plantes, eau] = report.ideas;
    assert.equal(frais.idea, 'Frais Réels');
    assert.equal(frais.demandFr.value, 12100);
    assert.equal(frais.beatability.value, 4);
    assert.equal(frais.revenue.value, 700);
    assert.equal(frais.demandUkUs.text, '1,300 / 4,400');
    assert.equal(plantes.demandUkUs.notAssessed, true);
    assert.match(plantes.beatability.text, /strong leader \| many clones/);
    assert.equal(plantes.revenue.value, 450);
    assert.equal(eau.demandFr.value, 2900);
    assert.equal(eau.revenue.notAssessed, true);
    assert.equal(eau.revenue.value, null);
  });

  test('section 3: scores with NOT ASSESSED cells kept as such', () => {
    assert.equal(report.scores.columns.length, 9);
    assert.equal(report.scores.columns[0], 'Demand');
    const eau = report.scores.rows[2];
    assert.equal(eau.idea, 'Compteur Eau');
    const pay = eau.cells[report.scores.columns.indexOf('People pay')];
    assert.equal(pay.notAssessed, true);
    assert.equal(pay.value, null);
    assert.equal(report.scores.rows[0].cells[report.scores.columns.indexOf('Score')].value, 4.2);
  });

  test('section 4: one card per idea', () => {
    assert.deepEqual(
      report.cards.map((card) => card.name),
      ['Frais Réels', 'Carnet Plantes', 'Compteur Eau'],
    );
    assert.equal(report.cards[0].items.at(-1).label, 'MR-REPORT');
    assert.match(report.cards[0].items[1].text, /KmPro/);
  });

  test('a report missing a template column fails loudly', () => {
    assert.throws(
      () =>
        parseResearchReport('# Research report — x\n## 1. R\nr\n## 2. D\n| Idea | Demand FR |\n|---|---|\n'),
      /column "demand uk"/,
    );
  });
});

describe('epics report', async () => {
  const report = parseEpicsReport(await fixture('epics-report.md'));

  test('section 2: size against expected effect, per app', () => {
    assert.equal(report.period, '2026-11-02');
    assert.deepEqual(
      report.epics.map((epic) => [epic.app, epic.size.value, epic.effect.value]),
      [
        ['frais-reels', 2, 3],
        ['frais-reels', 0.5, 12],
        ['carnet-plantes', 3, null],
      ],
    );
    assert.equal(report.epics[2].effect.notAssessed, true);
    assert.deepEqual(
      report.epics.map((epic) => [epic.price, epic.dataChange]),
      [
        [false, false],
        [true, false],
        [false, true],
      ],
    );
  });

  test('sections 3 and 4: cards, and prices apart', () => {
    assert.equal(report.cards.length, 2);
    assert.equal(report.cards[1].description, 'carnet-plantes');
    assert.equal(report.price.none, false);
    assert.equal(report.price.table.rows[0][4], '€19.99');
  });
});

describe('the templates as written', () => {
  // The empty templates in the Studio clone parse with no rows; skipped where the clone is not beside this repo.
  const read = (name) => readFile(new URL(name, templates), 'utf8').catch(() => null);

  test('research-report.md', async (t) => {
    const md = await read('research-report.md');
    if (!md) return t.skip('Studio clone not found');
    const report = parseReport(md);
    assert.equal(report.kind, 'research');
    assert.deepEqual(report.ideas, []);
    assert.equal(report.scores.columns.length, 9);
  });

  test('epics-report.md', async (t) => {
    const md = await read('epics-report.md');
    if (!md) return t.skip('Studio clone not found');
    const report = parseReport(md);
    assert.equal(report.kind, 'epics');
    assert.deepEqual(report.epics, []);
  });
});
