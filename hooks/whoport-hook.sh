#!/usr/bin/env sh

# Source this file from an AI terminal/session bootstrap.
# Example:
#   export WHOPORT_TOOL=codex
#   . /path/to/who-use-my-port/hooks/whoport-hook.sh
#   whoport_run 3000 -- pnpm dev

if [ -z "${WHOPORT_BIN:-}" ]; then
  if [ -x "./bin/whoport" ]; then
    WHOPORT_BIN="$PWD/bin/whoport"
  elif command -v whoport >/dev/null 2>&1; then
    WHOPORT_BIN="whoport"
  else
    echo "Set WHOPORT_BIN to the whoport executable path before sourcing whoport-hook.sh." >&2
    return 1 2>/dev/null || exit 1
  fi
fi

if [ -z "${WHOPORT_TOOL:-}" ] || [ "${WHOPORT_TOOL:-}" = "manual" ]; then
  if [ -n "${CODEX_HOME:-}" ] || [ -n "${OPENAI_API_KEY:-}" ] || [ -n "${CODEX_SANDBOX_NETWORK_DISABLED:-}" ]; then
    WHOPORT_TOOL="codex"
  elif [ -n "${CURSOR_TRACE_ID:-}" ] || [ -n "${CURSOR_AGENT:-}" ]; then
    WHOPORT_TOOL="cursor"
  elif [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE_ENTRYPOINT:-}" ]; then
    WHOPORT_TOOL="claude"
  else
    WHOPORT_TOOL="manual"
  fi
fi

export WHOPORT_BIN
export WHOPORT_TOOL

whoport_check() {
  "$WHOPORT_BIN" check "$1"
}

whoport_reserve() {
  port="$1"
  shift
  "$WHOPORT_BIN" reserve "$port" --tool "$WHOPORT_TOOL" --project "$PWD" "$@"
}

whoport_release() {
  port="$1"
  shift
  "$WHOPORT_BIN" release "$port" --tool "$WHOPORT_TOOL" --project "$PWD" "$@"
}

whoport_run() {
  port="$1"
  shift

  if [ "$1" = "--" ]; then
    shift
  fi

  "$WHOPORT_BIN" check "$port" >&2
  "$WHOPORT_BIN" wrap "$port" --tool "$WHOPORT_TOOL" --project "$PWD" "$@"
}

whoport_run_as() {
  tool="$1"
  port="$2"
  shift 2

  if [ "$1" = "--" ]; then
    shift
  fi

  "$WHOPORT_BIN" check "$port" >&2
  "$WHOPORT_BIN" wrap "$port" --tool "$tool" --project "$PWD" "$@"
}
