#!/usr/bin/env bash
# Create a fresh, standalone copy of the demo app for Bob to work in.
#
#   demo/setup.sh [target-dir]        (default: ~/alice-demo)
#   RELAY_URL=ws://localhost:8787 demo/setup.sh /tmp/alice-demo   # against a local relay
#
# Bob treats the enclosing git root as its workspace, so the demo can't run inside
# this monorepo. This copies demo/sample-app out, makes it its own git repo (so Bob
# can commit), and writes .bob/ with an absolute path to backend/companion-mcp.
# Re-running resets the target to the original failing state but keeps the pairing
# (.bob/companion-session.json), so the phone doesn't have to scan again.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-$HOME/alice-demo}"
relay="${RELAY_URL:-wss://bob-relay.zeigma.com}"
server="$repo/backend/companion-mcp/index.js"

if [[ ! -d "$repo/backend/node_modules" ]]; then
  echo "Installing backend dependencies…"
  (cd "$repo/backend" && npm install --no-audit --no-fund >/dev/null)
fi

session=""
if [[ -f "$target/.bob/companion-session.json" ]]; then
  session="$(cat "$target/.bob/companion-session.json")"
fi

rm -rf "$target"
mkdir -p "$target"
cp -R "$repo/demo/sample-app/src" "$repo/demo/sample-app/test" "$repo/demo/sample-app/package.json" "$target/"
mkdir -p "$target/.bob"
cp "$repo/.bob/custom_modes.yaml" "$target/.bob/custom_modes.yaml"

cat > "$target/.bob/mcp.json" <<EOF
{
  "mcpServers": {
    "bob-companion": {
      "command": "node",
      "args": ["$server"],
      "env": {
        "RELAY_URL": "$relay",
        "COMPANION_SESSION_FILE": ".bob/companion-session.json",
        "COMPANION_QR": "web",
        "DECISION_TIMEOUT_S": "120",
        "MAX_DECISION_TIMEOUT_S": "540"
      },
      "timeout": 600000,
      "alwaysAllow": ["pair_phone", "ask_decision", "request_approval", "notify", "get_instruction"]
    }
  }
}
EOF

if [[ -n "$session" ]]; then
  printf '%s' "$session" > "$target/.bob/companion-session.json"
  chmod 600 "$target/.bob/companion-session.json"
fi

printf 'node_modules/\n.bob/companion-session.json\n' > "$target/.gitignore"
(
  cd "$target"
  git init -q -b main
  git add -A
  git -c user.name="Alice Demo" -c user.email="demo@example.invalid" commit -q -m "Initial demo app (tests failing)"
)

echo "Demo workspace ready: $target"
echo "  relay: $relay"
echo "  run:   cd $target && BOB_API_KEY=… bob run --mode companion \"The tests are failing. Fix them.\" < /dev/null"
