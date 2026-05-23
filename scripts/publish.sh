#!/bin/bash
# publish.sh — copy NotePlan published posts to Hugo, commit, and push.
#
# Environment variable overrides (used by test-publish.sh):
#   GREYBEARD_NP_DIR     Override NotePlan Published/ path
#   GREYBEARD_POSTS_DIR  Override Hugo content/posts/ path
#   GREYBEARD_DRY_RUN    Set to 1 to skip git operations

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

NP_DIR="${GREYBEARD_NP_DIR:-$HOME/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents/Notes/Blog/Published}"
POSTS_DIR="${GREYBEARD_POSTS_DIR:-$REPO_ROOT/content/posts}"
DRY_RUN="${GREYBEARD_DRY_RUN:-0}"

echo "=== Greybeard Tech Publish ==="
[ "$DRY_RUN" = "1" ] && echo "(dry run — git operations skipped)"
echo "Source: $NP_DIR"
echo "Dest:   $POSTS_DIR"
echo ""

added=0
updated=0
removed=0

mkdir -p "$POSTS_DIR"

# ── Copy new / updated .txt → .md ────────────────────────────
while IFS= read -r -d '' f; do
  filename=$(basename "$f" .txt)
  dest="$POSTS_DIR/$filename.md"

  if [ ! -f "$dest" ]; then
    cp "$f" "$dest"
    echo "  + Added:   $filename"
    added=$((added + 1))
  elif [ "$f" -nt "$dest" ]; then
    cp "$f" "$dest"
    echo "  ~ Updated: $filename"
    updated=$((updated + 1))
  fi
done < <(find "$NP_DIR" -maxdepth 1 -name "*.txt" -print0 2>/dev/null)

# ── Remove .md with no matching .txt ─────────────────────────
while IFS= read -r -d '' md; do
  filename=$(basename "$md" .md)
  source_file="$NP_DIR/$filename.txt"

  if [ ! -f "$source_file" ]; then
    rm "$md"
    echo "  - Removed: $filename"
    removed=$((removed + 1))
  fi
done < <(find "$POSTS_DIR" -maxdepth 1 -name "*.md" -not -name ".gitkeep" -print0 2>/dev/null)

echo ""
echo "Changes: +$added added, ~$updated updated, -$removed removed"

# ── Git commit and push ───────────────────────────────────────
if [ "$DRY_RUN" = "1" ]; then
  echo "(dry run complete)"
  exit 0
fi

cd "$REPO_ROOT"

if git diff --quiet && git diff --cached --quiet; then
  echo "No changes to publish."
  exit 0
fi

git add .
git commit -m "publish: $(date '+%Y-%m-%d %H:%M')"
git push origin main

echo ""
echo "✓ Pushed. GitHub Actions will deploy in ~30-60 seconds."
echo "  Watch: https://github.com/macmedic13/greybeardtech/actions"
echo "  Live:  https://greybeardtech.ca"
