[English](README.md) | [中文](README-zh.md) | [Deutsch](README-de.md) | [Français](README-fr.md) | [Русский](README-ru.md)

# pattern-review

Pattern-Prüfungsausschuss für Claude Code — analysiert `~/.claude/patterns/`-Dateien auf Vollständigkeit, Instanziierbarkeit und Konsistenz, und behebt unbestrittene Probleme automatisch.

```
/pattern-review:pattern-review [--quick] [--regression] [all|<name>]
```

---

## Funktionsweise

`pattern-review` startet einen sechsköpfigen Prüfungsausschuss, der Ihre Workflow-Pattern-Dateien in `~/.claude/patterns/` untersucht. Jedes Mitglied deckt eine eigene Prüfdimension ab:

| Mitglied | Aufgabe | Modell |
|----------|---------|--------|
| P1 | Vollständigkeitsprüfung (Pflichtabschnitte, Rollentabellen) | sonnet |
| P2 | Instanziierbarkeit (Kickoff-Prompt, Agent-Existenz, I/O-Verträge) | sonnet |
| P3 | Interne Konsistenz (Rollennamen, Dateinamen, Variablenreferenzen) | sonnet |
| P4 | Externe Recherche (Vergleich mit LangGraph, AutoGen, Anthropic Best Practices) | sonnet |
| Challenger | Adversarielle Verifikation — widerlegt schwache Befunde | opus |
| Reporter | Berichtserstellung + automatische Korrektur bestätigter Probleme | sonnet |

Der Ausschuss läuft in zwei Stufen: Stage 1 (parallele Prüfung) → Stage 2 (Challenger + Reporter). Der Reporter bearbeitet Pattern-Dateien direkt zur Behebung unbestrittener P0/P1-Probleme.

---

## Installation

### Option A — Claude Code Plugin-Marktplatz (empfohlen)

```
/plugin marketplace add easyfan/pattern-review
/plugin install pattern-review@pattern-review
```

> ⚠️ **Teilweise durch automatisierte Tests abgedeckt**: Der zugrunde liegende `claude plugin install` CLI-Pfad wird durch looper T2b (Plan B) verifiziert. Der `/plugin` REPL-Einstiegspunkt (interaktive UI) kann nicht via `claude -p` getestet werden und muss manuell in einer Claude Code-Sitzung überprüft werden.

> **Bei `ENAMETOOLONG`-Fehlern** ist der Plugin-Cache durch einen CC-Runtime-Bug beschädigt. Reparatur:
> ```bash
> git clone https://github.com/easyfan/pattern-review && cd pattern-review && bash install.sh
> ```
> Der Installer erkennt und repariert den beschädigten Cache automatisch.

> ⚠️ **Option A installiert nur den Skill** (`~/.claude/skills/`). `/plugin install` kopiert das `agents/`-Verzeichnis nicht. Für den vollständigen Ausschussmodus Option B oder C verwenden.

### Option B — Installationsskript

```bash
git clone https://github.com/easyfan/pattern-review
cd pattern-review
bash install.sh
```

```bash
# Optionen
bash install.sh --dry-run           # Vorschau ohne Schreibzugriff
bash install.sh --uninstall         # Installierte Dateien entfernen
bash install.sh --target=~/.claude  # Benutzerdefiniertes Claude-Verzeichnis
CLAUDE_DIR=~/.claude bash install.sh
```

Installiert:
- `agents/*.md      → ~/.claude/agents/`
- `skills/pattern-review/ → ~/.claude/skills/pattern-review/`

> ✅ **Verifiziert**: Abgedeckt durch die skill-test-Pipeline (looper Stage 5).

### Option C — Manuell

```bash
cp -r skills/pattern-review ~/.claude/skills/
cp agents/*.md              ~/.claude/agents/
```

> ✅ **Verifiziert**: Abgedeckt durch die skill-test-Pipeline (looper Stage 5).

---

## Verwendung

```
/pattern-review:pattern-review [--quick] [--regression] [all|<name>,<name>]
```

| Argument | Beschreibung |
|----------|--------------|
| _(kein)_ oder `all` | Alle Pattern-Dateien in `~/.claude/patterns/` prüfen |
| `<name>` | Einzelnes Pattern prüfen |
| `<n>,<m>` | Kommagetrennte Liste von Pattern-Namen |
| `--quick` | Triage-Modus: Inline-Scan, keine Agents gestartet |
| `--regression` | Regressionsmodus: Nur P1+P2, P3/P4/Challenger übersprungen |

**Beispiele:**

```
/pattern-review:pattern-review all                   # Vollständige Ausschusskontrolle
/pattern-review:pattern-review agent-monitoring      # Einzelnes Pattern
/pattern-review:pattern-review --quick all           # Schnelle Gate-Prüfung
/pattern-review:pattern-review --regression all      # Leichtgewichtige Wiederholung
```

---

## Installierte Dateien

**Option A — Plugin-Installation:**
```
~/.claude/
└── skills/
    └── pattern-review/
        └── SKILL.md
```

**Option B/C — Skript / Manuell:**
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

## Paketstruktur

```
pattern-review/
├── .claude-plugin/
│   ├── plugin.json           # Plugin-Manifest
│   └── marketplace.json      # Marktplatz-Eintrag
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
├── install.sh                # Einstiegspunkt (delegiert an scripts/install.sh)
└── scripts/
    └── install.sh            # Installerlogik
```

---

## Voraussetzungen

- **Claude Code** CLI
- Keine weiteren Abhängigkeiten

---

## Hinweise

- Der Reporter **bearbeitet Pattern-Dateien direkt** für unbestrittene Korrekturen. Änderungen vor der Ausführung committen.
- Gleichzeitige Ausführung nicht unterstützt — parallele Instanzen überschreiben gegenseitig ihre Scratch-Dateien. Eine Lockfile-Absicherung erkennt und blockiert dies automatisch.
- `--quick`-Modus läuft inline (keine Agents), in der Regel unter 5 Sekunden.
- **Option A installiert nur den Skill** (`~/.claude/skills/`). Für vollständige Installation Option B oder C verwenden.

---

## Lizenz

MIT
