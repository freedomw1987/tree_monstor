# lib/install/symlink.sh — Symlink and idempotent file helpers.
#
# Source this from install.sh. Defines:
#   - ensure_symlink <link_path> <target_path>
#   - ensure_merged_skill <link_path> <target_path>
#   - ensure_merged_skills_into <src_skills_dir> <dst_skills_dir>
#   - ensure_file <path> <content>
#
# Requires:
#   log_info / log_ok / log_warn / log_err (from logging.sh)
#   run (from logging.sh)
#   abs_path (from paths.sh)
#   DRY_RUN (0 or 1)

# ensure_symlink <link_path> <target_path>
# Idempotent: if link exists and points to target, skip; if broken/wrong, repair; else create.
# REGRESSION-GUARD PROBE: symlink-idempotency
ensure_symlink() {
  local link="$1"
  local target="$2"
  local target_abs
  target_abs="$(abs_path "$target")"

  if [[ -L "$link" ]]; then
    local current
    current="$(readlink "$link")"
    if [[ "$current" == "$target_abs" ]]; then
      log_ok "symlink OK: $link -> $target_abs"
      return 0
    fi
    log_warn "symlink wrong target, repairing: $link (was -> $current, want -> $target_abs)"
    run rm "$link"
  elif [[ -e "$link" ]]; then
    log_err "Path exists but is not a symlink: $link"
    log_err "Refusing to overwrite. Move it aside and re-run."
    return 1
  fi

  # Ensure parent directory exists.
  local parent
  parent="$(dirname -- "$link")"
  [[ -d "$parent" ]] || run mkdir -p "$parent"

  run ln -s "$target_abs" "$link"
  log_ok "symlink created: $link -> $target_abs"
}

# ensure_merged_skill <link_path> <target_path>
# Place a per-skill symlink at <link_path> pointing to <target_path>.
# Idempotent: existing symlink pointing to target is left alone; pointing
# elsewhere is repaired; existing non-symlink (user-owned skill) is
# preserved with a warning.
# REGRESSION-GUARD PROBE: merged-skill
ensure_merged_skill() {
  local link="$1"
  local target="$2"
  local target_abs
  target_abs="$(abs_path "$target")"

  # Ensure parent dir exists.
  local parent
  parent="$(dirname -- "$link")"
  [[ -d "$parent" ]] || run mkdir -p "$parent"

  if [[ -L "$link" ]]; then
    local current
    current="$(readlink "$link")"
    if [[ "$current" == "$target_abs" ]]; then
      log_ok "merge OK: $link -> $target_abs"
      return 0
    fi
    log_warn "merge: wrong-target symlink, repairing: $link ($current -> $target_abs)"
    run rm "$link"
    run ln -s "$target_abs" "$link"
    log_ok "merged: $link -> $target_abs"
    return 0
  fi

  if [[ -e "$link" ]]; then
    log_warn "merge: target exists and is not a symlink, skipping: $link"
    return 0
  fi

  run ln -s "$target_abs" "$link"
  log_ok "merged: $link -> $target_abs"
}

# ensure_merged_skills_into <src_skills_dir> <dst_skills_dir>
# Merge a tree_monstor skills directory into an existing real directory
# at <dst_skills_dir>, by creating per-skill symlinks at the file level.
# - If <dst_skills_dir> is a symlink: defer to ensure_symlink (whole-tree).
# - If <dst_skills_dir> does not exist: defer to ensure_symlink (create).
# - If <dst_skills_dir> is a regular file or block device: error out.
# - If <dst_skills_dir> is a real directory: per-skill merge.
# REGRESSION-GUARD PROBE: merged-skills-into
ensure_merged_skills_into() {
  local src_skills="$1"
  local dst_skills="$2"

  if [[ -L "$dst_skills" ]] || [[ ! -e "$dst_skills" ]]; then
    # Already a symlink, or doesn't exist yet — use the standard tree-level
    # symlink flow (re-uses all the existing idempotency logic).
    ensure_symlink "$dst_skills" "$src_skills"
    return 0
  fi

  if [[ ! -d "$dst_skills" ]]; then
    log_err "merge: $dst_skills exists but is not a directory; cannot merge"
    return 1
  fi

  log_info "merge: $dst_skills is a real directory; merging per-skill symlinks"

  shopt -s nullglob
  local skill_path skill_name merged=0 skipped=0
  for skill_path in "$src_skills"/*; do
    skill_name="$(basename "$skill_path")"
    if [[ -e "$dst_skills/$skill_name" ]] && [[ ! -L "$dst_skills/$skill_name" ]]; then
      log_warn "merge: skipping non-symlink conflict: $dst_skills/$skill_name"
      skipped=$((skipped + 1))
      continue
    fi
    # Capture pre/post state to count actually-new symlinks.
    local existed=0
    [[ -e "$dst_skills/$skill_name" ]] && existed=1
    ensure_merged_skill "$dst_skills/$skill_name" "$skill_path"
    [[ $existed -eq 0 ]] && merged=$((merged + 1))
  done
  shopt -u nullglob

  log_info "merge: done — newly merged: $merged, skipped (conflicts): $skipped"
}

# ensure_file <path> <content>
# Idempotent write of a regular file (e.g. the Claude wrapper).
ensure_file() {
  local path="$1"
  local content="$2"

  if [[ -f "$path" ]] && [[ ! -L "$path" ]]; then
    if [[ "$(cat "$path")" == "$content" ]]; then
      log_ok "file OK: $path"
      return 0
    fi
    log_warn "file exists with different content, will overwrite: $path"
  elif [[ -L "$path" ]]; then
    log_warn "path is a symlink, removing: $path"
    run rm "$path"
  fi

  local parent
  parent="$(dirname -- "$path")"
  [[ -d "$parent" ]] || run mkdir -p "$parent"

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log_dry "write file: $path (length=${#content})"
  else
    printf "%s" "$content" > "$path"
    log_ok "file written: $path"
  fi
}