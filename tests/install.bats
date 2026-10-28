#!/usr/bin/env bats
#
# tests/install.bats
#
# Black-box tests for install.sh.
# Each test corresponds to one or more ACs in docs/backlog.md (US-001).
#
# Usage:
#   bats tests/

setup() {
  load 'helpers/test-env'
  setup_test_env
}

teardown() {
  teardown_test_env
}

# ---------- AC-1: skills symlinks globally ----------
@test "AC-1: default install symlinks skills to ~/.claude/skills and ~/.pi/agent/skills/" {
  run run_install --global --yes
  [ "$status" -eq 0 ]

  # Claude Code: per-skill symlinks merged into a freshly-created
  # ~/.claude/skills/ (matching ~/.pi/agent/skills/ behavior).
  # Pre-creating the dir as a real directory avoids the legacy tree-level
  # symlink that would shadow any other skills the user adds later.
  [ -d "$TEST_HOME/.claude/skills" ]
  [ ! -L "$TEST_HOME/.claude/skills" ]
  assert_path_is_symlink "$TEST_HOME/.claude/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"
  assert_path_is_symlink "$TEST_HOME/.claude/skills/dav-designer" "$TEST_SOURCE/skills/dav-designer"

  # Pi Agent: per-skill symlinks under ~/.pi/agent/skills/ (NOT ~/.pi/skills).
  # ~/.pi/agent/ is pi's documented global resource dir (see docs/usage.md).
  assert_path_is_symlink "$TEST_HOME/.pi/agent/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"
  assert_path_is_symlink "$TEST_HOME/.pi/agent/skills/dav-designer" "$TEST_SOURCE/skills/dav-designer"

  # Subagent definitions are symlinked per file into ~/.agents/ (home-level
  # user config for pi-subagents; project-scope .agents/*.md is the legacy form).
  assert_path_is_symlink "$TEST_HOME/.agents/mock-agent.md" "$TEST_SOURCE/agents/mock-agent.md"

  # ~/.pi/skills (the legacy wrong location) must NOT be created.
  [ ! -e "$TEST_HOME/.pi/skills" ]

  # Skill-bundled extensions (<skill>/extension/ with index.ts) are symlinked as
  # a DIRECTORY into pi's extension discovery dir — pi discovers <dir>/index.ts,
  # and relative imports inside the extension resolve against the real path.
  assert_path_is_symlink "$TEST_HOME/.pi/agent/extensions/dav-planner" \
    "$TEST_SOURCE/skills/dav-planner/extension"
}

# ---------- AC-2: Claude wrapper with @ references ----------
@test "AC-2: installs CLAUDE.md wrapper that @-references AGENTS.md and SOUL.md" {
  run run_install --global --agent claude --yes
  [ "$status" -eq 0 ]

  assert_path_is_file "$TEST_HOME/.claude/CLAUDE.md"
  assert_file_contains "$TEST_HOME/.claude/CLAUDE.md" "@$TEST_SOURCE/AGENTS.md"
  assert_file_contains "$TEST_HOME/.claude/CLAUDE.md" "@$TEST_SOURCE/SOUL.md"
  assert_file_contains "$TEST_HOME/.claude/CLAUDE.md" "tree-monstor-loader"
}

# ---------- AC-3: Pi Agent symlinks source files ----------
@test "AC-3: creates ~/.pi/agent/AGENTS.md symlink (NOT ~/.pi/AGENTS.md)" {
  run run_install --global --agent pi --yes
  [ "$status" -eq 0 ]

  # Correct location per pi docs/usage.md:100.
  assert_path_is_symlink "$TEST_HOME/.pi/agent/AGENTS.md" "$TEST_SOURCE/AGENTS.md"

  # Legacy wrong location must NOT exist.
  [ ! -e "$TEST_HOME/.pi/AGENTS.md" ]

  # SOUL.md is intentionally NOT installed globally:
  #   - pi does not read SOUL.md anywhere in its docs.
  #   - tree_monstor/AGENTS.md references SOUL.md via [[SOUL]] (same dir).
  #   - Global SOUL symlink would be a dead file no agent reads.
  [ ! -e "$TEST_HOME/.pi/SOUL.md" ]
  [ ! -e "$TEST_HOME/.pi/agent/SOUL.md" ]
}

# ---------- AC-4: also installs to local .agents/ ----------
@test "AC-4: also installs to ~/.agents/tree_monstor/ as copy" {
  run run_install --global --yes
  [ "$status" -eq 0 ]

  [ -d "$TEST_HOME/.agents/tree_monstor" ]
  assert_path_is_file "$TEST_HOME/.agents/tree_monstor/AGENTS.md"
  assert_path_is_file "$TEST_HOME/.agents/tree_monstor/SOUL.md"
  [ -d "$TEST_HOME/.agents/tree_monstor/skills/dav-planner" ]
  [ -d "$TEST_HOME/.agents/tree_monstor/skills/dav-designer" ]
}

@test "AC-4 (no-agents-dir): skips .agents/ when --no-agents-dir" {
  run run_install --global --no-agents-dir --yes
  [ "$status" -eq 0 ]
  # --no-agents-dir skips the tree_monstor COPY, not the directory: the pi
  # install still symlinks subagent definitions into ~/.agents/ (that is where
  # pi-subagents discovers them), which legitimately creates the directory.
  [ ! -e "$TEST_HOME/.agents/tree_monstor" ]
  assert_path_is_symlink "$TEST_HOME/.agents/mock-agent.md" "$TEST_SOURCE/agents/mock-agent.md"
}

# ---------- AC-5: --local installs to cwd ----------
@test "AC-5: --local installs to current directory" {
  run run_install --local --yes
  [ "$status" -eq 0 ]

  # DE-001 merge mode: ./skills may be a real dir (with per-skill symlinks)
  # OR a tree-level symlink — both are valid install states.
  [ -e "./.claude/skills" ]
  [ -e "./.pi/agent/skills" ]
  [ -f "./.claude/CLAUDE.md" ]
}

# ---------- AC-6: --target installs to specified path ----------
@test "AC-6: --target installs to specified path" {
  local target="$TEST_TMP_DIR/my-project"
  mkdir -p "$target"
  run run_install --target "$target" --yes
  [ "$status" -eq 0 ]

  [ -e "$target/.claude/skills" ]
  # Pi Agent target mirrors global layout: ~/.pi/agent/{AGENTS.md,skills/}.
  [ -L "$target/.pi/agent/AGENTS.md" ]
  [ -e "$target/.pi/agent/skills" ]
  [ -f "$target/.claude/CLAUDE.md" ]
  # Legacy wrong location must not be created under --target either.
  [ ! -e "$target/.pi/skills" ]
}

# ---------- AC-7: --agent filters targets ----------
@test "AC-7: --agent claude only installs Claude Code parts" {
  run run_install --global --agent claude --yes
  [ "$status" -eq 0 ]

  assert_path_exists "$TEST_HOME/.claude/CLAUDE.md"
  [ ! -e "$TEST_HOME/.pi" ]
}

@test "AC-7: --agent pi only installs Pi Agent parts" {
  run run_install --global --agent pi --yes
  [ "$status" -eq 0 ]

  assert_path_exists "$TEST_HOME/.pi/agent/AGENTS.md"
  assert_path_exists "$TEST_HOME/.pi/agent/skills/dav-planner"
  [ ! -e "$TEST_HOME/.claude" ]
}

# ---------- AC-8: --uninstall removes only managed files ----------
@test "AC-8: --uninstall removes symlinks and wrapper created by installer" {
  run run_install --global --yes
  [ "$status" -eq 0 ]

  # Pre-create an unrelated file in .claude/ to ensure installer doesn't touch it
  echo "user's own stuff" > "$TEST_HOME/.claude/user-notes.md"
  # Pre-create a user-owned extension: uninstall must only remove OUR symlinks.
  mkdir -p "$TEST_HOME/.pi/agent/extensions"
  echo "user's own extension" > "$TEST_HOME/.pi/agent/extensions/user-tool.ts"

  run run_install --uninstall --global --yes
  [ "$status" -eq 0 ]

  [ ! -e "$TEST_HOME/.claude/CLAUDE.md" ]
  # ~/.claude/skills/ may legitimately remain (empty or with user skills)
  # since we pre-create the dir to take the merge path; we only assert our
  # per-skill symlinks are gone, not the dir itself.
  [ ! -L "$TEST_HOME/.claude/skills/dav-planner" ]
  [ ! -L "$TEST_HOME/.claude/skills/dav-designer" ]
  [ ! -e "$TEST_HOME/.pi/agent/AGENTS.md" ]
  # ~/.pi/agent/skills/ may legitimately remain (empty) since we pre-create
  # the dir to take the merge path; we only assert our per-skill symlinks
  # are gone, not the dir itself.
  [ ! -L "$TEST_HOME/.pi/agent/skills/dav-planner" ]
  [ ! -L "$TEST_HOME/.agents/mock-agent.md" ]
  [ ! -e "$TEST_HOME/.agents/tree_monstor" ]
  # Our extension symlink goes; a user-owned extension file must survive.
  [ ! -L "$TEST_HOME/.pi/agent/extensions/dav-planner" ]
  assert_path_is_file "$TEST_HOME/.pi/agent/extensions/user-tool.ts"
  # Unrelated file must remain
  assert_path_is_file "$TEST_HOME/.claude/user-notes.md"
}

# ---------- AC-9: --dry-run makes no changes ----------
@test "AC-9: --dry-run prints plan but creates nothing" {
  run run_install --global --dry-run
  [ "$status" -eq 0 ]

  [ ! -e "$TEST_HOME/.claude" ]
  [ ! -e "$TEST_HOME/.pi" ]
  [ ! -e "$TEST_HOME/.agents" ]

  # Output should mention the planned actions
  [[ "$output" == *"CLAUDE.md"* ]] || {
    echo 'FAIL: tests/install.bats:174: assertion failed' >&2; return 1; }
  [[ "$output" == *"dry-run"* || "$output" == *"DRY"* ]]
}

# ---------- AC-10: --help prints usage ----------
@test "AC-10: --help prints usage and exits 0" {
  run run_install --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]] || {
    echo 'FAIL: tests/install.bats:183: assertion failed' >&2; return 1; }
  [[ "$output" == *"--global"* ]] || {
    echo 'FAIL: tests/install.bats:185: assertion failed' >&2; return 1; }
  [[ "$output" == *"--local"* ]] || {
    echo 'FAIL: tests/install.bats:187: assertion failed' >&2; return 1; }
  [[ "$output" == *"--uninstall"* ]] || {
    echo 'FAIL: tests/install.bats:189: assertion failed' >&2; return 1; }
}

# ---------- AC-11: idempotent ----------
@test "AC-11a: repeated runs produce identical state and no errors" {
  run run_install --global --yes
  [ "$status" -eq 0 ]

  # 拍一次快照：列出 install 產出的所有檔案 + 每個檔案的 sha256 hash
  # 跨平台友奸（不依賴 mtime / permissions / find 順序）
  snapshot_install_state() {
    local home="$1"
    # 只列 install.sh 管理的子目錄（$home/.claude, .pi, .agents/tree_monstor）
    {
      find "$home/.claude" "$home/.pi" "$home/.agents/tree_monstor" -type f -o -type l 2>/dev/null | sort
    } | while read -r p; do
      # 每一行：路徑 + 類型（file/symlink）+ 內容 hash 或 symlink target
      if [[ -L "$p" ]]; then
        echo "$(realpath "$p" 2>/dev/null || readlink "$p") symlink $(readlink "$p")"
      elif [[ -f "$p" ]]; then
        echo "$(realpath "$p" 2>/dev/null || echo "$p") file $(shasum -a 256 "$p" | awk '{print $1}')"
      fi
    done | sort | shasum -a 256 | awk '{print $1}'
  }

  local first_snapshot
  first_snapshot="$(snapshot_install_state "$TEST_HOME")"

  # 跑第二次
  run run_install --global --yes
  [ "$status" -eq 0 ]

  local second_snapshot
  second_snapshot="$(snapshot_install_state "$TEST_HOME")"

  [ "$first_snapshot" = "$second_snapshot" ]

  # 額外驗證：具體檔案清單（path basename）應一致
  local first_files second_files
  first_files="$(find "$TEST_HOME/.claude" "$TEST_HOME/.pi" "$TEST_HOME/.agents/tree_monstor" -mindepth 1 2>/dev/null | sort)"
  second_files="$(find "$TEST_HOME/.claude" "$TEST_HOME/.pi" "$TEST_HOME/.agents/tree_monstor" -mindepth 1 2>/dev/null | sort)"
  [ "$first_files" = "$second_files" ]
}

@test "AC-11b: re-running repairs a broken symlink" {
  run run_install --global --yes
  [ "$status" -eq 0 ]

  # Manually break the symlink (delete source subtree)
  rm -rf "$TEST_SOURCE/skills/dav-planner"
  [ ! -e "$TEST_HOME/.claude/skills/dav-planner" ]

  # Restore the source
  mkdir -p "$TEST_SOURCE/skills/dav-planner"
  echo "# restored" > "$TEST_SOURCE/skills/dav-planner/SKILL.md"

  run run_install --global --yes
  [ "$status" -eq 0 ]
  assert_path_exists "$TEST_HOME/.claude/skills/dav-planner/SKILL.md"
}

# ---------- AC-12: excludes .obsidian, .git, .DS_Store ----------
@test "AC-12: excludes .obsidian/, .git/, .DS_Store from copy to .agents/" {
  run run_install --global --yes
  [ "$status" -eq 0 ]

  [ ! -e "$TEST_HOME/.agents/tree_monstor/.obsidian" ]
  [ ! -e "$TEST_HOME/.agents/tree_monstor/.DS_Store" ]
  [ ! -e "$TEST_HOME/.agents/tree_monstor/.git" ]
  [ ! -e "$TEST_HOME/.agents/tree_monstor/should-exclude-git" ]
}

# ---------- AC-13: colored output (skipped when NO_COLOR set) ----------
@test "AC-13: output uses ANSI color codes when NO_COLOR is unset" {
  run env -i HOME="$TEST_HOME" PATH="/usr/bin:/bin" TERM="xterm" \
    bash "$INSTALL_SH" --source "$TEST_SOURCE" --global --dry-run
  [ "$status" -eq 0 ]
  # ANSI escape: ESC[
  [[ "$output" == *$'\033['* ]] || {
    echo 'FAIL: tests/install.bats:268: assertion failed' >&2; return 1; }
}

# ---------- AC-14: pure bash ----------
@test "AC-14: install.sh starts with #!/usr/bin/env bash" {
  run head -1 "$BATS_TEST_DIRNAME/../install.sh"
  [[ "$output" == *"bash"* ]] || {
    echo 'FAIL: tests/install.bats:275: assertion failed' >&2; return 1; }
}

# ---------- AC-15: README exists and documents usage ----------
@test "AC-15: README.md exists and contains usage section" {
  [ -f "$BATS_TEST_DIRNAME/../README.md" ]
  run cat "$BATS_TEST_DIRNAME/../README.md"
  [[ "$output" == *"Usage"* ]] || {
    echo 'FAIL: tests/install.bats:283: assertion failed' >&2; return 1; }
  [[ "$output" == *"--global"* ]] || {
    echo 'FAIL: tests/install.bats:285: assertion failed' >&2; return 1; }
  [[ "$output" == *"--uninstall"* ]] || {
    echo 'FAIL: tests/install.bats:287: assertion failed' >&2; return 1; }
}

# ---------- AC-16: meta — every AC has a test ----------
@test "AC-16 (meta): this bats file references AC-1..AC-15 in @test names" {
  run grep -E '@test "AC-' "$BATS_TEST_DIRNAME/install.bats"
  [ "$status" -eq 0 ]
  # Expect at least 15 distinct ACs (we have AC-1..AC-15 + AC-4 split + AC-11 split + AC-7 split)
  local count
  count="$(grep -cE '@test "AC-' "$BATS_TEST_DIRNAME/install.bats")"
  [ "$count" -ge 15 ]
}

# =======================================================================
# DE-001: installer merges into existing ~/.claude/skills (merge mode)
# =======================================================================

# ---------- DE-001 / AC-1: auto-merge into existing skills dir ----------
@test "DE-001 AC-1: when ~/.claude/skills is a real dir, installer merges per-skill symlinks (no error)" {
  create_existing_claude_skills_dir

  run run_install --global --yes
  [ "$status" -eq 0 ]

  # The dir must still exist (not replaced).
  [ -d "$TEST_HOME/.claude/skills" ]
  [ ! -L "$TEST_HOME/.claude/skills" ]

  # User's own skills were preserved.
  assert_path_is_file "$TEST_HOME/.claude/skills/user-skill-a/SKILL.md"
  assert_path_is_file "$TEST_HOME/.claude/skills/user-skill-b/SKILL.md"

  # Non-conflicting source skills got merged as symlinks.
  assert_path_is_symlink "$TEST_HOME/.claude/skills/dav-planner"  "$TEST_SOURCE/skills/dav-planner"
  assert_path_is_symlink "$TEST_HOME/.claude/skills/dav-designer" "$TEST_SOURCE/skills/dav-designer"

  # conflict-skill collides with a user-owned slot, so it must stay as the
  # user's file (not a symlink).
  assert_path_is_file "$TEST_HOME/.claude/skills/conflict-skill/SKILL.md"
  if [[ -L "$TEST_HOME/.claude/skills/conflict-skill" ]]; then
    echo "FAIL: installer overwrote user's conflict-skill with a symlink" >&2
    return 1
  fi
}

# ---------- DE-001 / AC-2: merge default is per-skill symlink ----------
@test "DE-001 AC-2: merge mode creates per-skill symlinks (not a replacing tree-level symlink)" {
  create_existing_claude_skills_dir

  run run_install --global --yes
  [ "$status" -eq 0 ]

  # ~/.claude/skills itself stays a real dir (not replaced by a symlink).
  [ -d "$TEST_HOME/.claude/skills" ]
  [ ! -L "$TEST_HOME/.claude/skills" ]

  # Each non-conflicting merged skill is its own symlink into the source tree.
  local skill
  for skill in dav-planner dav-designer; do
    assert_path_is_symlink "$TEST_HOME/.claude/skills/$skill" "$TEST_SOURCE/skills/$skill"
  done
}

# ---------- DE-001 / AC-3: skip naming conflicts with warning ----------
@test "DE-001 AC-3: merge skips naming conflicts (does not overwrite user-owned skill)" {
  create_existing_claude_skills_dir

  # Snapshot the user's conflict-skill so we can verify it isn't overwritten.
  cp -R "$TEST_HOME/.claude/skills/conflict-skill" "$TEST_TMP_DIR/user-conflict-snapshot"

  run run_install --global --yes
  [ "$status" -eq 0 ]

  # User's file content must survive.
  assert_path_is_file "$TEST_HOME/.claude/skills/conflict-skill/SKILL.md"
  run cat "$TEST_HOME/.claude/skills/conflict-skill/SKILL.md"
  [[ "$output" == *"User-owned version"* ]] || {
    echo 'FAIL: tests/install.bats:364: assertion failed' >&2; return 1; }
  [[ ! "$output" == *"Mock conflict-skill"* ]] || {
    echo "FAIL: installer's conflict-skill content leaked into user's dir" >&2
    return 1
  }

  # The fixture's `conflict-skill` was NOT symlinked (because the slot was taken).
  if [[ -L "$TEST_HOME/.claude/skills/conflict-skill" ]]; then
    echo "FAIL: existing user skill was overwritten with a symlink" >&2
    return 1
  fi

  # The fixture's `conflict-skill/SKILL.md` content must not have been copied.
  run diff -r "$TEST_TMP_DIR/user-conflict-snapshot" "$TEST_HOME/.claude/skills/conflict-skill"
  [ "$status" -eq 0 ]
}

# ---------- DE-001 / AC-3b: merge repairs wrong-pointing existing symlinks ----------
@test "DE-001 AC-3b: merge fixes a wrong-target existing symlink in the target dir" {
  create_existing_claude_skills_dir

  # Replace user's dav-planner with a symlink pointing to the wrong target.
  rm -rf "$TEST_HOME/.claude/skills/dav-planner"
  # 故意讓 symlink 指到一個不存在的目標（驗「安裝器會修好指錯的 symlink」）
  ln -s "/tmp/nowhere-at-all" "$TEST_HOME/.claude/skills/dav-planner"  # TMP-OK: 純字串（不會寫檔）

  run run_install --global --yes
  [ "$status" -eq 0 ]

  # It should now be a symlink to the real source.
  assert_path_is_symlink "$TEST_HOME/.claude/skills/dav-planner" "$TEST_SOURCE/skills/dav-planner"
}

# ---------- DE-001 / AC-4: --claude-skills-mode=replace backs up & symlinks ----------
@test "DE-001 AC-4: --claude-skills-mode=replace backs up the existing skills dir and symlinks" {
  create_existing_claude_skills_dir

  run run_install --global --claude-skills-mode=replace --yes
  [ "$status" -eq 0 ]

  # A backup directory matching ~/.claude/skills.bak.* must exist.
  local bak
  bak="$(find "$TEST_HOME/.claude" -maxdepth 1 -type d -name 'skills.bak.*' | head -1)"
  [ -n "$bak" ]
  [ -d "$bak" ]
  assert_path_is_file "$bak/user-skill-a/SKILL.md"

  # And the live ~/.claude/skills is now a symlink to the source tree.
  assert_path_is_symlink "$TEST_HOME/.claude/skills" "$TEST_SOURCE/skills"
}

# ---------- DE-001 / AC-4b: --claude-skills-mode=skip leaves dir untouched ----------
@test "DE-001 AC-4b: --claude-skills-mode=skip leaves existing skills dir untouched" {
  create_existing_claude_skills_dir

  run run_install --global --claude-skills-mode=skip --yes
  [ "$status" -eq 0 ]

  # The real dir is preserved with its original user skills.
  [ -d "$TEST_HOME/.claude/skills" ]
  [ ! -L "$TEST_HOME/.claude/skills" ]
  assert_path_is_file "$TEST_HOME/.claude/skills/user-skill-a/SKILL.md"
  # No tree_monstor skills got merged in.
  [ ! -e "$TEST_HOME/.claude/skills/dav-planner" ]

  # CLAUDE.md wrapper should still be written (skip only affects skills).
  assert_path_is_file "$TEST_HOME/.claude/CLAUDE.md"
}

# ---------- DE-001 / AC-5: wrapper overwrites a stale symlink ----------
@test "DE-001 AC-5: installer rewrites a stale CLAUDE.md symlink pointing to another source" {
  local stale_target="$TEST_TMP_DIR/old-tree-monstor"
  mkdir -p "$stale_target"
  echo "stale" > "$stale_target/AGENTS.md"
  create_existing_claude_wrapper_symlink "$stale_target/AGENTS.md"

  run run_install --global --agent claude --yes
  [ "$status" -eq 0 ]

  # The stale symlink must be gone, replaced by a regular wrapper file.
  [ ! -L "$TEST_HOME/.claude/CLAUDE.md" ]
  assert_path_is_file "$TEST_HOME/.claude/CLAUDE.md"
  assert_file_contains "$TEST_HOME/.claude/CLAUDE.md" "@$TEST_SOURCE/AGENTS.md"
  assert_file_contains "$TEST_HOME/.claude/CLAUDE.md" "@$TEST_SOURCE/SOUL.md"
  # The stale target path must NOT appear.
  if grep -F -q "$stale_target" "$TEST_HOME/.claude/CLAUDE.md"; then
    echo "FAIL: wrapper still references stale target $stale_target" >&2
    return 1
  fi
}

# ---------- 2026-10-28：sop/ 部署功能已退役（Gate 定義搬入各自 skill）----------

@test "SOP-RETIRE-1: install 唔再建立 ~/.pi/sop/ 或 ~/.claude/sop/" {
  run run_install --global --yes
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_HOME/.pi/sop" ]
  [ ! -e "$TEST_HOME/.claude/sop" ]
}

@test "SOP-RETIRE-2: --dry-run 計劃唔再提及 sop/ 部署" {
  run run_install --global --agent pi --dry-run --yes
  [ "$status" -eq 0 ]
  if printf '%s\n' "$output" | grep -F -q "/.pi/sop/"; then
    echo "FAIL: dry-run 計劃仲提及 /.pi/sop/ 部署（sop 部署功能已退役）" >&2
    return 1
  fi
}

@test "SOP-RETIRE-3: --uninstall 清走舊版安裝遺留嘅 sop symlink（user 檔案保留）" {
  # 模擬舊版（2026-10-28 前）安裝：~/.pi/sop/gates.json → <source>/docs/sop/gates.json
  # （docs/sop/ 已退役 → 個 symlink 變死連結；uninstall 仍然要清走「我哋建立嘅」嗰啲）
  mkdir -p "$TEST_HOME/.pi/sop"
  ln -sfn "$TEST_SOURCE/docs/sop/gates.json" "$TEST_HOME/.pi/sop/gates.json"
  echo '{"user": "data"}' > "$TEST_HOME/.pi/sop/my-rules.json"

  run run_install --uninstall --global --agent pi --yes
  [ "$status" -eq 0 ]
  # 死連結要用 -L 判斷（-e 對 dangling symlink 為 false → 會假綠）
  [ ! -L "$TEST_HOME/.pi/sop/gates.json" ]
  # user 自己嘅檔案要保留
  assert_path_is_file "$TEST_HOME/.pi/sop/my-rules.json"
}

@test "SOP-RETIRE-4: --uninstall 唔會誤刪唔係我哋建立嘅 symlink" {
  mkdir -p "$TEST_HOME/.pi/sop"
  ln -sfn "$TEST_HOME/somewhere-else.json" "$TEST_HOME/.pi/sop/foreign.json"

  run run_install --uninstall --global --agent pi --yes
  [ "$status" -eq 0 ]
  [ -L "$TEST_HOME/.pi/sop/foreign.json" ]
}

@test "SOP-RETIRE-5: --uninstall 對完全冇 ~/.pi/sop/ 嘅情況唔報錯" {
  run run_install --uninstall --global --agent pi --yes
  [ "$status" -eq 0 ]
}

# ---------- US-009 (trivial 1 SP — added by US-008 verification) ----------

@test "US-009 AC-1: log_ok prefix uses ANSI bold escape code" {
  # Trivial verification: log_ok() should emit the ANSI BOLD escape (\033[1m)
  # before the [✓] checkmark. This makes success messages more prominent.
  # Use a minimal env (like AC-13) so NO_COLOR is NOT inherited, otherwise
  # install.sh strips all ANSI codes and we can't observe BOLD output.
  run env -i HOME="$TEST_HOME" PATH="/usr/bin:/bin" TERM="xterm" \
    bash "$INSTALL_SH" --source "$TEST_SOURCE" --local --yes
  [ "$status" -eq 0 ]
  # Look for ESC[1m (bold on) in the install output.
  [[ "$output" == *$'\033[1m'* ]] || {
    echo 'FAIL: tests/install.bats:571: assertion failed' >&2; return 1; }
}
