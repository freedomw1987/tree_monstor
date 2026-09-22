#!/usr/bin/env bash
# tools/observe-pi-task.sh — 把 .pi/tasks/*.json 的 completed task 轉成 RSI observation
# 對應 docs/sop/handbook/2.8-rsi-evolution.md §5（觀察規範）
# 對應 backlog US-016「擴展錨點：自動觀察觸發」
# 對應 docs/sop/rsi-reviewer-verdict-2026-09-22-auto-observe-v2.md APPROVE_WITH_NITS
#
# 設計原則（v1.1）：
#   - 不依賴 agent 自律：由 Pi Extension 在 TaskUpdate(status=completed) 時呼叫
#   - 觀察寫入失敗不阻塞任務（exit 0 + stderr warning）
#   - 7 個白名單欄位（observation.md §3.1）：task_id / project_id / timestamp /
#     gate_results / skills_used / failure_signals / duration_seconds + note
#   - 黑名單：絕不存 raw conversation / file paths 明文 / code snippets
#   - 併發保護：temp file + atomic rename（POSIX mv 原子）
#   - 去重：用 task_id 當 dedup key，存 ~/.tree-monstor/observations/{project_id}/.observed-tasks
#
# Usage:
#   observe-pi-task.sh --cwd <path> [--task-id <id>] [--session-id <id>]
#
# Exit codes:
#   0 = 成功（或部分失敗但不影響）
#   1 = 參數錯誤或嚴重故障（cwd 不存在、jq 缺失）

set -u
# 不用 pipefail（跟其他 rsi tool 一致，macOS bash 3.2 相容）
export LC_ALL=C
export LANG=C

# === 預設值 ===
CWD=""
TASK_ID=""
SESSION_ID=""

usage() {
    cat <<EOF
Usage: observe-pi-task.sh [options]

把 .pi/tasks/*.json 的 completed task 轉成 RSI observation 寫到
~/.tree-monstor/observations/{project_id}/{YYYY-MM-DD}.json。

呼叫者通常是 extensions/auto-observe.ts 在 TaskUpdate(completed) 時觸發。
設計為 fire-and-forget：失敗 log warning + exit 0，不拋錯。

Options:
  --cwd <path>        工作目錄（必填；預設 = 當前目錄）
  --task-id <id>      只觀察指定 task（預設 = 全部 status=completed）
  --session-id <id>   session ID（必填；無 = 掃描 .pi/tasks/ 找最新）
  --help / -h         顯示說明

Exit codes:
  0  成功（或無觀察目標）
  1  參數錯誤（cwd 不存在、jq 缺失）
EOF
}

# === 旗標解析 ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cwd)       CWD="${2:-}"; shift 2 ;;
        --task-id)   TASK_ID="${2:-}"; shift 2 ;;
        --session-id) SESSION_ID="${2:-}"; shift 2 ;;
        --help|-h)   usage; exit 0 ;;
        *)           echo "ERROR: unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

# === 必要工具檢查 ===
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq not found (required for JSON parsing)" >&2
    exit 1
fi

if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
    echo "ERROR: shasum/sha256sum not found (required for project_id hash)" >&2
    exit 1
fi

# === 解析 cwd ===
if [[ -z "$CWD" ]]; then
    CWD="$(pwd)"
fi

if [[ ! -d "$CWD" ]]; then
    echo "ERROR: --cwd $CWD does not exist" >&2
    exit 1
fi

# === 計算 project_id = SHA256(cwd)[:8] ===
sha256_hash() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -c1-8
    else
        sha256sum "$1" | cut -c1-8
    fi
}

# macOS BSD 跟 Linux GNU 對 stdin 的 SHA256 行為略不同；用檔案統一
CWD_HASH_FILE="$(mktemp)"
trap 'rm -f "$CWD_HASH_FILE"' EXIT
printf '%s' "$CWD" > "$CWD_HASH_FILE"
PROJECT_ID="$(sha256_hash "$CWD_HASH_FILE")"

# === 解析 session_id（無給就掃 .pi/tasks/ 找最新）===
TASKS_DIR="$CWD/.pi/tasks"
if [[ ! -d "$TASKS_DIR" ]]; then
    echo "WARN: $TASKS_DIR does not exist; nothing to observe" >&2
    exit 0
fi

if [[ -z "$SESSION_ID" ]]; then
    # 找最新的 tasks-*.json（用 mtime 排序）
    LATEST_FILE="$(ls -t "$TASKS_DIR"/tasks-*.json 2>/dev/null | head -1)"
    if [[ -z "$LATEST_FILE" ]]; then
        echo "WARN: no tasks-*.json found in $TASKS_DIR" >&2
        exit 0
    fi
    SESSION_ID="$(basename "$LATEST_FILE" | sed 's/^tasks-//; s/\.json$//')"
fi

TASKS_FILE="$TASKS_DIR/tasks-${SESSION_ID}.json"
if [[ ! -f "$TASKS_FILE" ]]; then
    echo "WARN: $TASKS_FILE not found; nothing to observe" >&2
    exit 0
fi

# === 偵測 taskScope（v1 只支援 session scope）===
# 如果 .pi/tasks-config.json 設 taskScope=project/memory/session-global，
# log warning + skip（v1 不支援）
TASKS_CONFIG="$CWD/.pi/tasks-config.json"
if [[ -f "$TASKS_CONFIG" ]]; then
    SCOPE="$(jq -r '.taskScope // "session"' "$TASKS_CONFIG" 2>/dev/null || echo 'session')"
    if [[ "$SCOPE" != "session" ]]; then
        echo "WARN: taskScope=$SCOPE not supported by observe-pi-task.sh v1 (need session); skipping" >&2
        exit 0
    fi
fi

# === 解析任務（jq 過濾 + 提取）===
# 注意：jq query 必須能處理單一 task 或全部 task
if [[ -n "$TASK_ID" ]]; then
    # 單一 task：jq -c --arg id "$TASK_ID" '.tasks[] | select(.id == $id)'
    TASK_JSON="$(jq -c --arg id "$TASK_ID" '.tasks[] | select(.id == $id)' "$TASKS_FILE" 2>/dev/null)"
    if [[ -z "$TASK_JSON" ]]; then
        echo "WARN: task id=$TASK_ID not found in $TASKS_FILE" >&2
        exit 0
    fi
    TASKS_TO_OBSERVE_FILE="$(mktemp)"
    trap 'rm -f "$TASKS_TO_OBSERVE_FILE" "$CWD_HASH_FILE"' EXIT
    printf '%s\n' "$TASK_JSON" > "$TASKS_TO_OBSERVE_FILE"
else
    # 全部 completed task：jq -c 產出 multi-line JSON，用 process substitution + while read
    TASKS_TO_OBSERVE_FILE="$(mktemp)"
    trap 'rm -f "$TASKS_TO_OBSERVE_FILE" "$CWD_HASH_FILE"' EXIT
    jq -c '.tasks[] | select(.status == "completed")' "$TASKS_FILE" 2>/dev/null > "$TASKS_TO_OBSERVE_FILE" || true
fi

# 檢查是否有 task 要觀察
if [[ ! -s "$TASKS_TO_OBSERVE_FILE" ]]; then
    echo "INFO: no tasks to observe (filter: status=completed, task_id=${TASK_ID:-<all>})" >&2
    exit 0
fi

# === 觀察目錄 ===
OBS_ROOT="${HOME}/.tree-monstor/observations/${PROJECT_ID}"
mkdir -p "$OBS_ROOT" 2>/dev/null || {
    echo "ERROR: cannot create $OBS_ROOT" >&2
    exit 1
}

# === 去重檔（hidden file）===
DEDUP_FILE="$OBS_ROOT/.observed-tasks"
touch "$DEDUP_FILE" 2>/dev/null || true

# === 當日 observation 檔 ===
DATE="$(date -u +%Y-%m-%d)"
TODAY_FILE="$OBS_ROOT/${DATE}.json"

# 讀取當日已存在的 observation（若存在），否則初始化為空 array
if [[ -f "$TODAY_FILE" ]]; then
    EXISTING_JSON="$(cat "$TODAY_FILE")"
else
    EXISTING_JSON='[]'
fi

# === 白名單欄位（observation.md §3.1）===
# 7 個必填欄位 + note（共 8 個）：task_id, project_id, timestamp,
# gate_results, skills_used, failure_signals, duration_seconds, note

# === 函式：把 task JSON 轉成 observation JSON ===
task_to_observation() {
    local task_json="$1"
    local ts now_ms duration_ms duration_s task_id subject description

    # 提取欄位（jq 容錯：缺欄位時用空字串）
    task_id="$(echo "$task_json" | jq -r '.id // ""')"
    subject="$(echo "$task_json" | jq -r '.subject // ""')"
    description="$(echo "$task_json" | jq -r '.description // ""')"
    duration_ms="$(echo "$task_json" | jq -r '(.updatedAt // 0) - (.createdAt // 0)')"
    now_ms="$(date -u +%s)000"  # ISO-8601 timestamp（毫秒精度，非真實 ISO，但夠用）

    # duration_seconds：ms / 1000
    duration_s=$((duration_ms / 1000))

    # ISO-8601 timestamp：用 date -u +%FT%TZ（秒級）
    ISO_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # 構建 observation JSON（嚴格 7 欄位 + note = 8 欄位）
    jq -nc \
        --arg task_id "$task_id" \
        --arg project_id "$PROJECT_ID" \
        --arg timestamp "$ISO_TS" \
        --argjson gate_results '{"gate1_tdd":"n/a","gate2_lint":"n/a","gate3_regression":"n/a","gate4_reviewer":"n/a","gate5_rsi":"auto"}' \
        --argjson skills_used '["auto-observe"]' \
        --argjson failure_signals '[]' \
        --argjson duration_seconds "$duration_s" \
        --arg note "${subject}: ${description}" \
        '{
            task_id: $task_id,
            project_id: $project_id,
            timestamp: $timestamp,
            gate_results: $gate_results,
            skills_used: $skills_used,
            failure_signals: $failure_signals,
            duration_seconds: $duration_seconds,
            note: ($note | .[0:500])
        }'
}

# === 函式：驗證 observation schema（白名單嚴格，多餘欄位 reject）===
validate_observation() {
    local obs="$1"
    local expected_keys=(
        task_id project_id timestamp gate_results
        skills_used failure_signals duration_seconds note
    )

    # 必填欄位檢查
    local key
    for key in "${expected_keys[@]}"; do
        if ! echo "$obs" | jq -e --arg k "$key" 'has($k)' >/dev/null 2>&1; then
            echo "ERROR: observation missing required field: $key" >&2
            return 1
        fi
    done

    # 多餘欄位檢查（嚴格白名單）
    local extra_count
    extra_count="$(echo "$obs" | jq --argjson keys "$(printf '%s\n' "${expected_keys[@]}" | jq -R . | jq -s .)" '
        [keys[] | select(. as $k | $keys | index($k) | not)] | length
    ')"
    if [[ "$extra_count" -gt 0 ]]; then
        echo "ERROR: observation has $extra_count extra fields (whitelist violation)" >&2
        return 1
    fi

    # 黑名單檢查（raw conversation / file paths / code snippets 不應出現）
    if echo "$obs" | jq -e 'has("raw_conversation") or has("file_paths") or has("code_snippets")' >/dev/null 2>&1; then
        echo "ERROR: observation contains blacklisted field" >&2
        return 1
    fi

    return 0
}

# === 主迴圈：逐個 task 觀察 ===
NEW_OBSERVATIONS_FILE="$(mktemp)"
trap 'rm -f "$TASKS_TO_OBSERVE_FILE" "$NEW_OBSERVATIONS_FILE" "$CWD_HASH_FILE"' EXIT

NEW_COUNT=0
while IFS= read -r task_json; do
    [[ -z "$task_json" ]] && continue

    current_task_id="$(echo "$task_json" | jq -r '.id // ""')"
    [[ -z "$current_task_id" ]] && { echo "WARN: task missing id, skipping" >&2; continue; }

    # 去重檢查
    if grep -Fxq "$current_task_id" "$DEDUP_FILE" 2>/dev/null; then
        echo "INFO: task $current_task_id already observed (dedup); skipping" >&2
        continue
    fi

    # 轉 observation
    obs="$(task_to_observation "$task_json")" || {
        echo "ERROR: failed to build observation for task $current_task_id" >&2
        continue
    }

    # 驗證 schema
    if ! validate_observation "$obs"; then
        echo "ERROR: observation for task $current_task_id failed schema validation; NOT written" >&2
        continue
    fi

    # 加入本次新觀察 + 記錄到去重檔
    printf '%s\n' "$obs" >> "$NEW_OBSERVATIONS_FILE"
    echo "$current_task_id" >> "$DEDUP_FILE"
    NEW_COUNT=$((NEW_COUNT + 1))
done < "$TASKS_TO_OBSERVE_FILE"

# === 寫入 observation（atomic rename）===
if [[ "$NEW_COUNT" -eq 0 ]]; then
    echo "INFO: no new observations to write" >&2
    exit 0
fi

# 合併新觀察到當日檔
NEW_JSON="$(jq -n \
    --argjson existing "$EXISTING_JSON" \
    --argjson new "$(jq -s . "$NEW_OBSERVATIONS_FILE")" \
    '$existing + $new')"

# Atomic write：temp file + mv
TEMP_FILE="$(mktemp "${OBS_ROOT}/.${DATE}.json.XXXXXX")"
trap 'rm -f "$TEMP_FILE" "$CWD_HASH_FILE"' EXIT

if echo "$NEW_JSON" > "$TEMP_FILE"; then
    if mv "$TEMP_FILE" "$TODAY_FILE"; then
        echo "OK: wrote $NEW_COUNT observation(s) to $TODAY_FILE"
        trap 'rm -f "$CWD_HASH_FILE"' EXIT  # 清掉 CWD_HASH_FILE，保留其他 trap
        exit 0
    else
        echo "ERROR: atomic rename failed: $TEMP_FILE -> $TODAY_FILE" >&2
        rm -f "$TEMP_FILE"
        exit 0  # 不阻塞（fire-and-forget）
    fi
else
    echo "ERROR: failed to write temp file $TEMP_FILE" >&2
    rm -f "$TEMP_FILE"
    exit 0  # 不阻塞
fi