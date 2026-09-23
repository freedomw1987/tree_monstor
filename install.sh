#!/usr/bin/env bash
# install.sh — Idempotent installer for tree_monstor.
#
# Makes AGENTS.md, SOUL.md and skills/ available to AI coding agents
# (Claude Code, Pi Agent, ...) via symlinks (live updates) and a local
# .agents/ copy (official convention).
#
# Pure Bash. macOS (3.2+) and Linux (4+) compatible.
#
# Architecture: this script is the dispatch layer; helper functions live
# in lib/install/*.sh (logging / paths / symlink / agents / sop / agents_dir).
# This keeps the entry point short and the lib functions unit-testable.

set -euo pipefail

# Determine the project root (directory containing this install.sh).
# Needed BEFORE we can source any lib/install/*.sh file.
_PROJ_ROOT="$(cd "$(dirname "$0")" && pwd)"

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


# ---------- TD-008: Agent 路徑 / marker 常數集中 ----------
# 改這些變數就能影響全部 install.sh / uninstall 邏輯
readonly DIR_CLAUDE=".claude"
readonly DIR_PI=".pi"
readonly DIR_AGENTS=".agents"

# Loader marker 用來識別被本腳本管理的檔案
readonly LOADER_MARKER="tree-monstor-loader:DO-NOT-EDIT-START"
readonly LOADER_END_MARKER="tree-monstor-loader:DO-NOT-EDIT-END"

# 已知 agent 列表（驗證用）
readonly KNOWN_AGENTS=("claude" "pi")

# ---------- Source the lib/ helpers ----------
# Order matters: logging first (others depend on it), then paths/symlink,
# then agents/sop/agents_dir which call back into symlink.
# shellcheck source=lib/install/logging.sh
source "$_PROJ_ROOT/lib/install/logging.sh"
# shellcheck source=lib/install/paths.sh
source "$_PROJ_ROOT/lib/install/paths.sh"
# shellcheck source=lib/install/symlink.sh
source "$_PROJ_ROOT/lib/install/symlink.sh"
# shellcheck source=lib/install/sop.sh
source "$_PROJ_ROOT/lib/install/sop.sh"
# shellcheck source=lib/install/agents.sh
source "$_PROJ_ROOT/lib/install/agents.sh"
# shellcheck source=lib/install/agents_dir.sh
source "$_PROJ_ROOT/lib/install/agents_dir.sh"

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

# resolve_source() lives here (not in lib/install/paths.sh) because it
# depends on $0 = install.sh, not BASH_SOURCE inside a sourced lib.
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

# ---------- Dry-run preview ----------
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
      if [[ -f "$p" ]] && grep -q "${LOADER_MARKER}" "$p" 2>/dev/null; then
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
  local claude_root="$TARGET_ROOT/${DIR_CLAUDE}"
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
  local pi_root="$TARGET_ROOT/${DIR_PI}"
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

# uninstall_subagents: remove symlinks we created in ~/.agents/.
# Only removes symlinks pointing into our SOURCE_DIR/agents/ (safe against
# user-owned subagents, mirrors remove_merged_skills() pattern).
uninstall_subagents() {
  local src_agents_dir="$SOURCE_DIR/agents"
  [[ -d "$src_agents_dir" ]] || return 0

  local dst_agents_dir="$TARGET_ROOT/${DIR_AGENTS}"
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

uninstall_agents_dir() {
  remove_managed_path "$TARGET_ROOT/${DIR_AGENTS}/tree_monstor" tree
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

  for agent in "${AGENTS[@]}"; do
    case "$agent" in
      claude)
        install_claude
        install_sop "$TARGET_ROOT/${DIR_CLAUDE}"
        ;;
      pi)
        install_pi
        install_sop "$TARGET_ROOT/${DIR_PI}"
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