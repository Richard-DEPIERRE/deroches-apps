// The two report templates (apps/handbook/templates in deroches-studio) read into the data the pages draw.
import { cards, cell, column, likely, sections, table, title } from './markdown.mjs';

function section(parts, number, name) {
  const part = parts[number];
  if (!part) throw new Error(`section "## ${number}. ${name}" not found`);
  return part;
}

/** The scores table, every column but the first kept as cells, in the report's order. */
function scores(body) {
  const { headers, rows } = table(body);
  if (!headers.length) return { columns: [], rows: [] };
  column(headers, 'idea');
  return {
    columns: headers.slice(1),
    rows: rows.map(([idea, ...rest]) => ({ idea, cells: rest.map((text) => cell(text)) })),
  };
}

/**
 * `templates/research-report.md`: section 1 (recommendation), 2 (the bubble chart's rows), 3 (scores side by
 * side) and 4 (one card per idea). Bubble x is beatability, y the French demand, size the likely revenue at
 * 6 months; UK/US demand goes in the tooltip.
 */
export function parseResearchReport(md) {
  const parts = sections(md);
  const demand = table(section(parts, 2, 'Demand against competition').body);
  const at = {
    idea: column(demand.headers, 'idea'),
    fr: column(demand.headers, 'demand fr'),
    ukUs: column(demand.headers, 'demand uk'),
    beatability: column(demand.headers, 'beatability'),
    revenue: column(demand.headers, 'likely revenue'),
  };
  return {
    kind: 'research',
    ...title(md),
    recommendation: section(parts, 1, 'Recommendation').body,
    ideas: demand.rows.map((row) => ({
      idea: row[at.idea],
      demandFr: cell(row[at.fr]),
      demandUkUs: cell(row[at.ukUs]),
      beatability: cell(row[at.beatability]),
      revenue: cell(row[at.revenue], likely),
    })),
    scores: scores(section(parts, 3, 'Scores side by side').body),
    cards: cards(section(parts, 4, 'One card per idea').body),
    methods: parts[5]?.body ?? '',
    notPicked: parts[6]?.body ?? '',
  };
}

/** A `PRICE` or data-change cell: true for a yes or a mark, false for no, a dash or an empty cell. */
const flag = (text) => !/^(|no|non|none|-|—|–|n\/a|unchanged)$/i.test(text.replace(/[`*_]/g, '').trim());

/**
 * `templates/epics-report.md`: section 1 (recommendation), 2 (size in days against expected effect, per app),
 * 3 (one card per epic), 4 (price changes and tests, shown apart) and 6 (epics held back, not assessed).
 */
export function parseEpicsReport(md) {
  const parts = sections(md);
  const epics = table(section(parts, 2, "This week's epics side by side").body);
  const at = {
    epic: column(epics.headers, 'epic'),
    app: column(epics.headers, 'app'),
    why: column(epics.headers, 'why'),
    effect: column(epics.headers, 'expected effect'),
    size: column(epics.headers, 'size'),
    screen: column(epics.headers, 'new screen'),
    price: column(epics.headers, 'price'),
    data: column(epics.headers, 'data change'),
  };
  const price = section(parts, 4, 'Price changes and price tests');
  return {
    kind: 'epics',
    ...title(md),
    recommendation: section(parts, 1, 'Recommendation').body,
    epics: epics.rows.map((row) => ({
      epic: row[at.epic],
      app: row[at.app],
      why: row[at.why],
      effect: cell(row[at.effect]),
      size: cell(row[at.size]),
      newScreen: row[at.screen],
      price: flag(row[at.price]),
      dataChange: flag(row[at.data]),
      dataChangeText: row[at.data],
    })),
    cards: cards(section(parts, 3, 'One card per epic').body),
    price: { body: price.body, table: table(price.body), none: /none this week/i.test(price.body) },
    lastWeek: parts[5]?.body ?? '',
    // Epics held back for a MISSING input: shown open on the page, a gap is shown as a gap (handbook section 3).
    notAssessed: parts[6]?.body ?? '',
    methods: parts[7]?.body ?? '',
  };
}

/** Either report, told apart by its title. */
export function parseReport(md) {
  const { title: text } = title(md);
  if (/^research report/i.test(text)) return parseResearchReport(md);
  if (/^epics report/i.test(text)) return parseEpicsReport(md);
  throw new Error(`not a research or epics report: "${text}"`);
}
