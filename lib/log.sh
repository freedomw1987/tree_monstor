# lib/log.sh — Shared logging helpers for tools/* and lib/* scripts.
#
# Source this from any script that wants consistent color-aware logging
# matching install.sh's UX. Defines:
#   - log_info / log_ok / log_warn / log_err / log_dry / log_plan
#   - on_error <cmd...>  (error trap; prints message + exits non-zero)
#   - require_no_unset_var (utility for catching unbound variables)
#
# Usage (from a tool):
#   #!/usr/bin/env bash
#   set -uo pipefail
#   source "$(cd "$(dirname "$0")/.." && pwd)/lib/log.sh"
#   trap 'on_error "line $LINENO"' ERR
#
# Honors:
#   - QUIET (0/1)  — suppress info/ok
#   - NO_COLOR      — disable colors per no-color.org
#
# NOTE: This file is intentionally separate from lib/install/logging.sh
# because tools should not depend on install.sh's variable contract
# (QUIET, DRY_RUN are install.sh-only concepts). If you're writing
# a tool, use this file. If you're extending install.sh, use
# lib/install/logging.sh.

# ---------- Color setup (NO_COLOR-aware) ----------
if [[ -n "${NO_COLOR:-}" ]]; then
  C_RESET=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_DIM=""; C_BOLD=""
else
  C_RESET=$'\033[0m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
fi

# ---------- Logging ----------
log_info()  { [[ ${QUIET:-0} -eq 1 ]] || printf "%b[i]%b %s\n" "$C_BLUE"   "$C_RESET" "$*" >&2; }
log_ok()    { [[ ${QUIET:-0} -eq 1 ]] || printf "%b%b[✓]%b %s\n" "$C_BOLD" "$C_GREEN"  "$C_RESET" "$*" >&2; }
log_warn()  { printf "%b[!]%b %s\n" "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err()   { printf "%b[✗]%b %s\n" "$C_RED"    "$C_RESET" "$*" >&2; }
log_dry()   { printf "%b[~]%b %s (dry-run)\n" "$C_DIM" "$C_RESET" "$*" >&2; }
log_plan()  { printf "%b    →%b %s\n" "$C_DIM"   "$C_RESET" "$*" >&2; }

# ---------- Error trap helper ----------
# Usage: trap 'on_error "context message"' ERR
# Note: set -e / set -u / pipefail decide when ERR fires. We recommend:
#   set -uo pipefail
#   trap 'on_error "line $LINENO failed"' ERR
# so pipe failures still trigger the trap.
on_error() {
  local msg="${1:-unspecified error}"
  log_err "$msg (exit $?)"
  exit 1
}

# Helper: ensure required commands exist before continuing.
# Usage: require_cmd jq ffmpeg
require_cmd() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if (( ${#missing[@]} > 0 )); then
    log_err "Missing required command(s): ${missing[*]}"
    log_err "Install them and retry."
    exit 3
  fi
}