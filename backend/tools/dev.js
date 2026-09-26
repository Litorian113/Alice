#!/usr/bin/env node
// Local development backend for the app: relay + fake Bob in one command, with
// pairing links that point at this machine's LAN address, so a real iPhone on the
// same Wi-Fi can connect (a "localhost" link would point the phone at itself).
//
//   npm run dev                      # interactive fake Bob (keys: d a h x n s e)
//   npm run dev -- --loop 20         # unattended: a card every 20 s
//   npm run dev -- --host my-mac.local   # advertise a hostname instead of the IP
//   npm run dev -- --no-bob          # relay only (e.g. for real Bob via demo/setup.sh)
//
// Env: PORT (default 8787).

import { spawn } from 'node:child_process';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRelay } from '../relay/server.js';

const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

const port = Number(process.env.PORT || 8787);
const host = flag('--host') || lanAddress() || 'localhost';
const wsUrl = `ws://${host}:${port}`;
const httpUrl = `http://${host}:${port}`;

const relay = createRelay({
  port,
  // ntfy answer buttons then POST back to this machine; they work while the phone is on the same network.
  publicUrl: httpUrl,
  log: (...a) => console.log(`\x1b[2m[relay] ${a.join(' ')}\x1b[0m`),
});
await relay.listen();

console.log(`
Local Alice backend
  relay (phone)      ${wsUrl}
  relay (simulator)  ws://localhost:${port}
  web phone page     ${httpUrl}/
  health             ${httpUrl}/healthz
${host === 'localhost' ? '\n  ⚠ No LAN address found: only the simulator / this machine can connect.\n' : ''}
iPhone: same Wi-Fi as this machine. Real Bob against this relay:
  RELAY_URL=${wsUrl} demo/setup.sh ~/alice-demo
`);

let bob;
if (!args.includes('--no-bob')) {
  const dir = path.dirname(fileURLToPath(import.meta.url));
  const passthrough = args.includes('--loop') ? ['--loop', flag('--loop') || '20'] : [];
  bob = spawn(process.execPath, [path.join(dir, 'fake-bob.js'), ...passthrough], {
    stdio: 'inherit',
    env: { ...process.env, RELAY_URL: wsUrl },
  });
  bob.on('exit', () => shutdown());
}

function shutdown() {
  bob?.kill();
  relay.close().then(() => process.exit(0));
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

// First private IPv4 address (Wi-Fi / Ethernet), skipping loopback, link-local and
// common virtual interfaces (Docker, VPN tunnels).
function lanAddress() {
  const candidates = [];
  for (const [name, addrs] of Object.entries(os.networkInterfaces())) {
    if (/^(docker|br-|veth|utun|tun|tailscale|vmnet|bridge|lo)/.test(name)) continue;
    for (const a of addrs || []) {
      if (a.family !== 'IPv4' || a.internal || a.address.startsWith('169.254.')) continue;
      candidates.push({ name, address: a.address });
    }
  }
  const isPrivate = (ip) => /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(ip);
  // Prefer en0 (macOS Wi-Fi), then any private address.
  return (candidates.find((c) => c.name === 'en0' && isPrivate(c.address)) || candidates.find((c) => isPrivate(c.address)))?.address;
}
