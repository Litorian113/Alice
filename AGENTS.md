# Agent guide

Monorepo for Alice, the phone companion for IBM Bob.

- **iOS app** (`ios/`): read [ios/AGENTS.md](ios/AGENTS.md) and [ios/HANDOFF.md](ios/HANDOFF.md) first. They contain Franz's working agreements (in German).
- **Backend** (`backend/`): Node MCP server + relay. Read [backend/README.md](backend/README.md). Run `npm test` in `backend/` after changes.
- **Contract** between the two: [docs/PROTOCOL.md](docs/PROTOCOL.md). Change it together with the code on both sides.
- Never commit `.env` or `.bob/companion-session.json` (pairing secrets).
