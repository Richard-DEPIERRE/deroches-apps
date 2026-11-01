const ENTITIES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

export function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (c) => ENTITIES[c]);
}

/** JSON for a <script type="application/ld+json"> block, safe against a closing </script> in the data. */
export function jsonForScript(value) {
  return JSON.stringify(value).replace(/</g, '\\u003c');
}
