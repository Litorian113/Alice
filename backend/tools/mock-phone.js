#!/usr/bin/env node
// Terminal stand-in for the phone app. Pairs with a link and lets you answer cards.
//
//   node tools/mock-phone.js '<bobcompanion://pair?... | http://relay/#s=..&k=.. | path/to/companion-session.json>'
//                            [--auto rec,stop] [--approve once|task|reject] [--delay seconds] [--topic <ntfyTopic>] [--relay ws://host:8787]
//
// At the prompt:  a / b / 1 / 2   answer the newest open card (option id or number)
//                 a some note     answer with a note
//                 > text          answer with free text only (no option)
//                 ! text          send a free-text instruction
//                 q               quit

import fs from 'node:fs';
import readline from 'node:readline';
import WebSocket from 'ws';

const args = process.argv.slice(2);
const link = args.find((a) => !a.startsWith('--') && !isFlagValue(a));
const auto = flag('--auto');
const topic = flag('--topic');
if (!link) {
  console.error('usage: mock-phone.js <pair link> [--auto a|rec] [--topic ntfy-topic]');
  process.exit(1);
}

const { sessionId, secret, relayUrl } = parseLink(link);
const open = new Map(); // id -> card
let seq = 0;
let autoCount = 0;

let ws;
let backoff = 500;
function connect() {
  ws = new WebSocket(relayUrl);
  ws.on('open', () => ws.send(JSON.stringify({ type: 'hello', role: 'phone', sessionId, secret, ...(topic ? { pushTopic: topic } : {}) })));
  ws.on('close', (code, reason) => {
    if (code === 4003) {
      console.log(`\n✖ rejected: ${reason}`);
      process.exit(1);
    }
    // 4004 unknown session / 4001 session ended / network drop: Bob may (re)appear.
    if (code === 4004) process.stdout.write('.');
    else console.log(`\n• disconnected (${code} ${reason || ''}), retrying`);
    setTimeout(connect, backoff);
    backoff = Math.min(backoff * 2, 5000);
  });
  ws.on('error', () => {});
  ws.on('message', onMessage);
}
connect();

function onMessage(raw) {
  const msg = JSON.parse(raw.toString());
  switch (msg.type) {
    case 'paired':
      backoff = 500;
      console.log(`✔ paired with session ${msg.sessionId} (Bob ${msg.bobOnline ? 'online' : 'offline'})`);
      break;
    case 'bob_status':
      console.log(`• Bob ${msg.online ? 'online' : 'offline'}`);
      break;
    case 'notify':
      console.log(`\n${{ success: '✅', error: '❌' }[msg.level] || 'ℹ️ '} ${msg.message}`);
      break;
    case 'decision_request':
      open.set(msg.id, msg);
      printCard(msg);
      if (auto) {
        // --auto takes a comma list consumed one card at a time; the last entry repeats.
        // Entries: an option id (a-d, approve_once…), a number, "rec", "once", "task", or "stop".
        const plan = auto.split(',');
        // --approve <once|task|reject> answers approval cards separately from the --auto plan.
        const pick = msg.kind === 'approval' && flag('--approve') ? flag('--approve') : plan[Math.min(autoCount++, plan.length - 1)];
        const alias = { once: 'approve_once', task: 'approve_for_task' }[pick] || pick;
        const opt =
          alias === 'rec' ? msg.options.find((o) => o.recommended) || msg.options[0]
          : pick === 'stop' ? msg.options.find((o) => /stop|pause|done|finish|wait/i.test(o.label)) || msg.options.at(-1)
          : msg.options.find((o) => o.id === alias) || msg.options[Number(alias) - 1];
        console.log(`→ auto-tapping ${opt?.id}) ${opt?.label}`);
        setTimeout(() => answer(msg.id, opt?.id, ''), Number(flag('--delay') ?? 1.5) * 1000);
      }
      break;
    case 'decision_expired':
      if (open.delete(msg.id)) console.log(`\n⌛ ${msg.id} closed (${msg.reason})`);
      break;
    case 'ack':
      if (open.delete(msg.id)) console.log(`✔ ${msg.id} answered`);
      else console.log(`✔ ack ${msg.id}`);
      break;
    case 'error':
      if (msg.error !== 'unknown session') console.log(`✖ ${msg.error}`);
      break;
    default:
      console.log('?', msg);
  }
  rl?.prompt();
}

const rl = process.stdin.isTTY || !auto ? readline.createInterface({ input: process.stdin, output: process.stdout, prompt: 'phone> ' }) : null;
rl?.on('line', (line) => {
  const s = line.trim();
  if (s === 'q') process.exit(0);
  if (s.startsWith('!')) {
    ws.send(JSON.stringify({ type: 'instruction', id: `i_phone_${++seq}`, text: s.slice(1).trim() }));
  } else if (s) {
    const card = [...open.values()].at(-1);
    if (!card) console.log('no open card');
    else if (s.startsWith('>')) answer(card.id, undefined, s.slice(1).trim());
    else {
      const [pick, ...note] = s.split(' ');
      // Accept an option id or its 1-based number (handy for approve_once etc.).
      const opt = card.options.find((o) => o.id === pick) || card.options[Number(pick) - 1];
      answer(card.id, opt ? opt.id : pick, note.join(' '));
    }
  }
  rl.prompt();
});

function answer(id, optionId, text) {
  ws.send(JSON.stringify({ type: 'decision_response', id, ...(optionId ? { optionId } : {}), ...(text ? { text } : {}) }));
}

function printCard(c) {
  const risk = { low: '🟢', medium: '🟡', high: '🔴' }[c.risk];
  const kind = c.kind === 'approval' ? 'APPROVAL ' : '';
  console.log(`\n┌ ${risk} ${kind}${c.title}   [${c.id}, expires ${c.expiresAt ? new Date(c.expiresAt).toLocaleTimeString() : 'never'}]`);
  if (c.command) console.log(`│ $ ${c.command}`);
  if (c.context) console.log(`│ ${c.context}`);
  for (const e of c.explanations || []) console.log(`│   ${e.part} — ${e.meaning}`);
  c.options.forEach((o, i) => console.log(`│  ${i + 1}. ${o.id}) ${o.label}${o.recommended ? ' ★' : ''}${o.detail ? `  — ${o.detail}` : ''}`));
  console.log(`└${c.allowFreeText ? ' (free text allowed: "a note" or "> text")' : ''}`);
}

function parseLink(l) {
  if (l.endsWith('.json')) {
    // Session file written by the MCP server (COMPANION_SESSION_FILE).
    const { sessionId, secret } = JSON.parse(fs.readFileSync(l, 'utf8'));
    return { sessionId, secret, relayUrl: flag('--relay') || process.env.RELAY_URL || 'wss://bob-relay.zeigma.com' };
  }
  const u = new URL(l);
  if (u.protocol === 'bobcompanion:') {
    const p = u.searchParams;
    return { sessionId: p.get('s'), secret: p.get('k'), relayUrl: p.get('r') };
  }
  const p = new URLSearchParams(u.hash.slice(1));
  return { sessionId: p.get('s'), secret: p.get('k'), relayUrl: p.get('r') || `${u.protocol === 'https:' ? 'wss' : 'ws'}://${u.host}` };
}

function flag(name) {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
}

function isFlagValue(a) {
  const i = args.indexOf(a);
  return i > 0 && args[i - 1].startsWith('--');
}
