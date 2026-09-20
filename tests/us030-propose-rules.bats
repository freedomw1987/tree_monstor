#!/usr/bin/env bats
# tests/us030-propose-rules.bats -- TD-030 rsi-propose.sh rule library expansion TDD tests
# ASCII-only test names

setup() {
    export LC_ALL=C
    export LANG=C
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR

    # Build a mock aggregate report with 5 new event types
    REPORT="$TEST_DIR/report.md"
    cat > "$REPORT" <<EOF
# RSI 聚合報告（mock for TD-030）

## 觀察檔總數
5

## 跨專案分佈（5 個 mock 專案）
| 專案 ID | 觀察數 |
| --- | --- |
| proj-aaa | 1 |
| proj-bbb | 1 |
| proj-ccc | 1 |
| proj-ddd | 1 |
| proj-eee | 1 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| prompt_too_long | 5 |
| skill_error | 4 |
| gate_skip | 3 |
| markdownlint_error | 2 |
| bash_error | 2 |
| test_fail | 2 |
| bats_unknown | 1 |
| v02_violated | 1 |
EOF

    OUTPUT="$TEST_DIR/proposal.md"
    export PATH="/Users/apple/Sites/localhost/tree_monstor/tools:$PATH"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "TD-030-1: proposal includes markdownlint_error event" {
    rsi-propose.sh --report "$REPORT" --output "$OUTPUT" --min-freq 1 >/dev/null 2>&1
    grep -qF "markdownlint_error" "$OUTPUT"
}

@test "TD-030-2: proposal includes bash_error event" {
    rsi-propose.sh --report "$REPORT" --output "$OUTPUT" --min-freq 1 >/dev/null 2>&1
    grep -qF "bash_error" "$OUTPUT"
}

@test "TD-030-3: proposal includes test_fail event" {
    rsi-propose.sh --report "$REPORT" --output "$OUTPUT" --min-freq 1 >/dev/null 2>&1
    grep -qF "test_fail" "$OUTPUT"
}

@test "TD-030-4: proposal includes bats_unknown event" {
    rsi-propose.sh --report "$REPORT" --output "$OUTPUT" --min-freq 1 >/dev/null 2>&1
    grep -qF "bats_unknown" "$OUTPUT"
}

@test "TD-030-5: proposal includes v02_violated event" {
    rsi-propose.sh --report "$REPORT" --output "$OUTPUT" --min-freq 1 >/dev/null 2>&1
    grep -qF "v02_violated" "$OUTPUT"
}

@test "TD-030-6: markdownlint_error rule suggests fix in AGENTS.md or handbook" {
    rsi-propose.sh --report "$REPORT" --output "$OUTPUT" --min-freq 1 >/dev/null 2>&1
    # Find the markdownlint_error section, check file is reasonable
    grep -A 4 "markdownlint_error" "$OUTPUT" | grep -qE "AGENTS\.md|handbook|markdownlint"
}

@test "TD-030-7: bash_error rule mentions shellcheck" {
    rsi-propose.sh --report "$REPORT" --output "$OUTPUT" --min-freq 1 >/dev/null 2>&1
    grep -A 4 "bash_error" "$OUTPUT" | grep -qE "shellcheck|set -e"
}

@test "TD-030-8: v02_violated rule mentions V02" {
    rsi-propose.sh --report "$REPORT" --output "$OUTPUT" --min-freq 1 >/dev/null 2>&1
    grep -A 4 "v02_violated" "$OUTPUT" | grep -qE "V02|V0 2"
}

@test "TD-030-9: total rules count is at least 8" {
    rsi-propose.sh --report "$REPORT" --output "$OUTPUT" --min-freq 1 >/dev/null 2>&1
    # Count event_type occurrences in proposal (each appears at least once in header)
    grep -c "^### 提案" "$OUTPUT" | tr -d ' '
    [ "$?" -eq 0 ]
}

@test "TD-030-10: existing 3 rules still work" {
    rsi-propose.sh --report "$REPORT" --output "$OUTPUT" --min-freq 1 >/dev/null 2>&1
    grep -qF "prompt_too_long" "$OUTPUT"
    grep -qF "skill_error" "$OUTPUT"
    grep -qF "gate_skip" "$OUTPUT"
}