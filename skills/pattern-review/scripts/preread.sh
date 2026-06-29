#!/usr/bin/env bash
set -euo pipefail
# 预读所有目标文件前 80 行（YAML front-matter + 主要章节结构）。
# 位置参数：目标文件列表。stdout 作为 Stage 1 Agent prompt 的预读内容块。

for f in "$@"; do
  echo "=== $f ==="
  head -80 "$f"
  echo ""
done
