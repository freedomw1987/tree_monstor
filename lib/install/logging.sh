# lib/install/logging.sh — Logging helpers (color-aware, NO_COLOR aware).
#
# Source this from install.sh. Defines:
#   - Color variables: C_RESET / C_RED / C_GREEN / C_YELLOW / C_BLUE / C_DIM / C_BOLD
#   - log_info / log_ok / log_warn / log_err / log_dry / log_plan
#   - run <cmd...>  (executes or prints in dry-run mode)
#
# Prerequisites (must be set before sourcing):
#   QUIET     (0 or 1) — suppress info/ok output
#   DRY_RUN   (0 or 1) — print commands instead of running
#   NO_COLOR  (optional env) — disable colors

# ---------- Color setup ----------
# Respect NO_COLOR (https://no-color.org/) — only opt-out mechanism.
# Default to colors so piped output (e.g. CI logs) is also visible.
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
# REGRESSION-GUARD PROBE: log-output
log_info()  { [[ ${QUIET:-0} -eq 1 ]] || printf "%b[i]%b %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
log_ok()    { [[ ${QUIET:-0} -eq 1 ]] || printf "%b%b[✓]%b %s\n" "$C_BOLD" "$C_GREEN"  "$C_RESET" "$*"; }
log_warn()  { printf "%b[!]%b %s\n" "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err()   { printf "%b[✗]%b %s\n" "$C_RED"    "$C_RESET" "$*" >&2; }
log_dry()   { printf "%b[~]%b %s (dry-run)\n" "$C_DIM" "$C_RESET" "$*"; }
log_plan()  { printf "%b    →%b %s\n" "$C_DIM"   "$C_RESET" "$*"; }

# Conditional side-effect: run a command now (or print it under --dry-run).
run() {
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log_dry "$*"
  else
    "$@"
  fi
}