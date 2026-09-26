// Decision card contract: every card that leaves the MCP server is already
// reduced to these limits, so the app never has to handle a wall of text.
// See docs/PROTOCOL.md.

export const LIMITS = {
  title: 60,
  context: 140,
  contextSentences: 2,
  label: 25,
  detail: 60,
  minOptions: 2,
  maxOptions: 4,
  notify: 200,
  freeText: 500,
};

export const RISKS = ['low', 'medium', 'high'];
export const LEVELS = ['info', 'success', 'error'];

const OPTION_IDS = ['a', 'b', 'c', 'd'];

// Collapse whitespace (newlines, tabs, runs of spaces) into single spaces.
export function clean(text) {
  return String(text ?? '')
    .replace(/\s+/g, ' ')
    .trim();
}

// Trim to `max` characters, cutting at a word boundary when one is close,
// and marking the cut with an ellipsis. Result length is always <= max.
export function trimText(text, max) {
  const s = clean(text);
  if (s.length <= max) return s;
  const hard = s.slice(0, max - 1);
  const lastSpace = hard.lastIndexOf(' ');
  const cut = lastSpace >= max * 0.6 ? hard.slice(0, lastSpace) : hard;
  return cut.replace(/[\s,;:.\-–—]+$/, '') + '…';
}

// Keep at most `n` sentences. A sentence ends at . ! or ? followed by a space.
export function firstSentences(text, n) {
  const s = clean(text);
  const parts = s.split(/(?<=[.!?])\s+(?=[A-Z0-9"'(])/);
  return parts.slice(0, n).join(' ');
}

// Reduce raw ask_decision input to a card that satisfies the contract.
// Throws a CardError with a Bob-readable message if the input can't be salvaged.
export function normalizeCard(input, { id, now = Date.now(), timeoutS = 120 } = {}) {
  const title = trimText(input.title, LIMITS.title);
  if (!title) throw new CardError('title is required');

  const context = trimText(firstSentences(input.context, LIMITS.contextSentences), LIMITS.context);

  let options = (Array.isArray(input.options) ? input.options : [])
    .map((o) => ({
      label: trimText(o?.label, LIMITS.label),
      detail: trimText(o?.detail, LIMITS.detail),
      recommended: o?.recommended === true,
    }))
    .filter((o) => o.label);

  // Drop duplicate labels (case-insensitive) — two identical buttons are useless.
  const seen = new Set();
  options = options.filter((o) => {
    const key = o.label.toLowerCase();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  if (options.length < LIMITS.minOptions) {
    throw new CardError(
      `ask_decision needs ${LIMITS.minOptions}-${LIMITS.maxOptions} options with non-empty labels; got ${options.length}`,
    );
  }

  // At most one recommended: keep the first one marked.
  let recIndex = options.findIndex((o) => o.recommended);
  options.forEach((o, i) => (o.recommended = i === recIndex));

  // Too many options: keep the recommended one plus the first others, in original order.
  if (options.length > LIMITS.maxOptions) {
    const keep = new Set(options.map((_, i) => i).filter((i) => i !== recIndex).slice(0, recIndex >= 0 ? LIMITS.maxOptions - 1 : LIMITS.maxOptions));
    if (recIndex >= 0) keep.add(recIndex);
    options = options.filter((_, i) => keep.has(i));
  }

  const risk = RISKS.includes(input.risk) ? input.risk : 'medium';

  return {
    type: 'decision_request',
    id,
    title,
    context,
    risk,
    options: options.map((o, i) => {
      const out = { id: OPTION_IDS[i], label: o.label };
      if (o.detail) out.detail = o.detail;
      if (o.recommended) out.recommended = true;
      return out;
    }),
    allowFreeText: input.allow_free_text !== false,
    expiresAt: new Date(now + timeoutS * 1000).toISOString(),
  };
}

export class CardError extends Error {}
