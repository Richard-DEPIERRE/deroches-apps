import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, beforeEach, describe, test } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { build } from '../build.mjs';
import { storeButtons } from '../lib/render.mjs';
import { createWorker, MAX_BEACON_BYTES } from '../worker/worker.mjs';
import { wranglerConfig } from '../wrangler.mjs';

const FIXTURE = fileURLToPath(new URL('./fixture', import.meta.url));
const IDENTITY = fileURLToPath(new URL('./identity.fixture.json', import.meta.url));
const ORIGIN = 'https://exemple.test';
const IOS = 'https://apps.apple.com/fr/app/exemple/id0000000000';
const tmp = await mkdtemp(join(tmpdir(), 'site-worker-'));
after(() => rm(tmp, { recursive: true, force: true }));

/** A mocked Analytics Engine binding and static assets: no network. */
let points;
let env;
beforeEach(() => {
  points = [];
  env = {
    EVENTS: { writeDataPoint: (point) => points.push(point) },
    ASSETS: { fetch: async () => new Response('asset', { status: 200 }) },
  };
});

const worker = createWorker({
  slug: 'exemple',
  stores: { ios: IOS, android: null },
  paths: ['/', '/en/about/'],
});
const get = (path, headers) => worker.fetch(new Request(`${ORIGIN}${path}`, { headers }), env);
function beacon(body, headers = {}) {
  const text = typeof body === 'string' ? body : JSON.stringify(body);
  return worker.fetch(
    new Request(`${ORIGIN}/a`, {
      method: 'POST',
      body: text,
      headers: { 'Content-Length': String(Buffer.byteLength(text)), Origin: ORIGIN, ...headers },
    }),
    env,
  );
}

describe('the store-click redirect', () => {
  test('counts the click with the page, its language and the store, then goes to the store', async () => {
    const res = await get('/go/ios?from=%2Fen%2Fabout%2F');
    assert.equal(res.status, 302);
    assert.equal(res.headers.get('Location'), IOS);
    assert.deepEqual(points, [
      { indexes: ['exemple'], blobs: ['store_click', '/en/about/', 'en', 'ios'], doubles: [0] },
    ]);
  });

  test('never records a path that is not one of ours', async () => {
    await get('/go/ios?from=https%3A%2F%2Felsewhere.test%2F');
    assert.deepEqual(points[0].blobs, ['store_click', '', '', 'ios']);
  });

  test('sends an unknown store, or one with no URL yet, to the home page without counting', async () => {
    for (const [path, home] of [
      ['/go/android?from=/en/about/', '/en/'],
      ['/go/windows?from=/', '/'],
      ['/go/ios/extra', '/'],
    ]) {
      const res = await get(path);
      assert.equal(res.status, 302);
      assert.equal(res.headers.get('Location'), home);
    }
    assert.deepEqual(points, []);
  });

  test('records nothing about the visitor and sets the security headers itself', async () => {
    const res = await get('/go/ios?from=/', {
      'CF-Connecting-IP': '203.0.113.7',
      'User-Agent': 'Agent/1.0',
      Referer: 'https://elsewhere.test/page',
      Cookie: 'a=b',
    });
    const recorded = JSON.stringify(points);
    for (const value of ['203.0.113.7', 'Agent', 'elsewhere', 'a=b']) assert.ok(!recorded.includes(value));
    assert.equal(res.headers.get('Set-Cookie'), null);
    assert.match(res.headers.get('Content-Security-Policy'), /frame-ancestors 'none'/);
    assert.equal(res.headers.get('X-Content-Type-Options'), 'nosniff');
    assert.equal(res.headers.get('Cache-Control'), 'no-store');
  });
});

describe('the beacon', () => {
  test('records a page view and each reading depth', async () => {
    assert.equal((await beacon({ e: 'view', p: '/' })).status, 204);
    assert.equal((await beacon({ e: 'depth', p: '/en/about/', d: 50 })).status, 204);
    assert.deepEqual(points, [
      { indexes: ['exemple'], blobs: ['page_view', '/', 'fr', ''], doubles: [0] },
      { indexes: ['exemple'], blobs: ['read_depth', '/en/about/', 'en', ''], doubles: [50] },
    ]);
  });

  test('accepts only known fields, known depths and our own paths', async () => {
    const bad = [
      { e: 'view', p: '/nope/' },
      { e: 'view', p: '/', id: 'abc' },
      { e: 'depth', p: '/', d: 30 },
      { e: 'depth', p: '/' },
      { e: 'click', p: '/' },
      [1, 2],
      null,
      'not json',
    ];
    for (const body of bad) assert.equal((await beacon(body)).status, 400, JSON.stringify(body));
    assert.deepEqual(points, []);
  });

  test('caps the payload, refuses other origins and other methods', async () => {
    const big = JSON.stringify({ e: 'view', p: '/', x: 'x'.repeat(MAX_BEACON_BYTES) });
    assert.equal((await beacon(big)).status, 413);
    assert.equal((await beacon({ e: 'view', p: '/' }, { Origin: 'https://elsewhere.test' })).status, 403);
    assert.equal((await get('/a')).status, 405);
    assert.deepEqual(points, []);
  });
});

test('redirects www. to the bare domain and leaves everything else to the static assets', async () => {
  const res = await worker.fetch(new Request('https://www.exemple.test/guides/x/?q=1'), env);
  assert.equal(res.status, 301);
  assert.equal(res.headers.get('Location'), 'https://exemple.test/guides/x/?q=1');
  assert.equal(await (await get('/missing/')).text(), 'asset');
});

describe('a built site', () => {
  test("embeds the site's slug, stores and page paths in the Worker entry", async () => {
    const out = join(tmp, 'dist');
    await build(FIXTURE, out, { identityFile: IDENTITY });
    const { default: built } = await import(pathToFileURL(join(out, '_worker', 'index.mjs')));
    const body = '{"e":"view","p":"/a-propos/"}';
    const headers = { 'Content-Length': String(body.length) };
    await built.fetch(new Request(`${ORIGIN}/a`, { method: 'POST', body, headers }), env);
    assert.equal(
      (await built.fetch(new Request(`${ORIGIN}/go/ios?from=/`), env)).headers.get('Location'),
      '/',
    );
    assert.deepEqual(points, [
      { indexes: ['exemple'], blobs: ['page_view', '/a-propos/', 'fr', ''], doubles: [0] },
    ]);
    assert.equal(await readFile(join(out, '.assetsignore'), 'utf8'), '_worker\n');
    const html = await readFile(join(out, 'index.html'), 'utf8');
    assert.match(html, /<script src="\/assets\/a\.[0-9a-f]{10}\.js" defer><\/script>/);
    assert.doesNotMatch(await readFile(join(out, '404.html'), 'utf8'), /<script src/);
    assert.match(await readFile(join(out, 'robots.txt'), 'utf8'), /Disallow: \/go\/\nDisallow: \/a\$\n/);
  });
});

test('the deploy config is the kit template with the slug and domain', async () => {
  const config = await wranglerConfig({ slug: 'exemple', domain: 'exemple.test' });
  assert.doesNotMatch(config, /\{\{/);
  for (const line of [
    '"name": "site-exemple"',
    '"not_found_handling": "404-page"',
    '"command": "node ../kit/build.mjs . --production"',
    '{ "pattern": "exemple.test", "custom_domain": true }',
    '{ "pattern": "www.exemple.test", "custom_domain": true }',
    '"observability": { "enabled": false }',
  ])
    assert.ok(config.includes(line), line);
});

test('store buttons link to the counted redirect, in the page language, and only once the app is live', () => {
  const page = { lang: 'en', path: '/en/guides/x/' };
  const live = { status: 'live', stores: { ios: IOS, android: null } };
  assert.equal(
    storeButtons(page, live),
    '<p class="store-buttons"><a class="store-button" rel="nofollow" href="/go/ios?from=%2Fen%2Fguides%2Fx%2F">' +
      'Download on the App Store</a></p>\n',
  );
  assert.match(storeButtons({ ...page, lang: 'fr' }, live), />Télécharger dans l’App Store</);
  assert.equal(storeButtons(page, { ...live, status: 'coming-soon' }), '');
});
