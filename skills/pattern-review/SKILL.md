---
name: pattern-review
description: >
  启动 Pattern 审查委员会，审查 ~/.claude/patterns/ 下的 pattern 文件质量。
  检测完整性、可实例化性、一致性问题，并自动修复无争议缺陷。
  当用户调用 /pattern-review、/pattern-review:pattern-review，
  或说"审查 pattern 文件"、"检查 pattern 质量"时触发。
argument-hint: "[--quick] [--regression] [target_list|all]"
allowed-tools: ["Bash", "Read", "Write"]
---
# Pattern 审查委员会

## 使用方式

```
/pattern-review:pattern-review [--quick] [--regression] [target_list|all]
```

**示例**：
- `/pattern-review:pattern-review all` — 全量审查所有 pattern 文件
- `/pattern-review:pattern-review agent-monitoring` — 审查指定 pattern
- `/pattern-review:pattern-review --quick all` — 快速扫描模式（Triage）：无 🔴 则放行
- `/pattern-review:pattern-review --regression all` — 回归模式：仅 P1+P2，跳过 P3/P4/Challenger

**注意**：Reporter 在 Stage 2 完成后将**直接修改**已确认无争议的改进项。建议执行前先提交工作区变更。

**依赖**：本 skill 需要配套 agents 已安装到 `~/.claude/agents/`（通过 `install.sh` 或手动复制 `agents/` 目录）。仅通过 `/plugin install` 安装时 agents 不会自动复制，运行时 Task tool 将找不到 `pattern-reviewer-p1` 等 subagent，须使用安装方式 B/C。

**模式说明**：
- **完整模式**（默认）：4 个 Stage 1 Agent 并行审查 + opus Challenger 反驳验证 + Reporter 修复，约 2-8 分钟
- **快速扫描（--quick）**：内联 Bash 检查 3 个关键项（必需章节/占位符/长度），< 5 秒，无 Agent 启动，适合 CI 门控
- **回归模式（--regression）**：仅 P1（完整性）+ P2（可实例化性），跳过 P3/P4/Challenger，适合迭代后快速复查

---

## 你的角色：委员会协调者（Coordinator）

你负责：
1. 解析审查目标，收集所有 pattern 文件路径
2. 组建并调度 Stage 1 专项审查成员（并行）
3. 汇总后向用户展示 Stage 1 摘要，等待确认
4. 依序启动 Challenger（反驳验证）→ Reporter（报告+直接修改）

---

## 执行流程

### Step -1：参数预处理

解析参数中的 flag：

```
若包含 --quick      → QUICK_MODE=true
若包含 --regression → REGRESSION_MODE=true
否则               → 完整模式
```

去掉 flag 后的剩余部分为 TARGET（`all` 或逗号分隔的 pattern 名称列表）。

### Step 0：初始化

**Step 0a：确定目录，动态发现 pattern 文件**

首先通过 Bash 获取运行时路径：

```bash
PATTERN_DIR="$HOME/.claude/patterns"
PROJECT_ROOT=$(pwd)
SCRATCH_DIR="$PROJECT_ROOT/.claude/agent_scratch/pattern_review_committee"
REPORT_DIR="$PROJECT_ROOT/.claude/reports"
echo "PATTERN_DIR=$PATTERN_DIR"
echo "PROJECT_ROOT=$PROJECT_ROOT"
```

扫描所有 pattern 文件：

```bash
ls "$PATTERN_DIR"/*.md 2>/dev/null || echo "NO_PATTERNS"
```

解析目标：
- `all`（或无参数）→ 所有发现的 `.md` 文件
- 逗号分隔名称 → 在 `$PATTERN_DIR/<name>.md` 查找；名称不存在时输出错误并退出

**Step 0b：验证目标文件存在**

若 `PATTERN_DIR` 不存在或无 `.md` 文件：
```
错误：~/.claude/patterns/ 目录为空或不存在。
请先通过 /patterns:patterns <name> 实例化工作流，或手动向该目录添加 pattern 文件。
```
立即退出。

**Step 0b（续）：Triage 快速扫描（仅 `--quick` 模式）**

若 `QUICK_MODE=true`，协调者内联执行快速扫描后直接退出（不启动任何 Agent）：

```bash
FAIL=0
for f in <目标文件列表>; do
  echo "=== $(basename $f) ==="
  grep -q "## 适用场景\|## 使用场景\|## 触发场景" "$f" || { echo "  🔴 缺少适用场景章节"; FAIL=1; }
  grep -q "## 调用格式\|## 使用方式\|## Kickoff" "$f" || { echo "  🔴 缺少调用格式章节"; FAIL=1; }
  grep -qE "\[TODO\]|\[待填写\]|\[PLACEHOLDER\]" "$f" && { echo "  🔴 含未填占位符"; FAIL=1; }
  line_count=$(wc -l < "$f")
  [ "$line_count" -lt 20 ] && { echo "  🔴 文件内容过少（${line_count} 行）"; FAIL=1; }
done
[ "$FAIL" -eq 0 ] && echo "✅ 快速扫描通过，无 🔴 问题" || echo "⛔ 快速扫描发现 🔴 问题，运行完整审查：/pattern-review:pattern-review all"
```

输出结果后退出，不进入 Stage 1。

**Step 0c：创建工作目录**

```bash
mkdir -p "$SCRATCH_DIR" "$REPORT_DIR"

# 并发保护：防止多实例同时运行覆盖 scratch 文件
# lock.pid 格式：<PID> <创建时间戳epoch>，用于检测 stale lock 和排除 PID 复用
if [ -f "$SCRATCH_DIR/lock.pid" ]; then
  read lock_pid lock_ts < "$SCRATCH_DIR/lock.pid"
  now_ts=$(date +%s)
  lock_age=$((now_ts - ${lock_ts:-0}))
  if [ "$lock_age" -gt 1800 ]; then
    echo "⚠️ 检测到孤儿 lockfile（锁龄 ${lock_age}s），已自动清理。如有疑问，手动清理：rm $SCRATCH_DIR/lock.pid" >&2
    rm -f "$SCRATCH_DIR/lock.pid"
  elif kill -0 "$lock_pid" 2>/dev/null; then
    echo "错误：已有另一个 /pattern-review 实例在运行（PID $lock_pid），请等待其完成后再执行。如误报，手动清理：rm $SCRATCH_DIR/lock.pid" >&2
    exit 1
  fi
fi
echo "$$ $(date +%s)" > "$SCRATCH_DIR/lock.pid"

# 清理上次遗留（Write 工具对已存在文件需先 Read）
# MUST be after lock.pid write，避免竞态中锁文件被误删
rm -f "$SCRATCH_DIR"/*.md
```

若创建失败，终止并提示。

**Step 0d：前置格式快检**

对所有目标文件执行基础格式验证（耗时 < 5 秒），过滤机械可检出的明显问题：

```bash
FORMAT_ISSUES=""
for f in <目标文件列表>; do
  fname=$(basename "$f")
  head -1 "$f" | grep -q "^---" || FORMAT_ISSUES="${FORMAT_ISSUES}\n${fname}: ❌ 缺少 YAML front-matter"
  grep -q "^## 适用场景\|^## 使用场景\|^## 触发场景\|^## 概述" "$f" || \
    FORMAT_ISSUES="${FORMAT_ISSUES}\n${fname}: ❌ 缺少"适用场景/概述"章节"
  grep -q "^## 调用格式\|^## 使用方式\|^## Kickoff" "$f" || \
    FORMAT_ISSUES="${FORMAT_ISSUES}\n${fname}: ❌ 缺少"调用格式/Kickoff"章节"
  grep -qE "\[TODO\]|\[待填写\]|\[PLACEHOLDER\]" "$f" && \
    FORMAT_ISSUES="${FORMAT_ISSUES}\n${fname}: ⚠️ 含未填占位符"
done
if [ -z "$FORMAT_ISSUES" ]; then
  echo "✅ 格式快检通过（$(echo '<目标文件列表>' | wc -w) 个文件）" > "$SCRATCH_DIR/format_issues.md"
else
  printf "格式快检发现以下问题：${FORMAT_ISSUES}\n" | tee "$SCRATCH_DIR/format_issues.md"
fi
```

格式问题不中断流程；Reporter 将从 `$SCRATCH_DIR/format_issues.md` 读取并纳入报告。

**Step 0e：预读所有目标文件（前 80 行）**

```bash
for f in <目标文件列表>; do
  echo "=== $f ==="
  head -80 "$f"
  echo ""
done
```

将完整输出作为**预读内容块**嵌入 Stage 1 Agent prompt，并附说明：
> 以上预读内容包含所有目标文件前 80 行（YAML front-matter + 主要章节结构）。
> 无需再次 Read 文件头部，仅在分析后续内容时才调用 Read。
> 请保留至少 2 次工具调用用于最终 Write 步骤。

输出：
```
[审查启动] 目标：N 个 pattern 文件
模式：完整 / 回归 / --quick（以实际解析结果为准）
预计等待：Stage 1 共 1-5 分钟
```

---

### Stage 1：并行专项审查

向每个 Agent 传入：
- 审查目标文件绝对路径列表
- SCRATCH_DIR 绝对路径
- 预读内容块（Step 0e 输出）
- findings 格式要求（每条发现必须以 `### [P0/P1/P2/P3]` 开头）

**完整模式**：单条消息同时启动 4 个 Agent：

| Agent | subagent_type | 职责 |
|-------|--------------|------|
| P1 | `pattern-reviewer-p1` | 完整性审计（必需章节、内容充实度、角色表、实例化约定） |
| P2 | `pattern-reviewer-p2` | 可实例化性审计（Kickoff、Agent 文件存在性、I/O 契约） |
| P3 | `pattern-reviewer-p3` | 内部一致性审计（角色名、文件名、变量、术语） |
| P4 | `pattern-researcher` | 外部前沿研究（对标 LangGraph/AutoGen/Anthropic 最佳实践） |

**回归模式**：仅启动 P1 + P2，跳过 P3/P4。

等待所有 Agent 完成。验证 findings 文件：

```bash
for dim in p1 p2 p3 p4; do
  # 回归模式跳过 p3/p4
  [ "$REGRESSION_MODE" = "true" ] && [[ "$dim" =~ ^p[34]$ ]] && continue
  ls "$SCRATCH_DIR/${dim}_findings.md" 2>/dev/null && echo "$dim: OK" || echo "$dim: MISSING"
done
```

缺失维度在报告中标注 `[分析失败]`，不中断流程。

---

### Stage 1 中场汇总与暂停

读取所有 findings 文件，统计发现数量，向用户输出汇总：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏛️ Pattern 审查委员会 — Stage 1 完成
审查目标：N 个文件 | 发现总数：X 个
P1 发现：X 个 | P2 发现：X 个 | P3 发现：X 个 | P4 发现：X 个
其中 P0×X  P1×X  P2×X  P3×X
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴 高优先级（影响实例化正确性）
  [P1] <问题标题> — <一句话描述>
  ...

🟡 中优先级
  [P2] <问题标题>
  ...

🟢 低优先级：X 个 | 通过：X 个

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Stage 2 将启动 Challenger（opus）+ Reporter
⚠️ Reporter 将直接修改 pattern 文件中无争议的问题

请输入"继续"执行 Stage 2，或"停止"退出：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

等待用户确认。

若用户输入"停止"：释放 lockfile（`rm -f "$SCRATCH_DIR/lock.pid"`），保留 scratch 文件，输出提示后退出。

---

### Stage 2：深潜与修改

**回归模式**：跳过 Challenger，直接进入 Reporter。

**Step 2a：启动 Challenger（完整模式）**

Task tool，`subagent_type: "pattern-challenger"`

传入：
- 所有 findings 文件路径：`$SCRATCH_DIR/p1_findings.md`, `$SCRATCH_DIR/p2_findings.md`, `$SCRATCH_DIR/p3_findings.md`, `$SCRATCH_DIR/p4_findings.md`
- 所有目标文件绝对路径列表
- SCRATCH_DIR
- 高优先级发现列表（P0/P1 条目）

等待完成，读取 `$SCRATCH_DIR/challenger_response.md`，向用户展示关键争议项。

**Step 2b：启动 Reporter**

Task tool，`subagent_type: "pattern-reporter"`

传入：
- 所有 findings 文件路径 + challenger_response.md
- `$SCRATCH_DIR/format_issues.md`（前置格式快检结果）
- 审查目标列表（含绝对路径）
- 当前日期（`date +%Y-%m-%d`）和时间（`date +%H%M%S`）
- SCRATCH_DIR
- REPORT_DIR（报告输出路径）
- 失败维度列表
- 直接修改授权说明（修复无争议 P0/P1 CONFIRMED 项；DISPUTED 项降为建议）

等待完成，验证报告文件生成：

```bash
ls "$REPORT_DIR"/pattern_review_*.md 2>/dev/null | tail -1
```

---

### 最终输出

执行完成后释放 lockfile：

```bash
rm -f "$SCRATCH_DIR/lock.pid"
```

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Pattern 审查委员会执行完毕
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📄 审查报告：<路径>
🔧 直接修改：<已修复文件列表>

质量等级：<🔴/🟡/🟢/⭐>
剩余未修复：P0×X  P1×X  P2×X  P3×X

💡 查看完整报告：cat <路径>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
