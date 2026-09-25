#!/usr/bin/env bats
# tests/wiki-cross-ref.bats — TD-020 交叉引用比對演算法測試
#
# 驗證 dav-wiki §[5] 交叉引用規則：
#   1. tags 重疊 ≥ 50% 為初步候選
#   2. keywords 重疊 ≥ 1 個才算真正相關
#   3. 最多 5 篇、最少 0 篇

setup() {
    TEST_ROOT="$(mktemp -d)"
    cd "$TEST_ROOT"
    CROSS_REF="$BATS_TEST_DIRNAME/../skills/dav-wiki/scripts/wiki-cross-ref.sh"

    # 建立 _index.json，含 4 個既有 doc
    cat > _index.json <<EOF
{
  "version": 1,
  "documents": [
    {
      "id": "doc-a",
      "tags": ["react", "ssr", "performance"],
      "keywords": ["streaming", "hydration", "bundle-size"]
    },
    {
      "id": "doc-b",
      "tags": ["react", "ssr"],
      "keywords": ["routing", "app-router"]
    },
    {
      "id": "doc-c",
      "tags": ["python", "django"],
      "keywords": ["orm", "middleware"]
    },
    {
      "id": "doc-d",
      "tags": ["react", "performance"],
      "keywords": ["streaming", "ssr"]
    }
  ]
}
EOF
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "cross-ref: 新 doc tag 重疊 100% 且 keyword 重疊 → 推薦" {
    cat > new-doc.json <<EOF
{
  "tags": ["react", "ssr", "performance"],
  "keywords": ["streaming", "hydration"]
}
EOF
    run "$CROSS_REF" _index.json new-doc.json
    [ "$status" -eq 0 ]
    # doc-a (100% tag 重疊 + keywords "streaming" 重疊) 應被推薦
    [[ "$output" =~ "doc-a" ]]
}

@test "cross-ref: tag 重疊 0% → 不推薦（python vs react）" {
    cat > new-doc.json <<EOF
{
  "tags": ["python", "django", "orm"],
  "keywords": ["middleware"]
}
EOF
    run "$CROSS_REF" _index.json new-doc.json
    [ "$status" -eq 0 ]
    # doc-c 有 python 但 tag 重疊 100%，但這是例外（自己跟自己重疊不算）
    # 我們應該過濾掉自己，但這裡新 doc 不在 _index.json 中
    # doc-c (3/3 python 重疊 100% + keyword 重疊) → 會推薦
    # 實際行為：python 完全不在 react 文件中，doc-c 也不會有 keyword "middleware" 共用
    # 讓我們反過來測：new doc 是 react 風，doc-c 完全不相關
    cat > new-doc.json <<EOF
{
  "tags": ["react", "ssr"],
  "keywords": ["hydration"]
}
EOF
    run "$CROSS_REF" _index.json new-doc.json
    [ "$status" -eq 0 ]
    ! [[ "$output" =~ "doc-c" ]]
}

@test "cross-ref: tag 重疊 100% 但 keyword 無重疊 → 不推薦" {
    cat > new-doc.json <<EOF
{
  "tags": ["react", "ssr"],
  "keywords": ["routing", "app-router"]
}
EOF
    run "$CROSS_REF" _index.json new-doc.json
    [ "$status" -eq 0 ]
    # doc-b tag 重疊 100% (react, ssr) 但 keywords 完全一樣 = 重疊 2 個會推薦
    # 改測：tag 重疊 100%，keywords 完全無交集
    cat > new-doc.json <<EOF
{
  "tags": ["react", "ssr"],
  "keywords": ["completely-different", "no-overlap"]
}
EOF
    run "$CROSS_REF" _index.json new-doc.json
    [ "$status" -eq 0 ]
    # doc-a (react/ssr 但 keywords streaming/hydration/bundle-size) → 無重疊
    ! [[ "$output" =~ "doc-a" ]]
    # doc-b (react/ssr 但 keywords routing/app-router) → 無重疊
    ! [[ "$output" =~ "doc-b" ]]
}

@test "cross-ref: tag 重疊 50% + keyword 重疊 → 推薦" {
    # new doc: react, ssr, performance (3 tags)
    # doc-d: react, performance (2 tags) → 重疊 2/3 = 67% ≥ 50% ✓
    # doc-d keywords: streaming, ssr → 與 new doc 完全相同 → 推薦
    cat > new-doc.json <<EOF
{
  "tags": ["react", "ssr", "performance"],
  "keywords": ["streaming", "ssr"]
}
EOF
    run "$CROSS_REF" _index.json new-doc.json
    [ "$status" -eq 0 ]
    [[ "$output" =~ "doc-d" ]]
}

@test "cross-ref: tag 重疊 33% (< 50%) → 不推薦" {
    # new doc: react, ssr, performance, rendering, state (5 tags)
    # doc-d: react, performance → 重疊 2/5 = 40% < 50% ✗
    cat > new-doc.json <<EOF
{
  "tags": ["react", "ssr", "performance", "rendering", "state"],
  "keywords": ["streaming", "hydration", "bundle-size", "ssr", "routing"]
}
EOF
    run "$CROSS_REF" _index.json new-doc.json
    [ "$status" -eq 0 ]
    # doc-d tag 重疊不足，但 keywords 重疊多 → 仍不推薦（因為 tag 重疊 < 50%）
    # 這個 case 設計驗證 tag 門檻是硬規則
    ! [[ "$output" =~ "doc-d" ]]
}

@test "cross-ref: 最多推薦 5 篇" {
    # 建 8 個全 tag 重疊 + 全 keyword 重疊的文件
    cat > _index.json <<EOF
{
  "version": 1,
  "documents": [
    {"id": "d1", "tags": ["a", "b"], "keywords": ["x"]},
    {"id": "d2", "tags": ["a", "b"], "keywords": ["x"]},
    {"id": "d3", "tags": ["a", "b"], "keywords": ["x"]},
    {"id": "d4", "tags": ["a", "b"], "keywords": ["x"]},
    {"id": "d5", "tags": ["a", "b"], "keywords": ["x"]},
    {"id": "d6", "tags": ["a", "b"], "keywords": ["x"]},
    {"id": "d7", "tags": ["a", "b"], "keywords": ["x"]},
    {"id": "d8", "tags": ["a", "b"], "keywords": ["x"]}
  ]
}
EOF
    cat > new-doc.json <<EOF
{
  "tags": ["a", "b"],
  "keywords": ["x"]
}
EOF
    run "$CROSS_REF" _index.json new-doc.json
    [ "$status" -eq 0 ]
    # 計算 output 中出現 d[1-8] 的數量
    count=$(echo "$output" | grep -oE "d[1-8]" | sort -u | wc -l | tr -d ' ')
    [ "$count" -le 5 ]
}

@test "cross-ref: --help 顯示說明" {
    run "$CROSS_REF" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

# === 邊緣案例（E5-E7） ===

@test "E5 cross-ref: new-doc.tags=[] 應回 0 推薦" {
    cat > new-doc.json <<EOF
{
  "tags": [],
  "keywords": ["streaming"]
}
EOF
    run "$CROSS_REF" _index.json new-doc.json
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "E6 cross-ref: self-match 排除（新 doc 已在 _index.json 中）" {
    # new-doc 是 _index.json 中的 doc-a 本身
    cat > new-doc.json <<EOF
{
  "id": "doc-a",
  "tags": ["react", "ssr", "performance"],
  "keywords": ["streaming", "hydration", "bundle-size"]
}
EOF
    run "$CROSS_REF" _index.json new-doc.json
    [ "$status" -eq 0 ]
    # doc-a 是自己，不該被推薦
    ! [[ "$output" =~ "doc-a" ]]
}

@test "E7 cross-ref: tie 排序 deterministic（同分 doc 依 id 順序）" {
    # 建立 3 個全 tag 重疊 + 全 keyword 重疊的文件，同分
    cat > _index.json <<EOF
{
  "version": 1,
  "documents": [
    {"id": "doc-z", "tags": ["a", "b"], "keywords": ["x"]},
    {"id": "doc-a", "tags": ["a", "b"], "keywords": ["x"]},
    {"id": "doc-m", "tags": ["a", "b"], "keywords": ["x"]}
  ]
}
EOF
    cat > new-doc.json <<EOF
{
  "tags": ["a", "b"],
  "keywords": ["x"]
}
EOF
    run "$CROSS_REF" _index.json new-doc.json
    [ "$status" -eq 0 ]
    # 順序應為 doc-a → doc-m → doc-z（字母順序）
    first=$(echo "$output" | head -1)
    [ "$first" = "doc-a" ]
}