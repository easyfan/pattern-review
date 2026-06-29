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
