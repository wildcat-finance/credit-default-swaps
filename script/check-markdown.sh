#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

while IFS= read -r -d '' file; do
  relative="${file#"$REPO_ROOT/"}"

  if ! head -n 1 "$file" | grep -q '^# '; then
    echo "$relative: first line must be a level-one heading" >&2
    failed=1
  fi

  if LC_ALL=C grep -nE '[[:blank:]]+$' "$file"; then
    echo "$relative: trailing whitespace" >&2
    failed=1
  fi

  if LC_ALL=C grep -n $'\t' "$file"; then
    echo "$relative: tab character" >&2
    failed=1
  fi

  if [[ "$(tail -c 1 "$file" | od -An -t x1 | tr -d '[:space:]')" != "0a" ]]; then
    echo "$relative: missing final newline" >&2
    failed=1
  fi
done < <(find "$REPO_ROOT" -type f -name '*.md' \
  -not -path "$REPO_ROOT/lib/*" \
  -not -path "$REPO_ROOT/.git/*" \
  -not -path "$REPO_ROOT/.hexaemeron/*" \
  -print0)

if ((failed)); then
  exit 1
fi

echo "Markdown hygiene checks passed"
