#!/usr/bin/env bats
# tests/us031-rollback-tag.bats -- TD-031 rsi-rollback.sh add tag subcommand TDD tests
# ASCII-only test names (bats does not support UTF-8)

setup() {
    export LC_ALL=C
    export LANG=C
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    git init -q .
    git config user.email "test@example.com"
    git config user.name "Test User"
    git commit --allow-empty -m "init" -q
    export PATH="/Users/apple/Sites/localhost/tree_monstor/tools:$PATH"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "TD-031-1: tag subcommand writes first rsi-vYYYYMMDD-01" {
    run rsi-rollback.sh tag --message "fix: first"
    [[ "$output" =~ rsi-v[0-9]{8}-01 ]]
}

@test "TD-031-2: tag format rsi-vYYYYMMDD-NN (no dashes in date)" {
    rsi-rollback.sh tag --message "test" >/dev/null 2>&1
    run git tag -l "rsi-v*"
    [[ "$output" =~ ^rsi-v[0-9]{8}-[0-9]+$ ]]
}

@test "TD-031-3: same day second tag auto-increments to 02" {
    rsi-rollback.sh tag --message "first" >/dev/null 2>&1
    run rsi-rollback.sh tag --message "second"
    [[ "$output" =~ rsi-v[0-9]{8}-02 ]]
}

@test "TD-031-4: list command shows newly created tag" {
    rsi-rollback.sh tag --message "test-tag" >/dev/null 2>&1
    run rsi-rollback.sh list
    [[ "$output" =~ rsi-v ]]
}

@test "TD-031-5: tag --help shows usage" {
    run rsi-rollback.sh tag --help
    [[ "$output" =~ [Uu]sage ]]
}

@test "TD-031-6: non-git repo returns error" {
    cd "$BATS_TEST_TMPDIR"
    # Run with a non-existent target to simulate not a git repo
    run rsi-rollback.sh tag --message "should fail" --target /tmp/this-path-does-not-exist-and-is-not-git
    [ "$status" -ne 0 ]
}

@test "TD-031-7: tag visible in git tag -l after creation" {
    rsi-rollback.sh tag --message "verify" >/dev/null 2>&1
    run git tag -l "rsi-v*"
    [[ "$output" =~ ^rsi-v[0-9]{8}-[0-9]+$ ]]
}

@test "TD-031-8: list command works on empty repo without error" {
    run rsi-rollback.sh list
    [ "$status" -eq 0 ]
}