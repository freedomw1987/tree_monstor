#!/usr/bin/env bats
# tests/td037-propose-json.bats — TD-037 rsi-propose --output-format json
# 對應 Sprint 13 TD-037 (1 SP)
# 對應 docs/prd/04-self-evolution.md §11.6
# 對應 docs/system-design.md ADR-021

setup() {
    export LC_ALL=C
    export LANG=C
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "td037-1: --output-format json produces valid JSON" {
    cat > "$TEST_DIR/report.md" <<EOF
# RSI 聚合報告

## 事件類型分佈

| 事件類型 | 次數 |
| --- | --- |
| shellcheck_not_installed | 5 |
| user_lost_work_no_backup | 3 |
EOF

    run "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" \
        --report "$TEST_DIR/report.md" \
        --min-freq 2 --limit 5 \
        --output-format json \
        --output "$TEST_DIR/proposals.json"

    [ "$status" -eq 0 ]

    # 驗證是 valid JSON
    run python3 -c "import json; json.load(open('$TEST_DIR/proposals.json'))"
    [ "$status" -eq 0 ]
}

@test "td037-2: JSON contains expected top-level fields" {
    cat > "$TEST_DIR/report.md" <<EOF
# RSI 聚合報告

| 事件類型 | 次數 |
| --- | --- |
| shellcheck_not_installed | 5 |
EOF

    "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" \
        --report "$TEST_DIR/report.md" \
        --min-freq 1 --limit 5 \
        --output-format json \
        --output "$TEST_DIR/proposals.json"

    # 驗證 schema_version, generated_at, source_report, min_frequency, limit, proposals
    run python3 -c "
import json
d = json.load(open('$TEST_DIR/proposals.json'))
required = ['schema_version', 'generated_at', 'source_report', 'min_frequency', 'limit', 'proposals']
missing = [k for k in required if k not in d]
assert not missing, f'missing keys: {missing}'
print('all required keys present')
"
    [ "$status" -eq 0 ]
}

@test "td037-3: JSON preserves UTF-8 (not unicode-escaped)" {
    cat > "$TEST_DIR/report.md" <<EOF
# RSI 聚合報告

| 事件類型 | 次數 |
| --- | --- |
| gate_skip | 5 |
EOF

    "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" \
        --report "$TEST_DIR/report.md" \
        --min-freq 1 --limit 5 \
        --output-format json \
        --output "$TEST_DIR/proposals.json"

    # 不應該有 \uXXXX unicode escape
    run grep -c '\\u[0-9a-f]' "$TEST_DIR/proposals.json"
    # grep -c 找不到匹配會 return 1（status=1）
    [ "$output" = "0" ]
}

@test "td037-4: --output-format text still works (backward compat)" {
    cat > "$TEST_DIR/report.md" <<EOF
# RSI 聚合報告

| 事件類型 | 次數 |
| --- | --- |
| gate_skip | 5 |
EOF

    run "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" \
        --report "$TEST_DIR/report.md" \
        --min-freq 1 --limit 5 \
        --output-format text

    [ "$status" -eq 0 ]
    # 應該是 markdown 格式（含「# RSI 提案清單」）
    [[ "$output" == *"# RSI 提案清單"* ]]
}

@test "td037-5: invalid --output-format value rejected" {
    cat > "$TEST_DIR/report.md" <<EOF
# RSI 聚合報告

| 事件類型 | 次數 |
| --- | --- |
| gate_skip | 5 |
EOF

    run "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" \
        --report "$TEST_DIR/report.md" \
        --min-freq 1 --limit 5 \
        --output-format xml

    [ "$status" -eq 1 ]
    [[ "$output" == *"必須是 text 或 json"* ]]
}

@test "td037-6: confidence score in JSON is valid number" {
    cat > "$TEST_DIR/report.md" <<EOF
# RSI 聚合報告

| 事件類型 | 次數 |
| --- | --- |
| shellcheck_not_installed | 5 |
EOF

    "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" \
        --report "$TEST_DIR/report.md" \
        --min-freq 1 --limit 5 \
        --output-format json \
        --output "$TEST_DIR/proposals.json"

    run python3 -c "
import json
d = json.load(open('$TEST_DIR/proposals.json'))
for p in d['proposals']:
    conf = p['confidence']
    assert isinstance(conf, (int, float)), f'confidence is {type(conf)}'
    assert 0 <= conf <= 1, f'confidence {conf} out of range'
print('all confidence values valid')
"
    [ "$status" -eq 0 ]
}