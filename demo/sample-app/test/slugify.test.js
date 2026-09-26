import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slugify } from '../src/slugify.js';

test('basic', () => assert.equal(slugify('Hello World'), 'hello-world'));
test('trims dashes', () => assert.equal(slugify('  Hello, World!  '), 'hello-world'));
test('accents', () => assert.equal(slugify('Crème Brûlée'), 'creme-brulee'));
