import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { describe, test } from 'node:test';
import { inspect } from 'node:util';
import { assertMergedMain, buildPages, moduleSource, paperclip } from '../build.mjs';
import { CSP } from '../lib/html.mjs';
import { serve } from '../lib/serve.mjs';

const fixture = (name) => readFile(new URL(`./fixture/${name}`, import.meta.url), 'utf8');
const SECRET = 'the report text';
const site = { csp: CSP, pages: { '/': `<p>${SECRET}</p>`, '/research/a1': '<p>research</p>' } };
const access = { access: { aud: 'aud-tag', getIdentity: async () => ({ email: 'r@example.com' }) } };
const get = (path, ctx, method = 'GET') =>
  serve(new Request(`https://x.workers.dev${path}`, { method }), ctx, site);

function expectHeaders(res) {
  assert.equal(res.headers.get('X-Robots-Tag'), 'noindex, nofollow');
  assert.equal(res.headers.get('Cache-Control'), 'private, no-store');
  assert.equal(res.headers.get('Referrer-Policy'), 'no-referrer');
  const csp = res.headers.get('Content-Security-Policy');
  assert.match(csp, /^default-src 'none'; style-src 'sha256-[A-Za-z0-9+/=]+'; /);
  assert.match(csp, /frame-ancestors 'none'$/);
  assert.doesNotMatch(csp, /script-src|unsafe/);
}

describe('worker: fails closed', () => {
  for (const ctx of [undefined, {}, { access: undefined }, { access: null }]) {
    test(`403 with no report content when ctx is ${inspect(ctx)}`, async () => {
      for (const path of ['/', '/research/a1', '/nothing']) {
        const res = get(path, ctx);
        assert.equal(res.status, 403);
        const body = await res.text();
        assert.doesNotMatch(body, /report text|research/);
        expectHeaders(res);
      }
    });
  }

  test('a page when Access authenticated the request, with the headers', async () => {
    const res = get('/', access);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('Content-Type'), 'text/html; charset=utf-8');
    assert.equal(await res.text(), `<p>${SECRET}</p>`);
    expectHeaders(res);
    assert.equal(await get('/research/a1', access).text(), '<p>research</p>');
  });

  test('unknown paths are 404, prototype keys included; HEAD has no body; other methods 405', async () => {
    for (const path of ['/nothing', '/constructor', '/__proto__', '/research/a1/']) {
      assert.equal(get(path, access).status, 404, path);
    }
    const head = get('/', access, 'HEAD');
    assert.equal(head.status, 200);
    assert.equal(await head.text(), '');
    const post = get('/', access, 'POST');
    assert.equal(post.status, 405);
    assert.equal(post.headers.get('Allow'), 'GET, HEAD');
  });

  test('robots.txt disallows everything, with or without Access', async () => {
    for (const ctx of [undefined, access]) {
      const res = get('/robots.txt', ctx);
      assert.equal(res.status, 200);
      assert.equal(await res.text(), 'User-agent: *\nDisallow: /\n');
      expectHeaders(res);
    }
  });

  test('wrangler.jsonc: workers.dev only, no previews, no Static Assets', async () => {
    const text = await readFile(new URL('../wrangler.jsonc', import.meta.url), 'utf8');
    const config = JSON.parse(text.replace(/^\s*\/\/.*$/gm, ''));
    assert.equal(config.name, 'deroches-reports');
    assert.equal(config.main, 'worker.mjs');
    assert.equal(config.workers_dev, true);
    assert.equal(config.preview_urls, false);
    for (const key of ['assets', 'site', 'routes', 'route', 'vars', 'kv_namespaces', 'd1_databases'])
      assert.equal(config[key], undefined, key);
  });
});

/** A fake Paperclip: approvals, the issues they link, and documents by issue. */
function fakeApi({ approvals, links, docs }) {
  return {
    company: 'c1',
    get: async (path) => {
      if (path === '/api/companies/c1/approvals') return approvals;
      const link = path.match(/^\/api\/approvals\/([^/]+)\/issues$/);
      if (link) return links[link[1]] ?? [];
      const doc = path.match(/^\/api\/issues\/([^/]+)\/documents\/([^/]+)$/);
      if (doc) return docs[`${doc[1]}/${doc[2]}`] ?? null;
      throw new Error(`unexpected ${path}`);
    },
  };
}
const approval = (id, title, status = 'pending', type = 'request_board_approval') => ({
  id,
  type,
  status,
  payload: { title },
});

describe('build', () => {
  const world = async () => ({
    approvals: [
      approval('r1', 'MR-REPORT: research report 2026-11 — pick the apps to build'),
      approval('e1', 'PL-EPICS: week of 2026-11-02 — validate the epics', 'approved'),
      approval('x1', 'SPEND: domain'),
      approval('h1', 'MR-REPORT: a hire', 'pending', 'hire_agent'),
    ],
    links: {
      r1: [{ id: 'i1', identifier: 'DAPP-7' }],
      e1: [{ id: 'i0' }, { id: 'i2', identifier: 'DAPP-8' }],
    },
    docs: {
      'i1/research-report': { body: await fixture('research-report.md') },
      'i2/epics-report': { body: await fixture('epics-report.md') },
    },
  });

  test('one page per MR-REPORT / PL-EPICS approval, linked to it, and the index', async () => {
    const pages = await buildPages(fakeApi(await world()), {
      paperclipUrl: 'https://paperclip.example',
      takenAt: '2026-11-02T08:00:00Z',
    });
    assert.deepEqual(Object.keys(pages).sort(), ['/', '/epics/e1', '/research/r1']);
    assert.match(pages['/research/r1'], /href="https:\/\/paperclip\.example\/DAPP\/approvals\/r1"/);
    assert.match(pages['/epics/e1'], /href="https:\/\/paperclip\.example\/DAPP\/approvals\/e1"/);
    assert.match(pages['/'], /href="\/research\/r1"/);
    assert.match(pages['/'], /Approval approved at that time/);
  });

  test('a report that fails to parse fails the build, naming the report', async () => {
    const w = await world();
    w.docs['i1/research-report'] = { body: '# Research report — 2026-11\n\nNo sections here.\n' };
    await assert.rejects(
      buildPages(fakeApi(w), { takenAt: '2026-11-02T08:00:00Z' }),
      /"MR-REPORT: research report 2026-11 — pick the apps to build" \(approval r1\): DAPP-7 document research-report does not parse: /,
    );
  });

  test('an approval with no report document fails the build, naming it', async () => {
    const w = await world();
    delete w.docs['i2/epics-report'];
    await assert.rejects(
      buildPages(fakeApi(w), { takenAt: '2026-11-02T08:00:00Z' }),
      /"PL-EPICS: week of 2026-11-02 — validate the epics" \(approval e1\): no linked issue has a epics-report document/,
    );
  });

  test('no approval yet: the index alone', async () => {
    const pages = await buildPages(fakeApi({ approvals: [], links: {}, docs: {} }), { takenAt: 'x' });
    assert.deepEqual(Object.keys(pages), ['/']);
    assert.match(pages['/'], /No report published yet/);
  });

  test('the generated module carries the pages and the CSP their style block needs', async () => {
    const src = moduleSource({ '/': '<p>“x”  </p>' });
    const mod = await import(`data:text/javascript,${encodeURIComponent(src)}`);
    assert.equal(mod.csp, CSP);
    assert.deepEqual(mod.pages, { '/': '<p>“x”  </p>' });
  });

  test('the run’s Paperclip credentials are required', () => {
    assert.throws(
      () => paperclip({ PAPERCLIP_API_URL: 'http://x' }),
      /PAPERCLIP_API_KEY, PAPERCLIP_COMPANY_ID/,
    );
  });

  test('deploys only a clean checkout at the tip of origin/main', () => {
    const git =
      (state) =>
      (cmd, ...args) =>
        cmd === 'rev-parse'
          ? args[0] === 'HEAD'
            ? state.head
            : 'aaaaaaa1'
          : cmd === 'status'
            ? state.dirty
            : '';
    assert.doesNotThrow(() => assertMergedMain(git({ head: 'aaaaaaa1', dirty: '' })));
    assert.throws(() => assertMergedMain(git({ head: 'bbbbbbb2', dirty: '' })), /not origin\/main/);
    assert.throws(() => assertMergedMain(git({ head: 'aaaaaaa1', dirty: ' M lib/x.mjs' })), /local changes/);
  });
});
