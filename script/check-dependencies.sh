#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config/dependencies.env
source "$REPO_ROOT/config/dependencies.env"

check_submodule() {
  local path="$1"
  local expected="$2"
  local expected_url="$3"
  local actual
  local configured_url

  if [[ ! -e "$REPO_ROOT/$path/.git" ]]; then
    echo "missing submodule: $path; run git submodule update --init --recursive" >&2
    return 1
  fi

  actual="$(git -C "$REPO_ROOT/$path" rev-parse HEAD)"
  if [[ "$actual" != "$expected" ]]; then
    echo "$path is at $actual; expected $expected" >&2
    return 1
  fi

  configured_url="$(git -C "$REPO_ROOT" config -f .gitmodules --get "submodule.$path.url")"
  if [[ "$configured_url" != "$expected_url" ]]; then
    echo "$path uses $configured_url; expected $expected_url" >&2
    return 1
  fi

  echo "$path: $actual"
}

check_submodule \
  "lib/forge-std" \
  "$FORGE_STD_COMMIT" \
  "https://github.com/foundry-rs/forge-std.git"
check_submodule \
  "lib/v2-protocol" \
  "$V2_PROTOCOL_COMMIT" \
  "https://github.com/wildcat-finance/v2-protocol.git"

echo "Foundry CI pin: $FOUNDRY_VERSION"
