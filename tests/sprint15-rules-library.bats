#!/usr/bin/env bats
# tests/sprint15-rules-library.bats — Sprint 15 US-029-A rules library + review TDD tests
# 驗證：建基礎規則庫（12 條）+ 跑 rsi-rules-review.sh 產 REVIEW.md
# ASCII-only test names (bats does not support UTF-8)

setup() {
    export LC_ALL=C
    export LANG=C
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
    # BATS_TEST_DIRNAME 是 bats 內建變量（指向測試檔所在目錄）
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
    export REPO_ROOT
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "sprint15-1: docs/sop/rsi-rules.md exists with 12 rules" {
    [ -f "$REPO_ROOT/docs/sop/rsi-rules.md" ]
    count=$(grep -cE '^\| [0-9]+ \|' "$REPO_ROOT/docs/sop/rsi-rules.md")
    [[ "$count" -eq 12 ]]
}

@test "sprint15-2: rules file has all 7 event-type prefixes" {
    # markdown, bash, shellcheck, py, json, bats, awk
    for prefix in markdown bash shellcheck py json bats awk; do
        grep -qE "^\| [0-9]+ \| ${prefix}_" "$REPO_ROOT/docs/sop/rsi-rules.md"
    done
}

@test "sprint15-3: rsi-rules-review.sh runs without unbound-variable errors" {
    cd "$REPO_ROOT"
    run ./tools/rsi-rules-review.sh
    [[ "$status" -eq 0 ]]
    [[ ! "$output" =~ "unbound variable" ]]
}

@test "sprint15-4: REVIEW.md is generated with 12 rules count" {
    cd "$REPO_ROOT"
    rm -f tools/rules/REVIEW.md
    ./tools/rsi-rules-review.sh >/dev/null 2>&1
    [ -f tools/rules/REVIEW.md ]
    grep -q "總規則數 | 12" tools/rules/REVIEW.md
}

@test "sprint15-5: REVIEW.md finds similar pairs in real rules (not just mock)" {
    cd "$REPO_ROOT"
    ./tools/rsi-rules-review.sh >/dev/null 2>&1
    # 12 條 markdown_* 系列應有相似對（至少 1 對）
    grep -q '"similar_pairs"' tools/rules/REVIEW.md
    # 抓 JSON 區塊並驗證非空
    similar_count=$(python3 -c "
import re, json
with open('tools/rules/REVIEW.md') as f:
    content = f.read()
m = re.search(r'\`\`\`json\n(.*?)\n\`\`\`', content, re.DOTALL)
if m:
    data = json.loads(m.group(1))
    print(data.get('total_similar_pairs', 0))
else:
    print(0)
")
    [[ "$similar_count" -ge 1 ]]
}