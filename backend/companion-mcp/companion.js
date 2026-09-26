// Relay link + session state for the companion MCP server.
// Dials out to the relay, keeps the pairing, tracks pending decisions and the
// queue of free-text instructions sent from the phone.

import crypto from 'node:crypto';
import { EventEmitter } from 'node:events';
import WebSocket from 'ws';
import { LIMITS, clean, commandKey, trimText } from './card.js';

export class Companion extends EventEmitter {
  constructor({
    relayUrl,
    sessionId = randomSessionId(),
    secret = crypto.randomBytes(32).toString('base64url'),
    webUrl = '',
    log = () => {},
  }) {
    super();
    this.relayUrl = relayUrl;
    this.sessionId = sessionId;
    this.secret = secret;
    this.webUrl = webUrl || httpFromWs(relayUrl);
    this.log = log;

    this.ws = null;
    this.connected = false; // socket to relay is open and hello was accepted
    this.phones = 0; // phones currently connected to the room
    this.everPaired = false; // a phone has joined at least once
    this.pushEnabled = false; // relay has a push topic for this room
    this.lastError = '';

    /** @type {Map<string, {card: object, resolve: Function}>} */
    this.pending = new Map();
    /** @type {{id: string, text: string, at: string}[]} */
    this.instructions = [];
    // Commands the developer approved "for task" (canonical form). Cleared by endTask().
    /** @type {Set<string>} */
    this.taskApprovals = new Set();

    this.seq = 0;
    this.stopped = false;
    this.backoff = 1000;
  }

  get pairLink() {
    const q = new URLSearchParams({ s: this.sessionId, k: this.secret, r: this.relayUrl });
    return `bobcompanion://pair?${q}`;
  }

  // Dev phone page served by the relay. Credentials ride in the fragment so they
  // never reach HTTP logs.
  get webPairLink() {
    const q = new URLSearchParams({ s: this.sessionId, k: this.secret });
    return `${this.webUrl.replace(/\/$/, '')}/#${q}`;
  }

  nextId(prefix) {
    return `${prefix}_${++this.seq}`;
  }

  start() {
    this.stopped = false;
    this.connect();
  }

  stop() {
    this.stopped = true;
    clearTimeout(this.reconnectTimer);
    this.ws?.close();
  }

  connect() {
    const ws = new WebSocket(this.relayUrl, { handshakeTimeout: 10_000 });
    this.ws = ws;

    ws.on('open', () => {
      ws.send(JSON.stringify({ type: 'hello', role: 'bob', sessionId: this.sessionId, secret: this.secret }));
    });

    ws.on('message', (raw) => {
      let msg;
      try {
        msg = JSON.parse(raw.toString());
      } catch {
        return;
      }
      this.handle(msg);
    });

    ws.on('close', (code, reason) => {
      if (this.ws !== ws) return;
      const wasConnected = this.connected;
      this.connected = false;
      this.phones = 0;
      if (wasConnected) this.log(`relay disconnected (${code} ${reason})`);
      this.emit('status');
      if (this.stopped) return;
      if (code === 4003) {
        // The relay refused our hello (e.g. session id clash) — start a fresh session.
        this.lastError = String(reason || 'rejected by relay');
        this.sessionId = randomSessionId();
        this.everPaired = false;
        this.log(`relay rejected session, new session ${this.sessionId}`);
        this.emit('session');
      }
      this.reconnectTimer = setTimeout(() => this.connect(), this.backoff);
      this.backoff = Math.min(this.backoff * 2, 10_000);
    });

    ws.on('error', (err) => {
      this.lastError = err.message;
      if (!this.connected) this.log(`relay connect failed: ${err.message}`);
    });
  }

  handle(msg) {
    switch (msg.type) {
      case 'paired': {
        const firstConnect = !this.connected;
        this.connected = true;
        this.backoff = 1000;
        this.lastError = '';
        const before = this.phones;
        this.phones = Number(msg.phones) || 0;
        this.pushEnabled = !!msg.push;
        if (this.phones > 0) this.everPaired = true;
        if (firstConnect) this.log(`connected to relay, session ${this.sessionId}`);
        if (this.phones > before) this.log(`phone paired (${this.phones} connected)`);
        // A phone (re)joined or we reconnected: make sure it sees every open card.
        for (const { card } of this.pending.values()) this.send(card);
        this.emit('status');
        break;
      }
      case 'phone_left':
        this.phones = Number(msg.phones) || 0;
        this.emit('status');
        break;
      case 'decision_response':
        this.resolveDecision(msg);
        break;
      case 'instruction': {
        const text = trimText(msg.text, LIMITS.freeText);
        if (!text) break;
        const id = typeof msg.id === 'string' ? msg.id : this.nextId('i');
        this.instructions.push({ id, text, at: new Date().toISOString() });
        this.send({ type: 'ack', id });
        this.log(`instruction queued: ${text}`);
        this.emit('instruction');
        break;
      }
      case 'error':
        this.lastError = String(msg.error);
        this.log(`relay error: ${msg.error}`);
        break;
    }
  }

  send(msg) {
    if (this.ws?.readyState !== WebSocket.OPEN || !this.connected) return false;
    this.ws.send(JSON.stringify(msg));
    return true;
  }

  notify(message, level = 'info') {
    return this.send({ type: 'notify', id: this.nextId('n'), message: trimText(message, LIMITS.notify), level });
  }

  // Sends the card and resolves with {optionId, text, via} or {expired: reason}.
  // Never rejects; never hangs past card.expiresAt.
  askDecision(card, { signal } = {}) {
    return new Promise((resolve) => {
      const done = (result) => {
        clearTimeout(timer);
        signal?.removeEventListener('abort', onAbort);
        this.pending.delete(card.id);
        resolve(result);
      };
      const expire = (reason) => {
        this.send({ type: 'decision_expired', id: card.id, reason });
        done({ expired: reason });
      };
      const onAbort = () => expire('cancelled');
      const timer = setTimeout(() => expire('timeout'), Math.max(0, Date.parse(card.expiresAt) - Date.now()));
      signal?.addEventListener('abort', onAbort, { once: true });
      this.pending.set(card.id, { card, resolve: done });
      this.send(card);
    });
  }

  resolveDecision(msg) {
    const entry = this.pending.get(msg.id);
    if (!entry) {
      this.send({ type: 'decision_expired', id: msg.id, reason: 'unknown' });
      return;
    }
    const { card } = entry;
    const option = card.options.find((o) => o.id === msg.optionId);
    // A note that comes with an option is always kept (e.g. why a command was rejected);
    // allowFreeText only decides whether text may replace the options entirely.
    const text = option || card.allowFreeText ? trimText(msg.text, LIMITS.freeText) : '';
    if (!option && !text) {
      this.send({ type: 'error', id: msg.id, error: 'unknown optionId' });
      return;
    }
    this.send({ type: 'ack', id: msg.id });
    this.log(`decision ${msg.id}: ${option ? option.label : 'free text'}${text ? ` — "${text}"` : ''}`);
    entry.resolve({ option, text, via: clean(msg.via) || 'app' });
  }

  isApprovedForTask(command) {
    return this.taskApprovals.has(commandKey(command));
  }

  approveForTask(command) {
    this.taskApprovals.add(commandKey(command));
  }

  // The task finished or failed: "approve for task" permissions end here.
  endTask() {
    const n = this.taskApprovals.size;
    this.taskApprovals.clear();
    if (n) this.log(`task ended, cleared ${n} task approval(s)`);
  }

  popInstruction() {
    return this.instructions.shift() || null;
  }
}

export function randomSessionId() {
  // 10 chars of unambiguous base32 — short enough to read aloud.
  const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
  const bytes = crypto.randomBytes(10);
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join('');
}

function httpFromWs(url) {
  return String(url).replace(/^ws(s?):/, 'http$1:');
}
