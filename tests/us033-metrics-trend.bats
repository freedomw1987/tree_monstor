#!/usr/bin/env bats
# tests/us033-metrics-trend.bats
# TD-033：rsi-metrics.sh 加 30 天滑動 trend

setup() {
    export LC_ALL=C
    export LANG=C
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    export PATH="$REPO_ROOT/tools:$PATH"

    # 建 30 天 mock observation
    MOCK_OBS="$(mktemp -d -t rsi-trend-XXXXXX)"
    for i in 1 2 3; do
        mkdir -p "$MOCK_OBS/proj$i"
    done
    # 30 天的觀察，proj1 全 pass / proj2 半 pass / proj3 全 fail
    for d in $(seq 1 30); do
        date_str=$(date -v -${d}d '+%Y-%m-%d' 2>/dev/null || date -d "-${d}d" '+%Y-%m-%d')
        for i in 1 2 3; do
            cat > "$MOCK_OBS/proj$i/${date_str}.json" <<EOF
{
    "project_id": "proj${i}",
    "timestamp": "${date_str}T12:00:00Z",
    "gate_results": {"gate-1":"pass","gate-2":"pass","gate-3":"pass","gate-4":"pass","gate-5":"pass"}
}
EOF
        done
    done
}

teardown() {
    rm -rf "$MOCK_OBS"
}

# ---------- AC-1: trend_history subcommand 存在 ----------
@test "TD-033-1: rsi-metrics.sh has trend_history subcommand" {
    bash "$REPO_ROOT/tools/rsi-metrics.sh" --help 2>&1 | grep -qF "trend_history"
}

# ---------- AC-2: 30 天滑動視窗 ----------
@test "TD-033-2: trend_history shows 30-day window" {
    bash "$REPO_ROOT/tools/rsi-metrics.sh" trend_history --obs-root "$MOCK_OBS" 2>&1 | grep -qF "30 天"
}

# ---------- AC-3: 4 個指標有 trend ----------
@test "TD-033-3: trend_history shows at least 4 metric trends" {
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-metrics.sh" trend_history --obs-root "$MOCK_OBS" 2>&1)
    echo "$out" | grep -qF "completion_rate"
    echo "$out" | grep -qF "violation_count"
    echo "$out" | grep -qF "td_close_rate"
    echo "$out" | grep -qF "skill_usage"
}

# ---------- AC-4: 用 sparkline 字符顯示 ----------
@test "TD-033-4: trend_history uses sparkline characters" {
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-metrics.sh" trend_history --obs-root "$MOCK_OBS" 2>&1)
    # 8 級 sparkline 字符
    echo "$out" | grep -qE "▁|▂|▃|▄|▅|▆|▇|█"
}

# ---------- AC-5: 觀察 0 個專案時 graceful ----------
@test "TD-033-5: trend_history handles empty observation gracefully" {
    local empty
    empty=$(mktemp -d -t rsi-empty-XXXXXX)
    bash "$REPO_ROOT/tools/rsi-metrics.sh" trend_history --obs-root "$empty" 2>&1
    rm -rf "$empty"
}