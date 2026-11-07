// Cookie-free page counts (ADR 0007): one page view, then, when the reader leaves, one event per reading depth
// reached (25/50/75/100 % of the page's main text), each counted once per view. Nothing stored on the device, no
// identifier; the Worker (kit/worker/worker.mjs) accepts only these fields and our own paths.
(() => {
  const path = location.pathname;
  const send = (data) => navigator.sendBeacon?.('/a', JSON.stringify({ ...data, p: path }));
  const main = document.getElementById('main');
  let furthest = 0;
  let sent = 0;
  const measure = () => {
    const rect = main.getBoundingClientRect();
    const seen = (innerHeight - rect.top) / Math.max(rect.height, 1);
    furthest = Math.max(furthest, Math.min(4, Math.floor(seen * 4 + 0.001)) * 25);
  };
  const leave = () => {
    for (let d = sent + 25; d <= furthest; d += 25) send({ e: 'depth', d });
    sent = Math.max(sent, furthest);
  };
  send({ e: 'view' });
  measure();
  addEventListener('scroll', measure, { passive: true });
  addEventListener('pagehide', leave);
  document.addEventListener('visibilitychange', () => document.visibilityState === 'hidden' && leave());
})();
