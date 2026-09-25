#!/usr/bin/env bats
#
# tests/wiki-merge-media.bats
#
# Black-box tests for skills/dav-wiki/scripts/wiki-merge-media.sh
# Sprint 08: dav-wiki 多模組擴充 (FR-2.2.4 + FR-2.5.1)
#
# Coverage:
#   AC-M1: 把 media manifest 合併進 wiki frontmatter
#   AC-M2: 圖片加入 images 陣列
#   AC-M3: 影片加入 videos 陣列
#   AC-M4: 音訊加入 audio 陣列
#   AC-M5: 不破壞既有 frontmatter 欄位
#   AC-M6: 不破壞既有 markdown 內容
#   AC-M7: --dry-run
#   AC-M8: 沒給 wiki 屬性
#   AC-M9: 不存在的 wiki 屬性
#   AC-M10: 沒給 media 屬性
#
# Usage:
#   bats tests/wiki-merge-media.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TOOL="$REPO_ROOT/skills/dav-wiki/scripts/wiki-merge-media.sh"
  WORK="$(mktemp -d -t wiki-merge-test-XXXXXX)"
  export WORK
}

teardown() {
  rm -rf "$WORK"
}

# 建立範例 wiki 屬性
create_wiki() {
  cat > "$WORK/wiki.md" <<'EOF'
---
title: 測試文件
tags:
  - test
  - dav-wiki
date: 2026-01-15
---

# 測試文件

這是測試內容。
EOF
}

# === AC-M1: 合併 media 進 frontmatter ===
@test "AC-M1: merge images manifest into frontmatter" {
  create_wiki

  cat > "$WORK/media.json" <<'EOF'
{
  "type": "image",
  "source": "/path/to/red.png",
  "caption": "紅色方塊",
  "alt_text": "red square"
}
EOF

  run "$TOOL" --wiki "$WORK/wiki.md" --media "$WORK/media.json" --media-type image
  [ "$status" -eq 0 ]

  # 確認 frontmatter 有 images 欄位
  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "images:"
}

# === AC-M2: 圖片加入 images 陣列 ===
@test "AC-M2: images caption / alt_text / source" {
  create_wiki

  cat > "$WORK/media.json" <<'EOF'
{
  "type": "image",
  "source": "/path/to/red.png",
  "caption": "紅色方塊",
  "alt_text": "red square"
}
EOF

  run "$TOOL" --wiki "$WORK/wiki.md" --media "$WORK/media.json" --media-type image
  [ "$status" -eq 0 ]

  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "caption:"
  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "alt_text:"
  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "red.png"
}

# === AC-M3: 影片加入 videos 陣列 ===
@test "AC-M3: manifest adds videos" {
  create_wiki

  cat > "$WORK/media.json" <<'EOF'
{
  "type": "video",
  "source": "/path/to/clip.mp4",
  "duration": 30.5,
  "thumb": "/path/to/thumb.jpg"
}
EOF

  run "$TOOL" --wiki "$WORK/wiki.md" --media "$WORK/media.json" --media-type video
  [ "$status" -eq 0 ]

  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "videos:"
  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "duration: 30.5"
}

# === AC-M4: 音訊加入 audios 陣列 ===
@test "AC-M4: manifest adds audios" {
  create_wiki

  cat > "$WORK/media.json" <<'EOF'
{
  "type": "audio",
  "source": "/path/to/audio.wav",
  "duration": 120.0,
  "transcript": "Hello world"
}
EOF

  run "$TOOL" --wiki "$WORK/wiki.md" --media "$WORK/media.json" --media-type audio
  [ "$status" -eq 0 ]

  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "audios:"
  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "Hello world"
}

# === AC-M5: 不破壞既有欄位 ===
@test "AC-M5: frontmatter" {
  create_wiki

  cat > "$WORK/media.json" <<'EOF'
{
  "type": "image",
  "source": "/path/to/red.png",
  "caption": "紅色方塊"
}
EOF

  run "$TOOL" --wiki "$WORK/wiki.md" --media "$WORK/media.json" --media-type image
  [ "$status" -eq 0 ]

  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "title: 測試文件"
  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "tags:"
  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "date: 2026-01-15"
}

# === AC-M6: 不破壞 markdown 內容 ===
@test "AC-M6: markdown body" {
  create_wiki

  cat > "$WORK/media.json" <<'EOF'
{
  "type": "image",
  "source": "/path/to/red.png",
  "caption": "紅色方塊"
}
EOF

  run "$TOOL" --wiki "$WORK/wiki.md" --media "$WORK/media.json" --media-type image
  [ "$status" -eq 0 ]

  # 確認 body 內容還在
  grep -q "# 測試文件" "$WORK/wiki.md"
  grep -q "這是測試內容" "$WORK/wiki.md"
}

# === AC-M7: --dry-run ===
@test "AC-M7: --dry-run no changes" {
  create_wiki
  cp "$WORK/wiki.md" "$WORK/wiki.md.bak"

  cat > "$WORK/media.json" <<'EOF'
{
  "type": "image",
  "source": "/path/to/red.png",
  "caption": "紅色方塊"
}
EOF

  run "$TOOL" --wiki "$WORK/wiki.md" --media "$WORK/media.json" --media-type image --dry-run
  [ "$status" -eq 0 ]

  # wiki.md 應沒變
  diff "$WORK/wiki.md" "$WORK/wiki.md.bak"
}

# === AC-M8: 沒給 wiki ===
@test "AC-M8: missing --wiki → exit 1" {
  run "$TOOL" --media "$WORK/media.json" --media-type image
  [ "$status" -ne 0 ]
}

# === AC-M9: 不存在的 wiki ===
@test "AC-M9: nonexistent wiki → exit 2" {
  run "$TOOL" --wiki "/nonexistent/wiki.md" --media "$WORK/media.json" --media-type image
  [ "$status" -ne 0 ]
}

# === AC-M10: 沒給 media ===
@test "AC-M10: missing --media → exit 1" {
  create_wiki
  run "$TOOL" --wiki "$WORK/wiki.md" --media-type image
  [ "$status" -ne 0 ]
}

# === AC-M11: --help ===
@test "AC-M11: --help shows usage" {
  run "$TOOL" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage" ]]
}

# === AC-M12: 多個媒體依序合併 ===
@test "AC-M12: idempotent merge on re-run" {
  create_wiki

  # 第一次：圖片 1
  cat > "$WORK/media1.json" <<'EOF'
{
  "type": "image",
  "source": "/path/red.png",
  "caption": "red"
}
EOF
  run "$TOOL" --wiki "$WORK/wiki.md" --media "$WORK/media1.json" --media-type image
  [ "$status" -eq 0 ]

  # 第二次：圖片 2
  cat > "$WORK/media2.json" <<'EOF'
{
  "type": "image",
  "source": "/path/blue.png",
  "caption": "blue"
}
EOF
  run "$TOOL" --wiki "$WORK/wiki.md" --media "$WORK/media2.json" --media-type image
  [ "$status" -eq 0 ]

  # 兩個 caption 都應存在
  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "red"
  awk '/^---$/{c++; next} c==2{exit} c==1' "$WORK/wiki.md" | grep -q "blue"
}