// The Worker in front of every site's static assets (ADR 0007). It only runs for /go/* and /a (`run_worker_first`
// in wrangler.jsonc), plus the www. environment, which redirects everything to the bare domain.
// It records counts, never people: no IP address, user agent, referrer, identifier or cookie is read into a data
// point or logged. The privacy policy (kit/templates/legal) promises exactly that.

export const STORES = ['ios', 'android'];
export const DEPTHS = [25, 50, 75, 100];
/** A beacon is about 60 bytes; anything much bigger is not ours. */
export const MAX_BEACON_BYTES = 512;

/** The same headers as `_headers` gives the static pages, which doesn't apply to responses made here. */
const SECURITY_HEADERS = {
  'Content-Security-Policy':
    "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'X-Content-Type-Options': 'nosniff',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  'Cache-Control': 'no-store',
};

function respond(status, extra = {}) {
  return new Response(null, { status, headers: { ...SECURITY_HEADERS, ...extra } });
}

const redirect = (location, status = 302) => respond(status, { Location: location });

/** French at the root, English under /en/ (kit/lib/config.mjs). */
const langOf = (path) => (path === '/en/' || path.startsWith('/en/') ? 'en' : 'fr');

/**
 * Builds the Worker for one site. `config` is embedded by kit/build.mjs: `{ slug, stores: { ios, android },
 * paths: [every page path] }`. `env.EVENTS` is the Analytics Engine dataset binding; `env.ASSETS` the static assets.
 */
export function createWorker(config) {
  const paths = new Set(config.paths);
  const own = (path) => (typeof path === 'string' && paths.has(path) ? path : null);

  function record(env, event, path, store = '', depth = 0) {
    // index1: the site; blob1: event, blob2: page path ('' when not ours), blob3: language, blob4: store;
    // double1: reading depth.
    env.EVENTS?.writeDataPoint({
      indexes: [config.slug],
      blobs: [event, path ?? '', path ? langOf(path) : '', store],
      doubles: [depth],
    });
  }

  function storeClick(url, env) {
    const store = url.pathname.slice('/go/'.length);
    const target = STORES.includes(store) ? config.stores?.[store] : null;
    const from = own(url.searchParams.get('from'));
    const home = from && langOf(from) === 'en' ? '/en/' : '/';
    if (!target) return redirect(home);
    record(env, 'store_click', from, store);
    return redirect(target);
  }

  async function beacon(request, env, origin) {
    if (request.method !== 'POST') return respond(405, { Allow: 'POST' });
    const sender = request.headers.get('Origin');
    if (sender && sender !== origin) return respond(403);
    // A missing Content-Length is not a reason to drop the beacon: the length of the text read is checked below.
    if (Number(request.headers.get('Content-Length')) > MAX_BEACON_BYTES) return respond(413);
    const text = await request.text();
    if (text.length > MAX_BEACON_BYTES) return respond(413);
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      return respond(400);
    }
    const keys = data && typeof data === 'object' ? Object.keys(data).sort().join() : '';
    const path = own(data?.p);
    if (!path) return respond(400);
    if (data.e === 'view' && keys === 'e,p') record(env, 'page_view', path);
    else if (data.e === 'depth' && keys === 'd,e,p' && DEPTHS.includes(data.d))
      record(env, 'read_depth', path, '', data.d);
    else return respond(400);
    return respond(204);
  }

  return {
    async fetch(request, env) {
      const url = new URL(request.url);
      if (url.hostname.startsWith('www.')) {
        url.hostname = url.hostname.slice('www.'.length);
        return redirect(url.toString(), 301);
      }
      if (url.pathname.startsWith('/go/')) return storeClick(url, env);
      if (url.pathname === '/a') return beacon(request, env, url.origin);
      return env.ASSETS.fetch(request);
    },
  };
}
