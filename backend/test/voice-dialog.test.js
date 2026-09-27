import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Companion } from '../companion-mcp/companion.js';
import { normalizeCard, normalizeApproval } from '../companion-mcp/card.js';

function setup() {
  const companion = new Companion({ relayUrl: 'ws://localhost' });
  const sent = [];
  companion.send = msg => { sent.push(msg); return true; };
  return { companion, sent };
}
function dialog(id = 'dialog') {
  return normalizeCard({ title: 'Result', reply: 'Updated the document.\n\nWhat next?',
    accept_voice: true, options: [{ label: 'Review' }, { label: 'Stop here' }] }, { id });
}

test('voice replaces the open choice once; retry and stale taps cannot repeat it', async () => {
  const { companion: c, sent } = setup();
  const result = c.askDecision(dialog());
  const input = { type: 'instruction', id: 'voice-1', text: 'Add examples', source: 'voice' };
  c.handle(input);
  assert.equal((await result).instruction.text, 'Add examples');
  assert.equal(c.pending.size, 0);
  assert.equal(c.instructions.length, 0);
  assert.ok(sent.some(m => m.type === 'ack' && m.id === input.id));
  assert.ok(sent.some(m => m.type === 'decision_expired' && m.reason === 'voice_input'));
  c.handle(input);
  assert.equal(c.instructions.length, 0);
  c.resolveDecision({ id: 'dialog', optionId: 'a' });
  assert.equal(sent.at(-1).type, 'decision_expired');
  assert.equal(c.taskApprovals.size, 0);
});

test('speech during command approval queues without approving; next voice dialog consumes it', async () => {
  const { companion: c } = setup();
  const approval = normalizeApproval({ title: 'Commit', command: 'git commit -m test' }, { id: 'approval' });
  const result = c.askDecision(approval);
  c.handle({ type: 'instruction', id: 'voice', text: 'Add examples first', source: 'voice' });
  assert.equal(c.pending.size, 1);
  assert.equal(c.instructions.length, 1);
  c.resolveDecision({ id: 'approval', optionId: 'reject' });
  assert.equal((await result).option.id, 'reject');
  assert.equal((await c.askDecision(dialog())).instruction.text, 'Add examples first');
  assert.equal(c.taskApprovals.size, 0);
});

test('normal instructions do not wake voice dialogs, a tapped option still works', async () => {
  const { companion: c } = setup();
  const result = c.askDecision(dialog());
  c.handle({ type: 'instruction', id: 'typed', text: 'Legacy input' });
  assert.equal(c.pending.size, 1);
  c.resolveDecision({ id: 'dialog', optionId: 'b' });
  assert.equal((await result).option.label, 'Stop here');
  assert.equal(c.popInstruction().text, 'Legacy input');
});

test('a late voice after a tap belongs to the next dialog, not the answered card', async () => {
  const { companion: c } = setup();
  const result = c.askDecision(dialog());
  c.resolveDecision({ id: 'dialog', optionId: 'a' });
  c.handle({ type: 'instruction', id: 'late', text: 'Also explain it', source: 'voice' });
  assert.equal((await result).option.id, 'a');
  assert.equal((await c.askDecision(dialog('next'))).instruction.id, 'late');
});

test('timeout, cancellation and shutdown release waits without selecting an action', async () => {
  const { companion: c } = setup();
  const expired = { ...dialog(), expiresAt: new Date(Date.now() + 20).toISOString() };
  assert.equal((await c.askDecision(expired)).expired, 'timeout');
  const controller = new AbortController();
  const cancelled = c.askDecision(dialog('cancel'), { signal: controller.signal });
  controller.abort();
  assert.equal((await cancelled).expired, 'cancelled');
  const stopped = c.askDecision(dialog('stop'));
  c.stop();
  assert.equal((await stopped).expired, 'cancelled');
  assert.equal(c.pending.size, 0);
});

test('reply preserves paragraphs, rejects oversized text, and survives reconnect snapshots', () => {
  const { companion: c, sent } = setup();
  const card = dialog();
  assert.equal(card.reply, 'Updated the document.\n\nWhat next?');
  assert.throws(() => normalizeCard({ ...card, reply: 'x'.repeat(4001) }), /reply/);
  const wait = c.askDecision(card);
  c.handle({ type: 'paired', phones: 1 });
  assert.deepEqual(sent.find(m => m.type === 'sync').decisions[0], card);
  c.stop();
  return wait;
});

test('standby keeps the last result, clears task approvals and resumes once on new voice', async () => {
  const { companion: c, sent } = setup();
  c.connected = true; c.everPaired = true;
  c.approveForTask('git commit -m example');
  const wait = c.waitForVoice({ timeoutMs: 1000 });
  assert.equal(c.taskApprovals.size, 0);
  assert.ok(sent.at(-1).voiceReadyUntil);
  assert.equal(sent.some(m => m.type === 'notify' || m.type === 'decision_request'), false);
  c.handle({ type: 'paired', phones: 1 });
  assert.ok(sent.at(-1).voiceReadyUntil, 'reconnecting phone sees the active listener');
  const input = { type: 'instruction', id: 'next-job', source: 'voice', text: 'Please commit the changes.' };
  c.handle(input);
  assert.equal((await wait).instruction.text, input.text);
  assert.equal(c.instructionWaiter, null);
  assert.equal(sent.at(-1).voiceReadyUntil, null);
  c.handle(input);
  assert.equal(c.instructions.length, 0, 'retry cannot start work twice');
});

test('standby guards offline/unpaired/concurrent waits and never steals an approval response', async () => {
  const { companion: c } = setup();
  assert.equal((await c.waitForVoice()).reason, 'disconnected');
  c.connected = true;
  assert.equal((await c.waitForVoice()).reason, 'disconnected');
  c.everPaired = true;
  const approval = normalizeApproval({ title: 'Commit', command: 'git commit -m example' }, { id: 'approval' });
  const pending = c.askDecision(approval);
  assert.equal((await c.waitForVoice()).reason, 'busy');
  c.resolveDecision({ id: approval.id, optionId: 'reject' });
  assert.equal((await pending).option.id, 'reject');
  const controller = new AbortController();
  const wait = c.waitForVoice({ signal: controller.signal });
  assert.equal((await c.waitForVoice()).reason, 'busy');
  assert.equal((await c.askDecision(dialog())).expired, 'busy');
  controller.abort();
  assert.equal((await wait).reason, 'cancelled');
});

test('standby has bounded timeout and cancellation, ignores legacy input and accepts queued voice', async () => {
  const { companion: c, sent } = setup();
  c.connected = true; c.everPaired = true;
  c.handle({ type: 'instruction', id: 'legacy', text: 'Queued text' });
  assert.equal((await c.waitForVoice({ timeoutMs: 20 })).reason, 'timeout');
  assert.equal(sent.at(-1).voiceReadyUntil, null);
  c.handle({ type: 'instruction', id: 'queued-voice', source: 'voice', text: 'New work' });
  assert.equal((await c.waitForVoice()).instruction.id, 'queued-voice');
  assert.equal(c.popInstruction().id, 'legacy');
  const wait = c.waitForVoice();
  c.stop();
  assert.equal((await wait).reason, 'cancelled');
  assert.equal(c.instructionWaiter, null);
});
