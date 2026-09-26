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
  command: 500,
  explanations: 6,
  explanationPart: 40,
  explanationMeaning: 100,
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

// Every card has the same shape, whatever its kind, and every key is always present
// (null / "" / false / [] when unused) so strict decoders (Swift Codable) never
// hit a missing key:
//
//   kind "choice"    next-step options, ids a-d            (ask_decision)
//   kind "approval"  run this exact command? fixed ids     (request_approval)

// Choice card from raw ask_decision input.
// Throws a CardError with a Bob-readable message if the input can't be salvaged.
export function normalizeCard(input, { id, now = Date.now(), timeoutS = 120 } = {}) {
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

  return baseCard(input, {
    id,
    kind: 'choice',
    command: input.command == null || !String(input.command).trim() ? null : checkCommand(input.command),
    options: options.map((o, i) => ({ id: OPTION_IDS[i], ...o })),
    allowFreeText: input.allow_free_text !== false,
    expiresAt: expiry(now, timeoutS),
  });
}

// Approval options: ids are fixed so the app can style them (approve / reject).
export const APPROVAL_OPTIONS = [
  { id: 'approve_once', label: 'Approve once', detail: 'Just this time', recommended: false },
  { id: 'approve_for_task', label: 'Approve for task', detail: 'Allow this command for this task', recommended: false },
  { id: 'reject', label: 'Reject', detail: "Don't run it", recommended: false },
];

// Approval card from raw request_approval input. The command is shown and approved
// verbatim — it is never trimmed, because the developer must approve exactly what runs.
export function normalizeApproval(input, { id, now = Date.now(), timeoutS = 120 } = {}) {
  return baseCard(input, {
    id,
    kind: 'approval',
    command: checkCommand(input.command),
    options: APPROVAL_OPTIONS.map((o) => ({ ...o })),
    allowFreeText: input.allow_free_text === true,
    expiresAt: expiry(now, timeoutS),
  });
}

function baseCard(input, { id, kind, command, options, allowFreeText, expiresAt }) {
  const title = trimText(input.title, LIMITS.title);
  if (!title) throw new CardError('title is required');
  return {
    type: 'decision_request',
    id,
    kind,
    title,
    context: trimText(firstSentences(input.context, LIMITS.contextSentences), LIMITS.context),
    command,
    explanations: normalizeExplanations(input.explanations),
    risk: RISKS.includes(input.risk) ? input.risk : 'medium',
    options,
    allowFreeText,
    expiresAt,
  };
}

// Commands are approved verbatim: reject what can't be shown in full instead of trimming.
export function checkCommand(command) {
  const s = String(command ?? '').trim();
  if (!s) throw new CardError('command is required');
  if (s.length > LIMITS.command) {
    throw new CardError(`command is ${s.length} chars; the limit is ${LIMITS.command}. Split it into smaller commands or a script`);
  }
  return s;
}

// Optional "what each part does" list for the app's detail sheet.
function normalizeExplanations(list) {
  if (!Array.isArray(list)) return [];
  return list
    .map((e) => ({ part: trimText(e?.part, LIMITS.explanationPart), meaning: trimText(e?.meaning, LIMITS.explanationMeaning) }))
    .filter((e) => e.part && e.meaning)
    .slice(0, LIMITS.explanations);
}

// ISO 8601 without fractional seconds: Swift's .iso8601 decoding rejects milliseconds.
// Rounded up to the next whole second, because the wait timer runs until expiresAt:
// truncating would cut up to 999 ms off the timeout.
function expiry(now, timeoutS) {
  const ms = Math.ceil((now + timeoutS * 1000) / 1000) * 1000;
  return new Date(ms).toISOString().replace(/\.000Z$/, 'Z');
}

// Canonical form used to match "approved for this task" commands.
export function commandKey(command) {
  return String(command ?? '').trim().replace(/\s+/g, ' ');
}

export class CardError extends Error {}
