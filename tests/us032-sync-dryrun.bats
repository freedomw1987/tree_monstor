#!/usr/bin/env bats
# tests/us032-sync-dryrun.bats -- TD-032 rsi-sync.sh --dry-run file listing TDD tests
# ASCII-only test names (bats does not support UTF-8)

setup() {
    export LC_ALL=C
    export LANG=C
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR

    # 建 mock source dir
    SRC_DIR="$TEST_DIR/src-sop"
    mkdir -p "$SRC_DIR/handbook"
    echo "source handbook 1" > "$SRC_DIR/handbook/2.8-rsi-evolution.md"
    echo "source gates 1" > "$SRC_DIR/gates.json"

    # 建 3 個 mock 專案
    PROJ_LIST="$TEST_DIR/projects.txt"
    for i in 1 2 3; do
        PROJ_PATH="$TEST_DIR/proj$i"
        mkdir -p "$PROJ_PATH/.pi/sop"
        # proj1: 完全同步 (hash 同) -- skip
        cp -r "$SRC_DIR/." "$PROJ_PATH/.pi/sop/"
        # proj2: 有本地 override (會跳過)
        touch "$PROJ_PATH/.pi/sop/.local-override"
        # proj3: 本地版本較舊 (會被覆蓋)
        echo "old handbook" > "$PROJ_PATH/.pi/sop/handbook/2.8-rsi-evolution.md"
    done
    # 移除 proj1 的 local-override (讌 td-032-1 能看到 path)
    rm -f "$TEST_DIR/proj1/.pi/sop/.local-override"
    # 寫專案清單
    echo "$TEST_DIR/proj1" > "$PROJ_LIST"
    echo "$TEST_DIR/proj2" >> "$PROJ_LIST"
    echo "$TEST_DIR/proj3" >> "$PROJ_LIST"

    export PATH="/Users/apple/Sites/localhost/tree_monstor/tools:$PATH"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "TD-032-1: --dry-run shows file path" {
    run rsi-sync.sh --dry-run --source "$SRC_DIR" --project-list "$PROJ_LIST" --trigger manual
    [[ "$output" =~ handbook/2\.8-rsi-evolution\.md ]]
}

@test "TD-032-2: --dry-run shows action column" {
    run rsi-sync.sh --dry-run --source "$SRC_DIR" --project-list "$PROJ_LIST" --trigger manual
    [[ "$output" =~ [Aa]ction|[Uu]pdate|[Aa]dd|[Mm]odify ]]
}

@test "TD-032-3: --dry-run shows md5 hash" {
    run rsi-sync.sh --dry-run --source "$SRC_DIR" --project-list "$PROJ_LIST" --trigger manual
    [[ "$output" =~ md5|[Hh]ash ]]
}

@test "TD-032-4: --dry-run without --apply does not modify files" {
    rsi-sync.sh --dry-run --source "$SRC_DIR" --project-list "$PROJ_LIST" --trigger manual >/dev/null 2>&1
    run cat "$TEST_DIR/proj3/.pi/sop/handbook/2.8-rsi-evolution.md"
    [[ "$output" =~ "old handbook" ]]
}

@test "TD-032-5: --dry-run skips local-override projects" {
    run rsi-sync.sh --dry-run --source "$SRC_DIR" --project-list "$PROJ_LIST" --trigger manual
    # proj2 有 local-override，應該被跳過（不算 modify）
    [[ "$output" =~ "local-override"|"skip" ]]
}

@test "TD-032-6: --dry-run shows summary of projects" {
    run rsi-sync.sh --dry-run --source "$SRC_DIR" --project-list "$PROJ_LIST" --trigger manual
    # 結果是中文，用 grep -qF 匹配「已處理專案」
    echo "$output" | grep -qF "已處理專案"
}

@test "TD-032-7: dry-run without source dir does not crash" {
    run rsi-sync.sh --dry-run --source /tmp/nonexistent-source-xyz --project-list "$PROJ_LIST" --trigger manual
    [ "$status" -ne 0 ]
}