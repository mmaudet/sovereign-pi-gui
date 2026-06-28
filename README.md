# sovereign-pi-gui

Faire tourner un **LLM auto-hébergé compatible OpenAI** (ici `Ornith-1.0-35B` servi par vLLM sur
RunPod) à l'intérieur de l'agent de code [`pi`](https://www.npmjs.com/package/@earendil-works/pi-coding-agent),
aussi bien dans le **CLI terminal** que dans l'**application de bureau pi-gui**, avec les mêmes skills
et extensions de sécurité qu'on aurait sur un serveur. **Sans forker pi-gui ni le recompiler** : tout se
joue dans la configuration sous `~/.pi/agent`.

> Vérifié sur macOS avec pi `0.80.2`. Les mêmes étapes fonctionnent sous Linux.

## But

`pi` est livré avec des fournisseurs cloud (OpenAI, Anthropic…). Pour le pointer vers **votre propre
endpoint**, on enregistre un **fournisseur personnalisé** (custom provider) via une petite extension.
L'interface de pi-gui n'offre pas de formulaire « ajouter un provider », **mais** son runtime lit le
**même** fichier `~/.pi/agent/settings.json` que le CLI : enregistrer le provider une seule fois
l'active donc dans les deux surfaces.

## Opération (comment ça marche)

```
            ~/.pi/agent/settings.json   ← packages: [ ornith-provider, superpowers, … ]
                      │  (agent dir partagé)
        ┌─────────────┴─────────────┐
   pi (CLI)                    pi-gui (bureau Electron)
        │                            │
        └──────────► endpoint compatible OpenAI (vLLM / LM Studio / Ollama / RunPod)
```

Les deux runtimes résolvent `getAgentDir()` → `~/.pi/agent`. pi-gui ne le surcharge pas (il ne définit
que son propre dossier `userData` Electron) : il suffit donc de **remplir ce seul dossier**.

## Ce que vous obtenez

| Groupe | Éléments |
|------|----------|
| Provider | `ornith` → `Ornith-1.0-35B` (OpenAI Chat Completions, 131K de contexte, raisonnement) |
| Skills process (14) | [obra/superpowers](https://github.com/obra/superpowers) |
| Skills créatives (6) | frontend-design, web-artifacts-builder, **webapp-testing** (tests E2E Playwright), theme-factory, brand-guidelines, canvas-design (depuis [anthropics/skills](https://github.com/anthropics/skills)) |
| Sécurité (5) | notify, protected-paths, confirm-destructive, dirty-repo-guard, auto-commit-on-exit |
| TUI (3) | status-line, model-status, custom-footer |
| Subagents | délégation à contexte isolé (agents scout/planner/worker/reviewer sur Ornith) + workflow `/implement` |

Après installation, `pi list` affiche **11 paquets** et un prompt d'une ligne énumère **20 skills**.

## Commandes

### 1. Renseigner l'endpoint (ne jamais committer la clé)

```bash
cp .env.example .env
"$EDITOR" .env                 # renseignez ORNITH_BASE_URL et ORNITH_API_KEY
set -a; . ./.env; set +a       # charge les variables dans le shell courant
```

### 2. Lancer l'installateur idempotent

```bash
./scripts/mirror-setup.sh
```

Réexécuter le script est sans risque : `pi install` ignore les paquets déjà enregistrés.

### 3. Vérifier

```bash
pi --list-models ornith
echo "list all skills you have available" | pi --provider ornith --model Ornith-1.0-35B --print --thinking off
```

La deuxième commande doit lister **20 skills** (14 « Process & Meta » + 6 « Creative & Design »).

### Ce que fait le script, en clair

```bash
# le provider Ornith (lit ORNITH_BASE_URL / ORNITH_API_KEY)
pi install ./extensions/ornith-provider.ts

# 14 skills de process
pi install git:github.com/obra/superpowers

# 6 skills créatives Anthropic : clone du repo + wrapper qui les enregistre
git clone --depth 1 https://github.com/anthropics/skills.git \
  ~/.pi/agent/git/github.com/anthropics/skills
pi install ./extensions/anthropic-skills-pack.ts

# 5 extensions de sécurité + 3 extensions TUI (exemples fournis avec le SDK)
EX=$(npm config get prefix)/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions
for e in notify protected-paths confirm-destructive dirty-repo-guard auto-commit-on-exit \
         status-line model-status custom-footer; do
  pi install "$EX/$e.ts"
done
```

## pi-gui (bureau)

Après le script, **quittez complètement pi-gui (⌘Q) puis rouvrez-le**, et ouvrez le sélecteur de
modèle : `ornith · Ornith 1.0 35B MoE` y figure.

Pourquoi ça marche tout seul (et un piège à éviter) :
- Le sélecteur affiche **tous les modèles _disponibles_ quand aucune liste blanche n'est définie**,
  c.-à-d. quand `enabledModelPatterns` est vide (`composer-commands.ts` : `length === 0 ⇒ tout afficher`).
  Un provider personnalisé qui porte une clé API est « disponible » → il apparaît automatiquement.
- ⚠️ **N'ajoutez pas** `enabledModels` dans un `.pi/settings.json` de workspace, sauf si vous le voulez
  comme **liste blanche stricte** : une liste non vide **masque tous les modèles absents** de la liste
  (y compris les modèles gpt intégrés).
- Optionnel : pré-sélectionner ornith comme modèle par défaut d'un workspace en copiant
  [`pi-gui/workspace-settings.example.json`](pi-gui/workspace-settings.example.json) vers
  `<workspace>/.pi/settings.json`. Il ne définit que `defaultProvider` / `defaultModel`, sans impact
  sur la visibilité.

### Si ornith n'apparaît pas
1. Le CLI le voit-il ? `pi --list-models ornith`
2. L'endpoint répond-il ? `curl -sS "$ORNITH_BASE_URL/models" -H "Authorization: Bearer $ORNITH_API_KEY"`
3. Quittez **complètement** pi-gui (⌘Q, pas seulement fermer la fenêtre) pour que son runtime recharge
   l'agent dir.

## Tests E2E navigateur (Ornith)

Le test E2E en navigateur **headless** est déjà couvert côté pi : le skill **`webapp-testing`** (l'un
des 6 skills Anthropic ci-dessus) pilote **Playwright** pour tester des applications web locales. Il
permet de vérifier le fonctionnement d'un frontend, déboguer l'UI, capturer des screenshots et lire les
logs navigateur ; un helper `scripts/with_server.py` gère automatiquement le cycle de vie du ou des
serveurs (frontend + backend).

**Prérequis** (une seule fois) : Python avec Playwright.

```bash
pip install playwright
playwright install chromium
```

**Utilisation** : demandez à Ornith de tester votre application, par exemple :

```bash
echo "teste le formulaire de login sur http://localhost:5173 avec webapp-testing" \
  | pi --provider ornith --model Ornith-1.0-35B
```

Ornith écrit alors un script Playwright (chromium headless) et l'exécute via le helper de serveur.

> Note : `/browse` et `/qa` (gstack) sont des outils **Claude Code** séparés, pas des paquets `pi` ;
> ils ne font pas partie de ce dépôt.

## Subagents (délégation, contexte isolé)

Pour les tâches longues ou parallèles (par exemple la skill superpowers `subagent-driven-development`),
Ornith peut **déléguer** à des subagents : chacun s'exécute dans un **process `pi` isolé** avec son
propre contexte, ce qui évite de gonfler le thread principal. L'outil `subagent` offre 3 modes (un
agent, parallèle, chaîné). Workflow-prompts fournis : `/implement` (scout → planner → worker),
`/scout-and-plan`, `/implement-and-review`.

**Piège d'installation** : installer l'extension via le **fichier** `index.ts`, pas le dossier. Le
dossier n'a pas de `package.json`, donc `pi install <dossier>` n'expose aucun outil :

```bash
EX=$(npm config get prefix)/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions
pi install "$EX/subagent/index.ts"
```

**Agents sur Ornith** : les agents d'exemple ciblent des modèles Claude ; sur un setup Ornith-only il
faut les repointer sur `ornith/Ornith-1.0-35B` dans `~/.pi/agent/agents/*.md` (le script
`mirror-setup.sh` le fait). Les workflow-prompts vont dans `~/.pi/agent/prompts/`.

### Limite de contexte (erreur 400)

Ornith a une fenêtre de **131072 tokens** (input + output combinés). Sur un thread qui grossit trop on
voit : `400 ... maximum context length is 131072 ... N output + M input`. Deux leviers :

- `maxTokens` du provider est réglé à **16384** (au lieu de 32768) pour laisser de la marge à l'input.
- Pour les longues sessions : **déléguer aux subagents** (contexte isolé) et utiliser `/compact` ou un
  nouveau thread. La progression d'un flux SDD vit dans des fichiers (`.superpowers/sdd/progress.md`),
  donc un nouveau thread reprend où on en était.

## Fichiers

- [`extensions/ornith-provider.ts`](extensions/ornith-provider.ts) : le provider personnalisé. Lit
  `ORNITH_BASE_URL` / `ORNITH_API_KEY` depuis l'environnement ; modifiez le bloc `models` pour un autre modèle.
- [`extensions/anthropic-skills-pack.ts`](extensions/anthropic-skills-pack.ts) : enregistre les skills
  anthropics/skills choisies via le hook `resources_discover` (pointe sur chaque `SKILL.md`).
- [`scripts/mirror-setup.sh`](scripts/mirror-setup.sh) : installateur idempotent de tout ce qui précède.
- [`pi-gui/workspace-settings.example.json`](pi-gui/workspace-settings.example.json) : fichier optionnel
  de modèle par défaut, par workspace.

## Crédits

Construit sur [`@earendil-works/pi-coding-agent`](https://github.com/earendil-works/pi-mono),
[obra/superpowers](https://github.com/obra/superpowers) et [anthropics/skills](https://github.com/anthropics/skills).
