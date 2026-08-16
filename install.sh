#!/usr/bin/env bash
# install.sh — Idempotent installer for tree_monstor.
#
# Makes AGENTS.md, SOUL.md and skills/ available to AI coding agents
# (Claude Code, Pi Agent, ...) via symlinks (live updates) and a local
# .agents/ copy (official convention).
#
# Pure Bash. macOS (3.2+) and Linux (4+) compatible.

set -euo pipefail

# ---------- Version ----------
readonly VERSION="0.1.0"

# ---------- Defaults ----------
MODE="global"          # global | local | target
TARGET_DIR=""          # set when MODE=target
SOURCE_DIR=""          # set via --source or auto-detected
AGENTS=("claude" "pi") # default: both
INSTALL_AGENTS_DIR=1   # 1 = yes, 0 = no
UNINSTALL=0
DRY_RUN=0
YES=0
QUIET=0
CLAUDE_SKILLS_MODE="merge"  # merge | replace | skip

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
log_info()  { [[ $QUIET -eq 1 ]] || printf "%b[i]%b %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
log_ok()    { [[ $QUIET -eq 1 ]] || printf "%b[✓]%b %s\n" "$C_GREEN"  "$C_RESET" "$*"; }
log_warn()  { printf "%b[!]%b %s\n" "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err()   { printf "%b[✗]%b %s\n" "$C_RED"    "$C_RESET" "$*" >&2; }
log_dry()   { printf "%b[~]%b %s (dry-run)\n" "$C_DIM" "$C_RESET" "$*"; }
log_plan()  { printf "%b    →%b %s\n" "$C_DIM"   "$C_RESET" "$*"; }

# Conditional side-effect: run a command now (or print it under --dry-run).
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    log_dry "$*"
  else
    "$@"
  fi
}

# ---------- Help ----------
print_help() {
  cat <<EOF
${C_BOLD}install.sh${C_RESET} — Idempotent installer for tree_monstor (v${VERSION})

${C_BOLD}Usage:${C_RESET}
  ./install.sh [options]

${C_BOLD}Scope (pick one):${C_RESET}
  --global            Install to \$HOME (default)
  --local             Install to current working directory
  --target <path>     Install to a specific directory

${C_BOLD}Selection:${C_RESET}
  --agent <claude|pi> Limit to a single agent (repeatable, default: both)
  --no-agents-dir     Skip the local ~/.agents/ copy

${C_BOLD}Source:${C_RESET}
  --source <path>     Path to tree_monstor source (default: directory of this script)

${C_BOLD}Actions:${C_RESET}
  --uninstall         Remove what this script installed
  --dry-run           Print actions without executing

${C_BOLD}UX:${C_RESET}
  -y, --yes                          Skip confirmation prompt
  -q, --quiet                        Suppress info/ok output
  -h, --help                         Show this help and exit
      --version                      Show version and exit

${C_BOLD}Claude skills mode (when ~/.claude/skills already exists):${C_RESET}
      --claude-skills-mode <mode>    merge (default) | replace | skip
                                     merge  = per-skill symlinks, keep user skills
                                     replace = backup existing as .bak.<ts> then symlink
                                     skip    = leave ~/.claude/skills untouched

${C_BOLD}Examples:${C_RESET}
  ./install.sh                          # Global install for both agents
  ./install.sh --local                  # Project-level install
  ./install.sh --agent claude           # Only Claude Code
  ./install.sh --target ~/proj/foo      # Specific directory
  ./install.sh --dry-run                # Preview what would happen
  ./install.sh --uninstall --local      # Remove project-level install
EOF
}

print_version() {
  printf "install.sh %s\n" "$VERSION"
}

# ---------- Argument parsing ----------
# REGRESSION-GUARD PROBE: arg-parsing
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --global)   MODE="global" ;;
      --local)    MODE="local" ;;
      --target)   MODE="target"; TARGET_DIR="${2:-}"; [[ -z "$TARGET_DIR" ]] && { log_err "--target requires a path"; exit 2; }; shift ;;
      --agent)    AGENTS=("${2:-}"); [[ -z "${AGENTS[0]}" ]] && { log_err "--agent requires a name"; exit 2; }; shift ;;
      --no-agents-dir) INSTALL_AGENTS_DIR=0 ;;
      --source)   SOURCE_DIR="${2:-}"; [[ -z "$SOURCE_DIR" ]] && { log_err "--source requires a path"; exit 2; }; shift ;;
      --uninstall) UNINSTALL=1 ;;
      --dry-run)   DRY_RUN=1 ;;
      -y|--yes)    YES=1 ;;
      -q|--quiet)  QUIET=1 ;;
      --claude-skills-mode)
        CLAUDE_SKILLS_MODE="${2:-}"
        case "$CLAUDE_SKILLS_MODE" in
          merge|replace|skip) ;;
          *) log_err "--claude-skills-mode must be one of: merge, replace, skip"; exit 2 ;;
        esac
        shift
        ;;
      --claude-skills-mode=*)
        CLAUDE_SKILLS_MODE="${1#--claude-skills-mode=}"
        case "$CLAUDE_SKILLS_MODE" in
          merge|replace|skip) ;;
          *) log_err "--claude-skills-mode must be one of: merge, replace, skip"; exit 2 ;;
        esac
        ;;
      -h|--help)   print_help; exit 0 ;;
      --version)   print_version; exit 0 ;;
      *)
        log_err "Unknown argument: $1"
        log_err "Try '$0 --help' for usage."
        exit 2
        ;;
    esac
    shift
  done
}

# ---------- Path resolution ----------
resolve_source() {
  if [[ -z "$SOURCE_DIR" ]]; then
    # Default: directory containing this script.
    SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
  fi
  if [[ ! -d "$SOURCE_DIR" ]]; then
    log_err "Source directory not found: $SOURCE_DIR"
    exit 2
  fi
  if [[ ! -f "$SOURCE_DIR/AGENTS.md" ]] || [[ ! -f "$SOURCE_DIR/SOUL.md" ]] || [[ ! -d "$SOURCE_DIR/skills" ]]; then
    log_err "Source must contain AGENTS.md, SOUL.md, and skills/"
    log_err "Got: $SOURCE_DIR"
    exit 2
  fi
}

resolve_target_root() {
  case "$MODE" in
    global)
      TARGET_ROOT="${HOME:-}"
      [[ -n "$TARGET_ROOT" ]] || { log_err "HOME is not set"; exit 2; }
      ;;
    local)
      TARGET_ROOT="$(pwd)"
      ;;
    target)
      TARGET_ROOT="$TARGET_DIR"
      [[ -d "$TARGET_ROOT" ]] || { log_err "Target directory does not exist: $TARGET_ROOT"; exit 2; }
      ;;
  esac
}

# ---------- Confirmation ----------
confirm() {
  [[ $YES -eq 1 ]] && return 0
  [[ $DRY_RUN -eq 1 ]] && return 0  # dry-run is a preview, never blocks
  local ans
  if [[ -t 0 ]]; then
    read -r -p "[?] Proceed? [y/N] " ans
  else
    read -r ans < /dev/null || ans=""
  fi
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------- Dry-run preview (basic; richer version comes in Phase C/D) ----------
print_plan() {
  log_info "Plan:"
  log_plan "mode=$MODE  target=$TARGET_ROOT  source=$SOURCE_DIR"
  log_plan "agents: ${AGENTS[*]}"
  for agent in "${AGENTS[@]}"; do
    case "$agent" in
      claude)
        log_plan "$TARGET_ROOT/.claude/CLAUDE.md (wrapper with @references)"
        case "$CLAUDE_SKILLS_MODE" in
          merge)
            log_plan "$TARGET_ROOT/.claude/skills (merge: per-skill symlinks into existing dir if needed)"
            ;;
          replace)
            log_plan "$TARGET_ROOT/.claude/skills (replace: backup existing as .bak.<ts> then symlink)"
            ;;
          skip)
            log_plan "$TARGET_ROOT/.claude/skills (skip: leave alone)"
            ;;
        esac
        ;;
      pi)
        log_plan "$TARGET_ROOT/.pi/AGENTS.md -> $SOURCE_DIR/AGENTS.md"
        log_plan "$TARGET_ROOT/.pi/SOUL.md   -> $SOURCE_DIR/SOUL.md"
        log_plan "$TARGET_ROOT/.pi/skills    -> $SOURCE_DIR/skills"
        ;;
    esac
  done
  if [[ $INSTALL_AGENTS_DIR -eq 1 ]]; then
    log_plan "$TARGET_ROOT/.agents/tree_monstor/ (copy)"
  fi
}

# ---------- Symlink helpers ----------
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

  if [[ $DRY_RUN -eq 1 ]]; then
    log_dry "write file: $path (length=${#content})"
  else
    printf "%s" "$content" > "$path"
    log_ok "file written: $path"
  fi
}

# ---------- Agent installers ----------
# REGRESSION-GUARD PROBE: claude-install
install_claude() {
  log_info "Installing for Claude Code..."

  local claude_root="$TARGET_ROOT/.claude"
  local skills_link="$claude_root/skills"
  local wrapper="$claude_root/CLAUDE.md"

  # Resolve / create the wrapper directory.
  [[ -d "$claude_root" ]] || run mkdir -p "$claude_root"

  case "$CLAUDE_SKILLS_MODE" in
    merge)
      ensure_merged_skills_into "$SOURCE_DIR/skills" "$skills_link"
      ;;
    replace)
      if [[ -e "$skills_link" ]] && [[ ! -L "$skills_link" ]]; then
        local stamp
        stamp="$(date +%Y%m%d-%H%M%S)"
        log_warn "replace: backing up $skills_link -> $skills_link.bak.$stamp"
        run mv "$skills_link" "$skills_link.bak.$stamp"
      fi
      ensure_symlink "$skills_link" "$SOURCE_DIR/skills"
      ;;
    skip)
      log_info "skipping Claude skills (--claude-skills-mode=skip)"
      ;;
  esac

  # Wrapper content with marker comments so --uninstall can find it.
  local content
  content="$(cat <<EOF
# tree-monstor-loader:DO-NOT-EDIT-START
# Auto-generated by install.sh v${VERSION}. Safe to remove via:
#   ./install.sh --uninstall
#
# Pulls AGENTS.md and SOUL.md from the tree_monstor source so any edit
# there propagates immediately (this file is regenerated on each run).

@${SOURCE_DIR}/AGENTS.md
@${SOURCE_DIR}/SOUL.md
# tree-monstor-loader:DO-NOT-EDIT-END
EOF
)"

  ensure_file "$wrapper" "$content"
}

# ---------- Uninstall ----------
# REGRESSION-GUARD PROBE: uninstall
do_uninstall() {
  log_info "Uninstalling..."

  for agent in "${AGENTS[@]}"; do
    case "$agent" in
      claude)
        uninstall_claude
        ;;
      pi)
        uninstall_pi
        ;;
      *) log_warn "Unknown agent '$agent' — skipping"; ;;
    esac
  done

  if [[ $INSTALL_AGENTS_DIR -eq 1 ]]; then
    uninstall_agents_dir
  fi
}

# Remove a path only if it looks like something we created.
# Safe to call on missing paths.
remove_managed_path() {
  local p="$1"
  local kind="$2"  # "symlink" | "marker-file" | "tree"

  if [[ ! -e "$p" ]] && [[ ! -L "$p" ]]; then
    return 0
  fi

  case "$kind" in
    symlink)
      # Only remove symlinks — never touch real files/dirs.
      if [[ -L "$p" ]]; then
        run rm "$p"
        log_ok "removed symlink: $p"
      else
        log_warn "skipping non-symlink (user file?): $p"
      fi
      ;;
    marker-file)
      # Remove only if the file contains our marker.
      if [[ -f "$p" ]] && grep -q "tree-monstor-loader:DO-NOT-EDIT-START" "$p" 2>/dev/null; then
        run rm "$p"
        log_ok "removed managed file: $p"
      else
        log_warn "skipping (no marker): $p"
      fi
      ;;
    tree)
      # Remove a directory we copied (e.g. .agents/tree_monstor).
      if [[ -d "$p" ]] && [[ ! -L "$p" ]]; then
        run rm -rf "$p"
        log_ok "removed tree: $p"
      fi
      ;;
  esac
}

uninstall_claude() {
  local claude_root="$TARGET_ROOT/.claude"
  remove_managed_path "$claude_root/skills"   symlink
  remove_managed_path "$claude_root/CLAUDE.md" marker-file
}

uninstall_pi() {
  local pi_root="$TARGET_ROOT/.pi"
  remove_managed_path "$pi_root/AGENTS.md" symlink
  remove_managed_path "$pi_root/SOUL.md"   symlink
  remove_managed_path "$pi_root/skills"    symlink
}

uninstall_agents_dir() {
  remove_managed_path "$TARGET_ROOT/.agents/tree_monstor" tree
}

# ---------- Pi Agent installer ----------
# REGRESSION-GUARD PROBE: pi-install
install_pi() {
  log_info "Installing for Pi Agent..."
  local pi_root="$TARGET_ROOT/.pi"
  ensure_symlink "$pi_root/AGENTS.md" "$SOURCE_DIR/AGENTS.md"
  ensure_symlink "$pi_root/SOUL.md"   "$SOURCE_DIR/SOUL.md"
  ensure_symlink "$pi_root/skills"    "$SOURCE_DIR/skills"
}

# ---------- Local .agents/ copy installer ----------
# REGRESSION-GUARD PROBE: agents-dir-copy
install_agents_dir() {
  log_info "Installing local .agents/ copy..."
  ensure_copy_tree "$SOURCE_DIR" "$TARGET_ROOT/.agents/tree_monstor"
}

# ---------- Exclusion rules ----------
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

  if [[ $DRY_RUN -eq 1 ]]; then
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

# ---------- Main ----------
main() {
  parse_args "$@"
  resolve_source
  resolve_target_root

  log_info "Source : $SOURCE_DIR"
  log_info "Mode   : $MODE"
  log_info "Target : $TARGET_ROOT"
  log_info "Agents : ${AGENTS[*]}"
  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "(dry-run: no changes will be made)"
  fi

  if [[ $UNINSTALL -eq 1 ]]; then
    log_info "Action : uninstall"
    print_plan
    confirm || { log_warn "Aborted."; exit 1; }
    do_uninstall
    log_ok "Uninstall complete."
    exit 0
  fi

  log_info "Action : install"
  print_plan
  confirm || { log_warn "Aborted."; exit 1; }

  # Hooks for later phases (still no-op in Phase A).
  for agent in "${AGENTS[@]}"; do
    case "$agent" in
      claude) install_claude ;;
      pi)     install_pi ;;
      *)      log_warn "Unknown agent '$agent' — skipping"; ;;
    esac
  done

  if [[ $INSTALL_AGENTS_DIR -eq 1 ]]; then
    install_agents_dir
  fi

  log_ok "Install complete."
}

main "$@"
