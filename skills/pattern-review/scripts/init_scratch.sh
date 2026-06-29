#!/usr/bin/env bash
set -euo pipefail
# 创建工作目录 + 并发锁 + 清理上次遗留。位置参数：$1=SCRATCH_DIR $2=REPORT_DIR
# lock.pid 格式：<PID> <创建时间戳epoch>，用于检测 stale lock 和排除 PID 复用
# exit 1=已有实例运行（占用锁）

SCRATCH_DIR="$1"
REPORT_DIR="$2"

mkdir -p "$SCRATCH_DIR" "$REPORT_DIR"

if [ -f "$SCRATCH_DIR/lock.pid" ]; then
  read -r lock_pid lock_ts < "$SCRATCH_DIR/lock.pid"
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
echo "✅ 工作目录就绪：$SCRATCH_DIR"
