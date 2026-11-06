// The `deroches-reports` Worker (ADR 0004). The pages come from `generated/pages.mjs`, which `build.mjs` writes at
// publish time from Paperclip; it is never committed. Serving and the fail-closed Access check: `lib/serve.mjs`.
import * as site from './generated/pages.mjs';
import { serve } from './lib/serve.mjs';

export default {
  fetch: (request, _env, ctx) => serve(request, ctx, site),
};
