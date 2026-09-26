#!/usr/bin/env bats
#
# tests/restruct-agents-md.bats
#
# Regression guards for TMO-009 stage 5: AGENTS.md
# restructured to "task-navigation" style.
# Note: AGENTS.md carries the soul principles (1. Who are you + V01/V02/V03);
# we preserve them verbatim and restructure ONLY around them.

load 'helpers/test-env'

@test "RESTRUCT-AGENTS-MD: TL;DR section exists at top" {
  local f="$REPO_ROOT/AGENTS.md"
  # First ## section after frontmatter should be TL;DR
  grep -q "^## TL;DR" "$f" || {
    echo "FAIL: AGENTS.md should have ## TL;DR as first major section" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: V01/V02/V03 preserved (discipline rules)" {
  local f="$REPO_ROOT/AGENTS.md"
  for v in "V01" "V02" "V03"; do
    grep -qF "$v" "$f" || {
      echo "FAIL: missing $v 紀律 reference" >&2
      return 1
    }
  done
}

@test "RESTRUCT-AGENTS-MD: 萬事原則 (soul) preserved" {
  local f="$REPO_ROOT/AGENTS.md"
  # Key phrases from the soul that must NOT be lost
  for phrase in "用戶好伙伴" "誠實" "負責任" "有承擔" "Think Big"; do
    grep -qF "$phrase" "$f" || {
      echo "FAIL: missing soul phrase '$phrase'" >&2
      return 1
    }
  done
}

@test "RESTRUCT-AGENTS-MD: SOP version references v2.0" {
  local f="$REPO_ROOT/AGENTS.md"
  grep -qF "v2.0" "$f" || {
    echo "FAIL: AGENTS.md should reference v2.0" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: 4 Gate table still present (Gate 1-4)" {
  local f="$REPO_ROOT/AGENTS.md"
  for gate in "Gate 1" "Gate 2" "Gate 3" "Gate 4"; do
    grep -qF "$gate" "$f" || {
      echo "FAIL: missing $gate reference" >&2
      return 1
    }
  done
}

@test "RESTRUCT-AGENTS-MD: 變動歷史 section exists" {
  local f="$REPO_ROOT/AGENTS.md"
  grep -q "^## 變動歷史" "$f" || {
    echo "FAIL: AGENTS.md should have ## 變動歷史 section" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: handbook chapter index still exists" {
  local f="$REPO_ROOT/AGENTS.md"
  # Should still link to the 7 handbook files
  for ch in "2.1-planning" "2.2-design" "2.3-execution" "2.4-reflection" "2.5-submission" "2.6-general-task" "2.7-violations" "changelog"; do
    grep -qF "$ch" "$f" || {
      echo "FAIL: missing handbook link '$ch'" >&2
      return 1
    }
  done
}

@test "RESTRUCT-AGENTS-MD: install symlink path explanation preserved" {
  local f="$AGENTS.md"
  local f="$REPO_ROOT/AGENTS.md"
  # The V03 + install rules should still mention symlink
  grep -qF "symlink" "$f" || {
    echo "FAIL: AGENTS.md should still mention symlink (install rule)" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: SOUL.md cross-reference preserved" {
  local f="$REPO_ROOT/AGENTS.md"
  grep -qF "SOUL.md" "$f" || {
    echo "FAIL: AGENTS.md should still reference SOUL.md" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: file size sanity (was 85; allow up to 130 after restructure)" {
  local f="$REPO_ROOT/AGENTS.md"
  local lines
  lines=$(wc -l < "$f")
  [ "$lines" -lt 130 ] || {
    echo "FAIL: AGENTS.md grew too large ($lines lines, target < 130)" >&2
    return 1
  }
}
