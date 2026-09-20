#!/usr/bin/env bats
# tests/us026-rsi-propose-similar.bats — US-026 rsi-propose.sh --show-similar
# 對應 Sprint 14 US-026 (1 SP)
# 對應 docs/prd/04-self-evolution.md §11.7
# 對應 docs/system-design.md ADR-026

setup() {
    export LC_ALL=C
    export LANG=C
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "us026-1: --show-similar option exists in help" {
    run "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--show-similar"* ]]
}

@test "us026-2: --show-similar with no similar rules shows message" {
    cat > "$TEST_DIR/rules.md" <<EOF
# Rules

| ID | Event Type |
| --- | --- |
| 1 | shellcheck_not_installed |
| 2 | gate_skip |
EOF

    run "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" \
        --show-similar \
        --rules "$TEST_DIR/rules.md"

    [ "$status" -eq 0 ]
    [[ "$output" == *"無相似"* ]] || [[ "$output" == *"no similar"* ]]
}

@test "us026-3: --show-similar detects similar events (Levenshtein ≤ 3)" {
    cat > "$TEST_DIR/rules.md" <<EOF
# Rules

| ID | Event Type |
| --- | --- |
| 1 | bats_test_unicode_error |
| 2 | bats_test_chinese_paren |
EOF

    run "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" \
        --show-similar \
        --rules "$TEST_DIR/rules.md"

    [ "$status" -eq 0 ]
    [[ "$output" == *"bats_test_unicode_error"* ]]
    [[ "$output" == *"bats_test_chinese_paren"* ]]
    [[ "$output" == *"相似"* ]]
}

@test "us026-4: --show-similar outputs valid JSON when --output-format json" {
    cat > "$TEST_DIR/rules.md" <<EOF
# Rules

| ID | Event Type |
| --- | --- |
| 1 | bats_test_unicode_error |
| 2 | bats_test_chinese_paren |
EOF

    "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" \
        --show-similar \
        --rules "$TEST_DIR/rules.md" \
        --output-format json \
        --output "$TEST_DIR/similar.json"

    [ -f "$TEST_DIR/similar.json" ]
    run python3 -c "import json; json.load(open('$TEST_DIR/similar.json'))"
    [ "$status" -eq 0 ]
}

@test "us026-5: --show-similar suggests merge option" {
    cat > "$TEST_DIR/rules.md" <<EOF
# Rules

| ID | Event Type |
| --- | --- |
| 1 | gate_skip_v1 |
| 2 | gate_skip_v2 |
EOF

    run "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" \
        --show-similar \
        --rules "$TEST_DIR/rules.md"

    [ "$status" -eq 0 ]
    [[ "$output" == *"建議"* ]] || [[ "$output" == *"merge"* ]] || [[ "$output" == *"合併"* ]]
}