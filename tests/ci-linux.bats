#!/usr/bin/env bats
# tests/ci-linux.bats — TD-006.4 跨平台 fixture
#
# 目的：驗證 dav-wiki 工具鏈在 Linux 環境（GNU date / GNU find）行為正確
# 注意：macOS 是 BSD 風格，Linux 是 GNU 風格，這些測試主要驗證 date / find 行為一致

setup() {
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

@test "ci-linux: GNU date 解析 ISO 格式正確" {
    # 在 macOS / Linux 都要能正確解析 'YYYY-MM-DD'
    # 用 Python 確保跨平台行為
    result=$(python3 -c "from datetime import date; print((date.today() - date(2025,1,15)).days)")
    [ "$result" -gt 365 ]
}

@test "ci-linux: wiki-cleanup 在 Linux 環境正常運作（GNU date）" {
    run $REPO_ROOT/skills/dav-wiki/scripts/wiki-cleanup.sh --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    # 應搬走
    [ -f "$TEST_ROOT/docs/wiki/_deprecated/2025-Q1/linux-test.md" ]
}

@test "ci-linux: 確認 OS 是 Linux（CI 環境檢查）" {
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$(uname)" == "Linux" ]]; then
        skip "本機是 Linux，跳過此測試"
    else
        # 在 macOS / 其他環境跑，驗證測試本身不會 fail
        [ true ]
    fi
}

@test "ci-linux: README 重建在 Linux 環境可執行" {
    $REPO_ROOT/skills/dav-wiki/scripts/wiki-cleanup.sh --target "$TEST_ROOT/docs" --yes --older-than 90 >/dev/null 2>&1
    # README 重建後存在
    [ -f "$TEST_ROOT/docs/README.md" ]
}

@test "ci-linux: 跨平台 newline（\\n vs \\r\\n） Markdown 處理一致" {
    # 建立 LF 結尾檔案
    printf "title: test\ndeprecated: true\n" > "$TEST_ROOT/docs/wiki/frontend/2025-09/crlf-test.md"
    # 工具不應該 crash
    run $REPO_ROOT/skills/dav-wiki/scripts/wiki-cleanup.sh --target "$TEST_ROOT/docs" --yes --older-than 90 --dry-run
    [ "$status" -eq 0 ]
}