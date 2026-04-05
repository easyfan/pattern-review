[English](README.md) | [中文](README-zh.md) | [Deutsch](README-de.md) | [Français](README-fr.md) | [Русский](README-ru.md)

# pattern-review

Pattern Review Committee for Claude Code — audits `~/.claude/patterns/` files for completeness, instantiability, and consistency, then auto-fixes uncontested issues.

```
/pattern-review:pattern-review [--quick] [--regression] [all|<name>]
```

---

## What It Does

`pattern-review` launches a six-member review committee that inspects your workflow pattern files in `~/.claude/patterns/`. Each member covers a distinct audit dimension:

| Member | Role | Model |
|--------|------|-------|
| P1 | Completeness auditor (required sections, role tables) | sonnet |
| P2 | Instantiability auditor (Kickoff prompt, agent file existence, I/O contracts) | sonnet |
| P3 | Internal consistency auditor (role names, file names, variable references) | sonnet |
| P4 | External research specialist (benchmarks against LangGraph, AutoGen, Anthropic best practices) | sonnet |
| Challenger | Adversarial verifier — disputes weak findings | opus |
| Reporter | Report generator + auto-fixer for confirmed issues | sonnet |

The committee runs in two stages: Stage 1 (parallel audit) → Stage 2 (Challenger + Reporter). The Reporter directly edits pattern files to fix uncontested P0/P1 issues.

---

## Installation

### Option A — Claude Code Plugin Marketplace (recommended)

```
/plugin marketplace add easyfan/pattern-review
/plugin install pattern-review@pattern-review
```

> ⚠️ **Partially covered by automated tests**: The underlying `claude plugin install` CLI path is verified by looper T2b (Plan B). The `/plugin` REPL entry point (interactive UI) cannot be tested via `claude -p` and must be verified manually in a Claude Code session.

> **If you see `ENAMETOOLONG` errors**, the plugin cache has been corrupted by a CC runtime bug. Fix with:
> ```bash
> git clone https://github.com/easyfan/pattern-review && cd pattern-review && bash install.sh
> ```
> The installer detects and repairs the corrupt cache automatically.

> ⚠️ **Option A installs only the skill** (`~/.claude/skills/`). The bundled agents (`pattern-reviewer-p1`, etc.) are **not** copied to `~/.claude/agents/` by `/plugin install`. Use Option B or C to install the full agent set required for full-committee mode.

### Option B — Install script

```bash
git clone https://github.com/easyfan/pattern-review
cd pattern-review
bash install.sh
```

```bash
# Options
bash install.sh --dry-run           # preview without writing
bash install.sh --uninstall         # remove installed files
bash install.sh --target=~/.claude  # custom Claude config directory
CLAUDE_DIR=~/.claude bash install.sh
```

Installs:
- `agents/*.md      → ~/.claude/agents/`
- `skills/pattern-review/ → ~/.claude/skills/pattern-review/`

> ✅ **Verified**: covered by the skill-test pipeline (looper Stage 5).

### Option C — Manual

```bash
cp -r skills/pattern-review ~/.claude/skills/
cp agents/*.md              ~/.claude/agents/
```

> ✅ **Verified**: covered by the skill-test pipeline (looper Stage 5).

---

## Usage

```
/pattern-review:pattern-review [--quick] [--regression] [all|<name>,<name>]
```

| Argument | Description |
|----------|-------------|
| _(none)_ or `all` | Audit all pattern files in `~/.claude/patterns/` |
| `<name>` | Audit a single named pattern |
| `<n>,<m>` | Comma-separated list of pattern names |
| `--quick` | Triage mode: inline scan only, no agents launched |
| `--regression` | Regression mode: P1 + P2 only, skip P3/P4/Challenger |

**Examples:**

```
/pattern-review:pattern-review all                   # full committee review
/pattern-review:pattern-review agent-monitoring      # single pattern
/pattern-review:pattern-review --quick all           # fast gate check
/pattern-review:pattern-review --regression all      # lightweight re-check
```

---

## Installed Files

**Option A — plugin install:**
```
~/.claude/
└── skills/
    └── pattern-review/
        └── SKILL.md
```

**Option B/C — script / manual:**
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

## Package Structure

```
pattern-review/
├── .claude-plugin/
│   ├── plugin.json           # plugin manifest
│   └── marketplace.json      # marketplace entry
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
├── install.sh                # entry point (delegates to scripts/install.sh)
└── scripts/
    └── install.sh            # installer logic
```

---

## Requirements

- **Claude Code** CLI
- No additional dependencies

---

## Notes

- The Reporter **directly modifies** pattern files for uncontested fixes. Commit your work before running.
- Concurrent execution is not supported — simultaneous instances overwrite each other's scratch files. A lockfile guard is included to detect and block this.
- `--quick` mode runs inline (no agents), taking under 5 seconds.
- **Option A installs only the skill** (`~/.claude/skills/`). Use Option B or C to install the full agent set.

---

## License

MIT
