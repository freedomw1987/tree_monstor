# lib/install/sop.sh — sop/ directory installer (per-file symlinks).
#
# Source this from install.sh. Defines:
#   - install_sop <agent_root>
#
# Requires:
#   log_info / log_ok / log_warn / log_err (from logging.sh)
#   run / log_dry (from logging.sh)
#
# Reads:
#   SOURCE_DIR (looks for $SOURCE_DIR/docs/sop/)

# Symlinks every .json file at top level AND every .md file under handbook/
# in $SOURCE_DIR/docs/sop/ into <agent_root>/sop/. Each file becomes its own
# symlink so that edits to the source files take effect immediately
# (no need to re-run install).
# REGRESSION-GUARD PROBE: sop-per-file-symlinks
install_sop() {
  local agent_root="$1"
  local sop_src="$SOURCE_DIR/docs/sop"
  local sop_dst="$agent_root/sop"

  if [[ ! -d "$sop_src" ]]; then
    log_dry "skip: source has no docs/sop/ (sop not required for this agent)"
    return 0
  fi

  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log_dry "sop per-file symlinks: $sop_src/*.json -> $sop_dst/"
    if [[ -d "$sop_src/handbook" ]]; then
      log_dry "sop handbook per-file symlinks: $sop_src/handbook/*.md -> $sop_dst/handbook/"
    fi
    return 0
  fi

  [[ -d "$sop_dst" ]] || run mkdir -p "$sop_dst"
  local f name
  # Top-level *.json files (gates.json + gates.schema.json)
  for f in "$sop_src"/*.json; do
    [[ -e "$f" ]] || continue
    name="$(basename "$f")"
    run ln -sfn "$f" "$sop_dst/$name"
  done
  # handbook/*.md files (TD-018: required for AGENTS.md relative links)
  if [[ -d "$sop_src/handbook" ]]; then
    local hb_dst="$sop_dst/handbook"
    [[ -d "$hb_dst" ]] || run mkdir -p "$hb_dst"
    for f in "$sop_src/handbook"/*.md; do
      [[ -e "$f" ]] || continue
      name="$(basename "$f")"
      run ln -sfn "$f" "$hb_dst/$name"
    done
    log_ok "sop handbook installed: $hb_dst (per-file symlinks into $sop_src/handbook)"
  fi
  log_ok "sop installed: $sop_dst (per-file symlinks into $sop_src)"
}