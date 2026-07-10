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
        ├── SKILL.md
        ├── DESIGN.md           # design notes (not auto-loaded)
        └── scripts/            # extracted bash helpers
            ├── quick_triage.sh
            ├── init_scratch.sh
            ├── format_precheck.sh
            ├── verify_findings.sh
            └── preread.sh
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
        ├── SKILL.md
        ├── DESIGN.md
        └── scripts/
            ├── quick_triage.sh
            ├── init_scratch.sh
            ├── format_precheck.sh
            ├── verify_findings.sh
            └── preread.sh
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
│   ├── SKILL.md              # coordinator instructions (≤220 lines)
│   ├── DESIGN.md             # design notes (not loaded into exec context)
│   └── scripts/              # extracted bash helpers (B-class)
│       ├── quick_triage.sh
│       ├── init_scratch.sh
│       ├── format_precheck.sh
│       ├── verify_findings.sh
│       └── preread.sh
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

## Changelog

### v1.2.0 (2026-07-10)

UNI benchmark dimension (E2) — the universal failure-mode library now structurally audits every pattern:

| Item | Change |
|------|--------|
| Step 0f (`SKILL.md`) | Coordinator loads P0/P1-level UNI gotcha summaries via new `scripts/load_uni_gotchas.sh` into `uni_context.md`; load failure degrades gracefully (P1 skips the dimension) and the startup banner reports UNI status |
| P1 dimension D5 (`agents/pattern-reviewer-p1.md`) | New mandatory "UNI 对标" audit: per-entry applicability + structural-coverage verdict; applicable-but-uncovered entries become findings one priority level below the UNI entry |
| Stage 1 summary | Dimension counters renamed for clarity; new `🔍 UNI 对标` stat line; regression mode gets its own summary block |
| `DESIGN.md` | New §UNI 对标维度: mechanism rationale (P1-only injection), plus the periodic re-benchmark convention (quarterly or every 3 new P0/P1 UNI entries) |

### v1.1.1 (2026-07-08)

Committee-audit bug fixes (found by an external /skill-review audit):

| Item | Change |
|------|--------|
| Regression mode contract | `--regression` now writes a placeholder `challenger_response.md` before entering Reporter — previously the file was never created, breaking Reporter's input contract |
| Concurrency lock | `init_scratch.sh` switched to a pure timestamp lock (`LOCK_TTL=1800s`); the old `kill -0` check tested a short-lived bash PID and never actually blocked concurrent runs |

### v1.1.0 (2026-06-29)

Context-rot governance — coordinator slimmed via skill-shrink:

| Item | Change |
|------|--------|
| SKILL.md | 328 → 194 lines (-41%); now ≤220-line stable-coordinator target |
| scripts/ | 5 inline bash blocks extracted (`quick_triage`, `init_scratch`, `format_precheck`, `verify_findings`, `preread`); coordinator calls them as one-liners |
| set -e safety | Extracted scripts use `set -euo pipefail`; original `grep && {…}` / failing-test chains rewritten as explicit `if` to avoid spurious exits |
| DESIGN.md | Mode timings, agent-install dependency, and script index moved out of the exec context |

No behavior change — same modes (`--quick` / `--regression`), same agents, same outputs.

---

## License

MIT
