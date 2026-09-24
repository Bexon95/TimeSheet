#!/usr/bin/env bash
# Resolve Flutter binary (local .tools, sibling Cashy, or parent .tools).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT="$(cd "$ROOT/.." && pwd)"
CASHY="${PARENT}/Cashy"

FLUTTER="${PARENT}/.tools/flutter/bin/flutter"
if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]] || [[ -f "${PARENT}/.tools/flutter/bin/flutter.bat" ]]; then
  FLUTTER="${PARENT}/.tools/flutter/bin/flutter.bat"
fi
if [[ -f "${ROOT}/.tools/flutter/bin/flutter.bat" ]]; then
  FLUTTER="${ROOT}/.tools/flutter/bin/flutter.bat"
elif [[ -f "${ROOT}/.tools/flutter/bin/flutter" ]]; then
  FLUTTER="${ROOT}/.tools/flutter/bin/flutter"
elif [[ -f "${CASHY}/.tools/flutter/bin/flutter.bat" ]]; then
  FLUTTER="${CASHY}/.tools/flutter/bin/flutter.bat"
elif [[ -f "${CASHY}/.tools/flutter/bin/flutter" ]]; then
  FLUTTER="${CASHY}/.tools/flutter/bin/flutter"
fi

if [[ ! -f "$FLUTTER" && ! -x "$FLUTTER" ]]; then
  echo "ERROR: Flutter SDK not found. Expected one of:" >&2
  echo "  ${ROOT}/.tools/flutter" >&2
  echo "  ${CASHY}/.tools/flutter" >&2
  echo "  ${PARENT}/.tools/flutter" >&2
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

# Prefer the same JDK 21 bundle as Cashy for Gradle builds.
for jdk_home in \
  "${ROOT}/.tools/jdk-21" \
  "${CASHY}/.tools/jdk-21" \
  "${PARENT}/.tools/jdk-21"; do
  if use_java_at "$jdk_home"; then
    break
  fi
done

if [[ -z "${ProgramFiles(x86):-}" ]] && [[ -d "/c/Program Files (x86)" ]]; then
  export "ProgramFiles(x86)=C:\Program Files (x86)"
fi
