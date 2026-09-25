#!/usr/bin/env bats
# tests/wiki-cleanup.bats — TD-019 wiki-cleanup.sh CLI 測試

setup() {
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/docs/wiki/frontend/2025-09"
    mkdir -p "$TEST_ROOT/docs/concepts"
    cd "$TEST_ROOT"
    WIKI_CLEANUP="$BATS_TEST_DIRNAME/../skills/dav-wiki/scripts/wiki-cleanup.sh"

    # 建立一個超過 90 天的 deprecated 檔案
    cat > "$TEST_ROOT/docs/wiki/frontend/2025-09/old-react-pattern.md" <<EOF
---
title: "Old React Pattern"
extracted_at: 2025-09-15
category: frontend
tags: [react, deprecated]
deprecated: true
deprecated_at: 2025-09-15
superseded_by: null
---

# Old React Pattern

Class component 已經過時，建議改用 function component。
EOF

    # 建立一個剛 deprecate 的檔案（不應該被清理，用動態日期）
    RECENT_DATE=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d "30 days ago" +%Y-%m-%d)
    cat > "$TEST_ROOT/docs/wiki/frontend/2025-09/recent-deprecated.md" <<EOF
---
title: "Recently Deprecated"
extracted_at: ${RECENT_DATE}
category: frontend
tags: [react]
deprecated: true
deprecated_at: ${RECENT_DATE}
---

# Recently Deprecated
EOF

    # 建立一個 active 檔案（不應該被清理，用動態日期）
    TODAY_DATE=$(date +%Y-%m-%d)
    cat > "$TEST_ROOT/docs/wiki/frontend/2025-09/active-doc.md" <<EOF
---
title: "Active Doc"
extracted_at: ${TODAY_DATE}
category: frontend
tags: [react]
deprecated: false
---

# Active Doc
EOF

    # 建立 _index.json
    cat > "$TEST_ROOT/docs/wiki/_index.json" <<EOF
{
  "version": 1,
  "documents": [
    {"id": "old-react-pattern", "path": "frontend/2025-09/old-react-pattern.md", "deprecated": true},
    {"id": "recent-deprecated", "path": "frontend/2025-09/recent-deprecated.md", "deprecated": true},
    {"id": "active-doc", "path": "frontend/2025-09/active-doc.md", "deprecated": false}
  ],
  "tags_index": {"react": ["old-react-pattern", "recent-deprecated", "active-doc"]}
}
EOF
}

teardown() {
    rm -rf "$TEST_ROOT"
}

# === 基本功能 ===

@test "wiki-cleanup: --help" {
    run "$WIKI_CLEANUP" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "--older-than" ]]
    [[ "$output" =~ "--dry-run" ]]
}

@test "wiki-cleanup: --dry-run" {
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --dry-run --older-than 90
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Dry-run" ]] || [[ "$output" =~ "dry-run" ]] || [[ "$output" =~ "[INFO]" ]]
    # 檔案還在原位置
    [ -f "$TEST_ROOT/docs/wiki/frontend/2025-09/old-react-pattern.md" ]
    # 沒有 _deprecated/
    [ ! -d "$TEST_ROOT/docs/wiki/_deprecated" ]
}

@test "wiki-cleanup: --yes 90 deprecated" {
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    # 原檔案已移到 _deprecated/
    [ ! -f "$TEST_ROOT/docs/wiki/frontend/2025-09/old-react-pattern.md" ]
    # 2025-09 是 Q3
    [ -f "$TEST_ROOT/docs/wiki/_deprecated/2025-Q3/old-react-pattern.md" ]
}

@test "wiki-cleanup: < 90 deprecated" {
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    # recent-deprecated 還在原位置（才 deprecate 幾天）
    [ -f "$TEST_ROOT/docs/wiki/frontend/2025-09/recent-deprecated.md" ]
}

@test "wiki-cleanup: active" {
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    [ -f "$TEST_ROOT/docs/wiki/frontend/2025-09/active-doc.md" ]
}

# === 索引同步 ===

@test "wiki-cleanup: _index.json" {
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    # _index.json 不應再含 old-react-pattern
    ! grep -q "old-react-pattern" "$TEST_ROOT/docs/wiki/_index.json"
    # 仍含 recent-deprecated 與 active-doc
    grep -q "recent-deprecated" "$TEST_ROOT/docs/wiki/_index.json"
    grep -q "active-doc" "$TEST_ROOT/docs/wiki/_index.json"
}

@test "wiki-cleanup: _deprecated/_index.json" {
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    [ -f "$TEST_ROOT/docs/wiki/_deprecated/_index.json" ]
    grep -q "old-react-pattern" "$TEST_ROOT/docs/wiki/_deprecated/_index.json"
    grep -q "frontend/2025-09/old-react-pattern.md" "$TEST_ROOT/docs/wiki/_deprecated/_index.json"
}

# === Frontmatter 補欄位 ===

@test "wiki-cleanup: frontmatter deprecated_moved_at" {
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    grep -q "deprecated_moved_at" "$TEST_ROOT/docs/wiki/_deprecated/2025-Q3/old-react-pattern.md"
}

# === 邊緣案例 ===

@test "wiki-cleanup: deprecated" {
    rm -f "$TEST_ROOT/docs/wiki/frontend/2025-09/old-react-pattern.md"
    rm -f "$TEST_ROOT/docs/wiki/frontend/2025-09/recent-deprecated.md"
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0" ]] || [[ "$output" =~ "no deprecated" ]] || [[ "$output" =~ "nothing" ]]
}

@test "wiki-cleanup: missing-target-dir errors" {
    run "$WIKI_CLEANUP" --target "/tmp/nonexistent-xyz-123" --yes --older-than 90
    [ "$status" -ne 0 ]
}

@test "wiki-cleanup: --yes n" {
    run bash -c "echo 'n' | '$WIKI_CLEANUP' --target '$TEST_ROOT/docs' --older-than 90"
    [ "$status" -eq 0 ]
    # 檔案還在原位置
    [ -f "$TEST_ROOT/docs/wiki/frontend/2025-09/old-react-pattern.md" ]
}

@test "wiki-cleanup: --older-than 0 deprecated" {
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 0
    [ "$status" -eq 0 ]
    # recent-deprecated 也被清了（因為 < 1 天算過 0 天）
    [ ! -f "$TEST_ROOT/docs/wiki/frontend/2025-09/recent-deprecated.md" ]
}

@test "wiki-cleanup: _deprecated/" {
    mkdir -p "$TEST_ROOT/docs/wiki/_deprecated/2025-Q3"
    echo "HISTORICAL" > "$TEST_ROOT/docs/wiki/_deprecated/2025-Q3/old-react-pattern.md"
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    # 沒被覆蓋
    grep -q "HISTORICAL" "$TEST_ROOT/docs/wiki/_deprecated/2025-Q3/old-react-pattern.md"
}

# === 邊緣案例（E1-E4） ===

@test "E1 wiki-cleanup: --purge" {
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90 --purge
    [ "$status" -eq 0 ]
    # 檔案不存在
    [ ! -f "$TEST_ROOT/docs/wiki/frontend/2025-09/old-react-pattern.md" ]
    # --purge 不該建立 _deprecated/
    [ ! -d "$TEST_ROOT/docs/wiki/_deprecated" ]
}

@test "E2 wiki-cleanup: deprecated_at=2026-02 → 2026-Q1" {
    # 重建 fixture 用 2026 年 Q1 / Q3 日期（Q4 在 11 月，避免被 age 過濾）
    mkdir -p "$TEST_ROOT/docs/wiki/frontend/2026-02" "$TEST_ROOT/docs/wiki/frontend/2026-08"
    cat > "$TEST_ROOT/docs/wiki/frontend/2026-02/test-q1.md" <<EOF
---
title: "Q1 Test"
deprecated: true
deprecated_at: 2026-02-15
---

Q1 Test
EOF
    cat > "$TEST_ROOT/docs/wiki/frontend/2026-08/test-q3.md" <<EOF
---
title: "Q3 Test"
deprecated: true
deprecated_at: 2026-08-15
---

Q3 Test
EOF
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 0
    [ "$status" -eq 0 ]
    # Q1 → 2026-Q1
    [ -f "$TEST_ROOT/docs/wiki/_deprecated/2026-Q1/test-q1.md" ]
    # Q3 → 2026-Q3
    [ -f "$TEST_ROOT/docs/wiki/_deprecated/2026-Q3/test-q3.md" ]
}

@test "E3 wiki-cleanup: deprecated_at mtime fallback crash" {
    # 建立 deprecated 但無 deprecated_at 的檔案
    cat > "$TEST_ROOT/docs/wiki/frontend/2025-09/no-date.md" <<EOF
---
title: "No Date"
deprecated: true
---

No Date
EOF
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    # 不會 crash (status 0)，且不跳錯
    [ "$status" -eq 0 ]
}

@test "E4 wiki-cleanup: idempotent re-run" {
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    # 第一次：撽走 1 個 (old-react-pattern)
    # 跑第二次：沒有可撽
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    [[ "$output" =~ "nothing" ]] || [[ "$output" =~ "沒有 deprecated" ]]
}

# === TD-021.1：README 重建測試 ===

@test "TD-021 wiki-cleanup: README categories / tags" {
    # 改 _index.json 加上 active doc
    cat > "$TEST_ROOT/docs/wiki/_index.json" <<EOF
{
  "version": 1,
  "documents": [
    {"id": "old-react-pattern", "path": "frontend/2025-09/old-react-pattern.md", "deprecated": true},
    {"id": "react-app", "path": "frontend/2025-09/react-app.md", "deprecated": false, "category": "frontend", "tags": ["react"]},
    {"id": "python-doc", "path": "backend/2025-09/python-doc.md", "deprecated": false, "category": "backend", "tags": ["python"]}
  ],
  "tags_index": {"react": ["react-app"], "python": ["python-doc"]}
}
EOF
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90
    [ "$status" -eq 0 ]
    # README 應重建
    [ -f "$TEST_ROOT/docs/README.md" ]
    # 總文件數 2（old 已被撽走）
    grep -q "總文件數：2" "$TEST_ROOT/docs/README.md"
    # categories 2 個（frontend + backend）
    grep -q "Categories：2" "$TEST_ROOT/docs/README.md"
    # tags 2 個（react + python）
    grep -q "Tags：2" "$TEST_ROOT/docs/README.md"
}

@test "TD-021 wiki-cleanup: --purge README" {
    run "$WIKI_CLEANUP" --target "$TEST_ROOT/docs" --yes --older-than 90 --purge
    [ "$status" -eq 0 ]
    # --purge 不該重建 README
    [ ! -f "$TEST_ROOT/docs/README.md" ]
}