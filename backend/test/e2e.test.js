// End to end: real relay + real MCP server (spawned over stdio like Bob does)
// + a fake phone over WebSocket + a fake ntfy server.

import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import WebSocket from 'ws';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { createRelay } from '../relay/server.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');

let relay, relayPort, ntfy, ntfyPort, client;
const pushes = [];
const relayLog = [];

before(async () => {
  ntfy = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      pushes.push(JSON.parse(body));
      res.end('{}');
    });
  });
  await new Promise((r) => ntfy.listen(0, '0.0.0.0', r));
  ntfyPort = ntfy.address().port;

  relay = createRelay({
    port: 0,
    ntfyUrl: `http://localhost:${ntfyPort}`,
    publicUrl: 'http://placeholder', // replaced below once we know the port
    // A cold Node/MCP start can take seconds while Swift is typechecking.
    // Keep the restart test independent of host load (production uses 30 s).
    roomGraceMs: 10_000,
    log: (...a) => relayLog.push(a.join(' ')),
  });
  relayPort = await relay.listen();
});

after(async () => {
  await client?.close();
  await relay?.close();
  ntfy?.close();
});

async function startMcp(extraEnv = {}) {
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [path.join(root, 'companion-mcp/index.js')],
    env: { ...process.env, RELAY_URL: `ws://localhost:${relayPort}`, ...extraEnv },
    stderr: 'pipe',
  });
  const c = new Client({ name: 'test-bob', version: '1.0.0' });
  await c.connect(transport);
  return c;
}

const call = async (name, args = {}, opts) => (await client.callTool({ name, arguments: args }, undefined, opts)).content[0].text;

function phone({ sessionId, secret, pushTopic }) {
  const ws = new WebSocket(`ws://localhost:${relayPort}`);
  const inbox = [];
  const waiters = [];
  ws.on('message', (raw) => {
    const msg = JSON.parse(raw.toString());
    inbox.push(msg);
    for (const w of [...waiters]) if (w.pred(msg)) (waiters.splice(waiters.indexOf(w), 1), w.resolve(msg));
  });
  ws.on('open', () => ws.send(JSON.stringify({ type: 'hello', role: 'phone', sessionId, secret, pushTopic })));
  const closed = new Promise((r) => ws.on('close', (code) => r(code)));
  return {
    ws,
    inbox,
    closed,
    send: (m) => ws.send(JSON.stringify(m)),
    next(type, pred = () => true, ms = 5000) {
      const hit = inbox.find((m) => m.type === type && pred(m) && !m._seen);
      if (hit) return Promise.resolve(((hit._seen = true), hit));
      return new Promise((resolve, reject) => {
        const t = setTimeout(() => reject(new Error(`timeout waiting for ${type}`)), ms);
        waiters.push({ pred: (m) => m.type === type && pred(m), resolve: (m) => (clearTimeout(t), (m._seen = true), resolve(m)) });
      });
    },
    close: () => ws.close(),
  };
}

async function until(fn, ms = 3000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (await fn()) return;
    await new Promise((r) => setTimeout(r, 50));
  }
  throw new Error('condition not met');
}

let creds;
let p1;

test('MCP server lists the five tools', async () => {
  client = await startMcp();
  const { tools } = await client.listTools();
  assert.deepEqual(tools.map((t) => t.name).sort(), ['ask_decision', 'get_instruction', 'notify', 'pair_phone', 'request_approval']);
});

test('before pairing: notify and ask_decision return immediately', async () => {
  assert.equal(await call('notify', { message: 'hi' }), 'no phone paired');
  const r = await call('ask_decision', { title: 't', options: [{ label: 'a' }, { label: 'b' }] });
  assert.match(r, /^no phone paired, proceed conservatively/);
});

test('pair_phone returns link, QR and status', async () => {
  await until(async () => /waiting for phone/.test(await call('pair_phone')));
  const out = await call('pair_phone');
  const link = out.match(/App link: (\S+)/)[1];
  const u = new URL(link);
  assert.equal(u.protocol, 'bobcompanion:');
  creds = { sessionId: u.searchParams.get('s'), secret: u.searchParams.get('k') };
  assert.equal(u.searchParams.get('r'), `ws://localhost:${relayPort}`);
  assert.ok(creds.secret.length >= 43);
  assert.match(out, /Web link \(dev phone page\): http:\/\/localhost:\d+\/#s=/);
  assert.match(out, /```\n[▄▀█ ]+/);
});

test('wrong secret is rejected', async () => {
  const bad = phone({ sessionId: creds.sessionId, secret: 'x'.repeat(43) });
  const err = await bad.next('error');
  assert.match(err.error, /wrong secret/);
  assert.equal(await bad.closed, 4003);
  const unknown = phone({ sessionId: 'nosuchsession', secret: creds.secret });
  assert.equal(await unknown.closed, 4004);
});

test('phone pairs; both sides see it', async () => {
  p1 = phone({ ...creds, pushTopic: 'test-topic-123' });
  const paired = await p1.next('paired');
  assert.equal(paired.bobOnline, true);
  await until(async () => /phone connected \(1\)/.test(await call('pair_phone')));
});

test('notify reaches phone and ntfy', async () => {
  pushes.length = 0;
  assert.equal(await call('notify', { message: 'Build green', level: 'success' }), 'sent');
  const n = await p1.next('notify');
  assert.equal(n.message, 'Build green');
  assert.equal(n.level, 'success');
  await until(() => pushes.length === 1);
  assert.equal(pushes[0].topic, 'test-topic-123');
  assert.equal(pushes[0].message, 'Build green');
});

test('ask_decision: card is trimmed, phone answer unblocks Bob', async () => {
  pushes.length = 0;
  const pending = call('ask_decision', {
    title: 'Refactor done, 3 tests failing, and here is a lot more text nobody needs',
    context: 'Auth module refactored. 3 of 48 tests fail on outdated mocks. Also a third sentence.',
    risk: 'low',
    options: [
      { label: 'Fix tests', detail: 'Update mocks, then rerun', recommended: true },
      { label: 'Revert the whole refactor right now please', detail: 'Back to last green commit' },
      { label: 'Pause' },
    ],
  });
  const card = await p1.next('decision_request');
  assert.ok(card.title.length <= 60);
  assert.equal(card.context, 'Auth module refactored. 3 of 48 tests fail on outdated mocks.');
  assert.equal(card.options.length, 3);
  assert.ok(card.options[1].label.length <= 25);
  assert.ok(Date.parse(card.expiresAt) > Date.now() + 100_000);

  await until(() => pushes.length === 1);
  assert.equal(pushes[0].title, card.title);
  assert.equal(pushes[0].actions.length, 3);
  assert.match(pushes[0].actions[0].label, /^★ Fix tests/);

  p1.send({ type: 'decision_response', id: card.id, optionId: 'b', text: 'but keep the new types' });
  const res = await pending;
  assert.match(res, /chose \[b\] Revert the whole/);
  assert.match(res, /Their note: "but keep the new types"/);
  const ack = await p1.next('ack', (m) => m.id === card.id);
  assert.equal(ack.id, card.id);
});

test('ask_decision: free text only', async () => {
  const pending = call('ask_decision', { title: 'Next?', options: [{ label: 'A' }, { label: 'B' }] });
  const card = await p1.next('decision_request');
  p1.send({ type: 'decision_response', id: card.id, text: 'Neither, write docs first' });
  assert.match(await pending, /did not pick an option and replied: "Neither, write docs first"/);
});

test('ask_decision: unknown option is refused, card stays open', async () => {
  const pending = call('ask_decision', { title: 'Pick', options: [{ label: 'A' }, { label: 'B' }], allow_free_text: false });
  const card = await p1.next('decision_request');
  p1.send({ type: 'decision_response', id: card.id, optionId: 'z', text: 'ignored' });
  const err = await p1.next('error', (m) => m.id === card.id);
  assert.match(err.error, /unknown optionId/);
  p1.send({ type: 'decision_response', id: card.id, optionId: 'a' });
  assert.match(await pending, /chose \[a\] A/);
});

test('ask_decision: open card is re-sent when the phone reconnects', async () => {
  const pending = call('ask_decision', { title: 'Survives reconnect', options: [{ label: 'A' }, { label: 'B', recommended: true }] });
  const first = await p1.next('decision_request');
  p1.close();
  await p1.closed;
  p1 = phone(creds);
  const again = await p1.next('decision_request');
  assert.equal(again.id, first.id);
  p1.send({ type: 'decision_response', id: again.id, optionId: 'b' });
  assert.match(await pending, /chose \[b\] B/);
});

test('ask_decision: voice timeout ends the dialog without choosing an action', async () => {
  const t0 = Date.now();
  const res = await call('ask_decision', {
    title: 'Force push to main?',
    options: [{ label: 'Push', recommended: false }, { label: 'Skip', recommended: true }],
    risk: 'high',
    timeout_s: 1, // clamped to the 5 s minimum
  });
  assert.ok(Date.now() - t0 >= 4900);
  assert.match(res, /Phone choice ended \(timeout\)/);
  assert.match(res, /No action was selected/);
  assert.doesNotMatch(res, /proceed conservatively/);
  const exp = await p1.next('decision_expired');
  assert.equal(exp.reason, 'timeout');
});

test('ask_decision: cancelling the tool call expires the card', async () => {
  const ac = new AbortController();
  const pending = call('ask_decision', { title: 'Cancel me', options: [{ label: 'A' }, { label: 'B' }] }, { signal: ac.signal });
  await p1.next('decision_request', (m) => m.title === 'Cancel me');
  ac.abort();
  await assert.rejects(pending);
  const exp = await p1.next('decision_expired');
  assert.equal(exp.reason, 'cancelled');
});

test('answering from a push notification action', async () => {
  pushes.length = 0;
  const pending = call('ask_decision', { title: 'From the lock screen', options: [{ label: 'Yes', recommended: true }, { label: 'No' }] });
  await until(() => pushes.length === 1);
  const action = pushes[0].actions.find((a) => a.label === 'No');
  // Relay was created with a placeholder PUBLIC_URL; hit the same path on the real port.
  const url = new URL(action.url);
  const r = await fetch(`http://localhost:${relayPort}${url.pathname}`, { method: 'POST' });
  assert.equal(r.status, 200);
  assert.match(await pending, /chose \[b\] No/);
  const again = await fetch(`http://localhost:${relayPort}${url.pathname}`, { method: 'POST' });
  assert.equal(again.status, 410, 'token is single-use');
});

test('instructions queue and pop in order', async () => {
  assert.equal(await call('get_instruction', { wait_s: 0 }), 'none');
  p1.send({ type: 'instruction', id: 'i1', text: 'Also update the README' });
  p1.send({ type: 'instruction', id: 'i2', text: 'Then stop' });
  await p1.next('ack', (m) => m.id === 'i2');
  const first = await call('get_instruction', { wait_s: 0 });
  assert.match(first, /"Also update the README"/);
  assert.match(first, /1 more queued/);
  assert.match(await call('get_instruction', { wait_s: 0 }), /"Then stop"$/);
  assert.equal(await call('get_instruction', { wait_s: 0 }), 'none');
});

test('same MCP chat: omitted accept_voice still resumes on speech, returns a new reply and stops', async () => {
  const args = { title: 'Your result', context: 'The document is ready.', allow_free_text: true,
    options: [{ label: 'Review', recommended: true }, { label: 'Stop here' }], timeout_s: 30 };
  const pending = call('ask_decision', args);
  const card = await p1.next('decision_request', m => m.title === args.title && m.acceptsVoice === true);
  assert.equal(card.acceptsVoice, true);
  assert.equal(card.reply, undefined); // Reproduce Bob omitting both new arguments.
  const parallel = await call('ask_decision', args);
  assert.match(parallel, /already open/);
  p1.send({ type: 'instruction', id: 'voice-roundtrip', source: 'voice', text: 'Add a troubleshooting section.' });
  await p1.next('ack', m => m.id === 'voice-roundtrip');
  const removed = await p1.next('decision_expired', m => m.id === card.id);
  assert.equal(removed.reason, 'voice_input');
  assert.match(await pending, /Add a troubleshooting section/);
  assert.equal(await call('get_instruction', { wait_s: 0 }), 'none');
  const next = call('ask_decision', { ...args, reply: 'Troubleshooting is included.' });
  const replacement = await p1.next('decision_request', m => m.title === args.title && m.acceptsVoice && m.id !== card.id);
  assert.equal(replacement.reply, 'Troubleshooting is included.');
  p1.send({ type: 'decision_response', id: replacement.id, optionId: 'b' });
  assert.match(await next, /Stop here/);
  await p1.next('ack', m => m.id === replacement.id);
  // Push delivery is asynchronous. Drain both notifications before the next
  // test resets its shared fake-ntfy inbox and checks an approval notification.
  await until(() => pushes.filter(push => push.title === args.title).length === 2);
});

test('omitted wait_s starts real home voice standby and receives a new job without a card or replacing the last result', async () => {
  const message = 'Changes saved locally. Nothing committed.';
  await call('notify', { message, level: 'success' });
  await p1.next('notify', m => m.message === message);
  await until(() => pushes.some(push => push.message === message));
  const marker = p1.inbox.length;
  // Reproduce the real IDE sending {} despite the optional wait_s argument.
  let settled = false;
  const waiting = call('get_instruction').finally(() => { settled = true; });
  const ready = await p1.next('voice_status', m => !!m.voiceReadyUntil);
  assert.ok(Date.parse(ready.voiceReadyUntil) > Date.now() + 500_000);
  await new Promise(resolve => setTimeout(resolve, 50));
  assert.equal(settled, false, 'empty queue must keep the MCP call open');
  assert.equal(p1.inbox.slice(marker).some(m => ['notify', 'decision_request'].includes(m.type)), false);
  assert.match(await call('get_instruction', { wait_s: 0 }), /already owns the input queue/);
  p1.send({ type: 'instruction', id: 'home-voice', source: 'voice', text: 'Please commit the changes.' });
  await p1.next('ack', m => m.id === 'home-voice');
  const result = await waiting;
  assert.match(result, /Please commit the changes/);
  assert.match(result, /previous task approvals were cleared/);
  assert.equal(await call('get_instruction', { wait_s: 0 }), 'none');
  const timeout = await call('get_instruction', { wait_s: 1 });
  assert.match(timeout, /No action is authorized/);
  assert.match(timeout, /renew quiet standby/);
  const controller = new AbortController();
  const cancelled = call('get_instruction', { wait_s: 30 }, { signal: controller.signal });
  // Avoid stale status packets from the preceding one-second wait.
  await until(() => p1.inbox.some(m => m.type === 'voice_status' && Date.parse(m.voiceReadyUntil) > Date.now() + 5000 && m !== ready));
  controller.abort();
  await assert.rejects(cancelled);
  await until(() => p1.inbox.at(-1)?.type === 'voice_status' && p1.inbox.at(-1).voiceReadyUntil === null);
});

const APPROVAL = {
  command: 'npm test -- --runInBand --bail auth',
  title: 'Run the auth tests',
  context: "Checks that sign-in still works after Bob's changes.",
  risk: 'low',
  explanations: [{ part: '--bail', meaning: 'Stops when the first test fails.' }],
};

test('request_approval: approval card reaches the phone; approve once', async () => {
  pushes.length = 0;
  const pending = call('request_approval', APPROVAL);
  const card = await p1.next('decision_request', (m) => m.kind === 'approval');
  assert.equal(card.command, APPROVAL.command);
  assert.deepEqual(card.options.map((o) => o.id), ['approve_once', 'approve_for_task', 'reject']);
  assert.deepEqual(card.explanations, APPROVAL.explanations);
  await until(() => pushes.length === 1);
  assert.match(pushes[0].message, /^\$ npm test -- --runInBand --bail auth/);
  assert.deepEqual(pushes[0].actions.map((a) => a.label), ['Approve once', 'Approve for task', 'Reject']);
  p1.send({ type: 'decision_response', id: card.id, optionId: 'approve_once', text: null });
  assert.match(await pending, /^approved once: run `npm test -- --runInBand --bail auth`/);
  // Approve once does not carry over.
  const again = call('request_approval', APPROVAL);
  const card2 = await p1.next('decision_request', (m) => m.kind === 'approval');
  p1.send({ type: 'decision_response', id: card2.id, optionId: 'reject', text: 'use yarn' });
  const res = await again;
  assert.match(res, /^rejected: do NOT run/);
  assert.match(res, /Their note: "use yarn"/, 'a note with an option is kept even when free text is off');
});

test('request_approval: approve for task skips the phone until the task ends', async () => {
  const first = call('request_approval', APPROVAL);
  const card = await p1.next('decision_request', (m) => m.kind === 'approval');
  p1.send({ type: 'decision_response', id: card.id, optionId: 'approve_for_task' });
  assert.match(await first, /^approved for task/);

  const before = p1.inbox.length;
  // Same command, different whitespace: still approved, and no card is sent.
  const auto = await call('request_approval', { ...APPROVAL, command: ' npm test  --  --runInBand\t--bail auth ' });
  assert.match(auto, /^approved: .* already approved for this task/);
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(p1.inbox.filter((m) => m.type === 'decision_request').length, p1.inbox.slice(0, before).filter((m) => m.type === 'decision_request').length);

  // A different command still asks.
  const other = call('request_approval', { ...APPROVAL, command: 'npm install zod' });
  const c2 = await p1.next('decision_request', (m) => m.command === 'npm install zod');
  p1.send({ type: 'decision_response', id: c2.id, optionId: 'reject' });
  assert.match(await other, /^rejected/);

  // Task finished → permission gone.
  await call('notify', { message: 'done', level: 'success' });
  await p1.next('notify', (m) => m.message === 'done');
  const after = call('request_approval', APPROVAL);
  const c3 = await p1.next('decision_request', (m) => m.kind === 'approval');
  p1.send({ type: 'decision_response', id: c3.id, optionId: 'approve_once' });
  assert.match(await after, /^approved once/);
});

test('request_approval: timeout means not approved; high risk has no push buttons', async () => {
  pushes.length = 0;
  const pending = call('request_approval', { command: 'git push --force origin main', title: 'Force-push', risk: 'high', timeout_s: 5 });
  const card = await p1.next('decision_request', m => m.title === 'Force-push');
  const res = await pending;
  assert.match(res, /^not approved: no response.*Do NOT run `git push --force origin main`/);
  // A push from the previous test can finish after this test clears the array.
  // Select this request instead of relying on the shared asynchronous count.
  await until(() => pushes.some(p => p.title === 'Force-push'));
  assert.equal(pushes.find(p => p.title === 'Force-push').actions, undefined, 'no lock-screen buttons for high risk');
  assert.equal((await p1.next('decision_expired', m => m.id === card.id)).reason, 'timeout');
});

test('request_approval: invalid command is refused before anything is sent', async () => {
  const r = await client.callTool({ name: 'request_approval', arguments: { title: 'x', command: 'x'.repeat(501) } });
  assert.equal(r.isError, true);
  assert.match(r.content[0].text, /limit is 500/);
});

test('answering an approval from a push notification action', async () => {
  pushes.length = 0;
  const pending = call('request_approval', { ...APPROVAL, command: 'npm run lint' });
  await until(() => pushes.length === 1);
  const action = pushes[0].actions.find((a) => a.label === 'Approve for task');
  const r = await fetch(`http://localhost:${relayPort}${new URL(action.url).pathname}`, { method: 'POST' });
  assert.equal(r.status, 200);
  assert.match(await pending, /^approved for task: run `npm run lint`/);
  await call('notify', { message: 'task over', level: 'success' });
});

test('room closes after Bob exits; phone is told', async () => {
  const off = p1.next('bob_status', (m) => m.online === false);
  await client.close();
  client = null;
  await off;
  assert.equal(await p1.closed, 4001);
  assert.equal(relay.rooms.has(creds.sessionId), false);
});

test('fixed session id/secret survive a Bob restart', async () => {
  const env = { COMPANION_SESSION_ID: 'demo-session', COMPANION_SECRET: 'demo-secret-demo-secret' };
  client = await startMcp(env);
  await until(async () => /waiting for phone/.test(await call('pair_phone')));
  const p = phone({ sessionId: 'demo-session', secret: 'demo-secret-demo-secret' });
  await p.next('paired');
  await client.close();
  await p.next('bob_status', (m) => m.online === false);
  client = await startMcp(env); // within the relay's grace period
  await p.next('bob_status', (m) => m.online === true);
  assert.equal(await call('notify', { message: 'back' }), 'sent');
  assert.equal((await p.next('notify')).message, 'back');
  p.close();
});

test('COMPANION_SESSION_FILE persists the session across restarts', async () => {
  const os = await import('node:os');
  const fs = await import('node:fs');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bc-'));
  const file = path.join(dir, 'nested', 'session.json');
  await client?.close();
  client = await startMcp({ COMPANION_SESSION_FILE: file });
  const saved = JSON.parse(fs.readFileSync(file, 'utf8'));
  assert.equal(fs.statSync(file).mode & 0o777, 0o600);
  assert.match(await call('pair_phone'), new RegExp(`Session: ${saved.sessionId}`));
  await client.close();
  client = await startMcp({ COMPANION_SESSION_FILE: file });
  assert.match(await call('pair_phone'), new RegExp(`Session: ${saved.sessionId}`));
  fs.rmSync(dir, { recursive: true });
});
