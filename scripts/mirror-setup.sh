#!/usr/bin/env bash
#
# Idempotent installer for a "sovereign Pi" setup (Ornith on a self-hosted endpoint).
# Populates ~/.pi/agent so BOTH the pi CLI and pi-gui pick up the same provider + skills.
# Re-running is safe.
#
# Set your endpoint + key first (or edit the defaults below):
#   export ORNITH_BASE_URL=https://your-endpoint/v1
#   export ORNITH_API_KEY=...
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Pi CLI (skip if already installed)
if ! command -v pi >/dev/null 2>&1; then
  echo "==> installing @earendil-works/pi-coding-agent globally"
  npm install -g @earendil-works/pi-coding-agent
fi
PREFIX="$(npm config get prefix)"
PI="$PREFIX/bin/pi"
EX="$PREFIX/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions"

# 2. Ornith provider via NATIVE models.json (data, not code).
#    This is the documented way (docs/models.md) and works in BOTH the CLI and pi-gui.
#    We deliberately do NOT use a provider extension (pi.registerProvider): it pulls in pi-tui and
#    CRASHES pi-gui's Electron runtime. models.json is plain data, so it cannot crash anything.
#    NOTE: for pi-gui launched from the Finder, apiKey must be a LITERAL (GUI apps have no shell env).
echo "==> provider: ornith (native models.json)"
mkdir -p "$HOME/.pi/agent"
ORNITH_BASE_URL="${ORNITH_BASE_URL:-https://YOUR-ENDPOINT/v1}"
ORNITH_API_KEY="${ORNITH_API_KEY:-REPLACE_WITH_YOUR_KEY}"
python3 - "$HOME/.pi/agent/models.json" "$ORNITH_BASE_URL" "$ORNITH_API_KEY" <<'PY'
import json, sys, os
path, base, key = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except Exception:
        data = {}
data.setdefault("providers", {})["ornith"] = {
    "baseUrl": base,
    "api": "openai-completions",
    "apiKey": key,
    "models": [{
        "id": "Ornith-1.0-35B",
        "name": "Ornith 1.0 35B MoE",
        "reasoning": True,
        "input": ["text"],
        "contextWindow": 131072,
        "maxTokens": 16384,
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
    }],
}
json.dump(data, open(path, "w"), indent=2)
print("wrote", path)
PY

# 3. Superpowers (14 process skills)
echo "==> skills: obra/superpowers"
"$PI" install git:github.com/obra/superpowers

# 4. Anthropic creative/design skills (6) via wrapper
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
    echo "    skip $ext (not found)" >&2
  fi
done

# 6. Verify
echo "==> done. installed packages:"
"$PI" list
echo
echo "Try:  pi --list-models ornith"
echo "In pi-gui: the model appears in the composer MODEL PICKER (not the Providers settings page)."
