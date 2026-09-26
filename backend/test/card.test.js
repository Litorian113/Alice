import { test } from 'node:test';
import assert from 'node:assert/strict';
import { APPROVAL_OPTIONS, CardError, LIMITS, commandKey, firstSentences, normalizeApproval, normalizeCard, trimText } from '../companion-mcp/card.js';

const base = {
  title: 'Refactor done, 3 tests failing',
  context: 'Auth module refactored. 3 of 48 tests fail on outdated mocks.',
  risk: 'low',
  options: [
    { label: 'Fix tests', detail: 'Update mocks, then rerun', recommended: true },
    { label: 'Revert refactor', detail: 'Back to last green commit' },
    { label: 'Pause', detail: "Wait until I'm back" },
  ],
};

test('handoff example card passes through unchanged', () => {
  const card = normalizeCard(base, { id: 'd_42', now: Date.parse('2026-09-26T14:03:00Z'), timeoutS: 120 });
  assert.deepEqual(card, {
    type: 'decision_request',
    id: 'd_42',
    kind: 'choice',
    title: 'Refactor done, 3 tests failing',
    context: 'Auth module refactored. 3 of 48 tests fail on outdated mocks.',
    command: null,
    explanations: [],
    risk: 'low',
    options: [
      { id: 'a', label: 'Fix tests', detail: 'Update mocks, then rerun', recommended: true },
      { id: 'b', label: 'Revert refactor', detail: 'Back to last green commit', recommended: false },
      { id: 'c', label: 'Pause', detail: "Wait until I'm back", recommended: false },
    ],
    allowFreeText: true,
    expiresAt: '2026-09-26T14:05:00Z',
  });
});

test('trimText respects limit, cuts at words, adds ellipsis', () => {
  const s = trimText('The quick brown fox jumps over the lazy dog again and again', 25);
  assert.ok(s.length <= 25, s);
  assert.ok(s.endsWith('…'));
  assert.equal(s, 'The quick brown fox…');
  assert.equal(trimText('  a\n\nb\tc  ', 10), 'a b c');
  assert.equal(trimText('x'.repeat(100), 10), 'x'.repeat(9) + '…');
});

test('context is cut to two sentences and 140 chars', () => {
  assert.equal(firstSentences('One. Two! Three? Four.', 2), 'One. Two!');
  assert.equal(firstSentences('Version 1.2.3 released. Next up.', 2), 'Version 1.2.3 released. Next up.');
  const card = normalizeCard({ ...base, context: 'A'.repeat(200) + '. Second. Third.' }, { id: 'd' });
  assert.ok(card.context.length <= LIMITS.context);
});

test('every field is trimmed to the contract', () => {
  const long = 'word '.repeat(80);
  const card = normalizeCard(
    { title: long, context: long, options: [{ label: long, detail: long }, { label: 'Other ' + long, detail: long }] },
    { id: 'd' },
  );
  assert.ok(card.title.length <= LIMITS.title);
  assert.ok(card.context.length <= LIMITS.context);
  for (const o of card.options) {
    assert.ok(o.label.length <= LIMITS.label, o.label);
    assert.ok(o.detail.length <= LIMITS.detail, o.detail);
  }
});

test('at most one recommended, first wins', () => {
  const card = normalizeCard(
    { ...base, options: base.options.map((o) => ({ ...o, recommended: true })) },
    { id: 'd' },
  );
  assert.deepEqual(card.options.map((o) => !!o.recommended), [true, false, false]);
});

test('more than 4 options keeps the recommended one', () => {
  const options = ['A', 'B', 'C', 'D', 'E', 'F'].map((label) => ({ label, recommended: label === 'F' }));
  const card = normalizeCard({ ...base, options }, { id: 'd' });
  assert.deepEqual(card.options.map((o) => o.label), ['A', 'B', 'C', 'F']);
  assert.deepEqual(card.options.map((o) => o.id), ['a', 'b', 'c', 'd']);
  assert.equal(card.options[3].recommended, true);
});

test('fewer than 2 usable options is an error', () => {
  assert.throws(() => normalizeCard({ ...base, options: [{ label: 'Only' }] }, { id: 'd' }), CardError);
  assert.throws(() => normalizeCard({ ...base, options: [{ label: 'Same' }, { label: 'same' }] }, { id: 'd' }), CardError);
  assert.throws(() => normalizeCard({ ...base, options: [{ label: '' }, { label: ' ' }, { label: 'x' }] }, { id: 'd' }), CardError);
  assert.throws(() => normalizeCard({ ...base, title: '  ' }, { id: 'd' }), CardError);
});

test('risk defaults to medium, free text defaults on, empty detail is ""', () => {
  const card = normalizeCard({ title: 't', options: [{ label: 'x', detail: '' }, { label: 'y' }], risk: 'extreme' }, { id: 'd' });
  assert.equal(card.risk, 'medium');
  assert.equal(card.allowFreeText, true);
  assert.equal(card.context, '');
  assert.equal(card.options[0].detail, '');
  assert.equal(card.options[0].recommended, false);
  assert.equal(normalizeCard({ ...base, allow_free_text: false }, { id: 'd' }).allowFreeText, false);
});

// Keys every card must carry (the iOS app decodes with synthesized Codable, which
// fails on a missing non-optional key).
const CARD_KEYS = ['allowFreeText', 'command', 'context', 'expiresAt', 'explanations', 'id', 'kind', 'options', 'risk', 'title', 'type'];
const OPTION_KEYS = ['detail', 'id', 'label', 'recommended'];

test('choice and approval cards have the same, complete key set', () => {
  const choice = normalizeCard({ title: 't', options: [{ label: 'x' }, { label: 'y' }] }, { id: 'd' });
  const approval = normalizeApproval({ title: 't', command: 'ls' }, { id: 'd' });
  for (const card of [choice, approval]) {
    assert.deepEqual(Object.keys(card).sort(), CARD_KEYS);
    for (const o of card.options) assert.deepEqual(Object.keys(o).sort(), OPTION_KEYS);
    assert.match(card.expiresAt, /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/, 'no fractional seconds (Swift .iso8601)');
  }
});

test('approval card: fixed option ids, command verbatim, free text off by default', () => {
  const command = 'npm test -- --runInBand   --bail auth';
  const card = normalizeApproval(
    {
      title: 'Run the auth tests',
      context: "Checks that sign-in still works after Bob's changes. Stops at the first failing test.",
      command: `  ${command}\n`,
      risk: 'low',
      explanations: [{ part: '--bail', meaning: 'Stops when the first test fails.' }, { part: '', meaning: 'dropped' }],
    },
    { id: 'd_9' },
  );
  assert.equal(card.kind, 'approval');
  assert.equal(card.command, command, 'only outer whitespace trimmed');
  assert.deepEqual(card.options.map((o) => o.id), ['approve_once', 'approve_for_task', 'reject']);
  assert.deepEqual(card.options, APPROVAL_OPTIONS);
  assert.deepEqual(card.explanations, [{ part: '--bail', meaning: 'Stops when the first test fails.' }]);
  assert.equal(card.allowFreeText, false);
  assert.equal(normalizeApproval({ title: 't', command: 'ls', allow_free_text: true }, { id: 'd' }).allowFreeText, true);
});

test('commands are never trimmed: too long or empty is an error', () => {
  assert.throws(() => normalizeApproval({ title: 't', command: 'x'.repeat(LIMITS.command + 1) }, { id: 'd' }), /limit is 500/);
  assert.throws(() => normalizeApproval({ title: 't', command: '   ' }, { id: 'd' }), CardError);
  const ok = 'y'.repeat(LIMITS.command);
  assert.equal(normalizeApproval({ title: 't', command: ok }, { id: 'd' }).command, ok);
});

test('choice card can show an optional command', () => {
  const card = normalizeCard({ title: 'Migration ready', command: 'npm run migrate', options: [{ label: 'Run it' }, { label: 'Skip' }] }, { id: 'd' });
  assert.equal(card.command, 'npm run migrate');
  assert.equal(card.kind, 'choice');
});

test('explanations are capped', () => {
  const many = Array.from({ length: 10 }, (_, i) => ({ part: `p${i}`, meaning: 'm'.repeat(300) }));
  const card = normalizeApproval({ title: 't', command: 'ls', explanations: many }, { id: 'd' });
  assert.equal(card.explanations.length, LIMITS.explanations);
  assert.ok(card.explanations.every((e) => e.meaning.length <= LIMITS.explanationMeaning));
});

test('commandKey normalizes whitespace only', () => {
  assert.equal(commandKey(' npm  test\n--bail '), 'npm test --bail');
  assert.notEqual(commandKey('npm test'), commandKey('npm Test'));
});

test('expiresAt is rounded up, never shortening the timeout', () => {
  const now = Date.parse('2026-09-26T14:03:00.999Z');
  const card = normalizeCard(base, { id: 'd', now, timeoutS: 5 });
  assert.equal(card.expiresAt, '2026-09-26T14:03:06Z');
  assert.ok(Date.parse(card.expiresAt) >= now + 5000);
});
