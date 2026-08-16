#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

./script/check-dependencies.sh
./script/check-markdown.sh
./script/check-images.py
./script/check-worked-example.py
bash -n script/*.sh
forge fmt --check
forge build --sizes
forge test
FOUNDRY_PROFILE=ci forge test
git diff --check

echo "Release gate passed"
