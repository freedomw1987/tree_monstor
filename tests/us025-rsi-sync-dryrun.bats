setup() {
    export LC_ALL=C
    export LANG=C
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "us025-1: rsi-sync.sh --help shows --dry-run option" {
    run "$BATS_TEST_DIRNAME/../tools/rsi-sync.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--dry-run"* ]]
}

@test "us025-2: --dry-run lists files that would be synced" {
    mkdir -p "$TEST_DIR/source"
    mkdir -p "$TEST_DIR/target/.pi/sop"

    echo "v1" > "$TEST_DIR/source/file1.txt"

    run "$BATS_TEST_DIRNAME/../tools/rsi-sync.sh" \
        --source "$TEST_DIR/source" \
        --target "$TEST_DIR/target" \
        --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
}

@test "us025-3: --dry-run does not actually copy files" {
    mkdir -p "$TEST_DIR/source"
    mkdir -p "$TEST_DIR/target/.pi/sop"

    echo "v1" > "$TEST_DIR/source/file1.txt"

    "$BATS_TEST_DIRNAME/../tools/rsi-sync.sh" \
        --source "$TEST_DIR/source" \
        --target "$TEST_DIR/target" \
        --dry-run > /dev/null 2>&1

    [ ! -f "$TEST_DIR/target/.pi/sop/file1.txt" ]
}

@test "us025-4: --dry-run shows simulated actions" {
    mkdir -p "$TEST_DIR/source"
    mkdir -p "$TEST_DIR/target/.pi/sop"

    echo "v1" > "$TEST_DIR/source/file1.txt"

    run "$BATS_TEST_DIRNAME/../tools/rsi-sync.sh" \
        --source "$TEST_DIR/source" \
        --target "$TEST_DIR/target" \
        --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"[add]"* ]]
}

@test "us025-5: --dry-run compares hash when file exists in target" {
    mkdir -p "$TEST_DIR/source"
    mkdir -p "$TEST_DIR/target/.pi/sop"

    echo "v1" > "$TEST_DIR/source/file1.txt"
    echo "old" > "$TEST_DIR/target/.pi/sop/file1.txt"

    run "$BATS_TEST_DIRNAME/../tools/rsi-sync.sh" \
        --source "$TEST_DIR/source" \
        --target "$TEST_DIR/target" \
        --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"[modify]"* ]]
}
