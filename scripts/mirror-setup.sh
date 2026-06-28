#!/usr/bin/env bash
#
# Idempotent installer for a "sovereign Pi" setup.
# Populates ~/.pi/agent so BOTH the pi CLI and pi-gui pick up the same provider + skills.
# Re-running is safe: `pi install` skips packages already in the settings list.
#
# Before running, export your endpoint creds (or put them in .env and `set -a; . ./.env; set +a`):
#   ORNITH_BASE_URL=https://your-endpoint/v1
#   ORNITH_API_KEY=...
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Pi CLI itself (skip if already installed)
if ! command -v pi >/dev/null 2>&1; then
  echo "==> installing @earendil-works/pi-coding-agent globally"
  npm install -g @earendil-works/pi-coding-agent
fi

PREFIX="$(npm config get prefix)"
PI="$PREFIX/bin/pi"
EX="$PREFIX/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions"

# 2. Custom Ornith provider (override the file path with ORNITH_PROVIDER_FILE if you keep it elsewhere)
echo "==> provider: ornith"
"$PI" install "${ORNITH_PROVIDER_FILE:-$HERE/extensions/ornith-provider.ts}"

# 3. Superpowers: 14 process skills
echo "==> skills: obra/superpowers"
"$PI" install git:github.com/obra/superpowers

# 4. Anthropic creative/design skills: clone repo, then install the wrapper extension
SKILLS_DIR="$HOME/.pi/agent/git/github.com/anthropics/skills"
echo "==> skills: anthropics/skills"
if [ -d "$SKILLS_DIR/.git" ]; then
  git -C "$SKILLS_DIR" pull --ff-only || true
else
  mkdir -p "$(dirname "$SKILLS_DIR")"
  git clone --depth 1 https://github.com/anthropics/skills.git "$SKILLS_DIR"
fi
"$PI" install "$HERE/extensions/anthropic-skills-pack.ts"

# 5. Safety (5) + TUI (3) bundled example extensions
echo "==> extensions: safety + TUI"
for ext in notify protected-paths confirm-destructive dirty-repo-guard auto-commit-on-exit \
           status-line model-status custom-footer; do
  if [ -f "$EX/$ext.ts" ]; then
    "$PI" install "$EX/$ext.ts"
  else
    echo "    WARN: $EX/$ext.ts not found (SDK version mismatch?), skipping" >&2
  fi
done

# 6. Subagents: delegation tool (isolated context per task) + Ornith-pointed agents
echo "==> subagent + agents (Ornith)"
"$PI" install "$EX/subagent/index.ts"   # the FILE, not the dir (the dir has no package.json -> nothing loads)
mkdir -p "$HOME/.pi/agent/agents" "$HOME/.pi/agent/prompts"
for f in "$EX"/subagent/agents/*.md; do
  sed -E 's#^model:[[:space:]].*#model: ornith/Ornith-1.0-35B#' "$f" > "$HOME/.pi/agent/agents/$(basename "$f")"
done
cp "$EX"/subagent/prompts/*.md "$HOME/.pi/agent/prompts/" 2>/dev/null || true

# 7. Verify
echo "==> done. installed packages:"
"$PI" list
echo
echo "Try:  pi --list-models ornith"
echo "Try:  echo 'list all skills you have available' | pi --provider ornith --model Ornith-1.0-35B --print --thinking off"
