// The Worker's request handling (ADR 0004, decision 5). It fails closed: a page is served only when Cloudflare
// Access authenticated the request, which is when `ctx.access` is set. Without it the answer is 403 with no report
// content, so the pages stay private even if Access is turned off by mistake.
// Checked 2026-11-01, developers.cloudflare.com/workers/configuration/cloudflare-access/: "ctx.access is undefined
// if Access did not authenticate the request", and Static Assets don't pass ctx.access to the Worker (so the pages
// are a bundled module, never assets). No import here: the Worker needs no Node compatibility.

export const ROBOTS = 'User-agent: *\nDisallow: /\n';

/** Sent with every response, the 403 included. `csp` is the pages' own policy (`lib/html.mjs`). */
export const headers = (csp) => ({
  'Content-Security-Policy': `${csp}; frame-ancestors 'none'`,
  'X-Robots-Tag': 'noindex, nofollow',
  'Cache-Control': 'private, no-store',
  'Referrer-Policy': 'no-referrer',
  'X-Content-Type-Options': 'nosniff',
});

/**
 * One request. `site` is the generated module: `pages` maps a path (`/`, `/research/<approval id>`,
 * `/epics/<approval id>`) to its HTML, `csp` is the pages' Content-Security-Policy.
 */
export function serve(request, ctx, site) {
  const head = request.method === 'HEAD';
  const reply = (status, body, type, extra = {}) =>
    new Response(head ? null : body, {
      status,
      headers: { ...headers(site.csp), 'Content-Type': `${type}; charset=utf-8`, ...extra },
    });
  if (request.method !== 'GET' && !head)
    return reply(405, 'Method not allowed.\n', 'text/plain', { Allow: 'GET, HEAD' });
  const { pathname } = new URL(request.url);
  // robots.txt carries no report content; it is the one thing served without Access.
  if (pathname === '/robots.txt') return reply(200, ROBOTS, 'text/plain');
  if (!ctx?.access) return reply(403, 'Access required.\n', 'text/plain');
  if (!Object.hasOwn(site.pages, pathname)) return reply(404, 'Not found.\n', 'text/plain');
  return reply(200, site.pages[pathname], 'text/html');
}
