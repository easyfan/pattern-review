#!/usr/bin/env bash
set -euo pipefail
# 校验 Stage 1 各维度 findings 文件存在性。
# 位置参数：$1=SCRATCH_DIR $2=REGRESSION_MODE(true/false，默认 false)
# 回归模式跳过 p3/p4。stdout 每行 "<dim>: OK|MISSING"

SCRATCH_DIR="$1"
REGRESSION_MODE="${2:-false}"

for dim in p1 p2 p3 p4; do
  if [ "$REGRESSION_MODE" = "true" ] && [[ "$dim" =~ ^p[34]$ ]]; then
    continue
  fi
  if [ -f "$SCRATCH_DIR/${dim}_findings.md" ]; then
    echo "$dim: OK"
  else
    echo "$dim: MISSING"
  fi
done
