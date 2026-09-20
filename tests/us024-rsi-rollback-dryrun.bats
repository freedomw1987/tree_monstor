#!/usr/bin/env bats
# tests/us024-rsi-rollback-dryrun.bats — US-024 rsi-rollback --dry-run
# 對應 Sprint 13 US-024 (1 SP)
# 對應 docs/prd/04-self-evolution.md §11.6
# 對應 docs/system-design.md ADR-023

setup() {
    export LC_ALL=C
    export LANG=C
    # 建立 mock git repo
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    git init -q
    git config user.email "test@local"
    git config user.name "Test"
    echo "init" > file.txt
    git add file.txt
    git commit -q -m "init commit"
    git tag rsi-v20240901-99 HEAD
    echo "second" >> file.txt
    git commit -q -am "second commit"
    git tag rsi-v20250901-99 HEAD
    echo "third" >> file.txt
    git commit -q -am "third commit"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

@test "us024-1: --help shows --dry-run option" {
    run "$BATS_TEST_DIRNAME/../tools/rsi-rollback.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--dry-run"* ]]
}

@test "us024-2: dry-run shows repo / tag / commit" {
    cd "$TEST_DIR"
    run "$BATS_TEST_DIRNAME/../tools/rsi-rollback.sh" \
        --target rsi-v20240901-99 \
        --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry-run 模式"* ]]
    [[ "$output" == *"rsi-v20240901-99"* ]]
}

@test "us024-3: dry-run lists commits to revert" {
    cd "$TEST_DIR"
    run "$BATS_TEST_DIRNAME/../tools/rsi-rollback.sh" \
        --target rsi-v20240901-99 \
        --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Commits to revert"* ]]
    [[ "$output" == *"second commit"* ]]
    [[ "$output" == *"third commit"* ]]
}

@test "us024-4: dry-run lists affected files" {
    cd "$TEST_DIR"
    run "$BATS_TEST_DIRNAME/../tools/rsi-rollback.sh" \
        --target rsi-v20240901-99 \
        --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Affected files"* ]]
    [[ "$output" == *"file.txt"* ]]
}

@test "us024-5: dry-run does not execute git revert" {
    cd "$TEST_DIR"
    BEFORE_HEAD="$(git rev-parse HEAD)"

    "$BATS_TEST_DIRNAME/../tools/rsi-rollback.sh" \
        --target rsi-v20240901-99 \
        --dry-run > /dev/null 2>&1

    AFTER_HEAD="$(git rev-parse HEAD)"
    [ "$BEFORE_HEAD" = "$AFTER_HEAD" ]
}

@test "us024-6: dry-run shows simulated actions" {
    cd "$TEST_DIR"
    run "$BATS_TEST_DIRNAME/../tools/rsi-rollback.sh" \
        --target rsi-v20240901-99 \
        --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"git revert --no-edit"* ]]
    [[ "$output" == *"git checkout"* ]]
    [[ "$output" == *"Dry-run 完成"* ]]
}

@test "us024-7: dry-run with same-as-HEAD tag says no commits" {
    cd "$TEST_DIR"
    # 加一個新 tag 在 HEAD（tag 跟 HEAD 之間會有 0 個 commit）
    # tag 命名必須符合 rsi-vYYYYMMDD-NN 格式（NN = 數字）
    git tag rsi-v20250920-99 HEAD
    run "$BATS_TEST_DIRNAME/../tools/rsi-rollback.sh" \
        --target rsi-v20250920-99 \
        --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"無將被回滾的 commit"* ]]
}

@test "us024-8: dry-run works with macOS bash 3.2 + set -u (TD-035 fix)" {
    cd "$TEST_DIR"
    set +e
    bash -c "
        set -uo pipefail
        export LC_ALL=C
        $BATS_TEST_DIRNAME/../tools/rsi-rollback.sh \
            --target rsi-v20240901-99 \
            --dry-run
    " > /dev/null 2>&1
    [ "$?" -eq 0 ]
    set -e
}