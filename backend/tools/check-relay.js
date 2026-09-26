#!/usr/bin/env node
// Smoke-test a deployed relay end to end.
//
//   node tools/check-relay.js [https://bob-relay.zeigma.com] [--hold 130]
//
// Checks: /healthz, dev phone page, bob + phone pairing over wss, forwarding both
// ways, wrong-secret rejection. --hold N keeps both sockets idle N seconds and then
// checks they still forward, to catch proxy idle timeouts (Cloudflare drops idle
// WebSockets after 100 s; the relay's 30 s pings should prevent that).

import crypto from 'node:crypto';
import WebSocket from 'ws';

const args = process.argv.slice(2);
const base = (args.find((a) => /^https?:\/\//.test(a)) || 'https://bob-relay.zeigma.com').replace(/\/$/, '');
const holdIdx = args.indexOf('--hold');
const holdS = holdIdx >= 0 ? Number(args[holdIdx + 1] || 130) : 0;
const wsUrl = base.replace(/^http/, 'ws');

let failed = 0;
const ok = (msg) => console.log(`  ✔ ${msg}`);
const fail = (msg) => (failed++, console.log(`  ✖ ${msg}`));

function open(hello) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl, { handshakeTimeout: 10_000 });
    const inbox = [];
    const waiters = [];
    ws.on('message', (raw) => {
      const m = JSON.parse(raw.toString());
      const w = waiters.findIndex((x) => x.type === m.type);
      if (w >= 0) waiters.splice(w, 1)[0].resolve(m);
      else inbox.push(m);
    });
    ws.on('open', () => {
      ws.send(JSON.stringify(hello));
      resolve({
        ws,
        send: (m) => ws.send(JSON.stringify(m)),
        next: (type, ms = 10_000) => {
          const i = inbox.findIndex((m) => m.type === type);
          if (i >= 0) return Promise.resolve(inbox.splice(i, 1)[0]);
          return new Promise((res, rej) => {
            const t = setTimeout(() => rej(new Error(`no ${type} within ${ms} ms`)), ms);
            waiters.push({ type, resolve: (m) => (clearTimeout(t), res(m)) });
          });
        },
        closed: new Promise((r) => ws.on('close', (code) => r(code))),
      });
    });
    ws.on('error', reject);
  });
}

console.log(`Checking ${base}`);

try {
  const h = await fetch(`${base}/healthz`);
  const body = await h.json();
  h.ok && body.ok ? ok(`GET /healthz → ${h.status} ${JSON.stringify(body)}`) : fail(`GET /healthz → ${h.status}`);
} catch (e) {
  fail(`GET /healthz: ${e.message}`);
}

try {
  const p = await fetch(`${base}/`);
  const html = await p.text();
  p.ok && html.includes('Bob Companion') ? ok('GET / serves the dev phone page') : fail(`GET / → ${p.status}`);
} catch (e) {
  fail(`GET /: ${e.message}`);
}

const sessionId = 'check-' + crypto.randomBytes(4).toString('hex');
const secret = crypto.randomBytes(32).toString('base64url');

try {
  const bob = await open({ type: 'hello', role: 'bob', sessionId, secret });
  await bob.next('paired');
  ok(`bob joined room ${sessionId} over ${wsUrl}`);

  const phone = await open({ type: 'hello', role: 'phone', sessionId, secret });
  const p = await phone.next('paired');
  p.bobOnline ? ok('phone paired, sees Bob online') : fail('phone paired but Bob offline');
  const bp = await bob.next('paired');
  bp.phones === 1 ? ok('bob notified of phone') : fail(`bob sees ${bp.phones} phones`);

  const roundtrip = async (label) => {
    bob.send({ type: 'notify', id: 'n_check', message: 'relay check', level: 'info' });
    const n = await phone.next('notify');
    n.message === 'relay check' ? ok(`${label}: bob → phone`) : fail(`${label}: bad notify`);
    phone.send({ type: 'instruction', id: 'i_check', text: 'hello' });
    const i = await bob.next('instruction');
    i.text === 'hello' ? ok(`${label}: phone → bob`) : fail(`${label}: bad instruction`);
  };
  await roundtrip('forwarding');

  const bad = await open({ type: 'hello', role: 'phone', sessionId, secret: 'x'.repeat(43) });
  const code = await bad.closed;
  code === 4003 ? ok('wrong secret rejected (4003)') : fail(`wrong secret closed with ${code}, expected 4003`);

  if (holdS) {
    console.log(`  … holding idle for ${holdS} s`);
    let dropped = false;
    bob.closed.then(() => (dropped = true));
    phone.closed.then(() => (dropped = true));
    await new Promise((r) => setTimeout(r, holdS * 1000));
    if (dropped) fail(`a socket was dropped during the ${holdS} s idle hold`);
    else await roundtrip(`after ${holdS} s idle`);
  }

  phone.ws.close();
  bob.ws.close();
} catch (e) {
  fail(`websocket: ${e.message}`);
}

console.log(failed ? `\n${failed} check(s) failed` : '\nAll checks passed');
process.exit(failed ? 1 : 0);
