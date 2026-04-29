#!/usr/bin/env bash
# run_wolfram.sh — locate a Wolfram kernel and invoke nb_tool.wls.
#
# Probes for `wolframscript`, then `wolfram`, then `math` (in that order).
# Falls back to common macOS Mathematica.app / Wolfram*.app install paths.
#
# Deliberately does NOT use the desktop `Mathematica` binary — that's a frontend,
# not a kernel, and can't run scripts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WLS="$SCRIPT_DIR/nb_tool.wls"

if [ ! -f "$WLS" ]; then
  echo "Error: nb_tool.wls not found at $WLS" >&2
  exit 1
fi

find_wolfram() {
  local cmd
  for cmd in wolframscript wolfram math; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "$cmd"
      return 0
    fi
  done
  # macOS app-bundle fallbacks
  local p
  for p in \
    /Applications/Mathematica.app/Contents/MacOS/wolframscript \
    /Applications/Wolfram.app/Contents/MacOS/wolframscript \
    /Applications/Wolfram\ Engine.app/Contents/MacOS/wolframscript \
    /Applications/Wolfram*.app/Contents/MacOS/wolframscript \
    /Applications/Mathematica.app/Contents/MacOS/WolframKernel \
    /Applications/Mathematica.app/Contents/MacOS/MathKernel; do
    if [ -x "$p" ]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

WOLFRAM=$(find_wolfram) || {
  echo "Error: no Wolfram kernel found on PATH (tried: wolframscript, wolfram, math)." >&2
  echo "       Install Wolfram Engine (free), Wolfram Desktop, or Mathematica with a command-line kernel." >&2
  echo "       The desktop Mathematica front-end alone is not sufficient." >&2
  exit 1
}

BASENAME="$(basename "$WOLFRAM")"

case "$BASENAME" in
  wolframscript)
    # wolframscript: -file runs a script; args to the script follow.
    exec "$WOLFRAM" -file "$WLS" "$@"
    ;;
  wolfram|math|WolframKernel|MathKernel)
    # Kernel binaries: -script runs a file. Args go to $ScriptCommandLine.
    exec "$WOLFRAM" -script "$WLS" "$@"
    ;;
  *)
    # Unknown binary — try -script, which works for most kernels.
    exec "$WOLFRAM" -script "$WLS" "$@"
    ;;
esac
