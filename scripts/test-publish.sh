#!/bin/bash
# test-publish.sh — tests for publish.sh
# Run from repo root: bash scripts/test-publish.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBLISH_SCRIPT="$SCRIPT_DIR/publish.sh"

pass=0
fail=0

# ── Helpers ──────────────────────────────────────────────────

setup() {
  TMP=$(mktemp -d)
  NP_DIR="$TMP/noteplan/Published"
  POSTS_DIR="$TMP/hugo/content/posts"
  mkdir -p "$NP_DIR" "$POSTS_DIR"
}

teardown() {
  rm -rf "$TMP"
}

run_script() {
  GREYBEARD_NP_DIR="$NP_DIR" \
  GREYBEARD_POSTS_DIR="$POSTS_DIR" \
  GREYBEARD_DRY_RUN=1 \
  bash "$PUBLISH_SCRIPT" 2>/dev/null
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [ -f "$path" ]; then
    echo "  ✓ $desc"
    ((pass++)) || true
  else
    echo "  ✗ $desc (file not found: $path)"
    ((fail++)) || true
  fi
}

assert_file_missing() {
  local desc="$1" path="$2"
  if [ ! -f "$path" ]; then
    echo "  ✓ $desc"
    ((pass++)) || true
  else
    echo "  ✗ $desc (file should not exist: $path)"
    ((fail++)) || true
  fi
}

assert_content_equal() {
  local desc="$1" expected="$2" actual_path="$3"
  local actual
  actual=$(cat "$actual_path" 2>/dev/null || echo "")
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $desc"
    ((pass++)) || true
  else
    echo "  ✗ $desc"
    echo "    expected: $(echo "$expected" | head -1)..."
    echo "    actual:   $(echo "$actual" | head -1)..."
    ((fail++)) || true
  fi
}

# ── Tests ─────────────────────────────────────────────────────

echo "=== publish.sh tests ==="
echo ""

# Test 1: New .txt file is copied as .md
echo "Test 1: New file gets copied and renamed"
setup
printf -- '---\ntitle: Test Post\ndate: 2026-05-22\ntags: [test]\n---\nContent here.' > "$NP_DIR/my-first-post.txt"
run_script
assert_file_exists ".txt copied as .md" "$POSTS_DIR/my-first-post.md"
assert_content_equal "content is preserved" \
  "$(cat "$NP_DIR/my-first-post.txt")" \
  "$POSTS_DIR/my-first-post.md"
teardown

# Test 2: Existing .md not re-copied if source is older
echo "Test 2: Unchanged file is not re-copied"
setup
printf 'original content' > "$NP_DIR/stable-post.txt"
printf 'original content' > "$POSTS_DIR/stable-post.md"
# Make .md newer than .txt so it won't be overwritten
touch -t 203001010000 "$POSTS_DIR/stable-post.md"
run_script
assert_content_equal "unchanged .md not overwritten" \
  "original content" \
  "$POSTS_DIR/stable-post.md"
teardown

# Test 3: Updated .txt (newer mtime) overwrites .md
echo "Test 3: Updated source overwrites destination"
setup
printf 'old content' > "$POSTS_DIR/updated-post.md"
sleep 1
printf 'new content' > "$NP_DIR/updated-post.txt"
run_script
assert_content_equal "newer .txt overwrites .md" \
  "new content" \
  "$POSTS_DIR/updated-post.md"
teardown

# Test 4: .md removed when .txt removed from Published/
echo "Test 4: Removed source removes destination"
setup
printf 'orphaned' > "$POSTS_DIR/gone-post.md"
# No corresponding .txt in NP_DIR
run_script
assert_file_missing "orphaned .md removed" "$POSTS_DIR/gone-post.md"
teardown

# Test 5: Filenames with spaces are handled
echo "Test 5: Filenames with spaces work correctly"
setup
printf 'spaced content' > "$NP_DIR/my post with spaces.txt"
run_script
assert_file_exists "file with spaces in name copied" "$POSTS_DIR/my post with spaces.md"
teardown

echo ""
echo "=== Results: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ] || exit 1
