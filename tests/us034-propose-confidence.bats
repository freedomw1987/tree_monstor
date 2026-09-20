#!/usr/bin/env bats
# tests/us034-propose-confidence.bats
# TD-034：rsi-propose.sh 加 confidence score

setup() {
    export LC_ALL=C
    export LANG=C
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    export PATH="$REPO_ROOT/tools:$PATH"
}

# ---------- AC-1: confidence 旗標 ----------
@test "TD-034-1: rsi-propose.sh accepts --confidence flag" {
    local tmp
    tmp=$(mktemp -t rsi-report-XXXXXX.md)
    cat > "$tmp" <<'EOF'
# RSI Mock Report

## 跨專案分佈
| 專案 ID | 觀察數 |
| --- | --- |
| proj1 | 5 |
| proj2 | 3 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| test_fail | 8 |
EOF
    bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$tmp" --min-freq 1 --confidence 0.5 2>&1 | grep -qF "confidence"
    rm -f "$tmp"
}

# ---------- AC-2: ≥ 0.7 列主要提案 ----------
@test "TD-034-2: proposals with high confidence are listed as primary" {
    local tmp
    tmp=$(mktemp -t rsi-report-XXXXXX.md)
    cat > "$tmp" <<'EOF'
# RSI Mock Report

## 跨專案分佈
| 專案 ID | 觀察數 |
| --- | --- |
| proj1 | 5 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| test_fail | 20 |
EOF
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$tmp" --min-freq 1 --confidence 0.7 2>&1)
    echo "$out" | grep -qF "test_fail"
    rm -f "$tmp"
}

# ---------- AC-3: < 0.7 列需人工確認 ----------
@test "TD-034-3: proposals with low confidence need human confirmation" {
    local tmp
    tmp=$(mktemp -t rsi-report-XXXXXX.md)
    cat > "$tmp" <<'EOF'
# RSI Mock Report

## 跨專案分佈
| 專案 ID | 觀察數 |
| --- | --- |
| proj1 | 1 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| rare_event | 1 |
EOF
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$tmp" --min-freq 1 --confidence 0.7 2>&1)
    # 低 confidence 提案要有「Low Confidence」標記
    echo "$out" | grep -qF "Low Confidence"
    rm -f "$tmp"
}

# ---------- AC-4: 信心分數格式 ----------
@test "TD-034-4: confidence shown as 0.XX format" {
    local tmp
    tmp=$(mktemp -t rsi-report-XXXXXX.md)
    cat > "$tmp" <<'EOF'
# RSI Mock Report

## 跨專案分佈
| 專案 ID | 觀察數 |
| --- | --- |
| proj1 | 3 |
| proj2 | 2 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| test_fail | 5 |
EOF
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$tmp" --min-freq 1 --confidence 0.5 2>&1)
    # 應有 0.XX 格式的分數
    echo "$out" | grep -qE "conf.*0\.[0-9]+"
    rm -f "$tmp"
}

# ---------- AC-5: 用預設 confidence 時行為不退化 ----------
@test "TD-034-5: rsi-propose.sh without --confidence works as before" {
    local tmp
    tmp=$(mktemp -t rsi-report-XXXXXX.md)
    cat > "$tmp" <<'EOF'
# RSI Mock Report

## 跨專案分佈
| 專案 ID | 觀察數 |
| --- | --- |
| proj1 | 1 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| test_fail | 1 |
EOF
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$tmp" --min-freq 1 2>&1)
    # 沒 --confidence 也要正常工作，不加 ✅ 或 Low Confidence
    echo "$out" | grep -qF "test_fail"
    ! echo "$out" | grep -qF "Low Confidence"
    ! echo "$out" | grep -qF "主要提案"
    rm -f "$tmp"
}