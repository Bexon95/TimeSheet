#!/usr/bin/env bash
# Analyze + unit tests before release builds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT}/scripts/resolve_flutter.sh"

cd "$ROOT"

PUB_FLAG=()
if [[ -d "$ROOT/.dart_tool" ]]; then
  PUB_FLAG=(--no-pub)
fi

echo "==> flutter analyze lib/"
"$FLUTTER" analyze lib/ "${PUB_FLAG[@]}" --no-fatal-infos --no-fatal-warnings

echo "==> flutter test"
"$FLUTTER" test "${PUB_FLAG[@]}"

echo "==> check passed"
