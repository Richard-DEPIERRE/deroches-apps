// The publish build (ADR 0004, decision 2). It reads every `MR-REPORT:` / `PL-EPICS:` approval and its issue's
// `research-report` / `epics-report` document from Paperclip, with the run's own PAPERCLIP_API_URL,
// PAPERCLIP_API_KEY and PAPERCLIP_COMPANY_ID (no other secret). It renders the pages and writes them to
// `generated/pages.mjs`, the module the Worker bundles. A report that fails to parse fails the build, by name.
//   node build.mjs              build only (look at it with `npx wrangler deploy --dry-run`)
//   node build.mjs --from-main  what `npm run deploy` runs: also refuses anything but a clean, current `main`
import { execFileSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { CSP } from './lib/html.mjs';
import { renderEpicsPage, renderIndex, renderResearchPage } from './lib/render.mjs';
import { parseEpicsReport, parseResearchReport } from './lib/reports.mjs';
import settings from './settings.json' with { type: 'json' };

const KINDS = [
  { prefix: 'MR-REPORT:', doc: 'research-report', path: 'research', parse: parseResearchReport },
  { prefix: 'PL-EPICS:', doc: 'epics-report', path: 'epics', parse: parseEpicsReport },
];
const RENDER = { research: renderResearchPage, epics: renderEpicsPage };

/** GETs on the Paperclip API with the run's own credentials. A 404 is `null`. */
export function paperclip(env = process.env) {
  const names = ['PAPERCLIP_API_URL', 'PAPERCLIP_API_KEY', 'PAPERCLIP_COMPANY_ID'];
  const missing = names.filter((n) => !env[n]);
  if (missing.length) throw new Error(`${missing.join(', ')} not set: publish from an agent run`);
  return {
    company: env.PAPERCLIP_COMPANY_ID,
    async get(path) {
      const res = await fetch(new URL(path, env.PAPERCLIP_API_URL), {
        headers: { Authorization: `Bearer ${env.PAPERCLIP_API_KEY}` },
      });
      if (res.status === 404) return null;
      if (!res.ok) throw new Error(`Paperclip GET ${path}: HTTP ${res.status}`);
      return res.json();
    },
  };
}

/** The report document of an approval: the first linked issue that has it. */
async function reportOf(api, approval, kind, name) {
  for (const issue of (await api.get(`/api/approvals/${approval.id}/issues`)) ?? []) {
    const doc = await api.get(`/api/issues/${issue.id}/documents/${kind.doc}`);
    if (doc?.body) return { md: doc.body, where: `${issue.identifier ?? issue.id} document ${kind.doc}` };
  }
  throw new Error(`${name}: no linked issue has a ${kind.doc} document`);
}

/** Every report page by path, plus the index at `/`. */
export async function buildPages(api, { paperclipUrl = settings.paperclipUrl, takenAt } = {}) {
  const approvals = (await api.get(`/api/companies/${api.company}/approvals`)) ?? [];
  const pages = {};
  const index = [];
  for (const approval of approvals) {
    const title = approval.payload?.title ?? '';
    const kind = KINDS.find((k) => approval.type === 'request_board_approval' && title.startsWith(k.prefix));
    if (!kind) continue;
    const name = `"${title}" (approval ${approval.id})`;
    const { md, where } = await reportOf(api, approval, kind, name);
    let report;
    try {
      report = kind.parse(md);
    } catch (err) {
      throw new Error(`${name}: ${where} does not parse: ${err.message}`);
    }
    const href = `/${kind.path}/${approval.id}`;
    const opts = { paperclipUrl, approvalId: approval.id, approvalStatus: approval.status, takenAt };
    pages[href] = RENDER[kind.path](report, opts);
    index.push({ href, title: report.title, ...opts });
  }
  pages['/'] = renderIndex(index);
  return pages;
}

/** The generated module's source: the pages and the CSP their style block needs. */
export const moduleSource = (pages) =>
  `// Written by build.mjs at publish time from Paperclip. Never commit it (ADR 0004).
export const csp = ${JSON.stringify(CSP)};
export const pages = ${JSON.stringify(pages, null, 1)};
`;

/** Only what is merged deploys: a clean `reports/` at the tip of `origin/main` (RULES.md section 1). */
export function assertMergedMain(git = (...args) => execFileSync('git', args, { encoding: 'utf8' }).trim()) {
  git('fetch', '--quiet', 'origin', 'main');
  const head = git('rev-parse', 'HEAD');
  const main = git('rev-parse', 'FETCH_HEAD');
  if (head !== main)
    throw new Error(
      `HEAD ${head.slice(0, 7)} is not origin/main ${main.slice(0, 7)}: deploy from merged main`,
    );
  if (git('status', '--porcelain', '--', '.'))
    throw new Error('reports/ has local changes: deploy from merged main');
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    if (process.argv.includes('--from-main')) assertMergedMain();
    const pages = await buildPages(paperclip(), { takenAt: new Date().toISOString() });
    await mkdir(new URL('./generated/', import.meta.url), { recursive: true });
    await writeFile(new URL('./generated/pages.mjs', import.meta.url), moduleSource(pages));
    const reports = Object.keys(pages).filter((p) => p !== '/');
    console.log(`built ${reports.length} report page(s) and the index: ${reports.join(', ') || 'none yet'}`);
  } catch (err) {
    console.error(`publish build failed: ${err.message}`);
    process.exit(1);
  }
}
