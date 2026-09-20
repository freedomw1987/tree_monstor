#!/usr/bin/env bats
# tests/us020-rule-extension.bats
# US-020：Sprint 11 從 US-019 觀察反推 + 補規則 8→12+
# 對應 FR-4.17

setup() {
    export LC_ALL=C
    export LANG=C
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    export PATH="$REPO_ROOT/tools:$PATH"

    # 建 mock 觀察記錄（含 US-019 預期觀察到的 4 個新事件類型）
    MOCK_OBS="$(mktemp -d -t rsi-obs-XXXXXX)"
    mkdir -p "$MOCK_OBS/proj-a" "$MOCK_OBS/proj-b" "$MOCK_OBS/proj-c"

    # 每個 proj 3 天觀察，含 4 個新事件類型
    # rsi-aggregate 只認 gate_results，這個 schema 規範
    for proj in proj-a proj-b proj-c; do
        for day in 2026-09-19 2026-09-20 2026-09-21; do
            cat > "$MOCK_OBS/$proj/$day.json" <<EOF
{
    "project_id": "$proj",
    "timestamp": "${day}T12:00:00Z",
    "task_id": "T-$proj-$day",
    "gate_results": {
        "gate-1": "pass",
        "gate-2": "fail",
        "gate-3": "pass",
        "gate-4": "pass",
        "gate-5": "fail"
    },
    "violations": ["circular_ref", "skill_timeout", "agent_hang", "commit_no_msg"]
}
EOF
        done
    done
}

teardown() {
    rm -rf "$MOCK_OBS"
}

# ---------- AC-1: rsi-aggregate.sh 識別觀察中的 gate fail ----------
@test "US-020-1: rsi-aggregate produces report from observation" {
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-aggregate.sh" --obs-root "$MOCK_OBS" --output - 2>&1 || true)
    # 應該輸出「報告」並包含跨專案分佈表
    echo "$out" | grep -qE "報告|RSI|跨專案"
}

# ---------- AC-2: rsi-propose 給 4 個新事件產生提案 ----------
@test "US-020-2: rsi-propose generates proposals for 4 new event types" {
    # 先建 mock report 含 4 個新事件
    local report
    report=$(mktemp -t rsi-report-XXXXXX.md)
    cat > "$report" <<'EOF'
# RSI Mock Report

## 跨專案分佈
| 專案 ID | 觀察數 |
| --- | --- |
| proj-a | 3 |
| proj-b | 3 |
| proj-c | 3 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| circular_ref | 9 |
| skill_timeout | 9 |
| agent_hang | 9 |
| commit_no_msg | 9 |
EOF
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$report" --min-freq 5 --confidence 0.5 2>&1)
    # 4 個新事件都應有對應的「修法」描述
    echo "$out" | grep -qF "雙向跳脫"
    echo "$out" | grep -qF "frontmatter"
    echo "$out" | grep -qF "timeout"
    echo "$out" | grep -qF "conventional"
    rm -f "$report"
}

# ---------- AC-3: 規則庫新增 4 個規則 ----------
@test "US-020-3: rsi-propose has 12+ non-generic rules" {
    # 用 rsi-propose 跑所有可能事件，數有幾個產生「非通用」提案
    local report
    report=$(mktemp -t rsi-report-XXXXXX.md)
    cat > "$report" <<'EOF'
# RSI Mock Report

## 跨專案分佈
| 專案 ID | 觀察數 |
| --- | --- |
| proj-a | 1 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| prompt_too_long | 5 |
| skill_error | 5 |
| gate_skip | 5 |
| markdownlint_error | 5 |
| bash_error | 5 |
| test_fail | 5 |
| bats_unknown | 5 |
| v02_violated | 5 |
| circular_ref | 5 |
| skill_timeout | 5 |
| agent_hang | 5 |
| commit_no_msg | 5 |
EOF
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$report" --min-freq 1 --confidence 0.5 2>&1)
    # 12 個事件都有提案，但「待定」是通用樣板（未命中規則）
    ! echo "$out" | grep -qF "待定"
    # circular_ref 有「雙向跳脫」修法
    echo "$out" | grep -qF "雙向跳脫"
    rm -f "$report"
}

# ---------- AC-4: 新規則有建議修法 ----------
@test "US-020-4: new rules have actionable remediation" {
    local report
    report=$(mktemp -t rsi-report-XXXXXX.md)
    cat > "$report" <<'EOF'
# RSI Mock Report

## 跨專案分佈
| 專案 ID | 觀察數 |
| --- | --- |
| proj-a | 1 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| circular_ref | 10 |
EOF
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$report" --min-freq 1 --confidence 0.5 2>&1)
    # circular_ref 提案要有「雙向跳脫」修法
    echo "$out" | grep -qF "雙向跳脫"
    rm -f "$report"
}

# ---------- AC-5: 規則庫擴充文件 ----------
@test "US-020-5: rule extension document exists" {
    [[ -f "$REPO_ROOT/docs/prd/04-self-evolution.md" ]]
    grep -q "circular_ref\|skill_timeout\|agent_hang\|commit_no_msg" "$REPO_ROOT/docs/prd/04-self-evolution.md" 2>&1
}

# ---------- AC-6: 信心分數通過門檻 ----------
@test "US-020-6: high-frequency events pass confidence threshold" {
    local report
    report=$(mktemp -t rsi-report-XXXXXX.md)
    cat > "$report" <<'EOF'
# RSI Mock Report

## 跨專案分佈
| 專案 ID | 觀察數 |
| --- | --- |
| proj-a | 1 |
| proj-b | 1 |
| proj-c | 1 |
| proj-d | 1 |
| proj-e | 1 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| circular_ref | 20 |
EOF
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$report" --min-freq 1 --confidence 0.5 2>&1)
    # freq=20*0.05=1.0, projects=5*0.1=0.5, total=1.0 → 主要提案
    echo "$out" | grep -qE "主要提案"
    rm -f "$report"
}

# ---------- AC-7: 規則庫擴充日誌 ----------
@test "US-020-7: rule extension log exists" {
    [[ -f "$REPO_ROOT/docs/sop/rsi-rule-extension-2026-09-20.md" ]]
}