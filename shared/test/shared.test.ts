import assert from 'node:assert/strict';
import test from 'node:test';
import { normalizeServerUrl, resolveEndpoints } from '../src/endpoints.js';
import { formatBytes, getChunkRange, sanitizeFilename, totalChunksFor } from '../src/files.js';
import { getCatalog, isAppLanguage } from '../src/i18n.js';

test('endpoint resolver derives one-origin endpoints', () => {
  const endpoints = resolveEndpoints('https://example.com/base/');
  assert.equal(endpoints.origin, 'https://example.com/base');
  assert.equal(endpoints.apiBase, 'https://example.com/base/api/v1');
  assert.equal(endpoints.health, 'https://example.com/base/api/v1/health');
  assert.equal(endpoints.websocket, 'wss://example.com/base/ws');
});

test('endpoint resolver rejects unsafe URLs', () => {
  assert.throws(() => normalizeServerUrl('ftp://example.com'), /http/);
  assert.throws(() => normalizeServerUrl('https://user:pass@example.com'), /credentials/);
  assert.throws(() => normalizeServerUrl('not a url'), /valid/);
});

test('file helpers stream-friendly metadata without loading content', () => {
  assert.equal(sanitizeFilename('../secret.txt'), '.._secret.txt');
  assert.equal(formatBytes(1536), '1.5 KB');
  assert.deepEqual(getChunkRange(1, 1024, 3000), { start: 1024, end: 2047 });
  assert.equal(totalChunksFor(3000, 1024), 3);
});

test('language catalog includes all requested locales', () => {
  assert.equal(isAppLanguage('vi'), true);
  assert.equal(isAppLanguage('de'), false);
  assert.equal(getCatalog('ja').settings, '設定');
});
