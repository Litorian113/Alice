import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import WebSocket from 'ws';
import { Companion } from '../companion-mcp/companion.js';
import { createRelay } from '../relay/server.js';

test('instruction retry is idempotent, including after Bob consumed it', () => {
  const companion = new Companion({ relayUrl: 'ws://localhost' });
  const replies = [];
  companion.send = (message) => replies.push(message);
  companion.handle({ type: 'instruction', id: 'input-1', text: 'Check sign-in' });
  assert.equal(companion.popInstruction().text, 'Check sign-in');
  companion.handle({ type: 'instruction', id: 'input-1', text: 'Check sign-in' });
  assert.equal(companion.popInstruction(), null);
  assert.equal(replies.at(-1).type, 'ack');
  companion.handle({ type: 'instruction', id: 'input-1', text: 'Different input' });
  assert.equal(replies.at(-1).type, 'error');
  companion.handle({ type: 'instruction', id: 'input-2', text: 'x'.repeat(501) });
  assert.equal(replies.at(-1).type, 'error');
  assert.equal(companion.popInstruction(), null);
  assert.notEqual(companion.nextId('d'), new Companion({ relayUrl: 'ws://localhost' }).nextId('d'));
});

test('expired approval is refused even before its timer runs', () => {
  const companion = new Companion({ relayUrl: 'ws://localhost' });
  const replies = [];
  companion.send = (message) => replies.push(message);
  let result;
  companion.pending.set('old', { card: { expiresAt: new Date(0).toISOString() }, resolve: (r) => { result = r; } });
  companion.resolveDecision({ id: 'old', optionId: 'approve_once' });
  assert.deepEqual(result, { expired: 'timeout' });
  assert.equal(replies.at(-1).type, 'decision_expired');
});

function client(url, hello) {
  const socket = new WebSocket(url);
  const inbox = [];
  socket.on('message', (raw) => inbox.push(JSON.parse(raw)));
  socket.on('open', () => socket.send(JSON.stringify(hello)));
  return { socket, inbox, send: (m) => socket.send(JSON.stringify(m)), async next(type) {
    for (let i = 0; i < 300; i++) {
      const index = inbox.findIndex((m) => m.type === type);
      if (index >= 0) return inbox.splice(index, 1)[0];
      await new Promise((r) => setTimeout(r, 10));
    }
    throw new Error(`No ${type} received`);
  } };
}

test('native phone: token only to requester, deduplicated push opens Alice, unregister works', async () => {
  const pushes = [];
  let tokenCalls = 0;
  const relay = createRelay({ port: 0, host: '127.0.0.1', log: () => {}, publicUrl: 'https://relay.example',
    assemblyAIKey: 'server-test-key', fetchImpl: async (url, options) => {
      if (url.includes('/v3/token')) {
        tokenCalls++;
        assert.equal(options.headers.authorization, 'server-test-key');
        assert.match(url, /max_session_duration_seconds=180/);
        return { ok: true, json: async () => ({ token: 'temporary-test-token' }) };
      }
      pushes.push(JSON.parse(options.body));
      return { ok: true };
    } });
  const port = await relay.listen();
  const url = `ws://127.0.0.1:${port}`;
  const identity = { sessionId: 'mobile-test', secret: 's'.repeat(43) };
  const bob = client(url, { type: 'hello', role: 'bob', ...identity });
  let phone;
  try {
    await bob.next('paired');
    phone = client(url, { type: 'hello', role: 'phone', ...identity,
      pushTopic: 'alice-test-topic', pushClick: 'bobcompanion://open' });
    assert.equal((await phone.next('paired')).voiceAvailable, true);
    phone.send({ type: 'voice_session_request', id: 'token-1' });
    const token = await phone.next('voice_session');
    assert.equal(token.token, 'temporary-test-token');
    assert.equal(token.websocketURL, 'wss://streaming.eu.assemblyai.com/v3/ws');
    assert.equal(bob.inbox.some((m) => m.type.startsWith('voice')), false);
    phone.send({ type: 'voice_session_request', id: 'token-2' });
    assert.equal((await phone.next('error')).error, 'voice rate limited');
    assert.equal(tokenCalls, 1);
    const card = { type: 'decision_request', id: 'd-native', title: 'Choose', risk: 'low', options: [{ id: 'a', label: 'Continue' }] };
    bob.send(card);
    await phone.next('decision_request');
    bob.send(card);
    await phone.next('decision_request');
    assert.equal(pushes.length, 1);
    assert.equal(pushes[0].click, 'bobcompanion://open');
    assert.equal(pushes[0].actions, undefined);
    phone.send({ type: 'push_unregister', topic: 'alice-test-topic' });
    phone.send({ type: 'instruction', id: 'ordered-marker', text: 'marker' });
    await bob.next('instruction');
    bob.send({ ...card, id: 'after-unregister' });
    await phone.next('decision_request');
    assert.equal(pushes.length, 1);
  } finally {
    bob.socket.terminate(); phone?.socket.terminate(); await relay.close();
  }
});
