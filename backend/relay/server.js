#!/usr/bin/env node
// Bob Companion relay: rooms keyed by sessionId, joined only with the matching
// secret. Forwards messages between the MCP server ("bob") and phones, and sends
// push notifications (ntfy or Expo) for notify / decision_request.
//
// Env:
//   PORT          listen port (default 8787), always bound to 0.0.0.0
//   PUBLIC_URL    https URL the relay is reachable at; enables ntfy action buttons
//   NTFY_URL      ntfy server (default https://ntfy.sh)
//   NTFY_TOKEN    optional ntfy access token
//   PUSH_DETAILS  set to 0 to send generic push text instead of card content
//   ROOM_GRACE_S  seconds to keep a room after the MCP server disconnects (default 30)
//   DEV_PHONE     set to 0 to stop serving the dev phone page at /

import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { WebSocketServer } from 'ws';

const HELLO_TIMEOUT_MS = 10_000;
const HEARTBEAT_MS = 30_000;
const MAX_PAYLOAD = 64 * 1024;

export function createRelay({
  port = Number(process.env.PORT || 8787),
  host = '0.0.0.0',
  publicUrl = process.env.PUBLIC_URL || '',
  ntfyUrl = process.env.NTFY_URL || 'https://ntfy.sh',
  ntfyToken = process.env.NTFY_TOKEN || '',
  pushDetails = process.env.PUSH_DETAILS !== '0',
  roomGraceMs = Number(process.env.ROOM_GRACE_S ?? 30) * 1000,
  devPhone = process.env.DEV_PHONE !== '0',
  log = (...a) => console.log(new Date().toISOString(), ...a),
  fetchImpl = globalThis.fetch,
} = {}) {
  /** @type {Map<string, Room>} */
  const rooms = new Map();
  // One-time tokens for answering a card from a notification action button.
  /** @type {Map<string, {sessionId: string, decisionId: string, optionIds: string[], expires: number}>} */
  const answerTokens = new Map();

  const phonePage = path.join(path.dirname(fileURLToPath(import.meta.url)), 'public', 'phone.html');

  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://x');
    if (url.pathname === '/healthz') {
      return sendJson(res, 200, { ok: true, rooms: rooms.size });
    }
    const m = url.pathname.match(/^\/a\/([A-Za-z0-9_-]{16,})\/([a-d])$/);
    if (m && req.method === 'POST') {
      return answerFromPush(res, m[1], m[2]);
    }
    if (devPhone && req.method === 'GET' && (url.pathname === '/' || url.pathname === '/phone')) {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
      return fs.createReadStream(phonePage).pipe(res);
    }
    sendJson(res, 404, { error: 'not found' });
  });

  const wss = new WebSocketServer({ server, maxPayload: MAX_PAYLOAD });

  wss.on('connection', (ws, req) => {
    ws.isAlive = true;
    ws.on('pong', () => (ws.isAlive = true));
    ws.on('error', () => {});
    const helloTimer = setTimeout(() => reject(ws, 'hello timeout'), HELLO_TIMEOUT_MS);

    ws.once('message', (raw) => {
      clearTimeout(helloTimer);
      const msg = parse(raw);
      if (!msg || msg.type !== 'hello') return reject(ws, 'first message must be hello');
      const { role, sessionId, secret } = msg;
      if (typeof sessionId !== 'string' || !/^[A-Za-z0-9_-]{4,64}$/.test(sessionId)) return reject(ws, 'bad sessionId');
      if (typeof secret !== 'string' || secret.length < 16 || secret.length > 128) return reject(ws, 'bad secret');

      if (role === 'bob') joinBob(ws, sessionId, secret);
      else if (role === 'phone') joinPhone(ws, sessionId, secret, msg.pushTopic);
      else reject(ws, 'bad role');
    });
  });

  function joinBob(ws, sessionId, secret) {
    let room = rooms.get(sessionId);
    if (room && !safeEqual(room.secret, secret)) return reject(ws, 'session exists');
    if (!room) {
      room = { sessionId, secret, bob: null, phones: new Set(), pushTopics: new Set(), expiry: null };
      rooms.set(sessionId, room);
      log(`room ${sessionId} created`);
    } else {
      log(`room ${sessionId} bob reconnected`);
    }
    clearTimeout(room.expiry);
    room.expiry = null;
    if (room.bob && room.bob !== ws) room.bob.close(4000, 'replaced');
    room.bob = ws;

    send(ws, { type: 'paired', sessionId, role: 'bob', phones: room.phones.size, push: room.pushTopics.size > 0 });
    for (const p of room.phones) send(p, { type: 'bob_status', online: true });

    ws.on('message', (raw) => {
      if (room.bob !== ws) return;
      const msg = parse(raw);
      if (!msg || typeof msg.type !== 'string' || msg.type === 'hello') return;
      for (const p of room.phones) send(p, msg);
      if (msg.type === 'notify' || msg.type === 'decision_request') push(room, msg);
      if (msg.type === 'ack' || msg.type === 'decision_expired') dropAnswerTokens(room.sessionId, msg.id);
    });

    ws.on('close', () => {
      if (room.bob !== ws) return;
      room.bob = null;
      for (const p of room.phones) send(p, { type: 'bob_status', online: false });
      room.expiry = setTimeout(() => closeRoom(room), roomGraceMs);
    });
  }

  function joinPhone(ws, sessionId, secret, pushTopic) {
    const room = rooms.get(sessionId);
    // 4004: no such room (yet) — Bob may still be starting, clients should retry.
    // 4003: wrong secret — clients should give up and re-pair.
    if (!room) return reject(ws, 'unknown session', 4004);
    if (!safeEqual(room.secret, secret)) return reject(ws, 'wrong secret');
    room.phones.add(ws);
    if (typeof pushTopic === 'string' && validPushTopic(pushTopic)) room.pushTopics.add(pushTopic);
    log(`room ${sessionId} phone joined (${room.phones.size})`);

    send(ws, { type: 'paired', sessionId, role: 'phone', bobOnline: !!room.bob });
    send(room.bob, { type: 'paired', sessionId, role: 'bob', phones: room.phones.size, push: room.pushTopics.size > 0 });

    ws.on('message', (raw) => {
      const msg = parse(raw);
      if (!msg || typeof msg.type !== 'string' || msg.type === 'hello') return;
      if (msg.type === 'decision_response') dropAnswerTokens(room.sessionId, msg.id);
      send(room.bob, msg);
    });

    ws.on('close', () => {
      room.phones.delete(ws);
      send(room.bob, { type: 'phone_left', phones: room.phones.size });
    });
  }

  function closeRoom(room) {
    if (room.bob) return;
    for (const p of room.phones) p.close(4001, 'session ended');
    rooms.delete(room.sessionId);
    for (const [t, a] of answerTokens) if (a.sessionId === room.sessionId) answerTokens.delete(t);
    log(`room ${room.sessionId} closed`);
  }

  // ---- push ---------------------------------------------------------------

  function push(room, msg) {
    for (const topic of room.pushTopics) {
      const p = topic.startsWith('ExponentPushToken[') ? pushExpo(topic, msg) : pushNtfy(room, topic, msg);
      p.catch((err) => log(`push to ${topic.slice(0, 12)}… failed: ${err.message}`));
    }
  }

  function pushText(msg) {
    if (msg.type === 'notify') {
      const title = { success: 'Bob: done', error: 'Bob: failed' }[msg.level] || 'Bob';
      return { title, body: pushDetails ? String(msg.message) : 'New status update', tags: [{ success: 'white_check_mark', error: 'x' }[msg.level] || 'robot'] };
    }
    const rec = msg.options.find((o) => o.recommended);
    const body = pushDetails
      ? [msg.context, rec && `Recommended: ${rec.label}`].filter(Boolean).join('\n')
      : 'Bob is waiting for your decision';
    return {
      title: pushDetails ? msg.title : 'Bob needs a decision',
      body,
      tags: [msg.risk === 'high' ? 'warning' : 'question'],
      priority: msg.risk === 'high' ? 5 : 4,
    };
  }

  async function pushNtfy(room, topic, msg) {
    const t = pushText(msg);
    const body = { topic, title: t.title, message: t.body, tags: t.tags, priority: t.priority ?? 3 };
    if (publicUrl) body.click = publicUrl.replace(/\/$/, '') + '/';
    if (msg.type === 'decision_request' && publicUrl) {
      // ntfy allows at most 3 action buttons: recommended first, then the rest in order.
      const opts = [...msg.options].sort((a, b) => (b.recommended ? 1 : 0) - (a.recommended ? 1 : 0)).slice(0, 3);
      const token = crypto.randomBytes(18).toString('base64url');
      answerTokens.set(token, {
        sessionId: room.sessionId,
        decisionId: msg.id,
        optionIds: msg.options.map((o) => o.id),
        expires: Date.parse(msg.expiresAt) || Date.now() + 600_000,
      });
      body.actions = opts.map((o) => ({
        action: 'http',
        label: (o.recommended ? '★ ' : '') + o.label,
        url: `${publicUrl.replace(/\/$/, '')}/a/${token}/${o.id}`,
        method: 'POST',
        clear: true,
      }));
    }
    const headers = { 'content-type': 'application/json' };
    if (ntfyToken) headers.authorization = `Bearer ${ntfyToken}`;
    const res = await fetchImpl(ntfyUrl.replace(/\/$/, '') + '/', { method: 'POST', headers, body: JSON.stringify(body) });
    if (!res.ok) throw new Error(`ntfy ${res.status}`);
  }

  async function pushExpo(token, msg) {
    const t = pushText(msg);
    const res = await fetchImpl('https://exp.host/--/api/v2/push/send', {
      method: 'POST',
      headers: { 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({
        to: token,
        title: t.title,
        body: t.body,
        priority: 'high',
        sound: 'default',
        data: msg.type === 'decision_request' ? { type: msg.type, id: msg.id } : { type: msg.type },
      }),
    });
    if (!res.ok) throw new Error(`expo ${res.status}`);
  }

  function answerFromPush(res, token, optionId) {
    const a = answerTokens.get(token);
    if (!a || a.expires < Date.now()) {
      answerTokens.delete(token);
      return sendJson(res, 410, { error: 'decision expired or already answered' });
    }
    const room = rooms.get(a.sessionId);
    if (!room?.bob) return sendJson(res, 503, { error: 'Bob is offline' });
    if (!a.optionIds.includes(optionId)) return sendJson(res, 400, { error: 'unknown option' });
    dropAnswerTokens(a.sessionId, a.decisionId);
    send(room.bob, { type: 'decision_response', id: a.decisionId, optionId, via: 'push' });
    log(`room ${a.sessionId} ${a.decisionId} answered from notification: ${optionId}`);
    sendJson(res, 200, { ok: true });
  }

  function dropAnswerTokens(sessionId, decisionId) {
    for (const [t, a] of answerTokens) if (a.sessionId === sessionId && a.decisionId === decisionId) answerTokens.delete(t);
  }

  // ---- housekeeping ---------------------------------------------------------

  const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
      if (!ws.isAlive) {
        ws.terminate();
        continue;
      }
      ws.isAlive = false;
      ws.ping();
    }
    const now = Date.now();
    for (const [t, a] of answerTokens) if (a.expires < now) answerTokens.delete(t);
  }, HEARTBEAT_MS);

  server.on('close', () => clearInterval(heartbeat));

  return {
    server,
    rooms,
    listen: () =>
      new Promise((resolve) =>
        server.listen(port, host, () => {
          const addr = server.address();
          log(`relay listening on ${host}:${addr.port}${publicUrl ? ` (public ${publicUrl})` : ''}`);
          resolve(addr.port);
        }),
      ),
    close: () =>
      new Promise((resolve) => {
        for (const ws of wss.clients) ws.terminate();
        for (const room of rooms.values()) clearTimeout(room.expiry);
        wss.close();
        server.close(() => resolve());
      }),
  };
}

// ---- helpers ----------------------------------------------------------------

function parse(raw) {
  try {
    const msg = JSON.parse(raw.toString());
    return msg && typeof msg === 'object' && !Array.isArray(msg) ? msg : null;
  } catch {
    return null;
  }
}

function send(ws, msg) {
  if (ws && ws.readyState === ws.OPEN) ws.send(JSON.stringify(msg));
}

function reject(ws, reason, code = 4003) {
  send(ws, { type: 'error', error: reason });
  ws.close(code, reason);
}

function safeEqual(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

function validPushTopic(t) {
  return /^[A-Za-z0-9_-]{8,64}$/.test(t) || /^ExponentPushToken\[[^\]]{8,}\]$/.test(t);
}

function sendJson(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
}

if (process.argv[1] && import.meta.url === pathToFileURL(fs.realpathSync(process.argv[1])).href) {
  const relay = createRelay();
  relay.listen();
  for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => relay.close().then(() => process.exit(0)));
}
