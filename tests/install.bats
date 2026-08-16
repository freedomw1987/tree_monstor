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
@test "AC-1: default install symlinks skills to ~/.claude/ and ~/.pi/" {
  run run_install --global --yes
  [ "$status" -eq 0 ]

  assert_path_is_symlink "$TEST_HOME/.claude/skills" "$TEST_SOURCE/skills"
  assert_path_is_symlink "$TEST_HOME/.pi/skills"     "$TEST_SOURCE/skills"
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
@test "AC-3: creates ~/.pi/AGENTS.md and ~/.pi/SOUL.md as symlinks to source" {
  run run_install --global --agent pi --yes
  [ "$status" -eq 0 ]

  assert_path_is_symlink "$TEST_HOME/.pi/AGENTS.md" "$TEST_SOURCE/AGENTS.md"
  assert_path_is_symlink "$TEST_HOME/.pi/SOUL.md"   "$TEST_SOURCE/SOUL.md"
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
  [ ! -e "$TEST_HOME/.agents" ]
}

# ---------- AC-5: --local installs to cwd ----------
@test "AC-5: --local installs to current directory" {
  run run_install --local --yes
  [ "$status" -eq 0 ]

  [ -L "./.claude/skills" ]
  [ -L "./.pi/skills" ]
  [ -f "./.claude/CLAUDE.md" ]
}

# ---------- AC-6: --target installs to specified path ----------
@test "AC-6: --target installs to specified path" {
  local target="$TEST_TMP_DIR/my-project"
  mkdir -p "$target"
  run run_install --target "$target" --yes
  [ "$status" -eq 0 ]

  [ -L "$target/.claude/skills" ]
  [ -L "$target/.pi/skills" ]
  [ -f "$target/.claude/CLAUDE.md" ]
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

  assert_path_exists "$TEST_HOME/.pi/AGENTS.md"
  assert_path_exists "$TEST_HOME/.pi/SOUL.md"
  [ ! -e "$TEST_HOME/.claude" ]
}

# ---------- AC-8: --uninstall removes only managed files ----------
@test "AC-8: --uninstall removes symlinks and wrapper created by installer" {
  run run_install --global --yes
  [ "$status" -eq 0 ]

  # Pre-create an unrelated file in .claude/ to ensure installer doesn't touch it
  echo "user's own stuff" > "$TEST_HOME/.claude/user-notes.md"

  run run_install --uninstall --global --yes
  [ "$status" -eq 0 ]

  [ ! -e "$TEST_HOME/.claude/CLAUDE.md" ]
  [ ! -e "$TEST_HOME/.claude/skills" ]
  [ ! -e "$TEST_HOME/.pi/AGENTS.md" ]
  [ ! -e "$TEST_HOME/.pi/SOUL.md" ]
  [ ! -e "$TEST_HOME/.pi/skills" ]
  [ ! -e "$TEST_HOME/.agents/tree_monstor" ]
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
  [[ "$output" == *"CLAUDE.md"* ]]
  [[ "$output" == *"dry-run"* || "$output" == *"DRY"* ]]
}

# ---------- AC-10: --help prints usage ----------
@test "AC-10: --help prints usage and exits 0" {
  run run_install --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--global"* ]]
  [[ "$output" == *"--local"* ]]
  [[ "$output" == *"--uninstall"* ]]
}

# ---------- AC-11: idempotent ----------
@test "AC-11a: repeated runs produce identical state and no errors" {
  run run_install --global --yes
  [ "$status" -eq 0 ]
  local first_hash
  first_hash="$(find "$TEST_HOME/.claude" "$TEST_HOME/.pi" -maxdepth 4 -type l -o -type f | sort | xargs -I{} sh -c 'echo {}; readlink "{}" 2>/dev/null || true' | sort | shasum | awk '{print $1}')"

  run run_install --global --yes
  [ "$status" -eq 0 ]
  local second_hash
  second_hash="$(find "$TEST_HOME/.claude" "$TEST_HOME/.pi" -maxdepth 4 -type l -o -type f | sort | xargs -I{} sh -c 'echo {}; readlink "{}" 2>/dev/null || true' | sort | shasum | awk '{print $1}')"

  [ "$first_hash" = "$second_hash" ]
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
  [[ "$output" == *$'\033['* ]]
}

# ---------- AC-14: pure bash ----------
@test "AC-14: install.sh starts with #!/usr/bin/env bash" {
  run head -1 "$BATS_TEST_DIRNAME/../install.sh"
  [[ "$output" == *"bash"* ]]
}

# ---------- AC-15: README exists and documents usage ----------
@test "AC-15: README.md exists and contains usage section" {
  [ -f "$BATS_TEST_DIRNAME/../README.md" ]
  run cat "$BATS_TEST_DIRNAME/../README.md"
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--global"* ]]
  [[ "$output" == *"--uninstall"* ]]
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
  [[ "$output" == *"User-owned version"* ]]
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
  ln -s "/tmp/nowhere-at-all" "$TEST_HOME/.claude/skills/dav-planner"

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
