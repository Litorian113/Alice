import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { Companion, randomSessionId } from '../companion-mcp/companion.js';
import { ChatSession } from './session.js';
import { loadEnvironment } from '../relay/environment.js';

const require = createRequire(import.meta.url);
const QRCode = require('qrcode-terminal/vendor/QRCode');
const root = fileURLToPath(new URL('../../', import.meta.url));
const assets = fileURLToPath(new URL('./public/', import.meta.url));

export function qrSVG(link) {
  const qr = new QRCode(-1, 0); qr.addData(link); qr.make();
  const n = qr.getModuleCount(); let cells = '';
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) if (qr.isDark(y, x)) cells += `<path d="M${x + 4} ${y + 4}h1v1h-1z"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${n + 8} ${n + 8}" role="img" aria-label="Pair Alice"><path fill="white" d="M0 0h${n + 8}v${n + 8}H0z"/><g fill="#10223f">${cells}</g></svg>`;
}

export function createDesktopServer(chat, { token = crypto.randomBytes(32).toString('base64url') } = {}) {
  let origin;
  const server = http.createServer(async (req, res) => {
    const headers = { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer', 'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'" };
    const send = (code, value, type = 'application/json') => {
      if (res.writableEnded) return;
      res.writeHead(code, { ...headers, 'Content-Type': type }); res.end(type === 'application/json' ? JSON.stringify(value) : value);
    };
    if (req.headers.host !== new URL(origin).host || (req.headers.origin && req.headers.origin !== origin)) return send(403, { error: 'Local access only' });
    const url = new URL(req.url, origin);
    if (!url.pathname.startsWith('/api/')) {
      const file = { '/': ['index.html', 'text/html'], '/app.js': ['app.js', 'text/javascript'], '/style.css': ['style.css', 'text/css'] }[url.pathname];
      if (req.method !== 'GET' || !file) return send(404, { error: 'Not found' });
      return send(200, fs.readFileSync(path.join(assets, file[0])), file[1]);
    }
    const supplied = Buffer.from(req.headers.authorization?.replace(/^Bearer /, '') || '');
    const expected = Buffer.from(token);
    if (supplied.length !== expected.length || !crypto.timingSafeEqual(supplied, expected)) return send(401, { error: 'Open the private link printed by npm run chat' });
    try {
      if (req.method === 'GET' && url.pathname === '/api/state') return send(200, chat.state(Number(url.searchParams.get('after')) || 0));
      if (req.method === 'GET' && url.pathname === '/api/pair') return send(200, { svg: qrSVG(chat.companion.pairLink), relayUrl: chat.companion.relayUrl });
      if (req.method === 'GET' && url.pathname === '/api/license') {
        const dir = path.join(root, '.bob/acp-runtime/node_modules/bobshell/dist/ibm-licence');
        const files = ['license.txt', 'non_ibm_license.txt', 'notices.txt'];
        if (!chat.args?.includes(path.join(root, '.bob/acp-runtime/node_modules/bobshell/dist/bob.js')) || !fs.existsSync(dir)) throw new Error('Run bob --show-license acp to review the license for your installed Bob Shell.');
        return send(200, { files: files.map(name => ({ name, text: fs.readFileSync(path.join(dir, name), 'utf8') })) });
      }
      if (req.method !== 'POST' || req.headers['content-type'] !== 'application/json') return send(405, { error: 'JSON POST required' });
      let body = '';
      for await (const chunk of req) { body += chunk; if (body.length > 64_000) return send(413, { error: 'Message too large' }); }
      const input = JSON.parse(body || '{}');
      switch (url.pathname) {
        case '/api/connect': await chat.connect(); break;
        case '/api/authenticate': await chat.authenticate(); break;
        case '/api/accept-license':
          if (input.accept !== true) throw new Error('Explicit license acceptance is required');
          await chat.acceptLicense(); break;
        case '/api/prompt': {
          // prompt() claims busy synchronously. Return immediately; stream via state.
          if (chat.busy || chat.status !== 'ready' || typeof input.text !== 'string' || !input.text.trim() || input.text.length > 20_000) throw new Error('Bob is busy, disconnected, or the message is empty/too long');
          void chat.prompt(input.text); break;
        }
        case '/api/cancel': await chat.cancel(); break;
        case '/api/answer':
          if (!chat.permissions) throw new Error('No permission request is pending');
          chat.permissions.answer(input.id, input.optionId); break;
        default: return send(404, { error: 'Not found' });
      }
      send(200, { ok: true });
    } catch (error) { send(400, { error: error.message }); }
  });
  return {
    server, token,
    async listen(port = 8790) {
      await new Promise((resolve, reject) => { server.once('error', reject); server.listen(port, '127.0.0.1', resolve); });
      origin = `http://127.0.0.1:${server.address().port}`;
      return `${origin}/#${token}`;
    },
    async close() { chat.close(); server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); },
  };
}

async function main() {
  loadEnvironment();
  const directory = path.join(root, '.bob');
  const sessionFile = path.join(directory, 'acp-session.json');
  if (!fs.existsSync(sessionFile)) fs.writeFileSync(sessionFile, JSON.stringify({ sessionId: randomSessionId(), secret: crypto.randomBytes(32).toString('base64url') }), { mode: 0o600, flag: 'wx' });
  const saved = JSON.parse(fs.readFileSync(sessionFile, 'utf8'));
  let relayUrl = process.env.RELAY_URL || 'wss://bob-relay.zeigma.com';
  const override = path.join(directory, 'local-relay.json');
  if (!process.env.RELAY_URL && fs.existsSync(override)) relayUrl = JSON.parse(fs.readFileSync(override, 'utf8')).relayUrl;
  const companion = new Companion({ relayUrl, ...saved });
  const localBob = path.join(directory, 'acp-runtime/node_modules/bobshell/dist/bob.js');
  const command = process.env.BOB_ACP_COMMAND || (fs.existsSync(localBob) ? process.execPath : 'bob');
  const args = [...(!process.env.BOB_ACP_COMMAND && fs.existsSync(localBob) ? [localBob] : []), 'acp', '--disable-mcp', '--disable-subagents'];
  const env = { ...process.env };
  if (!env.BOB_API_KEY && env.BOBSHELL_API_KEY) env.BOB_API_KEY = env.BOBSHELL_API_KEY;
  const chat = new ChatSession({ companion, command, args, cwd: root, env });
  const desktop = createDesktopServer(chat);
  const url = await desktop.listen(Number(process.env.ALICE_CHAT_PORT || 8790));
  companion.start();
  console.log(`Alice + Bob desktop chat: ${url}`);
  console.log('Private local link. Scan the QR in this page for the ACP session.');
  // Also store the launch link locally so a launcher need not scrape logs.
  fs.writeFileSync(path.join(directory, 'acp-desktop-url'), url + '\n', { mode: 0o600 });
  for (const signal of ['SIGTERM', 'SIGINT']) process.once(signal, async () => { await desktop.close(); process.exit(0); });
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(error => { console.error(error.message); process.exitCode = 1; });
