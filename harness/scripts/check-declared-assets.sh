#!/usr/bin/env bash
# Validates that offline assets declared in spec.md or sprint-contract.md
# actually exist on disk under assets or Resources.
#
# Usage: bash harness/scripts/check-declared-assets.sh <docs-directory>
#
# Scans for file:///android_asset/ references, extracts the relative path,
# and asserts each file exists and is non-empty.
# Exits 0 if all declared assets are present, 1 if any are missing.

set -e

DOCS_DIR="${1:-}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if [ -z "$DOCS_DIR" ]; then
  echo "Usage: bash harness/scripts/check-declared-assets.sh <docs-directory>" >&2
  exit 2
fi

[ -d "$DOCS_DIR" ] || fail "missing docs directory $DOCS_DIR"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -d "$REPO_ROOT/NotesTakingAppiOS/assets" ]; then
  ASSETS_ROOT="$REPO_ROOT/NotesTakingAppiOS/assets"
elif [ -d "$REPO_ROOT/NotesTakingAppiOS/Resources" ]; then
  ASSETS_ROOT="$REPO_ROOT/NotesTakingAppiOS/Resources"
else
  ASSETS_ROOT="$REPO_ROOT/app/src/main/assets"
fi

# Collect all file:///android_asset/ references from spec and contract docs
DECLARED_ASSETS=""
for doc in "$DOCS_DIR/spec.md" "$DOCS_DIR/sprint-contract.md" "$DOCS_DIR/spec_v"*.md; do
  [ -f "$doc" ] || continue
  found=$(grep -oE 'file:///android_asset/[^)"'"'"'` >]+' "$doc" 2>/dev/null || true)
  if [ -n "$found" ]; then
    DECLARED_ASSETS="$DECLARED_ASSETS
$found"
  fi
done

# Deduplicate
DECLARED_ASSETS=$(printf '%s\n' "$DECLARED_ASSETS" | sort -u | sed '/^[[:space:]]*$/d')

if [ -z "$DECLARED_ASSETS" ]; then
  echo "PASS: no file:///android_asset/ references found in docs — nothing to check."
  exit 0
fi

MISSING_COUNT=0
while IFS= read -r asset_url; do
  [ -n "$asset_url" ] || continue
  relative_path="${asset_url#file:///android_asset/}"
  full_path="$ASSETS_ROOT/$relative_path"

  if [ ! -f "$full_path" ]; then
    # Also check case-insensitively or under Resources subdirectories
    alt_path="$REPO_ROOT/NotesTakingAppiOS/Resources/Mermaid/$(basename "$relative_path")"
    if [ -f "$alt_path" ]; then
      full_path="$alt_path"
    fi
  fi

  if [ ! -f "$full_path" ]; then
    echo "FAIL: declared asset '$asset_url' is missing on disk at $full_path" >&2
    MISSING_COUNT=$((MISSING_COUNT + 1))
  elif [ ! -s "$full_path" ]; then
    echo "FAIL: declared asset '$asset_url' exists but is empty at $full_path" >&2
    MISSING_COUNT=$((MISSING_COUNT + 1))
  else
    echo "OK: $relative_path ($(wc -c < "$full_path" | tr -d ' ') bytes)"
  fi
done <<EOF
$DECLARED_ASSETS
EOF

if [ "$MISSING_COUNT" -gt 0 ]; then
  fail "$MISSING_COUNT declared asset(s) are missing or empty"
fi

echo "PASS: all declared offline assets exist on disk."
