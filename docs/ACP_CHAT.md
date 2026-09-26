# Alice + Bob: local ACP chat

The browser chat starts a **new Bob Shell session in this repository**. Native
`session/request_permission` requests are forwarded to Alice and the selected
option is returned to that exact JSON-RPC request. The existing IBM Bob IDE chat
is independent. Both use the same project files; avoid editing the same files
from both active sessions at once.

## Start on this Mac

```sh
# Terminal 1, from the repository root (omit if the relay is already running):
cd backend
PORT=8788 npm run dev -- --no-bob --configure-bob

# Terminal 2, from the repository root:
cd backend
npm run chat
```

Open the **private URL printed by `npm run chat`**. It includes a browser access
token; don't share it. The chat binds only to `127.0.0.1:8790`. Set
`ALICE_CHAT_PORT` to change the port. Reloading in the same browser tab keeps the
token; after restarting the server, open its new private link.

1. Click **Connect Bob**. On first use, choose **Review Bob license** and review
   the installed IBM license and notices. Only the user's **Accept and connect**
   action supplies `--accept-license` to Bob.
2. If requested, click **Sign in to IBM** and complete the browser login. Alice
   never needs your password. Authentication is handled by Bob Shell.
3. Scan the QR in this page using Alice. This is a **separate ACP pairing**;
   an iPhone paired to the old IDE MCP session must switch to this QR.
4. Wait for **Ready** and **Phone connected**. Click **Try a phone approval**,
   then Send. It asks Bob to run a harmless `printf` command. The template is
   editable and does not send itself.
5. Approve or reject in Alice. The choice is returned to Bob; the PC shows the
   actual tool result. You can also answer the same request in the PC chat.

For background notifications, enable Alice's existing ntfy setup. The native
request's full input/diff stays in the app/relay flow; push messages use a short
instruction to open Alice, not the full diff. Local relay testing requires the
Mac and iPhone to reach the same LAN address.

## Bob Shell setup elsewhere

Use the [official Bob Shell installer](https://bob.ibm.com/docs/shell/getting-started/install-and-setup).
On Franz's Mac the verified official 2.0.5 package is installed locally in
`.bob/acp-runtime/` (ignored by Git; no global Node or Bob installation changed).
The package declares Node >=22; the latest online installation guide asks for
Node >=24, so use Node 24+ for a fresh setup.

The launcher prefers that local installation, then `bob` on PATH. Set
`BOB_ACP_COMMAND` to an alternative executable path; its arguments remain `acp
--disable-mcp --disable-subagents`. A custom installation's license can be
reviewed with `bob --show-license acp` and accepted interactively.

Trust the specific project once using `bob` in the repository root if Bob reports
an untrusted workspace. No global `--trust` or `--auto-approve` flag is added.
This Mac's Alice folder was trusted during setup; the Desktop parent was not.

Root `.env` may contain `BOB_API_KEY` (or `BOBSHELL_API_KEY`, mapped to it for
compatibility) instead of SSO. No API key is placed in the browser or iPhone.
`RELAY_URL` overrides the relay URL; otherwise `.bob/local-relay.json` wins over
the production default. The existing AssemblyAI configuration is unchanged.

## Implementation and contracts

| File | Responsibility |
| --- | --- |
| `backend/acp/rpc.js` | ACP JSON-RPC over UTF-8 newline-delimited stdio, request correlation and process shutdown |
| `backend/acp/session.js` | Initialization, SSO, session creation, chat streaming, cancellation and tool state |
| `backend/acp/permissions.js` | Exact ACP option mapping, native request cards, cancellation and stale-request checks |
| `backend/acp/server.js` | Loopback HTTP endpoints, access token, host/origin validation, local QR |
| `backend/acp/public/` | PC chat, pairing, live tool details and desktop fallback answers |
| `.bob/acp-session.json` | Persistent ACP relay credentials; ignored and created with mode 0600 |
| `.bob/acp-desktop-url` | Private current browser launch URL; ignored and created with mode 0600 |

The adapter owns the ACP session's relay connection. Bob starts with MCP disabled
so the repository's companion MCP config cannot start a competing Bob peer or
duplicate this approval path. The IDE's original companion session is untouched.

ACP `allow_once` and `reject_once` map to Alice's `approve_once` and `reject`.
The original ACP option IDs are returned verbatim. **Always allow is omitted**:
Bob Shell 2.0.5 remembers it by tool name for the rest of the session, which is
broader than the existing command-specific `approve_for_task`.

Alice's existing decoder renders these approval cards without a new app build.
Cards include `source: "acp"`; unknown fields are ignored by older decoders.
The `command` field contains complete tool input and supplied text/diffs (not
necessarily a shell command). Native cards allow up to 24,000 characters / 30 KB
of JSON-encoded review text; the adapter also bounds the combined sync snapshot.
Unrenderable/missing/oversized input is cancelled with an explanation in the PC
chat. It is never silently truncated and approved.

`ack` is sent after the JSON-RPC response was written to Bob's process. It means
**the decision was handed back**, not that the command completed successfully.
Tool execution results are streamed separately. Duplicate answers don't send a
second ACP response. Stop, timeout (nine minutes), process exit or changed tool
input invalidates outstanding cards. Loss of phone connectivity does not approve
anything; a pending card is re-sent on reconnect or can be answered on the PC.

## Current scope

Verified on 26 September 2026: all 49 backend tests passed, including a real local
relay plus simulated phone → ACP response round trip. Bob Shell 2.0.5 initialized
successfully after user license acceptance/login and emitted a real native
permission request for the harmless `printf` test. At that check the ACP phone
count was zero; real iPhone delivery and its returned choice are still awaiting
the user's scan/test. Do not describe the simulated phone test as physical iPhone
validation.

**Subsequent user verification:** Franz confirmed the browser ↔ physical iPhone
flow works as intended. His screenshot shows `Phone connected`, a rejection
returned to Bob, and Bob confirming that no files were changed. This validates
the ACP path; it does not connect the separate existing IBM Bob IDE chat.

- One active chat/session per desktop server, with an in-memory browser transcript.
  Refresh replays the retained events; restarting starts a fresh chat. Bob may
  persist its own session, but this UI doesn't yet offer history/resume.
- Native **tool permissions** are forwarded. Ordinary questions in Bob's prose
  remain in the PC chat; no arbitrary prose-to-choice conversion is claimed.
- Read-only operations can run without a permission request under Bob's ACP
  policy. Only requests Bob actually emits are forwarded.
- Voice input is received and placed in the PC composer for review and sending;
  it does not silently start a new task or approve an operation.
- No Accessibility automation or changes to IBM Bob's installed IDE are used.

References: [IBM ACP](https://bob.ibm.com/docs/shell/features/acp),
[ACP permission requests](https://agentclientprotocol.com/protocol/tool-calls),
[ACP stdio](https://agentclientprotocol.com/protocol/transports).
