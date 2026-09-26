import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CardError, LIMITS, firstSentences, normalizeCard, trimText } from '../companion-mcp/card.js';

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
    title: 'Refactor done, 3 tests failing',
    context: 'Auth module refactored. 3 of 48 tests fail on outdated mocks.',
    risk: 'low',
    options: [
      { id: 'a', label: 'Fix tests', detail: 'Update mocks, then rerun', recommended: true },
      { id: 'b', label: 'Revert refactor', detail: 'Back to last green commit' },
      { id: 'c', label: 'Pause', detail: "Wait until I'm back" },
    ],
    allowFreeText: true,
    expiresAt: '2026-09-26T14:05:00.000Z',
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

test('risk defaults to medium, free text defaults on, empty detail omitted', () => {
  const card = normalizeCard({ title: 't', options: [{ label: 'x', detail: '' }, { label: 'y' }], risk: 'extreme' }, { id: 'd' });
  assert.equal(card.risk, 'medium');
  assert.equal(card.allowFreeText, true);
  assert.equal(card.context, '');
  assert.ok(!('detail' in card.options[0]));
  assert.equal(normalizeCard({ ...base, allow_free_text: false }, { id: 'd' }).allowFreeText, false);
});
