#!/usr/bin/env bats
#
# tests/sop-evolver.bats
#
# Black-box tests for the sop-evolver skill structure and content.
# Each test corresponds to one or more ACs in docs/backlog.md (US-011).
#
# Usage:
#   bats tests/sop-evolver.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  SKILL_DIR="$REPO_ROOT/.agents/skills/sop-evolver"
}

# ---------- AC-1: skill folder structure ----------
@test "AC-1: skill folder exists at .agents/skills/sop-evolver/" {
  [ -d "$SKILL_DIR" ]
}

@test "AC-1a: SKILL.md exists" {
  [ -f "$SKILL_DIR/SKILL.md" ]
}

@test "AC-1b: observation.md exists" {
  [ -f "$SKILL_DIR/observation.md" ]
}

@test "AC-1c: aggregator.md exists" {
  [ -f "$SKILL_DIR/aggregator.md" ]
}

@test "AC-1d: proposer.md exists" {
  [ -f "$SKILL_DIR/proposer.md" ]
}

@test "AC-1e: safety.md exists" {
  [ -f "$SKILL_DIR/safety.md" ]
}

# ---------- AC-2: SKILL.md ≤ 150 lines ----------
@test "AC-2: SKILL.md is at most 150 lines" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  local lines
  lines=$(wc -l < "$SKILL_DIR/SKILL.md")
  [ "$lines" -le 150 ]
}

# ---------- AC-3: SKILL.md frontmatter ----------
@test "AC-3a: SKILL.md has YAML frontmatter" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  local first_line
  first_line=$(head -1 "$SKILL_DIR/SKILL.md")
  [ "$first_line" = "---" ]
}

@test "AC-3b: SKILL.md has name field" {
  grep -q "^name: sop-evolver" "$SKILL_DIR/SKILL.md"
}

@test "AC-3c: SKILL.md has description field" {
  grep -q "^description:" "$SKILL_DIR/SKILL.md"
}

# ---------- AC-6: safety.md has 4 rules ----------
@test "AC-6: safety.md mentions all 4 mandatory rules" {
  [ -f "$SKILL_DIR/safety.md" ]
  grep -q "觀察/改動分離\|觀察.*改動.*分離" "$SKILL_DIR/safety.md"
  grep -q "匿名化" "$SKILL_DIR/safety.md"
  grep -q "Reviewer 二審必經\|Reviewer.*二審" "$SKILL_DIR/safety.md"
  grep -q "一鍵回滾\|一鍵.*rollback" "$SKILL_DIR/safety.md"
}

@test "AC-6a: safety.md mentions 3 forbidden areas (V03 protected areas)" {
  [ -f "$SKILL_DIR/safety.md" ]
  grep -q "AGENTS.md §1" "$SKILL_DIR/safety.md"
  grep -q "§1.5" "$SKILL_DIR/safety.md"
  grep -q "§2.3" "$SKILL_DIR/safety.md"
}

# ---------- AC-7: observation.json schema fields ----------
@test "AC-7: observation.md documents all required JSON schema fields" {
  [ -f "$SKILL_DIR/observation.md" ]
  grep -q "task_id" "$SKILL_DIR/observation.md"
  grep -q "project_id" "$SKILL_DIR/observation.md"
  grep -q "timestamp" "$SKILL_DIR/observation.md"
  grep -q "gate_results" "$SKILL_DIR/observation.md"
  grep -q "skills_used" "$SKILL_DIR/observation.md"
  grep -q "failure_signals" "$SKILL_DIR/observation.md"
  grep -q "duration_seconds" "$SKILL_DIR/observation.md"
}

@test "AC-7a: observation.md has blacklist fields" {
  [ -f "$SKILL_DIR/observation.md" ]
  grep -q "raw_conversation\|raw_conversation" "$SKILL_DIR/observation.md"
  grep -q "code_snippets\|code_snippets" "$SKILL_DIR/observation.md"
  grep -q "file_paths\|file_paths" "$SKILL_DIR/observation.md"
}

# ---------- AC-4: aggregator.md flow ----------
@test "AC-4: aggregator.md documents aggregation flow" {
  [ -f "$SKILL_DIR/aggregator.md" ]
  grep -q "去重\|聚合\|排序\|收集" "$SKILL_DIR/aggregator.md"
}

# ---------- AC-5: proposer.md evidence/impact/rollback ----------
@test "AC-5: proposer.md requires evidence + impact + rollback" {
  [ -f "$SKILL_DIR/proposer.md" ]
  grep -q "證據\|evidence" "$SKILL_DIR/proposer.md"
  grep -q "影響專案數\|impact" "$SKILL_DIR/proposer.md"
  grep -q "rollback\|回滾" "$SKILL_DIR/proposer.md"
}

# ---------- AC-9/AC-10: modes separation ----------
@test "AC-9: skill distinguishes observation mode vs aggregation mode" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  grep -q "觀察模式\|observation" "$SKILL_DIR/SKILL.md"
  grep -q "聚合模式\|aggregation" "$SKILL_DIR/SKILL.md"
}

@test "AC-10: skill mentions source-repo-only modification" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  grep -q "源 repo\|源.*repo\|source.*repo" "$SKILL_DIR/SKILL.md"
}

# ---------- AC-12: cross-reference consistency ----------
@test "AC-12: SKILL.md cross-references related docs" {
  [ -f "$SKILL_DIR/SKILL.md" ]
  grep -q "docs/backlog\|backlog.md" "$SKILL_DIR/SKILL.md"
}

# ---------- Security: location hardening ----------
@test "SEC-1: observation location uses ~/.tree-monstor/observations/" {
  grep -q "~/.tree-monstor/observations/" "$SKILL_DIR/observation.md" \
    || grep -q "~/.tree-monstor/observations/" "$SKILL_DIR/SKILL.md"
}

@test "SEC-2: project_id uses SHA256 (not plaintext path)" {
  grep -q "SHA256" "$SKILL_DIR/observation.md"
}