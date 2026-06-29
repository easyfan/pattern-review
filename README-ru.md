[English](README.md) | [中文](README-zh.md) | [Deutsch](README-de.md) | [Français](README-fr.md) | [Русский](README-ru.md)

# pattern-review

Комитет по проверке паттернов для Claude Code — проверяет файлы в `~/.claude/patterns/` на полноту, инстанциируемость и согласованность, автоматически исправляя бесспорные дефекты.

```
/pattern-review:pattern-review [--quick] [--regression] [all|<имя>]
```

---

## Принцип работы

`pattern-review` запускает комитет из шести членов, который проверяет файлы рабочих паттернов в `~/.claude/patterns/`. Каждый член отвечает за отдельное измерение аудита:

| Член | Роль | Модель |
|------|------|--------|
| P1 | Аудит полноты (обязательные разделы, таблицы ролей) | sonnet |
| P2 | Аудит инстанциируемости (Kickoff prompt, существование агентов, контракты I/O) | sonnet |
| P3 | Аудит внутренней согласованности (имена ролей, имена файлов, ссылки на переменные) | sonnet |
| P4 | Внешний исследовательский специалист (сравнение с LangGraph, AutoGen, лучшими практиками Anthropic) | sonnet |
| Challenger | Состязательный верификатор — оспаривает слабые находки | opus |
| Reporter | Генератор отчётов + автоматическое исправление подтверждённых проблем | sonnet |

Комитет работает в два этапа: Stage 1 (параллельный аудит) → Stage 2 (Challenger + Reporter). Reporter напрямую редактирует файлы паттернов для исправления бесспорных проблем P0/P1.

---

## Установка

### Вариант A — Маркетплейс плагинов Claude Code (рекомендуется)

```
/plugin marketplace add easyfan/pattern-review
/plugin install pattern-review@pattern-review
```

> ⚠️ **Частично покрыто автоматизированными тестами**: Базовый CLI-путь `claude plugin install` проверяется looper T2b (Plan B). Точка входа REPL `/plugin` (интерактивный UI) не может быть протестирована через `claude -p` и требует ручной проверки в сессии Claude Code.

> **При ошибке `ENAMETOOLONG`** кэш плагина повреждён из-за бага в CC runtime. Исправление:
> ```bash
> git clone https://github.com/easyfan/pattern-review && cd pattern-review && bash install.sh
> ```
> Установщик автоматически обнаруживает и восстанавливает повреждённый кэш.

> ⚠️ **Вариант A устанавливает только skill** (`~/.claude/skills/`). `/plugin install` не копирует директорию `agents/`. Для полного режима комитета используйте вариант Б или В.

### Вариант Б — Скрипт установки

```bash
git clone https://github.com/easyfan/pattern-review
cd pattern-review
bash install.sh
```

```bash
# Параметры
bash install.sh --dry-run           # предпросмотр без записи
bash install.sh --uninstall         # удалить установленные файлы
bash install.sh --target=~/.claude  # пользовательский каталог Claude
CLAUDE_DIR=~/.claude bash install.sh
```

Устанавливает:
- `agents/*.md      → ~/.claude/agents/`
- `skills/pattern-review/ → ~/.claude/skills/pattern-review/`

> ✅ **Проверено**: охвачено пайплайном skill-test (looper Stage 5).

### Вариант В — Вручную

```bash
cp -r skills/pattern-review ~/.claude/skills/
cp agents/*.md              ~/.claude/agents/
```

> ✅ **Проверено**: охвачено пайплайном skill-test (looper Stage 5).

---

## Использование

```
/pattern-review:pattern-review [--quick] [--regression] [all|<имя>,<имя>]
```

| Аргумент | Описание |
|----------|----------|
| _（нет）_ или `all` | Проверить все файлы паттернов в `~/.claude/patterns/` |
| `<имя>` | Проверить один указанный паттерн |
| `<имя1>,<имя2>` | Список имён паттернов через запятую |
| `--quick` | Режим триажа: встроенное сканирование, без запуска агентов |
| `--regression` | Режим регрессии: только P1+P2, P3/P4/Challenger пропускаются |

**Примеры:**

```
/pattern-review:pattern-review all                   # полная проверка комитета
/pattern-review:pattern-review agent-monitoring      # один паттерн
/pattern-review:pattern-review --quick all           # быстрая проверка
/pattern-review:pattern-review --regression all      # лёгкая повторная проверка
```

---

## Установленные файлы

**Вариант A — установка через plugin:**
```
~/.claude/
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

**Вариант Б/В — скрипт / вручную:**
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

## Структура пакета

```
pattern-review/
├── .claude-plugin/
│   ├── plugin.json           # манифест плагина
│   └── marketplace.json      # запись маркетплейса
├── agents/
│   ├── pattern-reviewer-p1.md
│   ├── pattern-reviewer-p2.md
│   ├── pattern-reviewer-p3.md
│   ├── pattern-researcher.md
│   ├── pattern-challenger.md
│   └── pattern-reporter.md
├── skills/pattern-review/
│   ├── SKILL.md
│   ├── DESIGN.md
│   └── scripts/
│       ├── quick_triage.sh
│       ├── init_scratch.sh
│       ├── format_precheck.sh
│       ├── verify_findings.sh
│       └── preread.sh
├── evals/evals.json
├── install.sh                # точка входа (делегирует scripts/install.sh)
└── scripts/
    └── install.sh            # логика установки
```

---

## Требования

- **Claude Code** CLI
- Без дополнительных зависимостей

---

## Примечания

- Reporter **напрямую модифицирует** файлы паттернов для бесспорных исправлений. Зафиксируйте изменения перед запуском.
- Одновременное выполнение не поддерживается — параллельные экземпляры перезаписывают scratch-файлы друг друга. Защита через lockfile автоматически обнаруживает и блокирует это.
- Режим `--quick` выполняется встроенно (без агентов), обычно менее 5 секунд.
- **Вариант A устанавливает только skill** (`~/.claude/skills/`). Для полной установки используйте вариант Б или В.

---

## История изменений

### v1.1.0 (2026-06-29)

Борьба с «context rot» — координатор облегчён через skill-shrink:

| Элемент | Изменение |
|---------|-----------|
| SKILL.md | 328 → 194 строк (-41 %), достигнута цель ≤220 строк |
| scripts/ | 5 встроенных bash-блоков вынесены; координатор вызывает их одной строкой |
| set -e | Скрипты используют `set -euo pipefail`; ненадёжные цепочки `&&` переписаны в явный `if` |
| DESIGN.md | Детали режимов и индекс скриптов вынесены из контекста выполнения |

Поведение не изменилось.

Полные примечания к выпуску на английском: см. [README.md](README.md).

---

## Лицензия

MIT
