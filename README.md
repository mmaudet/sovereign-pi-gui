# sovereign-pi-gui

Faire tourner un **LLM auto-hébergé compatible OpenAI** (ici `Ornith-1.0-35B` servi par vLLM sur
RunPod) à l'intérieur de l'agent de code [`pi`](https://www.npmjs.com/package/@earendil-works/pi-coding-agent),
aussi bien dans le **CLI terminal** que dans l'**application de bureau pi-gui**, avec les mêmes skills
qu'on aurait sur un serveur. **Sans forker pi-gui ni le recompiler.**

> Vérifié sur macOS avec pi `0.80.2` et pi-gui `0.1.0-beta.28`.

## Le sujet en deux phrases

pi-gui n'a **pas encore d'interface** pour brancher un endpoint OpenAI-compatible (Ollama, vLLM, LM
Studio…). Mais son moteur sait déjà lire des providers custom depuis un fichier `~/.pi/agent/models.json` :
en l'écrivant à la main, on obtient le modèle dans pi-gui **dès aujourd'hui**, en attendant que l'UI
correspondante soit mergée en amont.

## Statut côté pi-gui (amont)

Deux fils suivent le sujet, **non mergés** à ce jour :

- **[PR #14 : Add OpenAI-compatible custom endpoints (Ollama, vLLM, etc.)](https://github.com/minghinmatthewlam/pi-gui/pull/14)**
  ajoute une section « Custom endpoints » dans Réglages > Providers, adossée à un `CustomProviderStore`
  qui écrit dans `~/.pi/agent/models.json`. État : **ouverte, en conflit**.
- **[Issue #24 : Feature: Local LLM Provider Support](https://github.com/minghinmatthewlam/pi-gui/issues/24)**
  porte la demande générale (offline, Ollama, vLLM, budget).

Le **backend existe déjà** dans le SDK : `RuntimeSupervisor` expose les modèles via
`modelRegistry.getAll()`, qui lit `~/.pi/agent/models.json`. Ce qui manque tant que la PR #14 n'est pas
mergée, c'est **uniquement le formulaire** dans les Réglages. La donnée, elle, est déjà prise en compte.

> **Pourquoi pas une extension ?** On peut aussi enregistrer un provider via une extension
> (`pi.registerProvider`), et ça marche en CLI. Mais cette voie tire `pi-tui` (prévu pour un terminal)
> et **fait crasher le runtime Electron de pi-gui** (`EXC_BREAKPOINT` au chargement). `models.json` est
> de la donnée pure : il ne peut rien crasher. On utilise donc `models.json`.

## Procédure pas-à-pas (en attendant la PR #14)

### 1. Écrire le provider dans `~/.pi/agent/models.json`

Créez le fichier s'il n'existe pas :

```json
{
  "providers": {
    "ornith": {
      "baseUrl": "https://VOTRE-ENDPOINT/v1",
      "api": "openai-completions",
      "apiKey": "VOTRE-CLE-EN-CLAIR",
      "models": [
        {
          "id": "Ornith-1.0-35B",
          "name": "Ornith 1.0 35B MoE",
          "reasoning": true,
          "input": ["text"],
          "contextWindow": 131072,
          "maxTokens": 16384,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    }
  }
}
```

> **Clé en clair obligatoire pour pi-gui.** Une app lancée par le Finder n'hérite pas des variables
> d'environnement du shell, donc `"$ORNITH_API_KEY"` ne serait pas résolu. Mettez la clé littérale.
> Le fichier est sous `~/.pi/agent/` (privé à votre compte, comme `settings.json`). En CLI uniquement,
> `"$ORNITH_API_KEY"` fonctionne aussi.

### 2. Vérifier en CLI

```bash
pi --list-models ornith
```

Doit afficher une ligne `ornith  Ornith-1.0-35B  131.1K  16.4K  yes  no`.

### 3. Relancer pi-gui

**Quittez complètement pi-gui (⌘Q, pas juste fermer la fenêtre) et rouvrez-le** pour qu'il recharge
`models.json`.

### 4. Choisir le modèle dans le composer

Ouvrez/créez un thread, puis ouvrez le **sélecteur de modèle** en bas du composer et choisissez
**Ornith 1.0 35B MoE**.

> ⚠️ **Ne cherchez pas ornith dans Réglages > Providers** : cette page ne liste que les providers à
> clé/OAuth intégrés. Tant que la PR #14 n'est pas mergée, l'endpoint custom n'y apparaît pas, mais il
> est bien disponible dans le sélecteur de modèle. Quand la PR sera mergée, la même config sera
> éditable depuis Réglages > Providers > « Custom endpoints » (format `models.json` identique).

## Opération (comment ça marche)

```
            ~/.pi/agent/models.json   ← providers: { ornith: { baseUrl, apiKey, models[] } }
                      │  (agent dir partagé)
        ┌─────────────┴─────────────┐
   pi (CLI)                    pi-gui (bureau Electron)
        │                            │
        └──────────► endpoint compatible OpenAI (vLLM / LM Studio / Ollama / RunPod)
```

Les deux runtimes lisent les modèles via le même `ModelRegistry` (`~/.pi/agent/models.json`).

## Ce que vous obtenez

| Groupe | Éléments |
|------|----------|
| Provider | `ornith` → `Ornith-1.0-35B` (OpenAI Chat Completions, 131K de contexte, raisonnement), via `models.json` |
| Skills process (14) | [obra/superpowers](https://github.com/obra/superpowers) |
| Skills créatives (6) | frontend-design, web-artifacts-builder, **webapp-testing** (tests E2E Playwright), theme-factory, brand-guidelines, canvas-design (depuis [anthropics/skills](https://github.com/anthropics/skills)) |
| Sécurité (5) | notify, protected-paths, confirm-destructive, dirty-repo-guard, auto-commit-on-exit |
| TUI (3) | status-line, model-status, custom-footer |

## Installation automatisée

Plutôt que les étapes manuelles ci-dessus, le script fait tout (provider `models.json` + skills) de
façon idempotente :

```bash
cp .env.example .env
"$EDITOR" .env                 # ORNITH_BASE_URL et ORNITH_API_KEY
set -a; . ./.env; set +a
./scripts/mirror-setup.sh
```

Puis vérification complète :

```bash
pi --list-models ornith
echo "list all skills you have available" | pi --provider ornith --model Ornith-1.0-35B --print --thinking off
```

## Limite de contexte (erreur 400)

Ornith a une fenêtre de **131072 tokens** (input + output combinés). Sur un thread qui grossit trop on
voit `400 ... maximum context length is 131072`. Pour l'éviter : `maxTokens` est réglé à **16384** (au
lieu de 32768) pour laisser de la marge à l'input ; pour les longues sessions, utilisez `/compact` ou
démarrez un nouveau thread.

## Tests E2E navigateur (Ornith)

Le skill **`webapp-testing`** (l'un des 6 skills Anthropic) pilote **Playwright** (chromium headless)
pour tester des applications web locales : vérifier un frontend, déboguer l'UI, screenshots, logs ; un
helper `scripts/with_server.py` gère le cycle de vie des serveurs. Prérequis : `pip install playwright`
puis `playwright install chromium`.

## Fichiers

- [`models.json.example`](models.json.example) : le provider ornith au format `models.json` (à copier
  vers `~/.pi/agent/models.json`).
- [`extensions/anthropic-skills-pack.ts`](extensions/anthropic-skills-pack.ts) : enregistre les skills
  anthropics/skills via le hook `resources_discover`.
- [`scripts/mirror-setup.sh`](scripts/mirror-setup.sh) : installateur idempotent (models.json + skills).
- [`pi-gui/workspace-settings.example.json`](pi-gui/workspace-settings.example.json) : modèle par défaut
  optionnel, par workspace.

## Crédits

Construit sur [`@earendil-works/pi-coding-agent`](https://github.com/earendil-works/pi-mono),
[obra/superpowers](https://github.com/obra/superpowers) et [anthropics/skills](https://github.com/anthropics/skills).
