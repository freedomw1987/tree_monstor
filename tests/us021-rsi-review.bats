#!/usr/bin/env bats
# tests/us021-rsi-review.bats
# US-021：14 天回顧 + 從 cron.log 反推新規則

setup() {
    export LC_ALL=C
    export LANG=C
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    export PATH="$REPO_ROOT/tools:$PATH"
}

# ---------- AC-1: rsi-review.sh 存在 + syntax OK ----------
@test "US-021-1: rsi-review.sh exists and passes bash -n" {
    [ -f "$REPO_ROOT/tools/rsi-review.sh" ]
    bash -n "$REPO_ROOT/tools/rsi-review.sh"
}

# ---------- AC-2: --help 顯示 ----------
@test "US-021-2: rsi-review.sh --help shows usage" {
    run "$REPO_ROOT/tools/rsi-review.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"days"* ]]
}

# ---------- AC-3: 跑 14 天回顧，產出 markdown 報告 ----------
@test "US-021-3: rsi-review produces a markdown report" {
    MOCK_OBS="$(mktemp -d -t rsi-review-XXXXXX)"
    # 建 14 天基線，每天 5 個 obs
    for d in $(seq 1 14); do
        date_str=$(date -v -${d}d '+%Y-%m-%d' 2>/dev/null || date -d "-${d}d" '+%Y-%m-%d')
        for proj in a b c; do
            mkdir -p "$MOCK_OBS/proj-$proj"
            echo '{}' > "$MOCK_OBS/proj-$proj/${date_str}.json"
        done
    done
    MOCK_OUT="$(mktemp -t rsi-review-out-XXXXXX).md"
    run "$REPO_ROOT/tools/rsi-review.sh" --obs-root "$MOCK_OBS" --days 14 --output "$MOCK_OUT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"報告已產出"* ]]
    [ -f "$MOCK_OUT" ]
    grep -q "RSI 14 天回顧報告" "$MOCK_OUT"
    grep -q "總 observation 數" "$MOCK_OUT"
    grep -q "跨專案分佈" "$MOCK_OUT"
    rm -rf "$MOCK_OBS" "$MOCK_OUT"
}

# ---------- AC-4: 空觀察目錄不會 crash ----------
@test "US-021-4: empty observation directory handled gracefully" {
    MOCK_OBS="$(mktemp -d -t rsi-review-empty-XXXXXX)"
    MOCK_OUT="$(mktemp -t rsi-review-out-XXXXXX).md"
    run "$REPO_ROOT/tools/rsi-review.sh" --obs-root "$MOCK_OBS" --days 14 --output "$MOCK_OUT"
    [ "$status" -eq 0 ]
    [ -f "$MOCK_OUT" ]
    grep -q "0" "$MOCK_OUT"
    rm -rf "$MOCK_OBS" "$MOCK_OUT"
}

# ---------- AC-5: 自訂 --days ----------
@test "US-021-5: custom --days parameter works" {
    MOCK_OBS="$(mktemp -d -t rsi-review-days-XXXXXX)"
    for d in $(seq 1 7); do
        date_str=$(date -v -${d}d '+%Y-%m-%d' 2>/dev/null || date -d "-${d}d" '+%Y-%m-%d')
        mkdir -p "$MOCK_OBS/proj-a"
        echo '{}' > "$MOCK_OBS/proj-a/${date_str}.json"
    done
    MOCK_OUT="$(mktemp -t rsi-review-out-XXXXXX).md"
    run "$REPO_ROOT/tools/rsi-review.sh" --obs-root "$MOCK_OBS" --days 7 --output "$MOCK_OUT"
    [ "$status" -eq 0 ]
    grep -q "回顧天數" "$MOCK_OUT"
    grep -qE "7|14" "$MOCK_OUT"
    rm -rf "$MOCK_OBS" "$MOCK_OUT"
}

# ---------- AC-6: 含規則庫擴充建議（從觀察反推） ----------
@test "US-021-6: report mentions new rule candidates section" {
    MOCK_OBS="$(mktemp -d -t rsi-review-rules-XXXXXX)"
    MOCK_OUT="$(mktemp -t rsi-review-out-XXXXXX).md"
    run "$REPO_ROOT/tools/rsi-review.sh" --obs-root "$MOCK_OBS" --days 14 --output "$MOCK_OUT"
    [ "$status" -eq 0 ]
    # 報告應有「新規則候選」section
    grep -q "新規則候選" "$MOCK_OUT"
    rm -rf "$MOCK_OBS" "$MOCK_OUT"
}