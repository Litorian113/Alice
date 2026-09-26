import { trimText } from '../companion-mcp/card.js';

export const MAX_REVIEW_LENGTH = 24_000;

// Keep the original option IDs only in the adapter. Alice's stable IDs describe
// one-time permission; ACP allow_always is tool-wide and is NOT approve_for_task.
export function permissionCard(params, tool, id, timeoutS = 540) {
  if (!tool?.toolCallId || !Array.isArray(params.options)) throw new Error('Incomplete permission request');
  const allow = params.options.find(o => o.kind === 'allow_once' && typeof o.optionId === 'string');
  const reject = params.options.find(o => o.kind === 'reject_once' && typeof o.optionId === 'string');
  if (!allow || !reject || allow.optionId === reject.optionId) throw new Error('Bob did not offer one-time allow and reject options');
  const parts = [];
  if (tool.rawInput != null) parts.push(typeof tool.rawInput === 'string' ? tool.rawInput : JSON.stringify(tool.rawInput, null, 2));
  for (const item of tool.content || []) {
    if (item.type === 'diff') parts.push(`File: ${item.path}\nBefore:\n${item.oldText ?? '(new file)'}\nAfter:\n${item.newText}`);
    else if (item.type === 'content' && item.content?.type === 'text') parts.push(item.content.text);
    else throw new Error('This request contains content that Alice cannot display completely');
  }
  // A title alone may hide arguments. Leave requests without complete tool input
  // on the PC rather than giving mobile approval to an unspecified operation.
  if (!parts.length) throw new Error('Bob supplied no reviewable tool input');
  const review = parts.join('\n\n');
  if (review.length > MAX_REVIEW_LENGTH || Buffer.byteLength(JSON.stringify(review)) > 30_000) throw new Error('Request is too large for phone review (24,000 characters / 30 KB)');
  const options = [
    { id: 'approve_once', label: 'Approve once', detail: 'Allow this operation once', recommended: false },
    { id: 'reject', label: 'Reject', detail: 'Do not run this operation', recommended: false },
  ];
  return {
    card: {
      type: 'decision_request', id, kind: 'approval', title: trimText(tool.title || 'Bob needs your approval', 60),
      context: 'Review the complete operation below. Your answer goes directly to the PC chat.',
      command: review, explanations: [], risk: ['delete', 'move'].includes(tool.kind) ? 'high' : 'medium',
      options, allowFreeText: false, expiresAt: new Date(Date.now() + timeoutS * 1000).toISOString(),
      source: 'acp',
    },
    optionMap: new Map([['approve_once', allow.optionId], ['reject', reject.optionId]]),
  };
}

export class Permissions {
  constructor(companion, agent, { changed = () => {}, timeoutS = 540 } = {}) {
    this.companion = companion; this.agent = agent; this.changed = changed; this.timeoutS = timeoutS;
    this.pending = new Map();
  }

  async request(message, tool, sessionId) {
    if (!sessionId || message.params?.sessionId !== sessionId) return this.agent.respond(message.id, { outcome: { outcome: 'cancelled' } });
    const id = this.companion.nextId('acp');
    let mapped;
    try { mapped = permissionCard(message.params, tool, id, this.timeoutS); }
    catch (error) {
      this.changed({ type: 'permission_error', message: error.message, tool });
      return this.agent.respond(message.id, { outcome: { outcome: 'cancelled' } });
    }
    const controller = new AbortController();
    const snapshot = [...this.companion.pending.values()].map(e => e.card).concat(mapped.card);
    if (Buffer.byteLength(JSON.stringify({ type: 'sync', decisions: snapshot })) > 60_000) {
      this.changed({ type: 'permission_error', message: 'Too many large approvals are pending. Ask Bob to request one operation at a time.', tool });
      return this.agent.respond(message.id, { outcome: { outcome: 'cancelled' } });
    }
    const entry = { ...mapped, controller, message, tool, replied: false };
    this.pending.set(id, entry);
    const apply = async result => {
      const optionId = entry.optionMap.get(result.option?.id);
      if (!optionId || controller.signal.aborted || this.pending.get(id) !== entry || entry.replied) throw new Error('Stale permission');
      entry.replied = true;
      await this.agent.respond(message.id, { outcome: { outcome: 'selected', optionId } });
    };
    const decision = this.companion.askDecision(entry.card, { signal: controller.signal, apply });
    this.changed({ type: 'permission', card: entry.card });
    const result = await decision;
    this.pending.delete(id);
    if (result.expired && !entry.replied) {
      entry.replied = true;
      await this.agent.respond(message.id, { outcome: { outcome: 'cancelled' } }).catch(() => {});
    }
    this.changed({ type: 'permission_resolved', id, optionId: result.option?.id, expired: result.expired });
  }

  answer(id, optionId) {
    const entry = this.pending.get(id);
    if (!entry || entry.replied || !entry.optionMap.has(optionId)) throw new Error('This permission is no longer available');
    this.companion.resolveDecision({ id, optionId, via: 'desktop' });
  }
  cancel() { for (const entry of this.pending.values()) entry.controller.abort(); }

  toolChanged(tool) {
    for (const entry of this.pending.values()) {
      if (entry.tool.toolCallId !== tool.toolCallId || entry.replied) continue;
      if (['completed', 'failed'].includes(tool.status)
        || JSON.stringify(entry.tool.rawInput) !== JSON.stringify(tool.rawInput)
        || JSON.stringify(entry.tool.content) !== JSON.stringify(tool.content)) entry.controller.abort();
    }
  }
}
