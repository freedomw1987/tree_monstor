#!/usr/bin/env bats
#
# tests/wiki-cross-ref-multimodal.bats
#
# Black-box tests for FR-2.5.1 / FR-2.5.2:
# - _index.json 加多模組索引
# - 交叉引用演算法支援多模組比對
#
# Coverage:
#   AC-MR1: index 工具產出含 images / videos / audio 索引
#   AC-MR2: index 從 wiki frontmatter 讀 images / videos / audios
#   AC-MR3: --input 單個 wiki 屬性
#   AC-MR4: --input-dir 批次掃描整個 docs/wiki/
#   AC-MR5: cross-ref 工具對多模組屬性產生交叉引用
#   AC-MR6: 標記 image / video / audio 為相關
#   AC-MR7: --help
#   AC-MR8: 不存在的輸入 → 錯誤
#   AC-MR9: 不破壞既有 frontmatter
#   AC-MR10: 沒給 --input
#
# Usage:
#   bats tests/wiki-cross-ref-multimodal.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  WORK="$(mktemp -d -t wiki-xref-mm-test-XXXXXX)"
  export WORK

  # 模擬 docs/wiki/ 結構
  mkdir -p "$WORK/docs/wiki/frontend/2026-01"
  mkdir -p "$WORK/docs/concepts"

  cat > "$WORK/docs/wiki/_index.json" <<'EOF'
{
  "version": 1,
  "documents": []
}
EOF

  cat > "$WORK/docs/wiki/frontend/2026-01/doc-a.md" <<'EOF'
---
title: 文檔 A
tags:
  - react
  - hooks
images:
  - source: /assets/a.png
    caption: red square
videos:
  - source: /assets/a.mp4
    duration: 30
audios:
  - source: /assets/a.wav
    duration: 60
---

# 文檔 A
EOF

  cat > "$WORK/docs/wiki/frontend/2026-01/doc-b.md" <<'EOF'
---
title: 文檔 B
tags:
  - react
  - components
images:
  - source: /assets/b.png
    caption: blue square
---

# 文檔 B
EOF

  cat > "$WORK/docs/wiki/frontend/2026-01/doc-c.md" <<'EOF'
---
title: 文檔 C
tags:
  - vue
images:
  - source: /assets/c.png
    caption: green
---

# 文檔 C
EOF
}

teardown() {
  rm -rf "$WORK"
}

# === AC-MR1: index 工具產出含多模組索引 ===
@test "AC-MR1: _index.json 加 images / videos / audios 索引" {
  cd "$WORK/docs/wiki"
  run "$REPO_ROOT/tools/wiki-index.sh" --input-dir .
  [ "$status" -eq 0 ]

  # _index.json 應含多模組索引欄位
  [ -f _index.json ]
  grep -q '"images"' _index.json
  grep -q '"videos"' _index.json
  grep -q '"audios"' _index.json
}

# === AC-MR2: index 從 frontmatter 讀多模組 ===
@test "AC-MR2: index 從 frontmatter 讀多模組" {
  cd "$WORK/docs/wiki"
  run "$REPO_ROOT/tools/wiki-index.sh" --input-dir .
  [ "$status" -eq 0 ]

  # doc-a 含圖 → images 索引應有 a.png
  grep -q "a.png" _index.json
  # doc-a 含影片 → videos 索引應有 a.mp4
  grep -q "a.mp4" _index.json
  # doc-a 含音訊 → audios 索引應有 a.wav
  grep -q "a.wav" _index.json
}

# === AC-MR3: --input 單個屬性 ===
@test "AC-MR3: --input 單個 wiki 屬性也能產索引" {
  cd "$WORK"
  run "$REPO_ROOT/tools/wiki-index.sh" --input "$WORK/docs/wiki/frontend/2026-01/doc-a.md"
  [ "$status" -eq 0 ]
  [ -f "$WORK/doc-a.index.json" ]
  grep -q "a.png" "$WORK/doc-a.index.json"
}

# === AC-MR4: --input-dir 批次 ===
@test "AC-MR4: --input-dir 批次掃描整個目錄" {
  cd "$WORK/docs/wiki"
  run "$REPO_ROOT/tools/wiki-index.sh" --input-dir .
  [ "$status" -eq 0 ]
  # 三個 doc 都應在 index
  grep -q "doc-a" _index.json
  grep -q "doc-b" _index.json
  grep -q "doc-c" _index.json
}

# === AC-MR5: cross-ref 工具對多模組屬性產生交叉引用 ===
@test "AC-MR5: cross-ref 對多模組屬性產生交叉引用" {
  cd "$WORK/docs/wiki"
  "$REPO_ROOT/tools/wiki-index.sh" --input-dir . >/dev/null 2>&1

  # 應讀 doc-a.md 的 frontmatter + index，產生 recommendations
  run "$REPO_ROOT/tools/wiki-cross-ref.sh" --input "$WORK/docs/wiki/frontend/2026-01/doc-a.md"
  [ "$status" -eq 0 ]

  # 輸出應為 JSON，含 recommendations 列表
  [ -f "$WORK/docs/wiki/frontend/2026-01/doc-a.recommendations.json" ]
  grep -q '"recommendations"' "$WORK/docs/wiki/frontend/2026-01/doc-a.recommendations.json"
}

# === AC-MR6: 標記 image / video / audio 為相關 ===
@test "AC-MR6: 多模組比對：含相同 image 來源的 doc 被標為相關" {
  # 兩個 doc 共用同一個 image source
  cat > "$WORK/docs/wiki/frontend/2026-01/doc-d.md" <<'EOF'
---
title: 文檔 D
tags:
  - misc
images:
  - source: /assets/shared.png
    caption: shared image
---

# 文檔 D
EOF

  cat > "$WORK/docs/wiki/frontend/2026-01/doc-e.md" <<'EOF'
---
title: 文檔 E
tags:
  - misc
images:
  - source: /assets/shared.png
    caption: same shared image
---

# 文檔 E
EOF

  cd "$WORK/docs/wiki"
  "$REPO_ROOT/tools/wiki-index.sh" --input-dir . >/dev/null 2>&1

  run "$REPO_ROOT/tools/wiki-cross-ref.sh" --input "$WORK/docs/wiki/frontend/2026-01/doc-d.md"
  [ "$status" -eq 0 ]

  # doc-e 應在 doc-d 的 recommendations（共用 shared.png）
  [ -f "$WORK/docs/wiki/frontend/2026-01/doc-d.recommendations.json" ]
  grep -q "doc-e" "$WORK/docs/wiki/frontend/2026-01/doc-d.recommendations.json"
}

# === AC-MR7: --help ===
@test "AC-MR7: --help 顯示使用說明" {
  run "$REPO_ROOT/tools/wiki-index.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage" ]]
}

# === AC-MR8: 不存在的輸入 → 錯誤 ===
@test "AC-MR8: 不存在的輸入 → exit 2" {
  run "$REPO_ROOT/tools/wiki-index.sh" --input "/nonexistent/wiki.md"
  [ "$status" -ne 0 ]
}

# === AC-MR9: 不破壞既有 frontmatter ===
@test "AC-MR9: index 工具不修改源 wiki 屬性" {
  cd "$WORK/docs/wiki"
  before=$(shasum frontend/2026-01/doc-a.md | awk '{print $1}')
  "$REPO_ROOT/tools/wiki-index.sh" --input-dir . >/dev/null 2>&1
  after=$(shasum frontend/2026-01/doc-a.md | awk '{print $1}')
  [ "$before" = "$after" ]
}

# === AC-MR10: 沒給 --input ===
@test "AC-MR10: 沒給 --input 或 --input-dir → exit 1" {
  run "$REPO_ROOT/tools/wiki-index.sh"
  [ "$status" -ne 0 ]
}