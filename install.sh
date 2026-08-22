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
log_ok()    { [[ $QUIET -eq 1 ]] || printf "%b%b[✓]%b %s\n" "$C_BOLD" "$C_GREEN"  "$C_RESET" "$*"; }
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
        # US-007 AC-6: sop/gates.json deployment plan
        if [[ -d "$SOURCE_DIR/docs/sop" ]]; then
          log_plan "$TARGET_ROOT/.claude/sop/*.json (per-file symlinks into docs/sop/)"
        fi
        ;;
      pi)
        # Pi Agent global resource dir is ~/.pi/agent/ (per pi docs/usage.md),
        # not ~/.pi/. Earlier versions of this script installed to ~/.pi/
        # which is silently ignored by pi.
        log_plan "$TARGET_ROOT/.pi/agent/AGENTS.md -> $SOURCE_DIR/AGENTS.md"
        # Skills are merged per-skill into ~/.pi/agent/skills/ (same model as
        # Claude Code's merge mode). Tree-level symlink would clobber the
        # user's other global skills (e.g. ~/.agents/skills/ peers).
        log_plan "$TARGET_ROOT/.pi/agent/skills/ (merge: per-skill symlinks)"
        # SOUL.md is intentionally NOT installed globally:
        #   - pi does not read SOUL.md (no mention in any pi doc).
        #   - tree_monstor/AGENTS.md references SOUL.md via [[SOUL]] (same dir).
        # Subagents: per-file symlinks into ~/.agents/<name>.md (user-scope).
        # Currently pi-only (pi-subagents discovers them automatically).
        if [[ -d "$SOURCE_DIR/agents" ]]; then
          log_plan "$TARGET_ROOT/.agents/*.md (merge: per-agent symlinks)"
        fi
        # US-007 AC-6: sop/gates.json deployment plan
        if [[ -d "$SOURCE_DIR/docs/sop" ]]; then
          log_plan "$TARGET_ROOT/.pi/sop/*.json (per-file symlinks into docs/sop/)"
        fi
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
      # Pre-create $skills_link as an empty real directory so
      # ensure_merged_skills_into() takes the per-skill merge path
      # (matching ~/.pi/agent/skills/ behavior). Falling back to a
      # tree-level symlink here would silently shadow any other skills
      # the user later drops into ~/.claude/skills/.
      # Idempotent: skip if it already exists (file, symlink, or dir).
      if [[ ! -e "$skills_link" ]] && [[ ! -L "$skills_link" ]]; then
        run mkdir -p "$skills_link"
      fi
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

# Remove per-skill symlinks we created in a merged skills dir, leaving the
# user's own skills and any non-symlink entries untouched.
# Args: <merged_skills_dir> <source_skills_dir>
# Used by uninstall_pi() to clean ~/.pi/agent/skills/ entries that point
# at <source_skills_dir>/<skill>, without touching siblings owned by the user.
remove_merged_skills() {
  local merged_dir="$1"
  local source_dir="$2"

  if [[ ! -d "$merged_dir" ]] && [[ ! -L "$merged_dir" ]]; then
    return 0
  fi

  # If the merged dir itself is a tree-level symlink (legacy install),
  # remove it entirely.
  if [[ -L "$merged_dir" ]]; then
    local target
    target="$(readlink "$merged_dir")"
    if [[ "$target" == "$source_dir" ]]; then
      run rm "$merged_dir"
      log_ok "removed tree-level symlink: $merged_dir"
      return 0
    fi
    log_warn "skipping symlink (not ours): $merged_dir -> $target"
    return 0
  fi

  # Real dir: scan and remove only our per-skill symlinks.
  shopt -s nullglob
  local entry removed=0 skipped=0
  for entry in "$merged_dir"/*; do
    local name
    name="$(basename "$entry")"
    if [[ ! -L "$entry" ]]; then
      skipped=$((skipped + 1))
      continue
    fi
    local target
    target="$(readlink "$entry")"
    # Match per-skill symlinks pointing into <source_dir>/<skill>.
    if [[ "$target" == "$source_dir/$name" ]]; then
      run rm "$entry"
      log_ok "removed merged skill: $entry"
      removed=$((removed + 1))
    else
      skipped=$((skipped + 1))
    fi
  done
  shopt -u nullglob

  # If the merged dir is now empty, leave it (may be owned by user).
  log_info "remove_merged_skills: removed=$removed, skipped=$skipped"
}

# Remove per-file symlinks we created in a merged sop/ directory
# (one symlink per .json file in <source_dir>/docs/sop/). Leaves the
# user's own .json files untouched.
# Args: <merged_sop_dir> <source_sop_dir>
# Used by uninstall_claude() and uninstall_pi() to clean
# ~/.pi/sop/ and ~/.claude/sop/ entries that point at files under
# <source_sop_dir>/ (including <source_sop_dir>/handbook/ subdir), without
# touching user-owned siblings.
remove_merged_sop() {
  local merged_dir="$1"
  local source_dir="$2"

  if [[ ! -d "$merged_dir" ]] && [[ ! -L "$merged_dir" ]]; then
    return 0
  fi

  # If sop/ itself is a tree-level symlink (legacy install), remove it
  # entirely (same pattern as remove_merged_skills).
  if [[ -L "$merged_dir" ]]; then
    local target
    target="$(readlink "$merged_dir")"
    if [[ "$target" == "$source_dir" ]]; then
      run rm "$merged_dir"
      log_ok "removed tree-level sop/ symlink: $merged_dir"
      return 0
    fi
    log_warn "skipping symlink (not ours): $merged_dir -> $target"
    return 0
  fi

  # Real dir: scan and remove only our per-file symlinks.
  # We recurse into subdirs (e.g. handbook/) so handbook symlinks created
  # by install_sop() are also cleaned up on uninstall (TD-018).
  local removed=0 skipped=0
  _remove_merged_sop_recurse() {
    local dir="$1"
    local base_src="$2"
    local entry
    for entry in "$dir"/*; do
      [[ -e "$entry" || -L "$entry" ]] || continue
      local name
      name="$(basename "$entry")"
      if [[ -L "$entry" ]]; then
        local target
        target="$(readlink "$entry")"
        if [[ "$target" == "$base_src/$name" ]]; then
          run rm "$entry"
          log_ok "removed merged sop file: $entry"
          removed=$((removed + 1))
        else
          skipped=$((skipped + 1))
        fi
      elif [[ -d "$entry" ]]; then
        # Recurse: handbook/ subdir contains per-file symlinks whose targets
        # live under <source_sop_dir>/handbook/<file>.
        _remove_merged_sop_recurse "$entry" "$base_src/$name"
      else
        skipped=$((skipped + 1))
      fi
    done
  }
  _remove_merged_sop_recurse "$merged_dir" "$source_dir"

  # If the merged dir is now empty, leave it (may be owned by user).
  log_info "remove_merged_sop: removed=$removed, skipped=$skipped"
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
  # ~/.claude/skills/ may be either a tree-level symlink (legacy install)
  # or a real directory holding our per-skill symlinks. Handle both:
  #   - symlink: remove only if it points at $SOURCE_DIR/skills.
  #   - real dir: remove only our per-skill symlinks, leave user skills.
  if [[ -L "$claude_root/skills" ]]; then
    remove_managed_path "$claude_root/skills" symlink
  elif [[ -d "$claude_root/skills" ]]; then
    remove_merged_skills "$claude_root/skills" "$SOURCE_DIR/skills"
  fi
  remove_managed_path "$claude_root/CLAUDE.md" marker-file
  # ~/.claude/sop/ may be either a tree-level symlink (legacy install)
  # or a real directory holding our per-file .json symlinks. Handle both,
  # mirroring the skills logic so user-owned .json files are preserved.
  if [[ -L "$claude_root/sop" ]]; then
    remove_managed_path "$claude_root/sop" symlink
  elif [[ -d "$claude_root/sop" ]]; then
    remove_merged_sop "$claude_root/sop" "$SOURCE_DIR/docs/sop"
  fi
}

uninstall_pi() {
  local pi_root="$TARGET_ROOT/.pi"
  # Global AGENTS.md lives at $pi_root/agent/AGENTS.md (NOT $pi_root/AGENTS.md,
  # which pi silently ignores). See install_pi() and pi docs/usage.md.
  remove_managed_path "$pi_root/agent/AGENTS.md" symlink
  # Skills are merged per-skill into $pi_root/agent/skills/.
  remove_merged_skills "$pi_root/agent/skills" "$SOURCE_DIR/skills"
  # sop/ is merged per-file into $pi_root/sop/ (mirrors the skills logic
  # so user-owned .json files are preserved).
  if [[ -L "$pi_root/sop" ]]; then
    remove_managed_path "$pi_root/sop" symlink
  elif [[ -d "$pi_root/sop" ]]; then
    remove_merged_sop "$pi_root/sop" "$SOURCE_DIR/docs/sop"
  fi
  # Subagents are symlinked into ~/.agents/<name>.md (user-scope).
  uninstall_subagents
}

uninstall_agents_dir() {
  remove_managed_path "$TARGET_ROOT/.agents/tree_monstor" tree
}

# ---------- Pi Agent installer ----------
# REGRESSION-GUARD PROBE: pi-install
install_pi() {
  log_info "Installing for Pi Agent..."
  local pi_root="$TARGET_ROOT/.pi"

  # Pi's documented global resource dir is ~/.pi/agent/ (see pi
  # docs/usage.md:100 and docs/skills.md#locations). Earlier versions of
  # this script installed to ~/.pi/ (e.g. ~/.pi/AGENTS.md,
  # ~/.pi/skills), which pi silently ignores — AGENTS.md was never
  # loaded at startup and skills were never discovered.
  local agent_root="$pi_root/agent"
  [[ -d "$agent_root" ]] || run mkdir -p "$agent_root"

  # AGENTS.md: single symlink at the correct location.
  ensure_symlink "$agent_root/AGENTS.md" "$SOURCE_DIR/AGENTS.md"

  # Skills: merge per-skill symlinks into ~/.pi/agent/skills/.
  # Use a dedicated merge function so we never clobber other global skills
  # the user may have placed there (e.g. ~/.pi/agent/skills/gsap-*).
  # Pre-create the dir so ensure_merged_skills_into() takes the merge path
  # instead of falling back to a tree-level symlink (which would shadow any
  # skills the user adds later).
  [[ -d "$agent_root/skills" ]] || [[ -L "$agent_root/skills" ]] || run mkdir -p "$agent_root/skills"
  ensure_merged_skills_into "$SOURCE_DIR/skills" "$agent_root/skills"

  # SOUL.md is NOT installed globally. See plan output above for rationale.

  # Subagents: per-file symlinks into ~/.agents/<name>.md (user-scope).
  # pi-subagents discovers them automatically and they take precedence
  # over builtins but lose to project-scope agents.
  install_subagents
}

# ---------- Subagent installer (pi-only) ----------
# Installs tree_monstor's subagents (e.g. suggester) to ~/.agents/<name>.md
# (user-scope). pi-subagents discovers them automatically; they take
# precedence over builtins but lose to project-scope agents.
#
# Layout:
#   - Source: $SOURCE_DIR/agents/<name>.md
#   - Target: $TARGET_ROOT/.agents/<name>.md  (symlink)
#
# Conflicts: if a non-symlink file already exists at the target, we skip
# with a warning (preserves user-owned subagents, mirroring skill merge).
# REGRESSION-GUARD PROBE: subagent-install
install_subagents() {
  local src_agents_dir="$SOURCE_DIR/agents"
  if [[ ! -d "$src_agents_dir" ]]; then
    return 0
  fi

  local dst_agents_dir="$TARGET_ROOT/.agents"
  [[ -d "$dst_agents_dir" ]] || run mkdir -p "$dst_agents_dir"

  shopt -s nullglob
  local agent_path installed=0 updated=0 ok=0 skipped=0
  for agent_path in "$src_agents_dir"/*.md; do
    local name
    name="$(basename "$agent_path")"
    local link="$dst_agents_dir/$name"
    local target_abs
    target_abs="$(abs_path "$agent_path")"

    if [[ -L "$link" ]]; then
      # Existing symlink — check target matches our source.
      local current
      current="$(readlink "$link")"
      if [[ "$current" == "$target_abs" ]]; then
        log_ok "subagent OK: $link -> $target_abs"
        ok=$((ok + 1))
        continue
      fi
      # Wrong target — ensure_symlink() will repair it (logs "wrong target,
      # repairing" + "symlink created").
      ensure_symlink "$link" "$agent_path"
      updated=$((updated + 1))
      continue
    fi

    # Not a symlink — either missing (create) or regular file (skip).
    if [[ -e "$link" ]]; then
      log_warn "subagent: target exists and is not a symlink, skipping: $link"
      skipped=$((skipped + 1))
      continue
    fi

    # Missing — create new (ensure_symlink() logs "symlink created").
    ensure_symlink "$link" "$agent_path"
    installed=$((installed + 1))
  done
  shopt -u nullglob

  local total=$((installed + updated + ok + skipped))
  if (( total > 0 )); then
    log_info "subagents: installed=$installed, updated=$updated, ok=$ok, skipped=$skipped"
  fi
}

# uninstall_subagents: remove symlinks we created in ~/.agents/.
# Only removes symlinks pointing into our SOURCE_DIR/agents/ (safe against
# user-owned subagents, mirrors remove_merged_skills() pattern).
uninstall_subagents() {
  local src_agents_dir="$SOURCE_DIR/agents"
  [[ -d "$src_agents_dir" ]] || return 0

  local dst_agents_dir="$TARGET_ROOT/.agents"
  [[ -d "$dst_agents_dir" ]] || return 0

  shopt -s nullglob
  local removed=0
  for agent_path in "$src_agents_dir"/*.md; do
    local name
    name="$(basename "$agent_path")"
    local link="$dst_agents_dir/$name"
    if [[ -L "$link" ]]; then
      local target
      target="$(readlink "$link")"
      if [[ "$target" == "$src_agents_dir/$name" ]] || [[ "$target" == "$(abs_path "$agent_path")" ]]; then
        run rm "$link"
        log_ok "removed subagent: $link"
        removed=$((removed + 1))
      else
        log_warn "skipping subagent (not ours): $link -> $target"
      fi
    fi
  done
  shopt -u nullglob

  if (( removed > 0 )); then
    log_info "subagents uninstalled: $removed"
  fi
}

# ---------- Local .agents/ copy installer ----------
# REGRESSION-GUARD PROBE: agents-dir-copy
install_agents_dir() {
  log_info "Installing local .agents/ copy..."
  ensure_copy_tree "$SOURCE_DIR" "$TARGET_ROOT/.agents/tree_monstor"
}

# ---------- sop/ directory installer (US-007, TD-018) ----------
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

  if [[ $DRY_RUN -eq 1 ]]; then
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
      claude)
        install_claude
        install_sop "$TARGET_ROOT/.claude"
        ;;
      pi)
        install_pi
        install_sop "$TARGET_ROOT/.pi"
        ;;
      *)      log_warn "Unknown agent '$agent' — skipping"; ;;
    esac
  done

  if [[ $INSTALL_AGENTS_DIR -eq 1 ]]; then
    install_agents_dir
  fi

  log_ok "Install complete."
}

main "$@"
