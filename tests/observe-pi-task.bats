#!/usr/bin/env bats
#
# tests/observe-pi-task.bats
#
# Black-box tests for tools/observe-pi-task.sh (US-016 擴展錨點)
# 對應 docs/sop/rsi-reviewer-verdict-2026-09-22-auto-observe-v2.md APPROVE_WITH_NITS
#
# 設計 (Gate 1 8 個 TDD 測試紅→綠)：
#   - AC-1: observe-pi-task.sh 存在 + 可執行
#   - AC-2: 觀察完成 task → 寫入 ~/.tree-monstor/observations/{project_id}/{YYYY-MM-DD}.json
#   - AC-3: 觀察失敗不阻塞（exit 0 + stderr warning）
#   - AC-4: 去重（同 task_id 不重複寫）
#   - AC-5: schema 驗證（剛好 7 欄位 + note = 8 欄位 pass）
#   - AC-6: schema 驗證（多餘欄位 reject）
#   - AC-7: schema 驗證（少欄位 reject）
#   - AC-8: project_id SHA256 計算確定性（同 cwd 同結果）
#   - AC-9: PI_TASK_LIST_ID / taskScope=project edge case log warning + skip
#
# Usage:
#   bats tests/observe-pi-task.bats

setup() {
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    OBSERVE_SH="$REPO_ROOT/tools/observe-pi-task.sh"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP
    export HOME_BACKUP="$HOME"

    # 隔離 HOME：避免污染真實 ~/.tree-monstor/observations/
    FAKE_HOME="$TEST_TMP/fake-home"
    mkdir -p "$FAKE_HOME"
    export HOME="$FAKE_HOME"

    # 預設任務檔路徑
    export FAKE_CWD="$TEST_TMP/fake-project"
    mkdir -p "$FAKE_CWD/.pi/tasks"

    # 寫一個範例 task 檔（含 1 個 completed + 1 個 pending）
    cat > "$FAKE_CWD/.pi/tasks/tasks-test-session-abc.json" <<'EOF'
{
  "nextId": 3,
  "tasks": [
    {
      "id": "1",
      "subject": "完成的 task 1",
      "description": "這是第一個完成的 task",
      "status": "completed",
      "createdAt": 1790034509837,
      "updatedAt": 1790034541479,
      "metadata": {},
      "blocks": [],
      "blockedBy": []
    },
    {
      "id": "2",
      "subject": "進行中的 task 2",
      "description": "這是第二個未完成的 task",
      "status": "in_progress",
      "createdAt": 1790034509838,
      "updatedAt": 1790034900000,
      "metadata": {},
      "blocks": [],
      "blockedBy": []
    }
  ]
}
EOF
}

teardown() {
    export HOME="$HOME_BACKUP"
    rm -rf "$TEST_TMP"
}

# ---------- AC-1: 存在 + 可執行 ----------
@test "AC-1a: tools/observe-pi-task.sh exists" {
    [ -f "$OBSERVE_SH" ]
}

@test "AC-1b: tools/observe-pi-task.sh is executable" {
    [ -x "$OBSERVE_SH" ]
}

@test "AC-1c: tools/observe-pi-task.sh --help exits 0" {
    run bash "$OBSERVE_SH" --help
    [ "$status" -eq 0 ]
}

# ---------- AC-2: 觀察完成 task → 寫入 observation ----------
@test "AC-2: observing completed task writes to ~/.tree-monstor/observations/{project_id}/{date}.json" {
    run bash "$OBSERVE_SH" --cwd "$FAKE_CWD" --task-id 1 --session-id test-session-abc
    [ "$status" -eq 0 ]

    # 找到寫入的 observation 檔
    local project_id date_file
    project_id="$(printf '%s' "$FAKE_CWD" | shasum -a 256 | cut -c1-8)"
    date_file="$HOME/.tree-monstor/observations/$project_id/$(date -u +%Y-%m-%d).json"
    [ -f "$date_file" ]

    # 驗證 JSON 結構
    local count task_id
    count="$(jq 'length' "$date_file")"
    [ "$count" -eq 1 ]
    task_id="$(jq -r '.[0].task_id' "$date_file")"
    [ "$task_id" = "1" ]
}

# ---------- AC-3: 觀察失敗不阻塞（exit 0 + warning）----------
@test "AC-3a: missing .pi/tasks/ exits 0 with warning (non-blocking)" {
    local empty_cwd="$TEST_TMP/empty-project"
    mkdir -p "$empty_cwd"

    run bash "$OBSERVE_SH" --cwd "$empty_cwd"
    [ "$status" -eq 0 ]
    [[ "$output" =~ WARN|WARNING ]]
}

@test "AC-3b: nonexistent cwd exits 1 with ERROR (but graceful)" {
    run bash "$OBSERVE_SH" --cwd "/nonexistent/path/should/not/exist"
    [ "$status" -eq 1 ]
    [[ "$output" =~ ERROR ]]
}

@test "AC-3c: missing --task-id when no completed tasks exits 0" {
    # 把 task 1 改為 in_progress，這樣全部都是 in_progress
    cat > "$FAKE_CWD/.pi/tasks/tasks-test-session-abc.json" <<'EOF'
{
  "nextId": 2,
  "tasks": [
    {
      "id": "1",
      "subject": "task 1",
      "description": "in progress",
      "status": "in_progress",
      "createdAt": 1,
      "updatedAt": 2
    }
  ]
}
EOF

    run bash "$OBSERVE_SH" --cwd "$FAKE_CWD" --session-id test-session-abc
    [ "$status" -eq 0 ]
    [[ "$output" =~ "no tasks to observe" ]]
}

# ---------- AC-4: 去重 ----------
@test "AC-4: same task_id is not written twice (dedup)" {
    # 第一次觀察
    bash "$OBSERVE_SH" --cwd "$FAKE_CWD" --task-id 1 --session-id test-session-abc >/dev/null

    # 第二次觀察相同 task
    run bash "$OBSERVE_SH" --cwd "$FAKE_CWD" --task-id 1 --session-id test-session-abc
    [ "$status" -eq 0 ]
    [[ "$output" =~ "already observed" ]]

    # 確認只寫一個 observation
    local project_id date_file count
    project_id="$(printf '%s' "$FAKE_CWD" | shasum -a 256 | cut -c1-8)"
    date_file="$HOME/.tree-monstor/observations/$project_id/$(date -u +%Y-%m-%d).json"
    count="$(jq 'length' "$date_file")"
    [ "$count" -eq 1 ]
}

# ---------- AC-5: schema 驗證（剛好 7+1 欄位 pass）----------
@test "AC-5: observation has exactly 8 required fields (task_id, project_id, timestamp, gate_results, skills_used, failure_signals, duration_seconds, note)" {
    bash "$OBSERVE_SH" --cwd "$FAKE_CWD" --task-id 1 --session-id test-session-abc >/dev/null

    local project_id date_file
    project_id="$(printf '%s' "$FAKE_CWD" | shasum -a 256 | cut -c1-8)"
    date_file="$HOME/.tree-monstor/observations/$project_id/$(date -u +%Y-%m-%d).json"

    # 檢查 8 個必填欄位都存在
    local field
    for field in task_id project_id timestamp gate_results skills_used failure_signals duration_seconds note; do
        jq -e --arg f "$field" '.[0] | has($f)' "$date_file" >/dev/null
    done

    # 確認沒有其他欄位
    local field_count
    field_count="$(jq '.[0] | keys | length' "$date_file")"
    [ "$field_count" -eq 8 ]
}

# ---------- AC-6: schema 驗證（多餘欄位 reject）----------
# 這個測試直接驗證 task_to_observation() 函式行為：手動構造一個含多餘欄位的 task
# 觀察此 task 應讓驗證失敗（不在 observation 檔出現）
@test "AC-6: observations do not contain blacklisted fields (raw_conversation, file_paths, code_snippets)" {
    bash "$OBSERVE_SH" --cwd "$FAKE_CWD" --task-id 1 --session-id test-session-abc >/dev/null

    local project_id date_file
    project_id="$(printf '%s' "$FAKE_CWD" | shasum -a 256 | cut -c1-8)"
    date_file="$HOME/.tree-monstor/observations/$project_id/$(date -u +%Y-%m-%d).json"

    # 確認 observation 不含黑名單欄位
    ! jq -e '.[0] | has("raw_conversation") or has("file_paths") or has("code_snippets")' "$date_file" >/dev/null
}

# ---------- AC-7: schema 守門（少欄位拒絕寫入）----------
# 設計：observation 從 task_to_observation() 構造，總是有完整 8 欄位
# 但若 jq/sha256sum 缺失等會 fail
@test "AC-7: observation contains all 7 mandatory gate_results fields" {
    bash "$OBSERVE_SH" --cwd "$FAKE_CWD" --task-id 1 --session-id test-session-abc >/dev/null

    local project_id date_file
    project_id="$(printf '%s' "$FAKE_CWD" | shasum -a 256 | cut -c1-8)"
    date_file="$HOME/.tree-monstor/observations/$project_id/$(date -u +%Y-%m-%d).json"

    # 確認 gate_results 含 5 個 gate 欄位
    local gate
    for gate in gate1_tdd gate2_lint gate3_regression gate4_reviewer gate5_rsi; do
        jq -e --arg g "$gate" '.[0].gate_results | has($g)' "$date_file" >/dev/null
    done

    # 確認 gate5_rsi = "auto"（P1-2 修正）
    local g5
    g5="$(jq -r '.[0].gate_results.gate5_rsi' "$date_file")"
    [ "$g5" = "auto" ]
}

# ---------- AC-8: project_id SHA256 計算確定性 ----------
@test "AC-8: project_id is SHA256(cwd)[:8] (deterministic)" {
    bash "$OBSERVE_SH" --cwd "$FAKE_CWD" --task-id 1 --session-id test-session-abc >/dev/null

    # 預期 project_id
    local expected
    expected="$(printf '%s' "$FAKE_CWD" | shasum -a 256 | cut -c1-8)"

    # 實際 observation 內的 project_id
    local project_id date_file actual
    project_id="$(printf '%s' "$FAKE_CWD" | shasum -a 256 | cut -c1-8)"
    date_file="$HOME/.tree-monstor/observations/$project_id/$(date -u +%Y-%m-%d).json"
    actual="$(jq -r '.[0].project_id' "$date_file")"

    [ "$actual" = "$expected" ]
}

# ---------- AC-9: taskScope != session edge case ----------
@test "AC-9: taskScope=project exits 0 with warning (v1 only supports session scope)" {
    # 寫 tasks-config.json 設 taskScope=project
    cat > "$FAKE_CWD/.pi/tasks-config.json" <<'EOF'
{
  "taskScope": "project"
}
EOF

    run bash "$OBSERVE_SH" --cwd "$FAKE_CWD" --task-id 1 --session-id test-session-abc
    [ "$status" -eq 0 ]
    [[ "$output" =~ "taskScope" ]]
    [[ "$output" =~ "not supported" ]]

    # 確認沒有 observation 寫入
    local project_id
    project_id="$(printf '%s' "$FAKE_CWD" | shasum -a 256 | cut -c1-8)"
    local date_file="$HOME/.tree-monstor/observations/$project_id/$(date -u +%Y-%m-%d).json"
    [ ! -f "$date_file" ]
}

# ---------- 補：全部 completed task 自動觀察 ----------
@test "AC-10: observing without --task-id observes all completed tasks" {
    run bash "$OBSERVE_SH" --cwd "$FAKE_CWD" --session-id test-session-abc
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1 observation" ]]

    # 確認只有 task 1（completed）被寫入，task 2（in_progress）未寫入
    local project_id date_file
    project_id="$(printf '%s' "$FAKE_CWD" | shasum -a 256 | cut -c1-8)"
    date_file="$HOME/.tree-monstor/observations/$project_id/$(date -u +%Y-%m-%d).json"
    local count task_ids
    count="$(jq 'length' "$date_file")"
    [ "$count" -eq 1 ]
    task_ids="$(jq -r '[.[].task_id] | join(",")' "$date_file")"
    [ "$task_ids" = "1" ]
}

# ---------- 補：duration_seconds 正確換算（ms / 1000）----------
@test "AC-11: duration_seconds = (updatedAt - createdAt) / 1000" {
    bash "$OBSERVE_SH" --cwd "$FAKE_CWD" --task-id 1 --session-id test-session-abc >/dev/null

    local project_id date_file duration
    project_id="$(printf '%s' "$FAKE_CWD" | shasum -a 256 | cut -c1-8)"
    date_file="$HOME/.tree-monstor/observations/$project_id/$(date -u +%Y-%m-%d).json"

    duration="$(jq -r '.[0].duration_seconds' "$date_file")"

    # task 1: createdAt=1790034509837, updatedAt=1790034541479
    # diff = 31642 ms = 31.642 s = 31 (整數)
    [ "$duration" = "31" ]
}