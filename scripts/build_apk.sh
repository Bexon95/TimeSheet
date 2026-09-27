#!/usr/bin/env bash
# Release APK for arm64 only, named timesheet-<version>.apk from pubspec version name.
# Runs check with --check (default: build only).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_CHECK=false
FLUTTER_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --check) RUN_CHECK=true ;;
    -h|--help)
      echo "Usage: scripts/build_apk.sh [--check] [flutter build args...]"
      echo "  --check  Run scripts/check.sh before building"
      exit 0
      ;;
    *)
      FLUTTER_ARGS+=("$arg")
      ;;
  esac
done

if [[ "$RUN_CHECK" == true ]]; then
  bash "${ROOT}/scripts/check.sh"
fi

source "${ROOT}/scripts/resolve_flutter.sh"

VERSION_LINE="$(grep '^version:' "$ROOT/pubspec.yaml" | head -1 | awk '{print $2}')"
VERSION_NAME="${VERSION_LINE%%+*}"

cd "$ROOT"
# One arm64 split only for a smaller sideloadable APK.
"$FLUTTER" build apk --release --split-per-abi --target-platform android-arm64 \
  -Pforce-version-code-ignoring-abi=true \
  "${FLUTTER_ARGS[@]}"

OUTPUT_DIR="$ROOT/build/app/outputs/flutter-apk"
SRC="$OUTPUT_DIR/app-arm64-v8a-release.apk"
DEST="$OUTPUT_DIR/timesheet-${VERSION_NAME}.apk"

cp -f "$SRC" "$DEST"
echo "Built $DEST ($(du -h "$DEST" | awk '{print $1}'))"
