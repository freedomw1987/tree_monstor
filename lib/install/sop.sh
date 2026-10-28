# shellcheck shell=bash  # 被 source 的函式庫（無 shebang），明確告知 shellcheck 目標 shell
# lib/install/sop.sh — 舊版 sop/ 安裝遺留嘅清理（uninstall 用）。
#
# Source this from install.sh. Defines:
#   - remove_merged_sop <merged_dir> <source_sop_dir>
#
# 2026-10-28：sop/ **部署**功能已移除 —— `docs/sop/`（handbook ＋ gates.json）已退役，
# Gate 定義搬入各自承載它的 skill（dav-developer／dav-reviewer）。
# → install.sh 唔再喺 `~/.pi/sop/`、`~/.claude/sop/` 放任何嘢。
#
# 但係：舊版本（2026-10-28 前）已經喺嗰啲位置留低 symlink → 升級後佢哋會變「指向已刪檔案」
# 嘅死連結。所以 uninstall 仍然要清走**我哋自己建立嘅** symlink，
# 而 user 自己放落去嘅檔案要保留（同一套 remove_merged_skills 邏輯）。
#
# 注意：source 端 `docs/sop/` 已經唔存在，但清理照樣做得 —— 靠 symlink 嘅 target path
# 對唔對得上嚟判斷「係咪我哋建立嘅」，唔靠 target 仲在唔在。

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
  # by the old installer are also cleaned up on uninstall (TD-018).
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
