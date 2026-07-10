本文档记录设计决策与背景说明，不被 CC 自动加载到执行上下文。

# Pattern 审查委员会 — 设计说明

## §模式说明

三种运行模式的耗时与适用场景：

- **完整模式**（默认）：4 个 Stage 1 Agent 并行审查 + opus Challenger 反驳验证 + Reporter 修复，约 2-8 分钟。适合正式质量审查与发布前门控。
- **快速扫描（--quick）**：协调者内联 Bash 检查 3 个关键项（必需章节 / 占位符 / 长度），< 5 秒，不启动任何 Agent，适合 CI 门控与本地快速自检。
- **回归模式（--regression）**：仅 P1（完整性）+ P2（可实例化性），跳过 P3/P4/Challenger，适合迭代修改后的快速复查。

## §依赖与安装

本 skill 需要配套 agents 已安装到 `~/.claude/agents/`：`pattern-reviewer-p1/p2/p3`、`pattern-researcher`、`pattern-challenger`、`pattern-reporter`。

安装途径：通过 `install.sh`，或手动复制 `agents/` 目录。**注意**：仅通过 `/plugin install` 安装时 agents 不会自动复制，运行时 Task tool 将找不到 `pattern-reviewer-p1` 等 subagent，须使用安装方式 B/C（install.sh / 手动复制）。

## §脚本提取（B 类）

协调者执行体内的可执行实现细节已提取到 `scripts/`，coordinator 仅保留单行调用：

| 脚本 | 职责 | 入参 |
|------|------|------|
| `quick_triage.sh` | --quick 内联快速扫描 | 目标文件列表 |
| `init_scratch.sh` | 工作目录创建 + 并发锁 + 清理 | SCRATCH_DIR REPORT_DIR |
| `format_precheck.sh` | 前置格式快检 | SCRATCH_DIR 目标文件列表 |
| `verify_findings.sh` | Stage 1 findings 存在性校验 | SCRATCH_DIR REGRESSION_MODE |
| `preread.sh` | 目标文件前 80 行预读 | 目标文件列表 |

所有脚本固定 `set -euo pipefail`；原内联代码在 set -e 下会被 `&&`/失败 test 链误触发退出的部分，已改写为显式 `if`。

section-header grep 模式与占位符正则 `\[TODO\]|\[待填写\]|\[PLACEHOLDER\]` 在 `quick_triage.sh` 与 `format_precheck.sh` 中各自维护：二者均为 bash 消费，物化为 JSON manifest 对脚本无益，故不引入 manifest，修改时需同步两处。

新增 `load_uni_gotchas.sh`：从 `~/.claude/skill-gotchas/universal-*.yaml` 提取 P0/P1 级条目的 id/title/priority/description 摘要，写入 `uni_context.md`。入参：gotcha 目录、输出文件路径。

## §UNI 对标维度（E2 回灌机制）

**来源**：proposal `20260708_cross-project-skill-refine-feedback.md` E2 项。UNI-001~015 是跨 skill 抽象出的通用失效模式，但此前仅 code-deep-research 零星引用（UNI-013），修复未结构性回流模板，导致同类缺陷跨项目复发（实证见该 proposal「核心发现」节）。

**机制**：协调者 Step 0f 加载 P0/P1 级 UNI 摘要 → 仅注入 P1 完整性审计员（D5 维度）→ 逐条判定「适用性 + 结构性覆盖」→ findings 末尾强制「UNI 对标」节。适用且未覆盖的条目产出发现，优先级按 UNI priority 降一级（模板缺失是复发风险而非即时错误）。仅注入 P1 的原因：结构性覆盖检查本质是完整性审计；P2（可实例化）/P3（一致性）/P4（外部研究）与内部执行历史无关，注入徒增 context。

**定期触发约定**：每季度、或 UNI 库每新增 3 条 P0/P1 级条目时，执行一次 `/pattern-review all` 全模板对标（重点看各 findings 的 UNI 对标节）。触发记录由使用者在 proposal/worklist 中自行追踪，本 skill 不做持久化。
