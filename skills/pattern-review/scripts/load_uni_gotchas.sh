#!/usr/bin/env bash
# 加载 P0/P1 级通用 gotcha（UNI）摘要，供 P1 审计员执行 D5「UNI 对标」维度
# 用法: load_uni_gotchas.sh <gotcha_dir> <output_file>
set -euo pipefail

GOTCHA_DIR="${1:?用法: load_uni_gotchas.sh <gotcha_dir> <output_file>}"
OUT="${2:?用法: load_uni_gotchas.sh <gotcha_dir> <output_file>}"

count=0
: > "$OUT"
for f in "$GOTCHA_DIR"/universal-*.yaml; do
  if [ ! -f "$f" ]; then continue; fi
  prio=$(awk -F': *' '/^priority:/{print $2; exit}' "$f")
  case "$prio" in P0|P1) ;; *) continue ;; esac
  id=$(awk -F': *' '/^id:/{print $2; exit}' "$f")
  title=$(awk -F': *' '/^title:/{print $2; exit}' "$f")
  # description: | 多行块，缩进 2 空格，遇顶格行结束
  desc=$(awk '/^description: \|/{f=1; next} f && /^[^ ]/{exit} f{sub(/^  /,""); print}' "$f")
  {
    printf '## %s [%s] %s\n' "${id:-未知ID}" "$prio" "${title:-无标题}"
    printf '%s\n\n' "$desc"
  } >> "$OUT"
  count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
  printf '（无 P0/P1 级 UNI gotcha）\n' > "$OUT"
fi
echo "已加载 ${count} 条 P0/P1 级 UNI gotcha → $OUT"
