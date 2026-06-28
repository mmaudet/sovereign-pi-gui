# sovereign-pi-gui

Run a **self-hosted, OpenAI-compatible LLM** (here: `Ornith-1.0-35B` on vLLM/RunPod) inside the
[`pi`](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) coding agent — both the
**terminal CLI** and the **pi-gui desktop app** — with the same skills and safety extensions you'd
run on a server. No fork of pi-gui, no rebuild: everything is config under `~/.pi/agent`.

> Verified on macOS with pi `0.80.2`. The same steps work on Linux.

## Why

`pi` ships with cloud providers (OpenAI, Anthropic, …). To point it at *your own* endpoint you register
a **custom provider extension**. pi-gui's UI has no "add custom provider" form — but its runtime reads
the **same** `~/.pi/agent/settings.json` as the CLI, so registering the provider once lights it up in
both surfaces.

## Architecture

```
            ~/.pi/agent/settings.json   ← packages: [ ornith-provider, superpowers, … ]
                      │  (shared agent dir)
        ┌─────────────┴─────────────┐
   pi (CLI)                    pi-gui (Electron desktop)
        │                            │
        └──────────► OpenAI-compatible endpoint (vLLM / LM Studio / Ollama / RunPod)
```

Both runtimes resolve `getAgentDir()` → `~/.pi/agent`. pi-gui does **not** override it (it only sets
its own Electron `userData` dir), so populating that one directory is all it takes.

## What you get

| Group | Items |
|------|-------|
| Provider | `ornith` → `Ornith-1.0-35B` (OpenAI Chat Completions, 131K context, reasoning) |
| Process skills (14) | [obra/superpowers](https://github.com/obra/superpowers) |
| Creative skills (6) | frontend-design, web-artifacts-builder, webapp-testing, theme-factory, brand-guidelines, canvas-design — from [anthropics/skills](https://github.com/anthropics/skills) |
| Safety (5) | notify, protected-paths, confirm-destructive, dirty-repo-guard, auto-commit-on-exit |
| TUI (3) | status-line, model-status, custom-footer |

After install, `pi list` shows **11 packages** and a one-line prompt enumerates **20 skills**.

## Quick start

```bash
# 1. Point at your endpoint (never commit the key)
cp .env.example .env && "$EDITOR" .env
set -a; . ./.env; set +a

# 2. Run the idempotent installer
./scripts/mirror-setup.sh

# 3. Verify
pi --list-models ornith
echo "list all skills you have available" | pi --provider ornith --model Ornith-1.0-35B --print --thinking off
```

Re-running `mirror-setup.sh` is safe — `pi install` skips packages already registered.

## pi-gui (desktop)

After running the installer, **fully quit (⌘Q) and reopen pi-gui**, then open the model picker —
`ornith · Ornith 1.0 35B MoE` is there.

Why it just works (and a footgun to avoid):
- The picker shows **every _available_ model when no allowlist is set** — i.e. when
  `enabledModelPatterns` is empty (`composer-commands.ts`: `enabledPatterns.length === 0 ⇒ show all`).
  A registered custom provider that carries an API key is "available", so it appears automatically.
- ⚠️ **Do not** add `enabledModels` to a workspace `.pi/settings.json` unless you intend it as a strict
  **allowlist** — a non-empty list **hides every model not in it**, including the gpt built-ins.
- Optional nicety: pre-select ornith as a workspace's default by copying
  [`pi-gui/workspace-settings.example.json`](pi-gui/workspace-settings.example.json) to
  `<workspace>/.pi/settings.json`. It sets only `defaultProvider` / `defaultModel` — zero visibility impact.

### If ornith doesn't appear
1. CLI sees it? `pi --list-models ornith`
2. Endpoint alive? `curl -sS "$ORNITH_BASE_URL/models" -H "Authorization: Bearer $ORNITH_API_KEY"`
3. **Fully** quit pi-gui (⌘Q — not just closing the window) so its runtime reloads the agent dir.

## Files

- [`extensions/ornith-provider.ts`](extensions/ornith-provider.ts) — the custom provider. Reads
  `ORNITH_BASE_URL` / `ORNITH_API_KEY` from the environment; edit the model block for a different model.
- [`extensions/anthropic-skills-pack.ts`](extensions/anthropic-skills-pack.ts) — registers selected
  anthropics/skills with pi via the `resources_discover` hook (points at each `SKILL.md`).
- [`scripts/mirror-setup.sh`](scripts/mirror-setup.sh) — idempotent installer for everything above.
- [`pi-gui/workspace-settings.example.json`](pi-gui/workspace-settings.example.json) — optional
  per-workspace default-model file.

## Security

- The provider key is read from `ORNITH_API_KEY` — keep it in `.env` (git-ignored), never in the repo.
- Rotate the key if it has ever been shared in plaintext.

## Credits

Built on [`@earendil-works/pi-coding-agent`](https://github.com/earendil-works/pi-mono),
[obra/superpowers](https://github.com/obra/superpowers), and [anthropics/skills](https://github.com/anthropics/skills).
