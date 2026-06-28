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
| Skills créatives (6) | frontend-design, web-artifacts-builder, webapp-testing, theme-factory, brand-guidelines, canvas-design (depuis [anthropics/skills](https://github.com/anthropics/skills)) |
| Sécurité (5) | notify, protected-paths, confirm-destructive, dirty-repo-guard, auto-commit-on-exit |
| TUI (3) | status-line, model-status, custom-footer |

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
