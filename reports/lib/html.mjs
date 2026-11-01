// HTML for the report pages: escaping, the small slice of Markdown the cards use, and the page shell.
// Every piece of report text goes through `esc` before any markup is added around it.
import { createHash } from 'node:crypto';
import { table } from './markdown.mjs';

const ENTITIES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
export const esc = (text) => String(text ?? '').replace(/[&<>"']/g, (c) => ENTITIES[c]);

/** One line of Markdown: code spans, bold (around code too), http(s) links (other links keep their label only). */
export const inline = (text) =>
  esc(text)
    .replace(/`([^`]*)`/g, '<code>$1</code>')
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, '<a href="$2" rel="noreferrer">$1</a>')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1');

export function tableHtml({ headers, rows }, cellHtml = (text) => `<td>${inline(text)}</td>`) {
  const head = headers.map((h) => `<th scope="col">${inline(h)}</th>`).join('');
  const body = rows.map((row) => `<tr>${row.map((text) => cellHtml(text)).join('')}</tr>`).join('');
  return `<div class="scroll"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

const ITEM = /^(?:[-*]|\d+\.) /;

/** Paragraphs, lists (items continue on lines indented two spaces) and tables, nested inside list items. */
export function blocks(md) {
  const lines = String(md ?? '')
    .replace(/\r\n?/g, '\n')
    .split('\n');
  const out = [];
  let i = 0;
  while (i < lines.length) {
    if (!lines[i].trim()) {
      i += 1;
    } else if (ITEM.test(lines[i])) {
      const ordered = /^\d/.test(lines[i]);
      const items = [];
      for (; i < lines.length; i += 1) {
        const line = lines[i];
        const goesOn = /^\s+\S/.test(lines[i + 1] ?? '') || ITEM.test(lines[i + 1] ?? '');
        if (ITEM.test(line)) items.push([line.replace(ITEM, '')]);
        else if (/^\s+\S/.test(line) || (!line.trim() && goesOn))
          items.at(-1).push(line.replace(/^ {1,3}/, ''));
        else break;
      }
      const tag = ordered ? 'ol' : 'ul';
      out.push(`<${tag}>${items.map((item) => `<li>${blocks(item.join('\n'))}</li>`).join('')}</${tag}>`);
    } else {
      const start = i;
      const isTable = lines[i].trim().startsWith('|');
      while (
        i < lines.length &&
        lines[i].trim() &&
        (isTable ? lines[i].trim().startsWith('|') : !ITEM.test(lines[i]))
      )
        i += 1;
      const text = lines.slice(start, i).join('\n');
      const parsed = isTable ? table(text) : { headers: [] };
      out.push(parsed.headers.length ? tableHtml(parsed) : `<p>${inline(text.replace(/\n/g, ' '))}</p>`);
    }
  }
  return out.join('\n');
}

// Colours: the dataviz reference palette (series slot 1 blue, its ordinal ramp from step 250, the status steps,
// the chart chrome), light and dark. No inline `style` attributes anywhere: the CSP allows this block by hash only.
const CSS = `:root{color-scheme:light dark;--bg:#f9f9f7;--surface:#fcfcfb;--ink:#0b0b0b;--ink2:#52514e;--grid:#e1e0d9;\
--axis:#c3c2b7;--series:#2a78d6;--border:rgba(11,11,11,.1);--na:#e1e0d9}
@media (prefers-color-scheme:dark){:root{--bg:#0d0d0d;--surface:#1a1a19;--ink:#f0efec;--ink2:#c3c2b7;--grid:#2c2c2a;\
--axis:#383835;--series:#3987e5;--border:rgba(255,255,255,.1);--na:#383835}}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif}
main{max-width:760px;margin:0 auto;padding:16px}
section,article{background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:12px 16px;margin:16px 0}
h1{font-size:1.5rem;line-height:1.25;margin:0 0 4px}h2{font-size:1.15rem;margin:0 0 8px}h3{font-size:1rem;margin:16px 0 4px}
article h3{margin-top:0}.meta,.hint{color:var(--ink2);font-size:.875rem}a{color:inherit}code{font-size:.875em}
.button{display:inline-block;margin:12px 0 0;background:#256abf;color:#fff;font-weight:600;padding:12px 20px;\
border-radius:8px;text-decoration:none}
.scroll{overflow-x:auto;margin:8px 0}table{border-collapse:collapse;font-size:.875rem;font-variant-numeric:tabular-nums}
th,td{text-align:left;padding:6px 8px;border-bottom:1px solid var(--grid);vertical-align:top}
.heat td{text-align:center;white-space:nowrap}.h1,.h2{background:#86b6ef;color:#0b0b0b}.h2{background:#5598e7}
.h3,.h4,.h5{background:#2a78d6;color:#fff}.h4{background:#1c5cab}.h5{background:#104281}
.na{background:repeating-linear-gradient(45deg,var(--na) 0 3px,transparent 3px 7px);color:var(--ink2);font-style:italic}
.v::before{content:"";display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:6px;background:#0ca30c}
.v-concerns::before{background:#fab219}.v-fail::before{background:#d03b3b}
svg{display:block;width:100%;max-width:480px;height:auto}svg text{fill:var(--ink2);font-size:13px}
svg .label{fill:var(--ink);font-size:14px}.grid{stroke:var(--grid)}.axis{stroke:var(--axis)}
.mark{fill:var(--series);fill-opacity:.85;stroke:var(--surface);stroke-width:2}.hollow{fill:none;stroke:var(--series)}
.off{margin:8px 0;padding:8px 12px;border-left:3px solid var(--axis)}.off ul{margin:4px 0;padding-left:20px}
ul.reports{list-style:none;padding:0}ul.reports li{margin:12px 0}`;

const CSP = `default-src 'none'; style-src 'sha256-${createHash('sha256').update(CSS).digest('base64')}'; base-uri 'none'; form-action 'none'`;

/** A whole page: noindex, a CSP that allows nothing but its own style block, no script and no outside request. */
export const page = (title, body) => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<meta http-equiv="Content-Security-Policy" content="${CSP}">
<meta name="referrer" content="no-referrer">
<title>${esc(title)}</title>
<style>${CSS}</style>
</head>
<body><main>
${body}
</main></body>
</html>
`;
