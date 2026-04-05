#!/usr/bin/env bash
# install.sh — pattern-review plugin installer
# Usage: ./install.sh [--dry-run] [--uninstall] [--target=<path>]
# Options:
#   --dry-run          Preview changes without writing
#   --uninstall        Remove installed files
#   --target=<path>    Custom Claude config directory (default: ~/.claude)
#   CLAUDE_DIR=<path>  Alternative to --target

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DRY_RUN=false
UNINSTALL=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=true ;;
    --uninstall)  UNINSTALL=true ;;
    --target=*)   CLAUDE_DIR="${arg#--target=}" ;;
  esac
done

# Files: "src_relative_to_PLUGIN_DIR|dst_relative_to_CLAUDE_DIR"
FILES=(
  "agents/pattern-reviewer-p1.md|agents/pattern-reviewer-p1.md"
  "agents/pattern-reviewer-p2.md|agents/pattern-reviewer-p2.md"
  "agents/pattern-reviewer-p3.md|agents/pattern-reviewer-p3.md"
  "agents/pattern-researcher.md|agents/pattern-researcher.md"
  "agents/pattern-challenger.md|agents/pattern-challenger.md"
  "agents/pattern-reporter.md|agents/pattern-reporter.md"
)
SKILL_SRC="skills/pattern-review"
SKILL_DST="skills/pattern-review"

# ── Uninstall ──────────────────────────────────────────────────────────────────
if [ "$UNINSTALL" = true ]; then
  echo "Uninstalling pattern-review..."
  for entry in "${FILES[@]}"; do
    dst="$CLAUDE_DIR/${entry#*|}"
    if [ -f "$dst" ]; then
      $DRY_RUN && echo "[dry-run] rm $dst" || rm "$dst"
      echo "  Removed $dst"
    fi
  done
  skill_dst="$CLAUDE_DIR/$SKILL_DST"
  if [ -d "$skill_dst" ]; then
    $DRY_RUN && echo "[dry-run] rm -rf $skill_dst" || rm -rf "$skill_dst"
    echo "  Removed $skill_dst"
  fi
  echo "Uninstall complete."
  exit 0
fi

# ── Install ────────────────────────────────────────────────────────────────────
echo "Installing pattern-review..."

MODIFIED=0

# Install agents
$DRY_RUN || mkdir -p "$CLAUDE_DIR/agents"
for entry in "${FILES[@]}"; do
  src="$PLUGIN_DIR/${entry%%|*}"
  dst="$CLAUDE_DIR/${entry#*|}"
  if [ -f "$dst" ] && diff -q "$src" "$dst" &>/dev/null; then
    : # unchanged
  else
    if $DRY_RUN; then
      echo "[dry-run] cp $src $dst"
    else
      cp "$src" "$dst"
    fi
    MODIFIED=$((MODIFIED + 1))
  fi
done

# Install skill
skill_src="$PLUGIN_DIR/$SKILL_SRC"
skill_dst="$CLAUDE_DIR/$SKILL_DST"
if [ -f "$skill_dst/SKILL.md" ] && diff -q "$skill_src/SKILL.md" "$skill_dst/SKILL.md" &>/dev/null; then
  : # unchanged
else
  if $DRY_RUN; then
    echo "[dry-run] cp -r $skill_src/ $skill_dst/"
  else
    mkdir -p "$skill_dst"
    cp -r "$skill_src/." "$skill_dst/"
  fi
  MODIFIED=$((MODIFIED + 1))
fi

if $DRY_RUN; then
  echo "${MODIFIED} files would be modified"
fi
echo ""
echo "Done! ${MODIFIED} items installed."
echo ""
echo "Usage: /pattern-review:pattern-review [--quick] [--regression] [all|<name>]"
