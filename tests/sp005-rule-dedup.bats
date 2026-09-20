#!/usr/bin/env bats
# tests/sp005-rule-dedup.bats — SP-005 跨專案規則去重研究驗證
# 對應 Sprint 13 SP-005 (2 SP 研究)
# 對應 docs/research/2026-09-20-cross-project-rule-dedup.md
# 對應 docs/system-design.md ADR-024

setup() {
    export LC_ALL=C
    export LANG=C
}

@test "sp005-1: research document exists and is non-empty" {
    [ -f "$BATS_TEST_DIRNAME/../docs/research/2026-09-20-cross-project-rule-dedup.md" ]
    [ -s "$BATS_TEST_DIRNAME/../docs/research/2026-09-20-cross-project-rule-dedup.md" ]
}

@test "sp005-2: research document covers 3 mock test cases" {
    content="$(cat "$BATS_TEST_DIRNAME/../docs/research/2026-09-20-cross-project-rule-dedup.md")"
    [[ "$content" == *"Mock 測試 1"* ]]
    [[ "$content" == *"Mock 測試 2"* ]]
    [[ "$content" == *"Mock 測試 3"* ]]
}

@test "sp005-3: research document contains clear conclusions" {
    content="$(cat "$BATS_TEST_DIRNAME/../docs/research/2026-09-20-cross-project-rule-dedup.md")"
    [[ "$content" == *"共用規則"* ]]
    [[ "$content" == *"獨立規則"* ]]
    [[ "$content" == *"結論"* ]]
}

@test "sp005-4: research document specifies rule library limit" {
    content="$(cat "$BATS_TEST_DIRNAME/../docs/research/2026-09-20-cross-project-rule-dedup.md")"
    [[ "$content" == *"規則庫"* ]]
    [[ "$content" == *"≤ 20"* ]]
}

@test "sp005-5: research document recommends AI suggest / human decide" {
    content="$(cat "$BATS_TEST_DIRNAME/../docs/research/2026-09-20-cross-project-rule-dedup.md")"
    [[ "$content" == *"AI 提建議"* ]]
    [[ "$content" == *"人類決策"* ]]
}

@test "sp005-6: research document has valid markdown" {
    run python3 -c "
content = open('$BATS_TEST_DIRNAME/../docs/research/2026-09-20-cross-project-rule-dedup.md').read()
# 至少要有 3 個 ## 標題
h2_count = sum(1 for line in content.split('\n') if line.startswith('## '))
assert h2_count >= 6, f'need ≥ 6 ## sections, got {h2_count}'
print(f'{h2_count} ## sections')
"
    [ "$status" -eq 0 ]
}