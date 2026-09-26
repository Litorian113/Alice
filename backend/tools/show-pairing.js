#!/usr/bin/env node
// Render locally, without sending pairing credentials to an external QR service.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { randomSessionId } from '../companion-mcp/companion.js';

const require = createRequire(import.meta.url);
const QRCode = require('qrcode-terminal/vendor/QRCode');
const root = fileURLToPath(new URL('../../', import.meta.url));
const directory = path.join(root, '.bob');
const config = JSON.parse(fs.readFileSync(path.join(directory, 'mcp.json'), 'utf8')).mcpServers['bob-companion'];
let relayUrl = config.env.RELAY_URL;
const local = path.join(directory, 'local-relay.json');
if (fs.existsSync(local)) relayUrl = JSON.parse(fs.readFileSync(local, 'utf8')).relayUrl;
const sessionFile = path.join(directory, 'companion-session.json');
if (!fs.existsSync(sessionFile)) {
  fs.writeFileSync(sessionFile, JSON.stringify({ sessionId: randomSessionId(), secret: crypto.randomBytes(32).toString('base64url') }), { mode: 0o600 });
}
const { sessionId, secret } = JSON.parse(fs.readFileSync(sessionFile, 'utf8'));
const link = `bobcompanion://pair?${new URLSearchParams({ s: sessionId, k: secret, r: relayUrl })}`;
const qr = new QRCode(-1, 0);
qr.addData(link); qr.make();
const size = qr.getModuleCount();
let cells = '';
for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
  if (qr.isDark(y, x)) cells += `<rect x="${x + 4}" y="${y + 4}" width="1" height="1"/>`;
}
const escape = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const html = `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:">
<title>Pair Alice + Bob</title><style>
*{box-sizing:border-box}body{margin:0;min-height:100vh;display:grid;place-items:center;background:#15233f;color:#fff;font:16px -apple-system,BlinkMacSystemFont,sans-serif;background-image:linear-gradient(#ffffff06 1px,transparent 1px),linear-gradient(90deg,#ffffff06 1px,transparent 1px);background-size:36px 36px}
main{text-align:center;padding:40px 24px;max-width:620px}small{color:#a6c8ff;letter-spacing:3px}h1{font-size:52px;letter-spacing:-2px;margin:18px 0 12px}p{color:#c2cde4;line-height:1.6}svg{display:block;width:min(420px,80vw);height:auto;background:white;border-radius:20px;margin:28px auto;shape-rendering:crispEdges;padding:12px}.host{font:13px monospace;color:#a6c8ff;overflow-wrap:anywhere}a{display:inline-block;margin:12px;padding:12px 20px;background:#0f62fe;color:white;text-decoration:none;border-radius:14px}
</style><main><small>THE MOBILE PARTNER FOR IBM BOB</small><h1>Alice, meet Bob.</h1><p>Open Alice on your iPhone and scan this code.<br>Keep Bob and the relay running on your computer.</p>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size + 8} ${size + 8}" role="img" aria-label="Bob session pairing QR code"><rect width="100%" height="100%" fill="white"/><g fill="#15233f">${cells}</g></svg>
<p class="host">${escape(relayUrl)} · ${escape(sessionId)}</p><p>Once paired, Bob's questions arrive in Alice.<br>You decide. Bob continues.</p><a href="${escape(link)}">Open Alice</a></main></html>`;
const output = path.join(directory, 'pairing.html');
fs.writeFileSync(output, html, { mode: 0o600 });
console.log(`Pairing page ready: ${output}`);
console.log('Open this file in your browser. It contains private pairing credentials; do not share it.');
