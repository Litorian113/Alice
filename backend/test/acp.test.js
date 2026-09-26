import { test } from 'node:test';
import assert from 'node:assert/strict';
import WebSocket from 'ws';
import http from 'node:http';
import { Companion } from '../companion-mcp/companion.js';
import { permissionCard, Permissions } from '../acp/permissions.js';
import { createRelay } from '../relay/server.js';
import { createDesktopServer } from '../acp/server.js';
import { AgentProcess } from '../acp/rpc.js';

const tool = { toolCallId: 'call-1', title: 'Execute command', kind: 'execute', rawInput: { command: 'printf "hello\\n"' } };
const params = { sessionId: 's-1', toolCall: tool, options: [
  { optionId: 'original-allow', kind: 'allow_once', name: 'Allow once' },
  { optionId: 'tool-wide', kind: 'allow_always', name: 'Always allow' },
  { optionId: 'original-reject', kind: 'reject_once', name: 'Reject' },
] };
const tick = () => new Promise(r => setImmediate(r));
const until = async fn => { for (let n = 0; n < 150; n++) { if (fn()) return; await new Promise(r => setTimeout(r, 10)); } throw new Error('Condition timed out'); };
function fixture(respond = async () => {}) {
  const companion = new Companion({ relayUrl: 'ws://unused' });
  const sent = []; companion.send = message => { sent.push(message); return true; };
  const replies = [];
  const permissions = new Permissions(companion, { respond: async (id, result) => { replies.push({ id, result }); await respond(); } });
  return { companion, sent, permissions, replies };
}

test('ACP review preserves inputs and diffs; broad tool permission is never mapped to task approval', () => {
  const expanded = { ...tool, content: [{ type: 'diff', path: 'a.txt', oldText: 'old\n', newText: 'new\n' }] };
  const { card, optionMap } = permissionCard(params, expanded, 'card');
  assert.match(card.command, /printf/); assert.match(card.command, /Before:\nold\n/); assert.match(card.command, /After:\nnew\n/);
  assert.deepEqual(card.options.map(o => o.id), ['approve_once', 'reject']);
  assert.equal(optionMap.get('approve_once'), 'original-allow');
  assert.throws(() => permissionCard(params, { ...tool, rawInput: 'x'.repeat(24001) }, 'card'));
  assert.throws(() => permissionCard(params, { toolCallId: 'empty' }, 'card'));
  assert.throws(() => permissionCard(params, { ...tool, content: [{ type: 'content', content: { type: 'image' } }] }, 'card'));
});

test('ACP response keeps original JSON-RPC/option IDs and acknowledges only after transport accepts response', async () => {
  let release; const gate = new Promise(r => release = r);
  const f = fixture(() => gate);
  const request = f.permissions.request({ id: 92, params }, tool, 's-1');
  const id = [...f.permissions.pending.keys()][0];
  f.companion.resolveDecision({ id, optionId: 'approve_once' });
  f.companion.resolveDecision({ id, optionId: 'approve_once' });
  await tick();
  assert.equal(f.replies.length, 1); assert.equal(f.sent.some(m => m.type === 'ack'), false);
  assert.deepEqual(f.replies[0], { id: 92, result: { outcome: { outcome: 'selected', optionId: 'original-allow' } } });
  release(); await request;
  assert.equal(f.sent.at(-1).type, 'ack');
  f.companion.resolveDecision({ id, optionId: 'approve_once' });
  assert.equal(f.replies.length, 1); assert.equal(f.sent.at(-1).type, 'ack');
});

test('ACP cancellation, late replies and mismatched sessions never approve', async () => {
  const f = fixture();
  const request = f.permissions.request({ id: 'rpc', params }, tool, 's-1');
  const id = [...f.permissions.pending.keys()][0];
  f.permissions.cancel(); await request;
  f.companion.resolveDecision({ id, optionId: 'approve_once' });
  assert.deepEqual(f.replies, [{ id: 'rpc', result: { outcome: { outcome: 'cancelled' } } }]);
  assert.equal(f.sent.at(-1).type, 'decision_expired');
  await f.permissions.request({ id: 'wrong', params }, tool, 'another-session');
  assert.equal(f.replies.at(-1).result.outcome.outcome, 'cancelled');
});

test('ACP transport failure never acknowledges a successful approval', async () => {
  const f = fixture(async () => { throw new Error('closed'); });
  const request = f.permissions.request({ id: 9, params }, tool, 's-1');
  const id = [...f.permissions.pending.keys()][0];
  f.permissions.answer(id, 'reject'); await request;
  assert.equal(f.sent.some(m => m.type === 'ack'), false);
  assert.equal(f.sent.at(-1).reason, 'delivery_failed');
});

test('changed tool input invalidates a pending phone card', async () => {
  const f = fixture();
  const request = f.permissions.request({ id: 12, params }, tool, 's-1');
  f.permissions.toolChanged({ ...tool, rawInput: { command: 'a different command' } });
  await request;
  assert.equal(f.replies[0].result.outcome.outcome, 'cancelled');
  assert.equal(f.sent.at(-1).reason, 'cancelled');
});

test('expired ACP approval cancels without selecting a fallback', async () => {
  const f = fixture(); f.permissions.timeoutS = 0.01;
  await f.permissions.request({ id: 13, params }, tool, 's-1');
  assert.equal(f.replies[0].result.outcome.outcome, 'cancelled');
  assert.equal(f.sent.at(-1).reason, 'timeout');
});

test('real relay carries native permission and phone decision back to ACP responder', async t => {
  const relay = createRelay({ port: 0, log: () => {} });
  const port = await relay.listen(); t.after(() => relay.close());
  const companion = new Companion({ relayUrl: `ws://127.0.0.1:${port}`, sessionId: 'acp-test', secret: 'a'.repeat(43) });
  t.after(() => companion.stop()); companion.start(); await until(() => companion.connected);
  const phone = new WebSocket(companion.relayUrl); t.after(() => phone.close());
  const messages = []; phone.on('message', raw => messages.push(JSON.parse(raw)));
  await new Promise(r => phone.once('open', r));
  phone.send(JSON.stringify({ type: 'hello', role: 'phone', sessionId: companion.sessionId, secret: companion.secret }));
  await until(() => companion.phones === 1);
  const replies = [];
  const permissions = new Permissions(companion, { respond: async (id, result) => replies.push({ id, result }) });
  const pending = permissions.request({ id: 101, params }, tool, 's-1');
  await until(() => messages.some(m => m.type === 'decision_request'));
  const card = messages.find(m => m.type === 'decision_request');
  phone.send(JSON.stringify({ type: 'decision_response', id: card.id, optionId: 'reject' }));
  await pending;
  assert.equal(replies[0].result.outcome.optionId, 'original-reject');
  await until(() => messages.some(m => m.type === 'ack' && m.id === card.id));
});

test('desktop endpoints require private token, reject foreign origins and DNS rebinding', async t => {
  const chat = { close() {}, state: () => ({ status: 'ready' }) };
  const app = createDesktopServer(chat); const link = new URL(await app.listen(0));
  t.after(() => app.close());
  assert.equal((await fetch(link.origin + '/api/state')).status, 401);
  const headers = { Authorization: 'Bearer ' + app.token };
  assert.equal((await fetch(link.origin + '/api/state', { headers })).status, 200);
  assert.equal((await fetch(link.origin + '/api/state', { headers: { ...headers, Origin: 'https://outside.example' } })).status, 403);
  const rebindingStatus = await new Promise((resolve, reject) => {
    http.get(link.origin + '/api/state', { headers: { ...headers, Host: 'outside.example' } }, res => {
      res.resume(); res.on('end', () => resolve(res.statusCode));
    }).on('error', reject);
  });
  assert.equal(rebindingStatus, 403);
});

test('ACP stdio supports interleaved requests and UTF-8 streaming, and rejects outstanding calls on exit', async t => {
  const source = `const rl=require('readline').createInterface({input:process.stdin}); rl.on('line',l=>{const m=JSON.parse(l);if(m.method==='start'){process.stdout.write(JSON.stringify({jsonrpc:'2.0',method:'session/update',params:{text:'Grüße'}})+'\\n');process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:81,method:'session/request_permission',params:{}})+'\\n');process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:m.id,result:{ok:true}})+'\\n')}else if(m.method==='exit'){process.exit(1)}});`;
  const agent = new AgentProcess(process.execPath, ['-e', source]); t.after(() => agent.close());
  const notifications = [], requests = [];
  agent.on('notification', m => notifications.push(m)); agent.on('request', m => requests.push(m));
  assert.deepEqual(await agent.request('start', {}), { ok: true });
  assert.equal(notifications[0].params.text, 'Grüße'); assert.equal(requests[0].id, 81);
  await assert.rejects(agent.request('exit', {}), /Bob stopped/);
});
