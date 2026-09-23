# lib/install/paths.sh — Path resolution helpers.
#
# Source this from install.sh. Defines:
#   - abs_path <path>
#
# Requires:
#   log_err (from logging.sh)
#
# NOTE: resolve_source() and resolve_target_root() remain in install.sh
# because resolve_source depends on $0 (the main script), not BASH_SOURCE
# inside a sourced lib. Keeping these in install.sh avoids subtle bugs.

# Resolve target -> absolute, normalized path (no trailing slash).
abs_path() {
  local p="$1"
  if [[ -d "$p" ]]; then
    (cd "$p" && pwd)
  else
    local d base
    d="$(dirname -- "$p")"
    base="$(basename -- "$p")"
    (cd "$d" 2>/dev/null && printf "%s/%s\n" "$(pwd)" "$base") || printf "%s\n" "$p"
  fi
}