#!/usr/bin/env bats
#
# tests/us013-handbook.bats
#
# Black-box tests for US-013: §2.8-rsi-evolution.md handbook + AGENTS.md reference.
# Each test corresponds to one or more ACs in docs/backlog.md (US-013).
#
# Usage:
#   bats tests/us013-handbook.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  HANDBOOK_DIR="$REPO_ROOT/docs/sop/handbook"
  HANDBOOK_FILE="$HANDBOOK_DIR/2.8-rsi-evolution.md"
  AGENTS_MD="$REPO_ROOT/AGENTS.md"
  BACKLOG="$REPO_ROOT/docs/backlog.md"
}

# ---------- AC-1: handbook file exists ----------
@test "AC-1: docs/sop/handbook/2.8-rsi-evolution.md exists" {
  [ -f "$HANDBOOK_FILE" ]
}

@test "AC-1a: handbook file is non-empty" {
  [ -s "$HANDBOOK_FILE" ]
}

# ---------- AC-2: handbook contains RSI flow ----------
@test "AC-2: handbook documents the full RSI flow (7 steps)" {
  [ -f "$HANDBOOK_FILE" ]
  for keyword in "觀察" "聚合" "提案" "Reviewer" "用戶" "合併" "同步"; do
    grep -q "$keyword" "$HANDBOOK_FILE"
  done
}

# ---------- AC-3: 4 safety rules ----------
@test "AC-3: handbook lists all 4 safety rules" {
  [ -f "$HANDBOOK_FILE" ]
  # 4 rules: 觀察/改動分離, 匿名化, Reviewer 二審必經, 一鍵回滾
  grep -q "觀察.*改動.*分離\|觀察/改動分離" "$HANDBOOK_FILE"
  grep -q "匿名化" "$HANDBOOK_FILE"
  grep -q "Reviewer.*二審\|Reviewer 二審必經" "$HANDBOOK_FILE"
  grep -q "一鍵回滾\|一鍵 rollback" "$HANDBOOK_FILE"
}

# ---------- AC-4: observation location ----------
@test "AC-4: handbook mentions ~/.tree-monstor/observations/ path" {
  [ -f "$HANDBOOK_FILE" ]
  grep -q "~/.tree-monstor/observations/" "$HANDBOOK_FILE"
}

# ---------- AC-5: AGENTS.md §2 reference ----------
@test "AC-5: AGENTS.md §2 chapter index has §2.8 reference" {
  [ -f "$AGENTS_MD" ]
  grep -q "2.8-rsi-evolution\|§2.8\|2\\.8" "$AGENTS_MD"
}

@test "AC-5a: AGENTS.md §2 lists 8 chapters (or includes new one)" {
  [ -f "$AGENTS_MD" ]
  # Should have §2.1 through §2.8 (8 chapters)
  for i in 1 2 3 4 5 6 7 8; do
    grep -qE "§2\.$i|2\.$i-" "$AGENTS_MD"
  done
}

# ---------- AC-6: ≥ 2 regression probes ----------
@test "AC-6a: handbook includes 4 rules as a regression probe section" {
  [ -f "$HANDBOOK_FILE" ]
  # Must mention all 4 rules together (regression probe = sentinel)
  content=$(cat "$HANDBOOK_FILE")
  echo "$content" | grep -q "觀察.*改動.*分離"
  echo "$content" | grep -q "匿名化"
  echo "$content" | grep -q "Reviewer.*二審"
  echo "$content" | grep -q "一鍵回滾"
}

@test "AC-6b: handbook includes observation path as regression probe" {
  [ -f "$HANDBOOK_FILE" ]
  grep -q "~/.tree-monstor/observations/" "$HANDBOOK_FILE"
}

# ---------- AC-7: markdownlint 0 issues ----------
@test "AC-7: handbook markdownlint 0 issues" {
  [ -f "$HANDBOOK_FILE" ]
  if command -v markdownlint-cli2 >/dev/null 2>&1; then
    run markdownlint-cli2 "$HANDBOOK_FILE"
    [ "$status" -eq 0 ] || {
      echo "markdownlint output:"
      echo "$output"
      return 1
    }
  fi
}

# ---------- AC-8 (implicit): SOP discipline integration ----------
@test "SOP-1: handbook references V03 discipline" {
  [ -f "$HANDBOOK_FILE" ]
  grep -q "V03\|RSI.*二審\|RSI.*Reviewer" "$HANDBOOK_FILE"
}

@test "SOP-2: handbook references gates.json Gate 5" {
  [ -f "$HANDBOOK_FILE" ]
  grep -q "Gate 5\|gate-5\|RSI gate" "$HANDBOOK_FILE"
}

@test "SOP-3: handbook mentions observation JSON schema (whitelist + blacklist)" {
  [ -f "$HANDBOOK_FILE" ]
  grep -q "白名單" "$HANDBOOK_FILE"
  grep -q "黑名單" "$HANDBOOK_FILE"
}

@test "SOP-4: handbook mentions source-repo-only modification" {
  [ -f "$HANDBOOK_FILE" ]
  grep -q "源 repo\|源.*repo\|source.*repo" "$HANDBOOK_FILE"
}

# ---------- AC-9 (cross-reference): US-013 references backlog ----------
@test "CROSS-1: handbook references US-013 in backlog" {
  [ -f "$HANDBOOK_FILE" ]
  # Indirect: handbook should mention Backlog US-013 / AC reference
  grep -q "US-013\|backlog" "$HANDBOOK_FILE"
}