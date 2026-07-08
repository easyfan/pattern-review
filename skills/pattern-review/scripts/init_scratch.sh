#!/usr/bin/env bash
set -euo pipefail
# 创建工作目录 + 并发锁 + 清理上次遗留。位置参数：$1=SCRATCH_DIR $2=REPORT_DIR
# lock.pid 格式：<PID> <创建时间戳epoch>。PID 仅作诊断记录：写锁的 bash 为协调者
# 每次调用临时派生的短命进程，kill -0 存活检测恒失效（2026-07-08 审查发现），
# 故锁语义为纯时间戳——锁龄 ≤ LOCK_TTL 视为占用，正常流程结束时由协调者 rm 释放。
# exit 1=已有实例运行（占用锁）

LOCK_TTL=1800  # 秒；完整模式典型耗时 2-8 分钟，留足余量

SCRATCH_DIR="$1"
REPORT_DIR="$2"

mkdir -p "$SCRATCH_DIR" "$REPORT_DIR"

if [ -f "$SCRATCH_DIR/lock.pid" ]; then
  read -r lock_pid lock_ts < "$SCRATCH_DIR/lock.pid" || true
  now_ts=$(date +%s)
  lock_age=$((now_ts - ${lock_ts:-0}))
  if [ "$lock_age" -gt "$LOCK_TTL" ]; then
    echo "⚠️ 检测到孤儿 lockfile（锁龄 ${lock_age}s > ${LOCK_TTL}s），已自动清理。如有疑问，手动清理：rm $SCRATCH_DIR/lock.pid" >&2
    rm -f "$SCRATCH_DIR/lock.pid"
  else
    echo "错误：已有另一个 /pattern-review 实例在运行（锁龄 ${lock_age}s，创建者 PID ${lock_pid:-未知}），请等待其完成后再执行。若确认无实例在运行（如上次异常中断），手动清理：rm $SCRATCH_DIR/lock.pid" >&2
    exit 1
  fi
fi
echo "$$ $(date +%s)" > "$SCRATCH_DIR/lock.pid"

# 清理上次遗留（Write 工具对已存在文件需先 Read）
# MUST be after lock.pid write，避免竞态中锁文件被误删
rm -f "$SCRATCH_DIR"/*.md
echo "✅ 工作目录就绪：$SCRATCH_DIR"
