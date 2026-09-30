#!/usr/bin/env bash
# Build release APK when missing or stale; adb install when a device is connected.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

VERSION_LINE="$(grep '^version:' "$ROOT/pubspec.yaml" | head -1 | awk '{print $2}')"
VERSION_NAME="${VERSION_LINE%%+*}"

APK="${ROOT}/build/app/outputs/flutter-apk/timesheet-${VERSION_NAME}.apk"

apk_needs_build() {
  if [[ ! -f "$APK" ]]; then
    return 0
  fi
  if [[ "$ROOT/pubspec.yaml" -nt "$APK" ]]; then
    return 0
  fi
  if [[ -n "$(find "$ROOT/lib" -type f -name '*.dart' -newer "$APK" -print -quit 2>/dev/null)" ]]; then
    return 0
  fi
  return 1
}

if apk_needs_build; then
  bash "${ROOT}/scripts/build_apk.sh" "$@"
fi

if adb devices 2>/dev/null | awk 'NR>1 && $2=="device" { found=1 } END { exit !found }'; then
  adb install -r "$APK"
  echo "Installed on device: $APK"
else
  echo "WARNING: No Android device connected (adb). Built: $APK" >&2
fi
