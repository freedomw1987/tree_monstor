# lib/install/agents_dir.sh — Local .agents/ copy installer + exclusion rules.
#
# Source this from install.sh. Defines:
#   - should_exclude <name>
#   - ensure_copy_tree <src> <dst>
#   - install_agents_dir
#
# Requires:
#   log_info / log_ok / log_warn / log_err (from logging.sh)
#   run / log_dry (from logging.sh)
#
# Reads:
#   SOURCE_DIR, TARGET_ROOT, DIR_AGENTS

# Anything matching these name patterns is skipped during copy.
# Used for the .agents/ snapshot (we never symlink that — it's a real copy).
should_exclude() {
  local name="$1"
  case "$name" in
    .obsidian|.git|.DS_Store) return 0 ;;  # exact names
    *) return 1 ;;
  esac
}

# ensure_copy_tree <src_dir> <dst_dir>
# Copies src_dir into dst_dir, skipping excluded names anywhere in the tree.
# Idempotent: re-runs overwrite existing files but skip excluded ones.
# REGRESSION-GUARD PROBE: copy-with-exclude
ensure_copy_tree() {
  local src="$1"
  local dst="$2"

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log_dry "cp -R (filtered) $src -> $dst"
    return 0
  fi

  mkdir -p "$dst"

  # Use rsync if available; fall back to cp+rm. rsync is faster and clearer.
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --prune-empty-dirs \
      --exclude='.obsidian' --exclude='.obsidian/**' \
      --exclude='.git'      --exclude='.git/**' \
      --exclude='.DS_Store' --exclude='.DS_Store/**' \
      "$src/" "$dst/"
  else
    # Fallback: copy everything then remove excluded from dst.
    cp -R "$src/." "$dst/"
    find "$dst" \( -name .obsidian -o -name .git -o -name .DS_Store \) -prune -exec rm -rf {} +
  fi

  log_ok "copied tree: $src -> $dst (excluding .obsidian, .git, .DS_Store)"
}

# REGRESSION-GUARD PROBE: agents-dir-copy
install_agents_dir() {
  log_info "Installing local .agents/ copy..."
  ensure_copy_tree "$SOURCE_DIR" "$TARGET_ROOT/${DIR_AGENTS}/tree_monstor"
}