#!/usr/bin/env node
// Plays the Bob / MCP side against a relay, so the app team can build and test
// without IBM Bob. Uses the same Companion class and card normalizer as the real
// MCP server, so every message matches the contract exactly.
//
//   RELAY_URL=wss://relay.example.com node tools/fake-bob.js [--loop 20]
//
// Keys: d = next sample choice card     h = high-risk choice card
//       a = next sample approval card   x = high-risk approval card   n = notify
//       e = error notify               s = success notify   l = list open cards
//       q = quit
// --loop N sends a notify + a card every N seconds (unattended mode).

import readline from 'node:readline';
import qrcode from 'qrcode-terminal';
import { normalizeApproval, normalizeCard } from '../companion-mcp/card.js';
import { Companion } from '../companion-mcp/companion.js';

const relayUrl = process.env.RELAY_URL || 'ws://localhost:8787';
const loopIdx = process.argv.indexOf('--loop');
const loopS = loopIdx > 0 ? Number(process.argv[loopIdx + 1] || 20) : 0;

const SAMPLES = [
  {
    title: 'Refactor done, 3 tests failing',
    context: 'Auth module refactored. 3 of 48 tests fail on outdated mocks.',
    risk: 'low',
    options: [
      { label: 'Fix tests', detail: 'Update mocks, then rerun', recommended: true },
      { label: 'Revert refactor', detail: 'Back to last green commit' },
      { label: 'Pause', detail: "Wait until I'm back" },
    ],
  },
  {
    title: 'Feature branch ready',
    context: 'Login rate limiting implemented and tested. 12 files changed.',
    risk: 'medium',
    options: [
      { label: 'Open PR', detail: 'Push branch and open a draft PR', recommended: true },
      { label: 'Add docs first', detail: 'Update README and API docs' },
      { label: 'Stop here' },
    ],
  },
  {
    title: 'Lint found 40 warnings',
    context: 'Mostly unused imports. Two are real bugs in date parsing.',
    risk: 'low',
    options: [
      { label: 'Fix the 2 bugs', recommended: true },
      { label: 'Fix all 40' },
      { label: 'Ignore for now' },
      { label: 'Show me the list', detail: 'Paste the bug warnings into a notify' },
    ],
  },
  {
    // Deliberately too long: shows server-side trimming.
    title: 'I have finished migrating the entire payments service to the new SDK version and everything compiles',
    context:
      'The migration touched 57 files across three packages. Integration tests pass locally. There is one deprecation warning left in the webhook handler. I also noticed the retry logic could be simplified.',
    options: [
      { label: 'Deploy to staging environment now', detail: 'Run the full staging deploy pipeline including smoke tests and notify QA', recommended: true },
      { label: 'Fix the deprecation warning first' },
      { label: 'Simplify retry logic' },
    ],
  },
];

const HIGH_RISK = {
  title: 'Force-push to main?',
  context: 'History rewrite drops 2 commits. Others may have pulled them.',
  risk: 'high',
  allow_free_text: true,
  options: [
    { label: 'Open PR instead', detail: 'Safe: push branch and open a PR', recommended: true },
    { label: 'Force-push', detail: 'Rewrites main on origin' },
    { label: 'Pause' },
  ],
};

const APPROVALS = [
  {
    // Same request as the iOS app's fixture (AliceFixtures.commandApproval).
    command: 'npm test -- --runInBand --bail auth',
    title: 'Run the auth tests',
    context: "Checks that sign-in still works after Bob's changes. Stops at the first failing test.",
    risk: 'low',
    explanations: [
      { part: 'npm test', meaning: "Starts the project's test runner." },
      { part: '--runInBand', meaning: 'Runs the tests one at a time.' },
      { part: '--bail', meaning: 'Stops when the first test fails.' },
      { part: 'auth', meaning: 'Selects the authentication tests.' },
    ],
  },
  {
    command: 'npm install zod@4',
    title: 'Add the zod package',
    context: 'Needed to validate the new config file. Adds one dependency.',
    risk: 'medium',
    explanations: [
      { part: 'npm install', meaning: 'Downloads a package and adds it to package.json.' },
      { part: 'zod@4', meaning: 'The schema validation library, version 4.' },
    ],
  },
];

const HIGH_RISK_APPROVAL = {
  command: 'git push --force origin main',
  title: 'Force-push to main',
  context: 'Rewrites history on origin. Two commits others may have pulled will disappear.',
  risk: 'high',
  explanations: [
    { part: '--force', meaning: 'Overwrites the remote branch even if it has other commits.' },
    { part: 'origin main', meaning: 'The shared main branch on GitHub.' },
  ],
};

const log = (...a) => console.log(`[fake-bob] ${a.join(' ')}`);
const companion = new Companion({ relayUrl, log });
let sample = 0;
let approvalSample = 0;

function printPairing() {
  qrcode.generate(companion.pairLink, { small: true }, (q) => console.log(`\n${q}`));
  console.log(`session  ${companion.sessionId}`);
  console.log(`app link ${companion.pairLink}`);
  console.log(`web link ${companion.webPairLink}\n`);
}

async function ask(input, timeoutS = 120, normalize = normalizeCard) {
  const card = normalize(input, { id: companion.nextId('d'), timeoutS });
  log(`→ ${card.id} "${card.title}" (${card.options.map((o) => o.id + ':' + o.label).join(', ')})`);
  const res = await companion.askDecision(card);
  if (res.expired) log(`← ${card.id} expired (${res.expired})`);
  else log(`← ${card.id} ${res.option ? `[${res.option.id}] ${res.option.label}` : '(free text)'}${res.text ? ` "${res.text}"` : ''} via ${res.via}`);
}

companion.on('instruction', () => {
  const i = companion.popInstruction();
  if (i) log(`← instruction ${i.id}: "${i.text}"`);
});
companion.on('status', () => log(`status: relay ${companion.connected ? 'up' : 'down'}, phones ${companion.phones}, push ${companion.pushEnabled ? 'on' : 'off'}`));

companion.start();
printPairing();

if (loopS) {
  setInterval(() => {
    companion.notify(`Heartbeat ${new Date().toLocaleTimeString()}`, 'info');
    // Alternate choice and approval cards.
    const t = Math.max(10, loopS - 2);
    if (sample <= approvalSample) ask(SAMPLES[sample++ % SAMPLES.length], t);
    else ask(APPROVALS[approvalSample++ % APPROVALS.length], t, normalizeApproval);
  }, loopS * 1000);
}

readline.emitKeypressEvents(process.stdin);
if (process.stdin.isTTY) process.stdin.setRawMode(true);
console.log('keys: d=choice h=high-risk choice a=approval x=high-risk approval n=notify s=success e=error l=list p=pairing q=quit');
process.stdin.on('keypress', (_s, key) => {
  if (!key) return;
  if (key.name === 'q' || (key.ctrl && key.name === 'c')) {
    companion.stop();
    process.exit(0);
  }
  const k = key.name;
  if (k === 'd') ask(SAMPLES[sample++ % SAMPLES.length]);
  else if (k === 'h') ask(HIGH_RISK, 60);
  else if (k === 'a') ask(APPROVALS[approvalSample++ % APPROVALS.length], 120, normalizeApproval);
  else if (k === 'x') ask(HIGH_RISK_APPROVAL, 60, normalizeApproval);
  else if (k === 'n') log(companion.notify('Running the test suite (48 tests)…', 'info') ? 'notify sent' : 'not sent');
  else if (k === 's') log(companion.notify('All 48 tests pass. Branch pushed.', 'success') ? 'notify sent' : 'not sent');
  else if (k === 'e') log(companion.notify('Build failed: missing env var DATABASE_URL', 'error') ? 'notify sent' : 'not sent');
  else if (k === 'l') log(`open cards: ${[...companion.pending.keys()].join(', ') || 'none'}`);
  else if (k === 'p') printPairing();
});
