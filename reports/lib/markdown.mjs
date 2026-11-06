// The small slice of Markdown the report templates use: `## N.` sections, GFM tables, `###` cards with
// `- **Label**: text` items, and table cells that hold a number, a range or `NOT ASSESSED`.

/** `## 2. Title` → { 2: { title, body } }. Text before the first section is `preamble`. */
export function sections(md) {
  const out = { preamble: '' };
  let current = null;
  for (const line of md.replace(/\r\n?/g, '\n').split('\n')) {
    const heading = /^## +(\d+)\.\s*(.*)$/.exec(line);
    if (heading) {
      current = { title: heading[2].trim(), lines: [] };
      out[Number(heading[1])] = current;
    } else if (current) {
      current.lines.push(line);
    } else {
      out.preamble += `${line}\n`;
    }
  }
  for (const [key, value] of Object.entries(out)) {
    if (key !== 'preamble') out[key] = { title: value.title, body: value.lines.join('\n').trim() };
  }
  return out;
}

/** The report's `# Title`, and what follows its em dash (the month or the week). */
export function title(md) {
  const match = /^# +(.+)$/m.exec(md);
  if (!match) return { title: '', period: '' };
  const [, text] = match;
  const dash = text.split(/\s+[—–-]\s+/);
  return {
    title: text.trim(),
    period:
      dash.length > 1
        ? dash
            .at(-1)
            .replace(/^week of\s+/i, '')
            .trim()
        : '',
  };
}

function splitRow(line) {
  const cells = [];
  let cell = '';
  const body = line.trim().replace(/^\|/, '').replace(/\|$/, '');
  for (let i = 0; i < body.length; i += 1) {
    if (body[i] === '\\' && body[i + 1] === '|') {
      cell += '|';
      i += 1;
    } else if (body[i] === '|') {
      cells.push(cell.trim());
      cell = '';
    } else {
      cell += body[i];
    }
  }
  cells.push(cell.trim());
  return cells;
}

const isDivider = (line) => /^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?\s*$/.test(line);

/** The first GFM table in `body`: { headers, rows } with each row as an array of cell strings. */
export function table(body) {
  const lines = body.split('\n');
  const start = lines.findIndex((line, i) => line.trim().startsWith('|') && isDivider(lines[i + 1] ?? ''));
  if (start === -1) return { headers: [], rows: [] };
  const headers = splitRow(lines[start]);
  const rows = [];
  for (const line of lines.slice(start + 2)) {
    if (!line.trim().startsWith('|')) break;
    const cells = splitRow(line);
    if (cells.every((cell) => cell === '')) continue;
    rows.push(headers.map((_, i) => cells[i] ?? ''));
  }
  return { headers, rows };
}

const plain = (text) => text.replace(/[`*_]/g, '').trim().toLowerCase();

/**
 * Index of the column whose header starts with `name` (case, backticks and emphasis ignored). A template column
 * that is missing throws: a report that drifted from its template fails the publish loudly instead of drawing a
 * wrong chart.
 */
export function column(headers, name) {
  const index = headers.findIndex((header) => plain(header).startsWith(name.toLowerCase()));
  if (index === -1) throw new Error(`table column "${name}" not found (columns: ${headers.join(', ')})`);
  return index;
}

/** `### Name — description` blocks: { name, description, items: [{ label, text }], body }. */
export function cards(body) {
  const out = [];
  for (const block of body.split(/^### +/m).slice(1)) {
    const [heading, ...rest] = block.split('\n');
    const [name, ...description] = heading.split(/\s+—\s+/);
    const items = [];
    for (const line of rest) {
      const item = /^- +\*\*(.+?)\*\*:?\s*(.*)$/.exec(line);
      if (item)
        items.push({ label: item[1].replace(/`/g, '').replace(/:$/, '').trim(), text: item[2].trim() });
      else if (items.length && line.trim()) items.at(-1).text += `\n${line.replace(/^ {2}/, '')}`;
    }
    out.push({
      name: name.trim(),
      description: description.join(' — ').trim(),
      items,
      body: rest.join('\n').trim(),
    });
  }
  return out;
}

// Thousands are grouped with a space, a no-break space, a narrow no-break space or a comma ("12 100",
// "12,100"); a comma with one or two digits after it is a French decimal ("1,5"). A sign counts only at the start
// of a word, so "300-900" is a range, not a negative number.
const SEP = '[ \\u00a0\\u202f,]';
const NUMBER = new RegExp(
  `(?:(?<!\\w)([+\\-\\u2212]))?(\\d{1,3}(?:${SEP}\\d{3})+(?!\\d|[.,]\\d)|\\d+(?:[.,]\\d+)?)\\s*([kKmM](?![a-zA-Z]))?`,
  'g',
);
// A date read ("2026-10-28", "2026-10") is the source's, never the cell's value.
const DATE = /\b(?:19|20)\d{2}-(?:0[1-9]|1[0-2])(?:-\d{2})?\b/g;
const GROUPED = new RegExp(`^\\d{1,3}(?:${SEP}\\d{3})+$`);

function toNumber([, sign, digits, suffix]) {
  let value = Number(GROUPED.test(digits) ? digits.replace(/\D/g, '') : digits.replace(',', '.'));
  if (suffix) value *= /k/i.test(suffix) ? 1_000 : 1_000_000;
  return sign ? (sign === '+' ? value : -value) : value;
}

/**
 * Every number in a text, in order: `12 100`, `12,100`, `1,5`, `12k`, `+2`, `−3`. A grouped number may be followed
 * by a comma or a full stop (`12 100, source`). Dates are not skipped here; `cell` drops them.
 */
export function numbers(text) {
  return [...text.matchAll(NUMBER)].map(toNumber);
}

/**
 * A table cell: its text, whether it is `NOT ASSESSED`, and the number it carries. Text in brackets and dates are
 * dropped first. A `NOT ASSESSED` cell, or one with no number, has `value: null`: a gap in the data is missing
 * data, never zero (handbook section 3).
 * `pick` chooses among the cell's numbers (default: the first).
 */
export function cell(text, pick = (values) => values[0]) {
  const raw = text.trim();
  if (/NOT ASSESSED/i.test(raw)) return { text: raw, notAssessed: true, value: null };
  const value = pick(numbers(raw.replace(/\([^)]*\)/g, ' ').replace(DATE, ' ')), raw);
  return { text: raw, notAssessed: false, value: Number.isFinite(value) ? value : null };
}

/**
 * The "likely" figure of a revenue range: the number after "likely" when it is named, else the middle of
 * low / likely / high, else the middle of a low–high range, else the only number.
 */
export function likely(values, text = '') {
  const named = /likely\D{0,12}?(\d[\d\s.,]*[kKmM]?)/i.exec(text);
  if (named) return numbers(named[1])[0];
  if (values.length >= 3) return values[1];
  if (values.length === 2) return (values[0] + values[1]) / 2;
  return values[0];
}
