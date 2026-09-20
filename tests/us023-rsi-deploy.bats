#!/usr/bin/env bats
# tests/us023-rsi-deploy.bats — US-023 rsi-deploy.sh 1 鍵部署
# 對應 Sprint 13 US-023 (2 SP)
# 對應 docs/prd/04-self-evolution.md §11.6
# 對應 docs/system-design.md ADR-022

setup() {
    export LC_ALL=C
    export LANG=C
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
}

teardown() {
    rm -rf "$TEST_DIR"
    rm -f "$HOME/.rsi_cron_us023-*"
}

@test "us023-1: rsi-deploy.sh --help shows usage" {
    run "$BATS_TEST_DIRNAME/../tools/rsi-deploy.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--target"* ]]
}

@test "us023-2: --target is required" {
    run "$BATS_TEST_DIRNAME/../tools/rsi-deploy.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"必填"* ]]
}

@test "us023-3: invalid --app-type rejected" {
    run "$BATS_TEST_DIRNAME/../tools/rsi-deploy.sh" \
        --target "$TEST_DIR/app" \
        --app-type rust
    [ "$status" -eq 1 ]
    [[ "$output" == *"必須是 python 或 node"* ]]
}

@test "us023-4: python mock app deployment creates app.py" {
    "$BATS_TEST_DIRNAME/../tools/rsi-deploy.sh" \
        --target "$TEST_DIR/myapp" \
        --app-type python \
        --yes > /dev/null 2>&1

    [ -f "$TEST_DIR/myapp/app.py" ]
    [[ "$(cat "$TEST_DIR/myapp/app.py")" == *"Hello from mock RSI-deployed app"* ]]
}

@test "us023-5: node mock app deployment creates app.js" {
    "$BATS_TEST_DIRNAME/../tools/rsi-deploy.sh" \
        --target "$TEST_DIR/myapp" \
        --app-type node \
        --yes > /dev/null 2>&1

    [ -f "$TEST_DIR/myapp/app.js" ]
    [[ "$(cat "$TEST_DIR/myapp/app.js")" == *"Hello from mock RSI-deployed app"* ]]
}

@test "us023-6: deployment creates deploy-report.md" {
    "$BATS_TEST_DIRNAME/../tools/rsi-deploy.sh" \
        --target "$TEST_DIR/myapp" \
        --app-type python \
        --yes > /dev/null 2>&1

    [ -f "$TEST_DIR/myapp/docs/deploy-report.md" ]
    [[ "$(cat "$TEST_DIR/myapp/docs/deploy-report.md")" == *"# 部署報告"* ]]
}

@test "us023-7: deployment creates valid deploy-report.json" {
    "$BATS_TEST_DIRNAME/../tools/rsi-deploy.sh" \
        --target "$TEST_DIR/myapp" \
        --app-type python \
        --yes > /dev/null 2>&1

    [ -f "$TEST_DIR/myapp/docs/deploy-report.json" ]
    run python3 -c "import json; d = json.load(open('$TEST_DIR/myapp/docs/deploy-report.json')); assert 'schema_version' in d and 'deployed_at' in d and 'app_type' in d"
    [ "$status" -eq 0 ]
}

@test "us023-8: cron file created at HOME" {
    "$BATS_TEST_DIRNAME/../tools/rsi-deploy.sh" \
        --target "$TEST_DIR/us023-mockapp" \
        --app-type python \
        --cron-hour 5 \
        --yes > /dev/null 2>&1

    [ -f "$HOME/.rsi_cron_us023-mockapp" ]
    [[ "$(cat "$HOME/.rsi_cron_us023-mockapp")" == *"0 5"* ]]
    [[ "$(cat "$HOME/.rsi_cron_us023-mockapp")" == *"rsi-metrics.sh"* ]]
    [[ "$(cat "$HOME/.rsi_cron_us023-mockapp")" == *"rsi-alert.sh"* ]]
}

@test "us023-9: sop-evolver skill deployed (--yes)" {
    "$BATS_TEST_DIRNAME/../tools/rsi-deploy.sh" \
        --target "$TEST_DIR/myapp" \
        --app-type python \
        --yes > /dev/null 2>&1

    [ -d "$TEST_DIR/myapp/skills/sop-evolver" ]
    [ -f "$TEST_DIR/myapp/skills/sop-evolver/SKILL.md" ]
}

@test "us023-10: without --yes sop-evolver skill not deployed" {
    "$BATS_TEST_DIRNAME/../tools/rsi-deploy.sh" \
        --target "$TEST_DIR/myapp" \
        --app-type python \
        > /dev/null 2>&1

    [ ! -d "$TEST_DIR/myapp/skills/sop-evolver" ]
}