#!/usr/bin/env bash
set -euo pipefail
# 前置格式快检（机械可检出项）。位置参数：$1=SCRATCH_DIR，其余=目标文件列表
# 结果写入 $SCRATCH_DIR/format_issues.md 并回显；格式问题不影响 exit code（恒为 0）

SCRATCH_DIR="$1"; shift
nfiles=$#
FORMAT_ISSUES=""

for f in "$@"; do
  fname=$(basename "$f")
  head -1 "$f" | grep -q "^---" || FORMAT_ISSUES="${FORMAT_ISSUES}\n${fname}: ❌ 缺少 YAML front-matter"
  grep -q "^## 适用场景\|^## 使用场景\|^## 触发场景\|^## 概述" "$f" || \
    FORMAT_ISSUES="${FORMAT_ISSUES}\n${fname}: ❌ 缺少『适用场景/概述』章节"
  grep -q "^## 调用格式\|^## 使用方式\|^## Kickoff" "$f" || \
    FORMAT_ISSUES="${FORMAT_ISSUES}\n${fname}: ❌ 缺少『调用格式/Kickoff』章节"
  if grep -qE "\[TODO\]|\[待填写\]|\[PLACEHOLDER\]" "$f"; then
    FORMAT_ISSUES="${FORMAT_ISSUES}\n${fname}: ⚠️ 含未填占位符"
  fi
done

if [ -z "$FORMAT_ISSUES" ]; then
  echo "✅ 格式快检通过（${nfiles} 个文件）" | tee "$SCRATCH_DIR/format_issues.md"
else
  printf "格式快检发现以下问题：${FORMAT_ISSUES}\n" | tee "$SCRATCH_DIR/format_issues.md"
fi
