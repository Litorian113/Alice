# Native Bob IDE approvals → Alice

**Chosen direction:** Franz approved a separate Bob Shell ACP chat instead of
UI automation. See [ACP_CHAT.md](ACP_CHAT.md) for the implementation and setup.
The native existing IDE chat remains separate. macOS UI access was subsequently
granted for diagnosis; no clicking adapter was implemented.

## Required behavior

Franz wants the existing Bob IDE approval dialogs (including normal Agent mode) on
his iPhone. Answering in Alice must resolve the same pending IDE request. Requiring
Bob to call `request_approval` first is not sufficient. Neither is showing a phone
card while still requiring a second approval at the computer.

## Investigation — 26 September 2026

Inspected the installed IBM Bob IDE 1.126.0+bob2.2.0 / `IBM.bob-code` 2.2.0:

- Its exported extension API provides source registration, chat content/task
  startup, workflows, findings and active MCP servers. No pending-approval event
  or approval-response method was found in that API.
- `PreToolUse` runs before Bob's normal tool approval handler. The bundled hook
  guidance explicitly says `permissionDecision: "allow"` does not bypass normal
  command approval. Thus a phone-backed hook would still leave the IDE dialog.
- The existing companion MCP tools cannot observe or resolve an internal IDE
  approval. Switching modes does not change this API limitation.
- macOS rejected the attempted Apple Events access to System Events (`-1743`).
  Reading and controlling the approval UI has therefore not been validated.

IBM's public [lifecycle hook documentation](https://bob.ibm.com/docs/ide/configuration/lifecycle-hooks)
describes pre-tool blocking but no native approval-response interface.
[Bob Shell ACP](https://bob.ibm.com/docs/shell/features/acp) is a separate integration
route; it is not an attachment to the already-running IDE chat.

## Next implementation step

First obtain user-enabled macOS UI access and inspect whether Bob exposes the
pending request text and buttons through Accessibility. A local Mac adapter is
only viable if it can identify the exact request reliably. Do not promise this
before inspecting the actual Accessibility tree.

Required adapter behavior:

1. Identify the Bob application, workspace/window, current task and exact pending
   request. Preserve the complete command or edit details; do not approve a
   truncated representation.
2. Forward that request through the existing companion connection. Do not connect
   a second Bob peer to the same relay room and displace the MCP server.
3. Before applying the phone response, verify the original request is still
   pending and unchanged. A desktop answer, cancellation, changed dialog or
   expiry invalidates the phone response.
4. Apply only the selected native action. Offer task-wide approval only if its
   exact native scope is available. Never enable global auto-approval.
5. Send the phone's completion acknowledgement only after the native dialog
   accepts the action. Receiving a response at the relay is not confirmation
   that the IDE applied it.
6. If UI access is unavailable or ambiguous, leave the IDE request pending and
   report that no action was applied.

No native approval adapter is installed or implemented yet. The currently working
MCP pairing and explicit phone decisions remain separate from this missing path.
