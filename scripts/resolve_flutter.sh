#!/usr/bin/env bash
# Resolve Flutter binary (wrapper on Windows, direct binary elsewhere).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT="$(cd "$ROOT/.." && pwd)"
CASHY="${PARENT}/Cashy"

if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]] || [[ "$(uname -s)" == CYGWIN* ]]; then
  FLUTTER="${ROOT}/scripts/flutter.bat"
elif [[ -f "${ROOT}/.tools/flutter/bin/flutter" ]]; then
  FLUTTER="${ROOT}/.tools/flutter/bin/flutter"
elif [[ -f "${CASHY}/.tools/flutter/bin/flutter" ]]; then
  FLUTTER="${CASHY}/.tools/flutter/bin/flutter"
elif [[ -f "${PARENT}/.tools/flutter/bin/flutter" ]]; then
  FLUTTER="${PARENT}/.tools/flutter/bin/flutter"
else
  echo "ERROR: Flutter SDK not found." >&2
  exit 1
fi

use_java_at() {
  local jdk_home="$1"
  if [[ -x "${jdk_home}/bin/java" || -x "${jdk_home}/bin/java.exe" ]]; then
    export JAVA_HOME="$jdk_home"
    export PATH="${JAVA_HOME}/bin:${PATH}"
    return 0
  fi
  return 1
}

for jdk_home in \
  "${ROOT}/.tools/jdk-21" \
  "${CASHY}/.tools/jdk-21" \
  "${PARENT}/.tools/jdk-21"; do
  if use_java_at "$jdk_home"; then
    break
  fi
done
