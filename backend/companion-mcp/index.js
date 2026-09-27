#!/usr/bin/env node
// Bob Companion MCP server. Bob spawns this over stdio; it dials out to the relay
// so the developer can steer Bob from their phone.
//
// stdout is reserved for MCP — everything human-readable goes to stderr.
//
// Env:
//   RELAY_URL               ws(s):// URL of the relay (default ws://localhost:8787)
//   RELAY_WEB_URL           http(s) URL of the relay's dev phone page (default: derived from RELAY_URL)
//   COMPANION_SESSION_ID    fixed session id (optional; keeps pairing across Bob restarts)
//   COMPANION_SECRET        fixed secret, >= 16 chars (optional, use together with the above)
//   COMPANION_SESSION_FILE  JSON file to keep the session in (optional; created mode 0600). Lets the
//                           phone stay paired across Bob runs — each `bob run` spawns a new server.
//   COMPANION_QR            "app" (bobcompanion:// link, default) or "web" (dev phone page link)
//   DECISION_TIMEOUT_S      default ask_decision timeout (default 120)
//   MAX_DECISION_TIMEOUT_S  upper bound for timeout_s (default 540; keep below Bob's mcp.json timeout)

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import qrcode from 'qrcode-terminal';
import { z } from 'zod';
import { CardError, LEVELS, LIMITS, RISKS, normalizeApproval, normalizeCard } from './card.js';
import { Companion, randomSessionId } from './companion.js';

const env = process.env;
const DEFAULT_TIMEOUT_S = clampInt(env.DECISION_TIMEOUT_S, 120, 10, 3600);
const MAX_TIMEOUT_S = clampInt(env.MAX_DECISION_TIMEOUT_S, 540, 10, 3600);
const QR_MODE = env.COMPANION_QR === 'web' ? 'web' : 'app';

const log = (...a) => process.stderr.write(`[bob-companion] ${a.join(' ')}\n`);

const companion = new Companion({
  relayUrl: localRelayURL() || env.RELAY_URL || 'ws://localhost:8787',
  webUrl: env.RELAY_WEB_URL,
  ...loadSession(),
  log,
});

const qrLink = () => (QR_MODE === 'web' ? companion.webPairLink : companion.pairLink);

function renderQr(text) {
  let out = '';
  qrcode.generate(text, { small: true }, (q) => (out = q));
  return out;
}

function printPairing() {
  process.stderr.write(
    `\n[bob-companion] Scan to pair your phone (session ${companion.sessionId}):\n${renderQr(qrLink())}\n` +
      `  app link: ${companion.pairLink}\n  web link: ${companion.webPairLink}\n\n`,
  );
}

function statusLine() {
  if (!companion.connected) return `relay offline (${companion.relayUrl}${companion.lastError ? `: ${companion.lastError}` : ''})`;
  if (companion.phones > 0) return `phone connected (${companion.phones})`;
  if (companion.everPaired) return companion.pushEnabled ? 'phone paired, app closed (push enabled)' : 'phone paired but disconnected';
  return 'waiting for phone to scan';
}

const text = (t, isError = false) => ({ content: [{ type: 'text', text: t }], ...(isError ? { isError: true } : {}) });

const server = new McpServer(
  { name: 'bob-companion', version: '0.1.0' },
  {
    instructions:
      'Write all phone-facing titles, replies, context, option labels/details and notifications in English. The developer may be away and steering you from their phone. Use ask_decision for next-step choices, request_approval before running state-changing commands, notify for one-line status, get_instruction between steps. For same-chat voice follow-ups call ask_decision with accept_voice=true, reply containing your answer, and relevant options including Stop here. Voice resumes that call without approving commands.',
  },
);

server.registerTool(
  'pair_phone',
  {
    title: 'Pair phone',
    description:
      "Show the QR code / link the developer scans with the Bob Companion phone app, plus the current pairing status. Call this when asked to pair or connect a phone, or when another companion tool reports that no phone is paired.",
    inputSchema: {},
    annotations: { readOnlyHint: true },
  },
  async () =>
    text(
      [
        `Status: ${statusLine()}`,
        `Session: ${companion.sessionId}`,
        '',
        'Scan this QR code with the phone:',
        '```',
        renderQr(qrLink()).trimEnd(),
        '```',
        `App link: ${companion.pairLink}`,
        `Web link (dev phone page): ${companion.webPairLink}`,
        '',
        'Show the QR code and links to the developer verbatim.',
      ].join('\n'),
    ),
);

server.registerTool(
  'ask_decision',
  {
    title: 'Ask the developer (phone)',
    description:
      'Send a short decision card to the developer\'s phone and wait for their tap. Use when a step is done and there is more than one sensible next step. To ask permission to run one specific command, use request_approval instead. ' +
      `Write every phone-facing field in English. Keep it short: title <= ${LIMITS.title} chars, context <= ${LIMITS.context} chars (max 2 sentences), 2-4 options with labels <= ${LIMITS.label} chars and optional detail <= ${LIMITS.detail} chars. Mark exactly one option recommended. Longer text is cut off. ` +
      'Blocks until the developer answers or the timeout passes. Voice replies are enabled by default (accept_voice=false explicitly opts out): a spoken instruction can replace the options and resume this SAME chat. Put your actual answer in reply, also write it in the IDE chat, and include a Stop here option. After handling voice, call ask_decision again with your new reply and fresh actions. On timeout/cancellation stop the conversation; never choose an action for the user.',
    inputSchema: {
      title: z.string().describe(`What just happened / what needs deciding. <= ${LIMITS.title} chars.`),
      context: z.string().optional().describe(`Situation in 1-2 short sentences. <= ${LIMITS.context} chars.`),
      options: z
        .array(
          z.object({
            label: z.string().describe(`Button text, imperative. <= ${LIMITS.label} chars.`),
            detail: z.string().optional().describe(`What happens if chosen. <= ${LIMITS.detail} chars.`),
            recommended: z.boolean().optional().describe('true for your single recommended option.'),
          }),
        )
        .describe('2-4 concrete next steps.'),
      risk: z.enum(RISKS).optional().describe('low / medium / high. Use high for destructive or irreversible actions.'),
      command: z.string().optional().describe('Optional shell command the options relate to, shown verbatim on the card.'),
      allow_free_text: z.boolean().optional().describe('Let the developer type a note or alternative instruction (default true).'),
      accept_voice: z.boolean().optional().describe('Wait for either a button or a voice instruction in this same chat. Default true, including when omitted. Set false only to opt out; never for command approval.'),
      reply: z.string().max(LIMITS.reply).optional().describe('Your actual English answer/result for the phone, preserving paragraphs. Up to 4000 characters. Replaced by the next card, no chat history.'),
      timeout_s: z
        .number()
        .optional()
        .describe(`Seconds to wait for an answer (default ${DEFAULT_TIMEOUT_S}, max ${MAX_TIMEOUT_S}).`),
    },
  },
  async (args, extra) => {
    if (!companion.everPaired) {
      return text(
        'no phone paired, proceed conservatively. Continue only with the safest recommended option and do not perform risky actions. ' +
          'Call pair_phone to show the developer the pairing QR code.',
      );
    }

    let card;
    try {
      card = normalizeCard(args, { id: companion.nextId('d'), timeoutS: timeoutFor(args) });
    } catch (err) {
      if (err instanceof CardError) return text(`Invalid decision card: ${err.message}. Fix it and call ask_decision again.`, true);
      throw err;
    }

    if (companion.pending.size > 0 && (card.acceptsVoice || [...companion.pending.values()].some(entry => entry.card.acceptsVoice))) {
      return text('A request is already open. Finish it before starting another phone wait.', true);
    }

    const result = await sendAndWait(card, extra);
    if (result.instruction) {
      return text(`Voice input from the developer (${result.instruction.id}): ${JSON.stringify(result.instruction.text)}\nThe previous choice card was withdrawn, not approved. Continue this SAME conversation with the new instruction. Follow normal tool permissions. Write your answer in English in chat and send it to the phone in ask_decision.reply with accept_voice=true and relevant English actions including Stop here. Keep all phone dialog text in English even if the spoken instruction was in another language. If the developer explicitly asked to stop, send a final notify and end instead.`);
    }
    if (result.expired) {
      if (card.acceptsVoice) {
        return text(`Phone conversation ended (${result.expired}). No action was selected. Stop waiting; do not perform a suggested action or automatically reopen the dialog. The developer can resume from the IDE.`);
      }
      const rec = card.options.find((o) => o.recommended);
      return text(
        [
          'no response, proceed conservatively.',
          card.risk === 'high'
            ? 'Do NOT perform the risky action. Pause it and continue with other safe work, or stop and summarise.'
            : 'Do not perform risky actions.',
          rec ? `The recommended option was [${rec.id}] ${rec.label}; continue with it only if it is safe and reversible.` : '',
        ]
          .filter(Boolean)
          .join(' '),
      );
    }

    const { option, text: note } = result;
    if (!option) {
      return text(`The developer did not pick an option and replied: "${note}". Follow this instruction.`);
    }
    return text(
      [
        `The developer chose [${option.id}] ${option.label}${option.detail ? ` (${option.detail})` : ''}.`,
        note ? `Their note: "${note}".` : '',
        'Proceed with this choice.',
      ]
        .filter(Boolean)
        .join(' '),
    );
  },
);

server.registerTool(
  'request_approval',
  {
    title: 'Ask to run a command (phone)',
    description:
      "Ask the developer on their phone for permission to run ONE exact shell command, and wait for Approve once / Approve for task / Reject. " +
      'Call it before running commands that change state: installing packages, running migrations, deleting files, git commit/push, deploying, or anything with risk. Read-only commands (ls, cat, grep, git status/diff/log) and running tests do not need approval. ' +
      'Pass the command exactly as you will run it; it is shown and approved verbatim. If the developer already approved this command for the current task, it returns approved at once without asking again. ' +
      'Only run the command if the result says approved. "Approve for task" lasts until you call notify with level success or error.',
    inputSchema: {
      command: z.string().describe(`The exact command you will run, <= ${LIMITS.command} chars. Never shortened.`),
      title: z.string().describe(`What the command does, plain language, <= ${LIMITS.title} chars. E.g. "Run the auth tests".`),
      context: z.string().optional().describe(`Why / what it changes, 1-2 short sentences, <= ${LIMITS.context} chars.`),
      explanations: z
        .array(z.object({ part: z.string(), meaning: z.string() }))
        .optional()
        .describe(`Optional: up to ${LIMITS.explanations} parts of the command with a short plain-language meaning, e.g. {part: "--bail", meaning: "Stops at the first failing test"}.`),
      risk: z.enum(RISKS).optional().describe('low / medium / high. high for destructive or irreversible commands.'),
      timeout_s: z
        .number()
        .optional()
        .describe(`Seconds to wait for an answer (default ${DEFAULT_TIMEOUT_S}, max ${MAX_TIMEOUT_S}).`),
    },
  },
  async (args, extra) => {
    let card;
    try {
      card = normalizeApproval(args, { id: companion.nextId('d'), timeoutS: timeoutFor(args) });
    } catch (err) {
      if (err instanceof CardError) return text(`Invalid approval request: ${err.message}.`, true);
      throw err;
    }
    const cmd = '`' + card.command + '`';

    if (companion.isApprovedForTask(card.command)) {
      log(`approval auto-granted (approved for task): ${card.command}`);
      return text(`approved: ${cmd} was already approved for this task. You may run it.`);
    }
    if (!companion.everPaired) {
      return text(`not approved: no phone paired. Do NOT run ${cmd}. Call pair_phone so the developer can pair, or continue without it.`);
    }

    const result = await sendAndWait(card, extra);
    if (result.expired) {
      return text(`not approved: no response from the developer. Do NOT run ${cmd}. Continue with other safe work or stop and summarise.`);
    }
    const note = result.text ? ` Their note: "${result.text}".` : '';
    switch (result.option?.id) {
      case 'approve_once':
        return text(`approved once: run ${cmd} exactly as shown, one time. Ask again before running it another time.${note}`);
      case 'approve_for_task':
        companion.approveForTask(card.command);
        return text(`approved for task: run ${cmd}. You may run this exact command again during this task without asking.${note}`);
      case 'reject':
        return text(`rejected: do NOT run ${cmd}. Find a different approach or ask the developer with ask_decision.${note}`);
      default:
        return text(`not approved: the developer replied "${result.text}" instead of approving. Do NOT run ${cmd}; follow their reply.`);
    }
  },
);

server.registerTool(
  'notify',
  {
    title: 'Notify phone',
    description:
      "Send a one-line status message to the developer's phone (fire-and-forget). Call when a task finishes (level success) or fails (level error), or for a notable milestone (info).",
    inputSchema: {
      message: z.string().describe(`One-line summary, <= ${LIMITS.notify} chars.`),
      level: z.enum(LEVELS).optional().describe('info (default), success, or error.'),
    },
  },
  async ({ message, level }) => {
    // A finished or failed task ends every "approve for task" permission.
    if (level === 'success' || level === 'error') companion.endTask();
    if (!companion.everPaired) return text('no phone paired');
    return text(companion.notify(message, level || 'info') ? 'sent' : 'not sent: relay offline');
  },
);

server.registerTool(
  'get_instruction',
  {
    title: 'Get instruction from phone',
    description:
      'Pop the next free-text instruction the developer sent from their phone. Call between steps of a long task and follow any instruction returned. Returns "none" if nothing is queued.',
    inputSchema: {},
  },
  async () => {
    const next = companion.popInstruction();
    if (!next) return text('none');
    const more = companion.instructions.length;
    return text(
      `Instruction from the developer: "${next.text}"` +
        (more ? `\n(${more} more queued — call get_instruction again after this one.)` : ''),
    );
  },
);

function timeoutFor(args) {
  return Math.min(MAX_TIMEOUT_S, Math.max(5, Math.round(args.timeout_s ?? DEFAULT_TIMEOUT_S)));
}

// Push the card to the phone and block until answered, expired or cancelled.
async function sendAndWait(card, extra) {
  // Keep clients that honour progress notifications from timing out while we wait.
  const progressToken = extra?._meta?.progressToken;
  let ticks = 0;
  const keepAlive =
    progressToken !== undefined &&
    setInterval(() => {
      extra
        .sendNotification({
          method: 'notifications/progress',
          params: { progressToken, progress: ++ticks, message: 'Waiting for the developer to answer on their phone' },
        })
        .catch(() => {});
    }, 15_000);

  log(`${card.kind} ${card.id} sent: ${card.title}${card.command ? ` [${card.command}]` : ''}${keepAlive ? ' (progress keep-alive on)' : ''}`);
  const result = await companion.askDecision(card, { signal: extra?.signal });
  if (keepAlive) clearInterval(keepAlive);
  if (result.expired) log(`${card.kind} ${card.id} ${result.expired}`);
  return result;
}

companion.on('session', printPairing);
companion.start();
printPairing();

const transport = new StdioServerTransport();
await server.connect(transport);
log(`MCP server ready (relay ${companion.relayUrl})`);

const shutdown = () => {
  companion.stop();
  process.exit(0);
};
process.stdin.on('close', shutdown);
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

// Session credentials: explicit env > session file > fresh random (memory only).
function loadSession() {
  if (env.COMPANION_SESSION_ID && env.COMPANION_SECRET) {
    return { sessionId: env.COMPANION_SESSION_ID, secret: env.COMPANION_SECRET };
  }
  const file = env.COMPANION_SESSION_FILE && path.resolve(env.COMPANION_SESSION_FILE);
  if (!file) return {};
  try {
    const saved = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (typeof saved.sessionId === 'string' && typeof saved.secret === 'string') return saved;
  } catch (err) {
    if (err.code !== 'ENOENT') log(`ignoring unreadable session file ${file}: ${err.message}`);
  }
  const fresh = { sessionId: randomSessionId(), secret: crypto.randomBytes(32).toString('base64url') };
  try {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify(fresh, null, 2) + '\n', { mode: 0o600 });
  } catch (err) {
    log(`could not write session file ${file}: ${err.message}`);
  }
  return fresh;
}

function clampInt(v, dflt, min, max) {
  const n = Number.parseInt(v, 10);
  return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : dflt;
}

// Optional, gitignored per-machine override written by dev --configure-bob.
// The shared MCP config can keep the production URL without hardcoding a LAN IP.
function localRelayURL() {
  if (!env.COMPANION_LOCAL_CONFIG) return '';
  try {
    const config = JSON.parse(fs.readFileSync(path.resolve(env.COMPANION_LOCAL_CONFIG), 'utf8'));
    const url = new URL(config.relayUrl);
    if (!['ws:', 'wss:'].includes(url.protocol)) throw new Error('invalid relay URL');
    return url.toString();
  } catch (error) {
    if (error.code === 'ENOENT') return '';
    throw new Error('Invalid local relay configuration. Check COMPANION_LOCAL_CONFIG.');
  }
}
