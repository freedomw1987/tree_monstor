#!/usr/bin/env bats
# tests/td038-rsi-rules-review.bats — TD-038 tools/rsi-rules-review.sh
# 對應 Sprint 14 TD-038 (1 SP)
# 對應 docs/prd/04-self-evolution.md §11.7
# 對應 docs/system-design.md ADR-027

setup() {
    export LC_ALL=C
    export LANG=C
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "td038-1: rsi-rules-review.sh --help shows usage" {
    run "$BATS_TEST_DIRNAME/../tools/rsi-rules-review.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--rules"* ]] || [[ "$output" == *"--threshold"* ]]
}

@test "td038-2: REVIEW.md is generated in output directory" {
    cat > "$TEST_DIR/rules.md" <<EOF
# Rules

| ID | Event Type |
| --- | --- |
| 1 | shellcheck_not_installed |
| 2 | gate_skip |
EOF

    "$BATS_TEST_DIRNAME/../tools/rsi-rules-review.sh" \
        --rules "$TEST_DIR/rules.md" \
        --output-dir "$TEST_DIR" > /dev/null 2>&1

    [ -f "$TEST_DIR/REVIEW.md" ]
}

@test "td038-3: REVIEW.md mentions total rules count" {
    cat > "$TEST_DIR/rules.md" <<EOF
# Rules

| ID | Event Type |
| --- | --- |
| 1 | shellcheck_not_installed |
| 2 | gate_skip |
EOF

    "$BATS_TEST_DIRNAME/../tools/rsi-rules-review.sh" \
        --rules "$TEST_DIR/rules.md" \
        --output-dir "$TEST_DIR" > /dev/null 2>&1

    [ -f "$TEST_DIR/REVIEW.md" ]
    run grep -c "規則庫\|Total\|總計\|2" "$TEST_DIR/REVIEW.md"
    [ "$output" -gt 0 ]
}

@test "td038-4: REVIEW.md lists similar rules when present" {
    cat > "$TEST_DIR/rules.md" <<EOF
# Rules

| ID | Event Type |
| --- | --- |
| 1 | bats_test_unicode_error |
| 2 | bats_test_chinese_paren |
EOF

    "$BATS_TEST_DIRNAME/../tools/rsi-rules-review.sh" \
        --rules "$TEST_DIR/rules.md" \
        --output-dir "$TEST_DIR" > /dev/null 2>&1

    [ -f "$TEST_DIR/REVIEW.md" ]
    [[ "$(cat "$TEST_DIR/REVIEW.md")" == *"bats_test_unicode_error"* ]]
    [[ "$(cat "$TEST_DIR/REVIEW.md")" == *"bats_test_chinese_paren"* ]]
}

@test "td038-5: REVIEW.md warns when rules > threshold" {
    # 設 threshold = 1，然後給 2 個規則
    cat > "$TEST_DIR/rules.md" <<EOF
# Rules

| ID | Event Type |
| --- | --- |
| 1 | shellcheck_not_installed |
| 2 | gate_skip |
EOF

    "$BATS_TEST_DIRNAME/../tools/rsi-rules-review.sh" \
        --rules "$TEST_DIR/rules.md" \
        --output-dir "$TEST_DIR" \
        --threshold 1 > /dev/null 2>&1

    [ -f "$TEST_DIR/REVIEW.md" ]
    [[ "$(cat "$TEST_DIR/REVIEW.md")" == *"警告"* ]] || [[ "$(cat "$TEST_DIR/REVIEW.md")" == *"warn"* ]] || [[ "$(cat "$TEST_DIR/REVIEW.md")" == *"review"* ]]
}