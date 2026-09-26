#!/usr/bin/env bats
#
# tests/backlog-trust-mode-completion.bats
#
# Trust mode period completed backlog items should be status=done (not pending).
# Corresponds to trust-log 2026-09-23 08:08~08:55 four completion entries.
#
# UTF-8 issue workaround: use English test names (homebrew bats cannot handle Chinese test names).

load 'helpers/test-env'

@test "BACKLOG-001: TMO-001 status is done (trust-log 2026-09-23 08:08)" {
  local backlog="$REPO_ROOT/docs/backlog.md"
  LC_ALL=C grep -E '\| TMO-001 \|' "$backlog" | grep -qE '\| done( |\(|$)' || {
    echo "FAIL: TMO-001 status should be done" >&2
    LC_ALL=C grep -E '\| TMO-001 \|' "$backlog" >&2
    return 1
  }
}

@test "BACKLOG-002: TMO-002 status is done (trust-log 2026-09-23 08:25)" {
  local backlog="$REPO_ROOT/docs/backlog.md"
  LC_ALL=C grep -E '\| TMO-002 \|' "$backlog" | grep -qE '\| done( |\(|$)' || {
    echo "FAIL: TMO-002 status should be done" >&2
    LC_ALL=C grep -E '\| TMO-002 \|' "$backlog" >&2
    return 1
  }
}

@test "BACKLOG-003: TMO-003 status is done (trust-log 2026-09-23 08:38)" {
  local backlog="$REPO_ROOT/docs/backlog.md"
  LC_ALL=C grep -E '\| TMO-003 \|' "$backlog" | grep -qE '\| done( |\(|$)' || {
    echo "FAIL: TMO-003 status should be done" >&2
    LC_ALL=C grep -E '\| TMO-003 \|' "$backlog" >&2
    return 1
  }
}

@test "BACKLOG-004: TMO-004 status is done (trust-log 2026-09-23 08:55)" {
  local backlog="$REPO_ROOT/docs/backlog.md"
  LC_ALL=C grep -E '\| TMO-004 \|' "$backlog" | grep -qE '\| done( |\(|$)' || {
    echo "FAIL: TMO-004 status should be done" >&2
    LC_ALL=C grep -E '\| TMO-004 \|' "$backlog" >&2
    return 1
  }
}

@test "BACKLOG-005: no backlog row stays in pending" {
  local backlog="$REPO_ROOT/docs/backlog.md"
  if LC_ALL=C grep -E '^\| TMO-[0-9]+ \|' "$backlog" | grep -qE '\| pending( |\(|$)'; then
    echo "FAIL: Some TMO still in pending state" >&2
    LC_ALL=C grep -E '^\| TMO-[0-9]+ \|' "$backlog" | grep -E '\| pending( |\(|$)' >&2
    return 1
  fi
}
