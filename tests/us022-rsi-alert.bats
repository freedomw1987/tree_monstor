#!/usr/bin/env bats
# tests/us022-rsi-alert.bats
# US-022：rsi-metrics 加回歸警告

setup() {
    export LC_ALL=C
    export LANG=C
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    export PATH="$REPO_ROOT/tools:$PATH"
}

# ---------- AC-1: rsi-alert.sh 存在 + syntax OK ----------
@test "US-022-1: rsi-alert.sh exists and passes bash -n" {
    [ -f "$REPO_ROOT/tools/rsi-alert.sh" ]
    bash -n "$REPO_ROOT/tools/rsi-alert.sh"
}

# ---------- AC-2: --help 顯示 ----------
@test "US-022-2: rsi-alert.sh --help shows usage" {
    run "$REPO_ROOT/tools/rsi-alert.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"threshold"* ]]
}

# ---------- AC-3: 觀察數正常（不告警）----------
@test "US-022-3: no alert when observation count is stable" {
    MOCK_OBS="$(mktemp -d -t rsi-alert-ok-XXXXXX)"
    # 建 7 天基線，每天 5 個 obs
    for d in $(seq 1 7); do
        date_str=$(date -v -${d}d '+%Y-%m-%d' 2>/dev/null || date -d "-${d}d" '+%Y-%m-%d')
        for proj in a b c; do
            mkdir -p "$MOCK_OBS/proj-$proj"
            echo '{}' > "$MOCK_OBS/proj-$proj/${date_str}.json"
        done
    done
    # 今天也 5 個
    today=$(date '+%Y-%m-%d')
    for proj in a b c; do
        mkdir -p "$MOCK_OBS/proj-$proj"
        echo '{}' > "$MOCK_OBS/proj-$proj/${today}.json"
    done
    MOCK_LOG="$(mktemp -t rsi-alert-log-XXXXXX)"
    run "$REPO_ROOT/tools/rsi-alert.sh" --obs-root "$MOCK_OBS" --alert-log "$MOCK_LOG" --baseline-days 7 --window-days 1 --threshold 0.7
    [ "$status" -eq 0 ]
    [[ "$output" == *"正常"* ]]
    rm -rf "$MOCK_OBS" "$MOCK_LOG"
}

# ---------- AC-4: 觀察數下降 30%+ 觸發告警 ----------
@test "US-022-4: alert triggers when observation drops 30%+" {
    MOCK_OBS="$(mktemp -d -t rsi-alert-drop-XXXXXX)"
    # 建 7 天基線，每天 10 個 obs（基線 = 10）
    for d in $(seq 1 7); do
        date_str=$(date -v -${d}d '+%Y-%m-%d' 2>/dev/null || date -d "-${d}d" '+%Y-%m-%d')
        for proj in a b c d e; do
            mkdir -p "$MOCK_OBS/proj-$proj"
            echo '{}' > "$MOCK_OBS/proj-$proj/${date_str}.json"
        done
    done
    # 今天只有 1 個（比值 0.1 < 0.7 → 告警）
    today=$(date '+%Y-%m-%d')
    mkdir -p "$MOCK_OBS/proj-a"
    echo '{}' > "$MOCK_OBS/proj-a/${today}.json"
    MOCK_LOG="$(mktemp -t rsi-alert-log-XXXXXX)"
    run "$REPO_ROOT/tools/rsi-alert.sh" --obs-root "$MOCK_OBS" --alert-log "$MOCK_LOG" --baseline-days 7 --window-days 1 --threshold 0.7
    [ "$status" -eq 1 ]  # 告警 exit 1
    [[ "$output" == *"警告"* ]]
    [[ -s "$MOCK_LOG" ]]  # log 有寫入
    rm -rf "$MOCK_OBS" "$MOCK_LOG"
}

# ---------- AC-5: 自訂閾值 ----------
@test "US-022-5: custom threshold works" {
    MOCK_OBS="$(mktemp -d -t rsi-alert-thr-XXXXXX)"
    for d in $(seq 1 7); do
        date_str=$(date -v -${d}d '+%Y-%m-%d' 2>/dev/null || date -d "-${d}d" '+%Y-%m-%d')
        for proj in a b c; do
            mkdir -p "$MOCK_OBS/proj-$proj"
            echo '{}' > "$MOCK_OBS/proj-$proj/${date_str}.json"
        done
    done
    today=$(date '+%Y-%m-%d')
    for proj in a b; do  # 今天只有 2 個（基線 3， 比值 0.67）
        mkdir -p "$MOCK_OBS/proj-$proj"
        echo '{}' > "$MOCK_OBS/proj-$proj/${today}.json"
    done
    MOCK_LOG="$(mktemp -t rsi-alert-log-XXXXXX)"
    # 閾值 0.5 → 0.67 > 0.5 → 不告警
    run "$REPO_ROOT/tools/rsi-alert.sh" --obs-root "$MOCK_OBS" --alert-log "$MOCK_LOG" --baseline-days 7 --window-days 1 --threshold 0.5
    [ "$status" -eq 0 ]
    # 閾值 0.8 → 0.67 < 0.8 → 告警
    run "$REPO_ROOT/tools/rsi-alert.sh" --obs-root "$MOCK_OBS" --alert-log "$MOCK_LOG" --baseline-days 7 --window-days 1 --threshold 0.8
    [ "$status" -eq 1 ]
    rm -rf "$MOCK_OBS" "$MOCK_LOG"
}