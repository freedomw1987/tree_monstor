#!/usr/bin/env bats
# tests/ci-linux.bats — TD-006.4 跨平台 fixture
#
# 目的：驗證 dav-wiki 工具鏈在 Linux 環境（GNU date / GNU find）行為正確
# 注意：macOS 是 BSD 風格，Linux 是 GNU 風格，這些測試主要驗證 date / find 行為一致

setup() {
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    TEST_ROOT="$(mktemp -d)"
    cd "$TEST_ROOT"
    mkdir -p docs/wiki/frontend/2025-09

    # 建立 deprecated 檔案
    cat > docs/wiki/frontend/2025-09/linux-test.md <<EOF
---
title: "Linux Test"
deprecated: true
deprecated_at: 2025-01-15
---
EOF

    # 建立 _index.json
    cat > docs/wiki/_index.json <<EOF
{
  "version": 1,
  "documents": [
    {"id": "linux-test", "path": "frontend/2025-09/linux-test.md", "deprecated": true, "category": "frontend", "tags": ["linux"]}
  ],
  "tags_index": {"linux": ["linux-test"]}
}
EOF
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "ci-linux: GNU date ISO" {
    # 在 macOS / Linux 都要能正確解析 'YYYY-MM-DD'
    # 用 Python 確保跨平台行為
    result=$(python3 -c "from datetime import date; print((date.today() - date(2025,1,15)).days)")
    [ "$result" -gt 365 ]
}

@test "ci-linux: wiki-cleanup Linux GNU date" {
    run $REPO_ROOT/skills/dav-wiki/scripts/wiki-cleanup.sh --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    # 應搬走
    [ -f "$TEST_ROOT/docs/wiki/_deprecated/2025-Q1/linux-test.md" ]
}

@test "ci-linux: date 90d back matches Python (GNU or BSD)" {
    # 原測試是空過（Linux skip／macOS `[ true ]`），永遠不可能失敗 → 改成真斷言：
    # 兩種平台的 date 回溯寫法都必須跟 Python 算出的日期一致（工具鏈跨平台契約）。
    local py got=""
    py=$(python3 -c "from datetime import date, timedelta; print((date.today() - timedelta(days=90)).isoformat())")
    if date -v-90d +%F >/dev/null 2>&1; then
        got=$(date -v-90d +%F)            # BSD（macOS）
    elif date -d '90 days ago' +%F >/dev/null 2>&1; then
        got=$(date -d '90 days ago' +%F)  # GNU（Linux）
    fi
    [ -n "$got" ] || { echo "FAIL: 既非 GNU 也非 BSD date → 工具鏈沒有可用的回溯寫法" >&2; return 1; }
    [ "$got" = "$py" ] || { echo "FAIL: date 回溯 90 天 = ${got}，Python = $py" >&2; return 1; }
}

@test "ci-linux: README Linux" {
    $REPO_ROOT/skills/dav-wiki/scripts/wiki-cleanup.sh --target "$TEST_ROOT/docs" --yes --older-than 90 >/dev/null 2>&1
    # README 重建後存在
    [ -f "$TEST_ROOT/docs/README.md" ]
}

@test "ci-linux: newline\\n vs \\r\\n Markdown" {
    # 建立 LF 結尾檔案
    printf "title: test\ndeprecated: true\n" > "$TEST_ROOT/docs/wiki/frontend/2025-09/crlf-test.md"
    # 工具不應該 crash
    run $REPO_ROOT/skills/dav-wiki/scripts/wiki-cleanup.sh --target "$TEST_ROOT/docs" --yes --older-than 90 --dry-run
    [ "$status" -eq 0 ]
}
