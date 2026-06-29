[English](README.md) | [中文](README-zh.md) | [Deutsch](README-de.md) | [Français](README-fr.md) | [Русский](README-ru.md)

# pattern-review

Claude Code Pattern 审查委员会 — 审查 `~/.claude/patterns/` 下的 pattern 文件质量，检测完整性、可实例化性、一致性问题，并自动修复无争议缺陷。

```
/pattern-review:pattern-review [--quick] [--regression] [all|<名称>]
```

---

## 功能介绍

`pattern-review` 启动六人审查委员会，对 `~/.claude/patterns/` 下的工作流 pattern 文件进行全面审查。每位成员负责独立的审计维度：

| 成员 | 职责 | 模型 |
|------|------|------|
| P1 | 完整性审计（必需章节、角色表） | sonnet |
| P2 | 可实例化性审计（Kickoff prompt、agent 文件存在性、I/O 契约） | sonnet |
| P3 | 内部一致性审计（角色名、文件名、变量引用） | sonnet |
| P4 | 外部前沿研究（对标 LangGraph/AutoGen/Anthropic 最佳实践） | sonnet |
| Challenger | 反驳验证——挑战弱发现 | opus |
| Reporter | 报告生成 + 直接修复已确认问题 | sonnet |

委员会分两阶段执行：Stage 1（并行审查）→ Stage 2（Challenger + Reporter）。Reporter 将直接修改 pattern 文件，修复无争议的 P0/P1 问题。

---

## 安装

### 方式 A — Claude Code 插件市场（推荐）

```
/plugin marketplace add easyfan/pattern-review
/plugin install pattern-review@pattern-review
```

> ⚠️ **部分自动化测试覆盖**：底层 `claude plugin install` CLI 路径已被 looper T2b（Plan B）验证。`/plugin` REPL 入口点（交互界面）无法通过 `claude -p` 测试，需在 Claude Code 会话中手动确认。

> **如遇 `ENAMETOOLONG` 错误**，说明插件缓存被 CC runtime bug 破坏。修复方法：
> ```bash
> git clone https://github.com/easyfan/pattern-review && cd pattern-review && bash install.sh
> ```
> 安装脚本会自动检测并修复损坏的缓存。

> ⚠️ **方式 A 仅安装 skill**（`~/.claude/skills/`），`/plugin install` 不会复制 `agents/` 目录。全委员会模式依赖这些 agent，请使用方式 B 或 C 完整安装。

### 方式 B — 安装脚本

```bash
git clone https://github.com/easyfan/pattern-review
cd pattern-review
bash install.sh
```

```bash
# 选项
bash install.sh --dry-run           # 预览变更，不实际写入
bash install.sh --uninstall         # 卸载已安装文件
bash install.sh --target=~/.claude  # 指定自定义 Claude 配置目录
CLAUDE_DIR=~/.claude bash install.sh
```

安装内容：
- `agents/*.md      → ~/.claude/agents/`
- `skills/pattern-review/ → ~/.claude/skills/pattern-review/`

> ✅ **已验证**：被 skill-test 流水线（looper Stage 5）覆盖。

### 方式 C — 手动

```bash
cp -r skills/pattern-review ~/.claude/skills/
cp agents/*.md              ~/.claude/agents/
```

> ✅ **已验证**：被 skill-test 流水线（looper Stage 5）覆盖。

---

## 使用方式

```
/pattern-review:pattern-review [--quick] [--regression] [all|<名称>,<名称>]
```

| 参数 | 说明 |
|------|------|
| _（无参数）_ 或 `all` | 审查 `~/.claude/patterns/` 下所有 pattern 文件 |
| `<名称>` | 审查单个指定 pattern |
| `<名称1>,<名称2>` | 逗号分隔的多个 pattern 名称 |
| `--quick` | Triage 模式：内联快速扫描，不启动 agent |
| `--regression` | 回归模式：仅 P1+P2，跳过 P3/P4/Challenger |

**示例：**

```
/pattern-review:pattern-review all                   # 全量委员会审查
/pattern-review:pattern-review agent-monitoring      # 审查单个 pattern
/pattern-review:pattern-review --quick all           # 快速门控检查
/pattern-review:pattern-review --regression all      # 轻量回归复查
```

---

## 安装的文件

**方式 A — plugin 安装：**
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

**方式 B/C — 安装脚本 / 手动：**
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

## 包结构

```
pattern-review/
├── .claude-plugin/
│   ├── plugin.json           # 插件清单
│   └── marketplace.json      # 市场条目
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
├── install.sh                # 入口（委托给 scripts/install.sh）
└── scripts/
    └── install.sh            # 安装逻辑
```

---

## 依赖要求

- **Claude Code** CLI
- 无其他依赖

---

## 注意事项

- Reporter 会**直接修改** pattern 文件中无争议的问题。建议执行前先提交工作区变更。
- 不支持并发运行——同时运行多个实例会导致 scratch 文件互相覆盖。skill 内置 lockfile 保护，会自动检测并阻止。
- `--quick` 模式内联执行（不启动 agent），通常在 5 秒内完成。
- **方式 A 仅安装 skill**（`~/.claude/skills/`）。完整安装请使用方式 B 或 C。

---

## 更新日志

### v1.1.0 (2026-06-29)

Context rot 治理 —— 通过 skill-shrink 精简协调者：

| 项目 | 变更 |
|------|------|
| SKILL.md | 328 → 194 行（-41%），达到 ≤220 行稳定型协调者目标 |
| scripts/ | 5 段内联 bash 外提（quick_triage / init_scratch / format_precheck / verify_findings / preread），协调者改为单行调用 |
| set -e 安全 | 外提脚本统一 `set -euo pipefail`，原 `grep && {…}` / 失败 test 链改写为显式 `if`，避免误退出 |
| DESIGN.md | 模式耗时、agent 安装依赖、脚本索引移出执行上下文 |

行为不变 —— 模式（`--quick` / `--regression`）、agents、输出均保持一致。

完整英文发布说明见 [README.md](README.md)。

---

## 许可证

MIT
