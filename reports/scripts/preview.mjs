// Renders the test fixtures to dist/ (gitignored), to look at the pages and take the Designer's screenshots.
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { renderEpicsPage, renderIndex, renderResearchPage } from '../lib/render.mjs';
import { parseEpicsReport, parseResearchReport } from '../lib/reports.mjs';

const read = (name) => readFile(new URL(`../test/fixture/${name}`, import.meta.url), 'utf8');
const out = new URL('../dist/', import.meta.url);
const paperclipUrl = 'http://127.0.0.1:3100';
const research = parseResearchReport(await read('research-report.md'));
const epics = parseEpicsReport(await read('epics-report.md'));
const pages = [
  [
    'research.html',
    research,
    renderResearchPage,
    { approvalId: 'example-research', takenAt: '2026-11-01T09:00Z' },
  ],
  ['epics.html', epics, renderEpicsPage, { approvalId: 'example-epics', takenAt: '2026-11-02T07:30Z' }],
];
await mkdir(out, { recursive: true });
for (const [file, report, render, opts] of pages) {
  await writeFile(new URL(file, out), render(report, { ...opts, paperclipUrl, approvalStatus: 'pending' }));
}
const index = pages.map(([href, report, , opts]) => ({
  href,
  title: report.title,
  ...opts,
  approvalStatus: 'pending',
}));
await writeFile(new URL('index.html', out), renderIndex(index));
console.log(`wrote ${pages.length + 1} pages to ${out.pathname}`);
