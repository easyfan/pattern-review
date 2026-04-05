[English](README.md) | [中文](README-zh.md) | [Deutsch](README-de.md) | [Français](README-fr.md) | [Русский](README-ru.md)

# pattern-review

Comité d'audit de patterns pour Claude Code — inspecte les fichiers `~/.claude/patterns/` pour détecter les problèmes de complétude, d'instanciabilité et de cohérence, et corrige automatiquement les défauts non contestés.

```
/pattern-review:pattern-review [--quick] [--regression] [all|<nom>]
```

---

## Fonctionnement

`pattern-review` lance un comité de révision de six membres qui inspecte vos fichiers de pattern de workflow dans `~/.claude/patterns/`. Chaque membre couvre une dimension d'audit distincte :

| Membre | Rôle | Modèle |
|--------|------|--------|
| P1 | Auditeur de complétude (sections obligatoires, tables de rôles) | sonnet |
| P2 | Auditeur d'instanciabilité (Kickoff prompt, existence des agents, contrats I/O) | sonnet |
| P3 | Auditeur de cohérence interne (noms de rôles, noms de fichiers, références de variables) | sonnet |
| P4 | Spécialiste en recherche externe (comparaison avec LangGraph, AutoGen, bonnes pratiques Anthropic) | sonnet |
| Challenger | Vérificateur adversarial — conteste les résultats faibles | opus |
| Reporter | Générateur de rapport + correcteur automatique des problèmes confirmés | sonnet |

Le comité s'exécute en deux étapes : Stage 1 (audit parallèle) → Stage 2 (Challenger + Reporter). Le Reporter modifie directement les fichiers de pattern pour corriger les problèmes P0/P1 non contestés.

---

## Installation

### Option A — Place de marché Claude Code (recommandé)

```
/plugin marketplace add easyfan/pattern-review
/plugin install pattern-review@pattern-review
```

> ⚠️ **Partiellement couvert par des tests automatisés** : Le chemin CLI sous-jacent `claude plugin install` est vérifié par looper T2b (Plan B). Le point d'entrée REPL `/plugin` (interface interactive) ne peut pas être testé via `claude -p` et doit être vérifié manuellement dans une session Claude Code.

> **En cas d'erreur `ENAMETOOLONG`**, le cache du plugin est corrompu par un bug du runtime CC. Réparer avec :
> ```bash
> git clone https://github.com/easyfan/pattern-review && cd pattern-review && bash install.sh
> ```
> L'installeur détecte et répare automatiquement le cache corrompu.

> ⚠️ **L'option A installe uniquement le skill** (`~/.claude/skills/`). `/plugin install` ne copie pas le répertoire `agents/`. Utiliser l'option B ou C pour l'installation complète du mode comité.

### Option B — Script d'installation

```bash
git clone https://github.com/easyfan/pattern-review
cd pattern-review
bash install.sh
```

```bash
# Options
bash install.sh --dry-run           # aperçu sans écriture
bash install.sh --uninstall         # supprimer les fichiers installés
bash install.sh --target=~/.claude  # répertoire Claude personnalisé
CLAUDE_DIR=~/.claude bash install.sh
```

Installe :
- `agents/*.md      → ~/.claude/agents/`
- `skills/pattern-review/ → ~/.claude/skills/pattern-review/`

> ✅ **Vérifié** : couvert par le pipeline skill-test (looper Stage 5).

### Option C — Manuel

```bash
cp -r skills/pattern-review ~/.claude/skills/
cp agents/*.md              ~/.claude/agents/
```

> ✅ **Vérifié** : couvert par le pipeline skill-test (looper Stage 5).

---

## Utilisation

```
/pattern-review:pattern-review [--quick] [--regression] [all|<nom>,<nom>]
```

| Argument | Description |
|----------|-------------|
| _(aucun)_ ou `all` | Auditer tous les fichiers de pattern dans `~/.claude/patterns/` |
| `<nom>` | Auditer un seul pattern nommé |
| `<n>,<m>` | Liste de noms de patterns séparés par des virgules |
| `--quick` | Mode triage : scan inline uniquement, sans lancer d'agents |
| `--regression` | Mode régression : P1+P2 uniquement, P3/P4/Challenger ignorés |

**Exemples :**

```
/pattern-review:pattern-review all                   # révision complète du comité
/pattern-review:pattern-review agent-monitoring      # pattern unique
/pattern-review:pattern-review --quick all           # vérification rapide
/pattern-review:pattern-review --regression all      # re-vérification légère
```

---

## Fichiers installés

**Option A — installation via plugin :**
```
~/.claude/
└── skills/
    └── pattern-review/
        └── SKILL.md
```

**Option B/C — script / manuel :**
```
~/.claude/
├── agents/
│   ├── pattern-reviewer-p1.md
│   ├── pattern-reviewer-p2.md
│   ├── pattern-reviewer-p3.md
│   ├── pattern-researcher.md
│   ├── pattern-challenger.md
│   └── pattern-reporter.md
└── skills/
    └── pattern-review/
        └── SKILL.md
```

---

## Structure du paquet

```
pattern-review/
├── .claude-plugin/
│   ├── plugin.json           # manifest du plugin
│   └── marketplace.json      # entrée marketplace
├── agents/
│   ├── pattern-reviewer-p1.md
│   ├── pattern-reviewer-p2.md
│   ├── pattern-reviewer-p3.md
│   ├── pattern-researcher.md
│   ├── pattern-challenger.md
│   └── pattern-reporter.md
├── skills/pattern-review/
│   └── SKILL.md
├── evals/evals.json
├── install.sh                # point d'entrée (délègue à scripts/install.sh)
└── scripts/
    └── install.sh            # logique d'installation
```

---

## Prérequis

- **Claude Code** CLI
- Aucune dépendance supplémentaire

---

## Notes

- Le Reporter **modifie directement** les fichiers de pattern pour les corrections non contestées. Commitez vos modifications avant d'exécuter.
- L'exécution simultanée n'est pas supportée — des instances parallèles s'écrasent mutuellement les fichiers scratch. Un verrou (lockfile) intégré détecte et bloque cela automatiquement.
- Le mode `--quick` s'exécute en ligne (sans agents), en général en moins de 5 secondes.
- **L'option A installe uniquement le skill** (`~/.claude/skills/`). Pour une installation complète, utiliser l'option B ou C.

---

## Licence

MIT
