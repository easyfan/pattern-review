---
name: pattern-review
description: >
  启动 Pattern 审查委员会，审查 ~/.claude/patterns/ 下的 pattern 文件质量。
  检测完整性、可实例化性、一致性问题，并自动修复无争议缺陷。
  当用户调用 /pattern-review、/pattern-review:pattern-review，
  或说"审查 pattern 文件"、"检查 pattern 质量"时触发。
argument-hint: "[--quick] [--regression] [target_list|all]"
model: claude-sonnet-4-6
allowed-tools: ["Bash", "Read", "Write", "Task"]
---
# Pattern 审查委员会

## 使用方式

```
/pattern-review:pattern-review [--quick] [--regression] [target_list|all]
```

- `all` — 全量审查所有 pattern 文件
- `<name>` — 审查指定 pattern（逗号分隔可多个）
- `--quick` — 快速扫描（Triage）：内联检查必需章节/占位符/长度，无 🔴 则放行，< 5 秒
- `--regression` — 回归模式：仅 P1+P2，跳过 P3/P4/Challenger

模式耗时与适用场景、agents 安装依赖见 `DESIGN.md`。
⚠️ Reporter 在 Stage 2 将**直接修改**已确认无争议的改进项，执行前建议先提交工作区变更。

---

## 你的角色：委员会协调者（Coordinator）

1. 解析审查目标，收集所有 pattern 文件路径
2. 组建并调度 Stage 1 专项审查成员（并行）
3. 汇总后向用户展示 Stage 1 摘要，等待确认
4. 依序启动 Challenger（反驳验证）→ Reporter（报告+直接修改）

脚本目录：`SKILL_DIR="$HOME/.claude/skills/pattern-review"`，下述 `bash` 调用均以此为前缀。

---

## 执行流程

### Step -1：参数预处理

解析 flag：`--quick → QUICK_MODE=true`；`--regression → REGRESSION_MODE=true`；否则完整模式。
去掉 flag 后剩余部分为 TARGET（`all` 或逗号分隔的 pattern 名称列表）。

### Step 0：初始化

**0a 确定目录，动态发现 pattern 文件**

```bash
SKILL_DIR="$HOME/.claude/skills/pattern-review"
PATTERN_DIR="$HOME/.claude/patterns"
SCRATCH_DIR="$HOME/.claude/agent_scratch/pattern_review_committee"
REPORT_DIR="$HOME/.claude/reports"
ls "$PATTERN_DIR"/*.md 2>/dev/null || echo "NO_PATTERNS"
```

解析目标：`all`（或无参数）→ 所有 `.md`；逗号分隔名称 → 在 `$PATTERN_DIR/<name>.md` 查找，不存在则报错退出。

**0b 验证目标存在**：若 `PATTERN_DIR` 不存在或无 `.md` 文件，提示「先通过 /patterns:patterns <name> 实例化，或手动添加 pattern 文件」后立即退出。

**0b（续）Triage（仅 --quick）**：协调者执行后直接退出，不启动任何 Agent：

```bash
bash "$SKILL_DIR/scripts/quick_triage.sh" <目标文件列表>
```

**0c 创建工作目录 + 并发锁**（exit 1 表示已有实例运行，须终止）：

```bash
bash "$SKILL_DIR/scripts/init_scratch.sh" "$SCRATCH_DIR" "$REPORT_DIR"
```

**0d 前置格式快检**（结果写入 `$SCRATCH_DIR/format_issues.md`，不中断流程，Reporter 后续读取）：

```bash
bash "$SKILL_DIR/scripts/format_precheck.sh" "$SCRATCH_DIR" <目标文件列表>
```

**0e 预读目标文件前 80 行**：

```bash
bash "$SKILL_DIR/scripts/preread.sh" <目标文件列表>
```

将完整输出作为**预读内容块**嵌入 Stage 1 Agent prompt，并附说明：
> 以上为所有目标文件前 80 行（front-matter + 章节结构）。无需再次 Read 文件头部，仅分析后续内容时才 Read。请保留至少 2 次工具调用用于最终 Write。

**0f UNI 对标上下文加载**（写入 `$SCRATCH_DIR/uni_context.md`，失败不中断，P1 降级为无 UNI 维度）：

```bash
bash "$SKILL_DIR/scripts/load_uni_gotchas.sh" "$HOME/.claude/skill-gotchas" "$SCRATCH_DIR/uni_context.md" \
  || echo "[WARN] UNI 上下文加载失败，P1 将跳过 D5 维度"
```

加载后判定：若 `$SCRATCH_DIR/uni_context.md` 存在且非空，则 Stage 1 传参时注入 P1；否则省略 UNI 专属传参（P1 自动跳过 D5）。
加载 P0/P1 级通用失效模式库（UNI gotcha）摘要，仅注入 P1 审计员（见 Stage 1 传参）。设计背景与定期触发约定见 `DESIGN.md` §UNI 对标维度。

读取 UNI 加载结果：
```bash
if [ -s "$SCRATCH_DIR/uni_context.md" ]; then UNI_STATUS="已加载"; else UNI_STATUS="已降级（加载失败或目录不存在）"; fi
```

输出启动提示：`[审查启动] 目标 N 个文件 | 模式：完整/回归/--quick | UNI 对标：${UNI_STATUS} | 预计 Stage 1 共 1-5 分钟`。

---

### Stage 1：并行专项审查

向每个 Agent 传入：目标文件绝对路径列表、SCRATCH_DIR 绝对路径、预读内容块、findings 格式要求（每条以 `### [P0/P1/P2/P3]` 开头）。

**P1 专属传参（UNI 对标）**：仅当 `$SCRATCH_DIR/uni_context.md` 存在且非空时，才额外内联其全文，并在 prompt 头部加入：
> 以下为跨 skill 通用失效模式库（UNI）的 P0/P1 级条目。你必须执行 D5「UNI 对标」维度：逐条判定该模式对本 pattern 的适用性与结构性覆盖，并在 findings 末尾输出「UNI 对标」节（逐条 适用/N/A + 已覆盖/未覆盖 + 判定依据）。

P2/P3/P4 不注入（UNI 为内部执行历史，与可实例化性/一致性/外部研究维度无关）。

**spawn 前额度门**（缺口④：并发 subagent 运行期 gate 失明，必须 spawn 前裁决）：启动前先运行 `~/.claude/quota-pilot/bin/quota_report.sh --spawn 4`（脚本缺失或输出含 `error` → 跳过本门按原计划执行）。按 `verdict`：`parallel` → 按下述并发执行；`serial` → 改为逐个 spawn（P1→P2→P3→P4，每个返回后再发下一个，收到 warn/critical 告警时在单元边界按 quota-pilot 协议存档）；`park` → 不 spawn，按 quota-pilot 协议以输出中 `five_hour.resets_at_epoch` 挂闹钟、写 checkpoint（此时为干净边界）、结束 turn。

**完整模式**：单条消息同时启动 4 个 Agent（额度门裁决为 serial/park 时除外）：

| Agent | subagent_type | 职责 |
|-------|--------------|------|
| P1 | `pattern-reviewer-p1` | 完整性审计（必需章节、内容充实度、角色表、实例化约定） |
| P2 | `pattern-reviewer-p2` | 可实例化性审计（Kickoff、Agent 文件存在性、I/O 契约） |
| P3 | `pattern-reviewer-p3` | 内部一致性审计（角色名、文件名、变量、术语） |
| P4 | `pattern-researcher` | 外部前沿研究（对标 LangGraph/AutoGen/Anthropic 最佳实践） |

**回归模式**：仅启动 P1 + P2。

等待全部完成后校验 findings 文件（缺失维度报告中标 `[分析失败]`，不中断）：

```bash
bash "$SKILL_DIR/scripts/verify_findings.sh" "$SCRATCH_DIR" "${REGRESSION_MODE:-false}"
```

---

### Stage 1 中场汇总与暂停

读取所有 findings 文件，统计后向用户输出：

完整模式输出：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏛️ Pattern 审查委员会 — Stage 1 完成
审查目标：N 个文件 | 发现总数：X 个
完整性(P1)：X条 | 实例化(P2)：X条 | 一致性(P3)：X条 | 研究(P4)：X条    其中 P0级×X  P1级×X  P2级×X  P3级×X
🔍 UNI 对标：X 条适用 / Y 条未覆盖
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

回归模式输出：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏛️ Pattern 审查委员会 — Stage 1 完成（回归模式）
审查目标：N 个文件 | 发现总数：X 个
完整性(P1)：X条 | 实例化(P2)：X条 | 已跳过：P3/P4    其中 P0级×X  P1级×X  P2级×X  P3级×X
🔍 UNI 对标：X 条适用 / Y 条未覆盖
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

两种模式的头部之后均接以下公共主体：
```
🔴 高优先级（影响实例化正确性）
  [P1] <问题标题> — <一句话描述>
🟡 中优先级
  [P2] <问题标题>
🟢 低优先级：X 个 | 通过：X 个
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Stage 2 将启动 Challenger（opus）+ Reporter
⚠️ Reporter 将直接修改 pattern 文件中无争议的问题
请输入"继续"执行 Stage 2，或"停止"退出：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

等待用户确认。若输入"停止"：释放锁（`rm -f "$SCRATCH_DIR/lock.pid"`），保留 scratch 文件，输出提示后退出。

---

### Stage 2：深潜与修改

**回归模式**：跳过 Challenger，写入占位裁定文件后直接进入 Reporter：

```bash
echo "[回归模式，已跳过 Challenger，无 CONFIRMED/DISPUTED 裁定]" \
  > "$SCRATCH_DIR/challenger_response.md"
```

**2a 启动 Challenger（完整模式）** — Task tool，`subagent_type: "pattern-challenger"`，传入：

- findings 文件路径：`$SCRATCH_DIR/p{1,2,3,4}_findings.md`
- 所有目标文件绝对路径列表、SCRATCH_DIR、高优先级发现列表（P0/P1 条目）

等待完成。若 `challenger_response.md` 不存在（Challenger 失败），写占位文件：

```bash
[ -f "$SCRATCH_DIR/challenger_response.md" ] || \
  echo "[Challenger 失败，无法完成验证，所有发现保持 UNVERIFIED 状态]" \
  > "$SCRATCH_DIR/challenger_response.md"
```

读取并摘要展示 DISPUTED 条目（完整内容 `cat $SCRATCH_DIR/challenger_response.md`）。

**等待同步点**：Challenger 完成且 `challenger_response.md` 存在后，方可启动 2b。两者必须串行，不得同消息调用。

**2b 启动 Reporter** — Task tool，`subagent_type: "pattern-reporter"`，传入：

- findings 文件路径 + `challenger_response.md` + `format_issues.md`
- 审查目标列表（含绝对路径）、当前日期/时间（`date +%Y-%m-%d` / `date +%H%M%S`）
- SCRATCH_DIR、REPORT_DIR、失败维度列表
- 直接修改授权：修复无争议 P0/P1 CONFIRMED 项；DISPUTED 项降为建议

等待完成，验证报告生成：`ls "$REPORT_DIR"/pattern_review_*.md 2>/dev/null | tail -1`。

---

### 最终输出

释放锁后输出结果：

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
