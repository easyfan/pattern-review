#!/usr/bin/env bash
set -euo pipefail
# --quick Triage 快速扫描。位置参数：目标 pattern 文件列表
# stdout=扫描结果；exit 0=无🔴；exit 1=发现🔴问题

FAIL=0
for f in "$@"; do
  echo "=== $(basename "$f") ==="
  grep -q "## 适用场景\|## 使用场景\|## 触发场景" "$f" || { echo "  🔴 缺少适用场景章节"; FAIL=1; }
  grep -q "## 调用格式\|## 使用方式\|## Kickoff" "$f" || { echo "  🔴 缺少调用格式章节"; FAIL=1; }
  if grep -qE "\[TODO\]|\[待填写\]|\[PLACEHOLDER\]" "$f"; then echo "  🔴 含未填占位符"; FAIL=1; fi
  line_count=$(wc -l < "$f")
  if [ "$line_count" -lt 20 ]; then echo "  🔴 文件内容过少（${line_count} 行）"; FAIL=1; fi
done

if [ "$FAIL" -eq 0 ]; then
  echo "✅ 快速扫描通过，无 🔴 问题"
else
  echo "⛔ 快速扫描发现 🔴 问题，运行完整审查：/pattern-review:pattern-review all"
fi
exit "$FAIL"
