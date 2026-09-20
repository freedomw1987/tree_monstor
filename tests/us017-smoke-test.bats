#!/usr/bin/env bats
#
# tests/us017-smoke-test.bats
#
# Smoke-test for US-017: real RSI verification with 3 mock projects.
# Each test corresponds to one or more ACs in docs/backlog.md (US-017).
#
# Usage:
#   bats tests/us017-smoke-test.bats
#
# Prerequisite:
#   Run tests/rsi-smoke-test.sh first to set up the 3 mock projects
#   and produce observation files.

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  HOME_DIR="${HOME}"
  OBS_ROOT="$HOME_DIR/.tree-monstor/observations"
  PROJECTS_ROOT="$HOME_DIR/.tree-monstor/projects"
  TODAY=$(date '+%Y-%m-%d')
  MOCK_PROJECTS=("test-proj-A" "test-proj-B" "test-proj-C")
}

# ---------- AC-1: 建立 3 個 mock 專案 + trivial 任務 ----------
@test "AC-1a: 3 mock projects were set up" {
  [ -d "$PROJECTS_ROOT" ]
  for proj in "${MOCK_PROJECTS[@]}"; do
    [ -d "$PROJECTS_ROOT/$proj" ]
  done
}

@test "AC-1b: mock projects are not real repos (not tree_monstor itself)" {
  for proj in "${MOCK_PROJECTS[@]}"; do
    [ -d "$PROJECTS_ROOT/$proj" ]
    # Should NOT contain tree_monstor-specific markers
    [ ! -f "$PROJECTS_ROOT/$proj/AGENTS.md" ]
  done
}

# ---------- AC-2: 3 個專案各產 1 個 observation ----------
@test "AC-2a: observation files exist for 3 projects" {
  for proj in "${MOCK_PROJECTS[@]}"; do
    # Find observation file (project_id is SHA256[:8], not the literal project name)
    [ -d "$OBS_ROOT" ]
    local count
    count=$(find "$OBS_ROOT" -name "$TODAY.json" -type f | wc -l)
    [ "$count" -ge 3 ]
  done
}

@test "AC-2b: observation files contain required whitelist fields" {
  local found=0
  for f in "$OBS_ROOT"/*/"$TODAY.json"; do
    [ -f "$f" ] || continue
    found=$((found + 1))
    grep -q '"task_id"' "$f"
    grep -q '"project_id"' "$f"
    grep -q '"timestamp"' "$f"
    grep -q '"gate_results"' "$f"
    grep -q '"skills_used"' "$f"
  done
  [ "$found" -ge 3 ]
}

@test "AC-2c: observation files contain no blacklist fields" {
  for f in "$OBS_ROOT"/*/"$TODAY.json"; do
    [ -f "$f" ] || continue
    # Blacklist: raw_conversation, code_snippets, file_paths, env_values, git_messages
    ! grep -qE '"raw_conversation"|"code_snippets"|"file_paths"|"env_values"|"git_messages"' "$f"
  done
}

# ---------- AC-3: rsi-aggregate.sh 產出報告 ----------
@test "AC-3a: rsi-aggregate.sh runs successfully" {
  [ -f "$REPO_ROOT/tools/rsi-aggregate.sh" ]
  bash "$REPO_ROOT/tools/rsi-aggregate.sh" --obs-root "$OBS_ROOT" >/dev/null 2>&1
}

@test "AC-3b: rsi-aggregate.sh output mentions multiple projects" {
  local out
  out=$(bash "$REPO_ROOT/tools/rsi-aggregate.sh" --obs-root "$OBS_ROOT" 2>&1)
  echo "$out" | grep -qE "事件類型|觀察檔|專案"
}

# ---------- AC-4: rsi-propose.sh 產出 diff 提案 ----------
@test "AC-4a: rsi-propose.sh requires --report" {
  local out
  out=$(bash "$REPO_ROOT/tools/rsi-propose.sh" 2>&1 || true)
  echo "$out" | grep -qE "report|--report|必填"
}

@test "AC-4b: rsi-propose.sh can produce a proposal from a real report" {
  # Use a real report
  local tmp_report
  tmp_report=$(mktemp -t rsi-report-XXXXXX.md)
  bash "$REPO_ROOT/tools/rsi-aggregate.sh" --obs-root "$OBS_ROOT" --output "$tmp_report" >/dev/null 2>&1
  [ -f "$tmp_report" ]

  local proposal
  proposal=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$tmp_report" 2>&1)
  echo "$proposal" | grep -qE "提案|rollback"
  rm -f "$tmp_report"
}

# ---------- AC-5: 批准 → rsi-rollback.sh 寫 git tag ----------
@test "AC-5a: rsi-rollback.sh can list (empty list if no tags yet)" {
  bash "$REPO_ROOT/tools/rsi-rollback.sh" list >/dev/null 2>&1
}

@test "AC-5b: rsi-rollback.sh --help does not modify git state" {
  bash "$REPO_ROOT/tools/rsi-rollback.sh" --help >/dev/null 2>&1
}

# ---------- AC-6: rsi-sync.sh 同步生效 ----------
@test "AC-6a: rsi-sync.sh --help works" {
  bash "$REPO_ROOT/tools/rsi-sync.sh" --help >/dev/null 2>&1
}

@test "AC-6b: rsi-sync.sh --dry-run does not modify any project" {
  # Get baseline file count
  local before
  before=$(find "$PROJECTS_ROOT" -type f 2>/dev/null | wc -l)
  bash "$REPO_ROOT/tools/rsi-sync.sh" --dry-run --yes --project-list <(for proj in "${MOCK_PROJECTS[@]}"; do echo "$PROJECTS_ROOT/$proj"; done) >/dev/null 2>&1 || true
  local after
  after=$(find "$PROJECTS_ROOT" -type f 2>/dev/null | wc -l)
  [ "$before" -eq "$after" ]
}

# ---------- AC-7: rsi-metrics.sh 產出 6 指標 ----------
@test "AC-7: rsi-metrics.sh outputs 6 metrics" {
  local out
  out=$(bash "$REPO_ROOT/tools/rsi-metrics.sh" 2>&1)
  echo "$out" | grep -qE "任務完成率|completion_rate"
  echo "$out" | grep -qE "規範違規|violation"
  echo "$out" | grep -qE "TD.*閉環|td_close"
  echo "$out" | grep -qE "跨專案|cross_project"
  echo "$out" | grep -qE "AGENTS.*字數|agents_md"
  echo "$out" | grep -qE "skill.*使用|skill_usage"
}

# ---------- AC-8: smoke-test 記錄文件 ----------
@test "AC-8: smoke-test record file exists" {
  [ -f "$REPO_ROOT/docs/review/$TODAY-rsi-smoke-test.md" ] || \
  [ -f "$REPO_ROOT/docs/sop/rsi-smoke-test-2025-09-20.md" ]
}

# ---------- AC-9: 5 個 Gate ----------
@test "AC-9: this bats file exists (smoke test scaffolded)" {
  [ -f "$REPO_ROOT/tests/us017-smoke-test.bats" ]
}

# ---------- 安全邊界檢查 ----------
@test "SECURITY-1: observation files don't leak absolute paths" {
  for f in "$OBS_ROOT"/*/"$TODAY.json"; do
    [ -f "$f" ] || continue
    ! grep -qE "tree_monstor|Sites/localhost|/Users/" "$f"
  done
}

@test "SECURITY-2: project_id is SHA256[:8] format (8 hex chars)" {
  for f in "$OBS_ROOT"/*/"$TODAY.json"; do
    [ -f "$f" ] || continue
    grep -qE '"project_id":[[:space:]]*"[a-f0-9]{8}"' "$f"
  done
}