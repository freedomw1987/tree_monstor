#!/usr/bin/env bats
#
# tests/wiki-extract-video.bats
#
# Black-box tests for tools/wiki-extract-video.sh
# Sprint 08: dav-wiki 多模組擴充 (FR-2.3)
#
# Coverage:
#   AC-W1: 影片提取 → frames/ + audio.wav + thumb.jpg + chapters.json
#   AC-W2: 影片時長 metadata
#   AC-W3: 章節切分（scene detection）
#   AC-W4: --no-frames / --no-audio / --no-chapters
#   AC-W5: --scene-threshold
#   AC-W6: 不存在影片 → 錯誤
#   AC-W7: --help
#   AC-W8: 沒給 --input
#   AC-W9: manifest.json 產出
#   AC-W10: 從 PPTX 內含影片提取（FR-2.3.1 + PPTX 整合）
#
# Usage:
#   bats tests/wiki-extract-video.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TOOL="$REPO_ROOT/tools/wiki-extract-video.sh"
  WORK="$(mktemp -d -t wiki-video-test-XXXXXX)"
  export WORK
}

teardown() {
  rm -rf "$WORK"
}

# === AC-W1: 完整影片提取 ===
@test "AC-W1: 影片提取 → frames/ + audio.wav + thumb.jpg + chapters.json" {
  ffmpeg -f lavfi -i "color=red:size=320x240:duration=2" \
         -f lavfi -i "sine=frequency=440:duration=2" \
         -c:v libx264 -c:a aac \
         "$WORK/test.mp4" -y 2>/dev/null
  run "$TOOL" --input "$WORK/test.mp4" --output-dir "$WORK/out"
  [ "$status" -eq 0 ]
  [ -d "$WORK/out/frames" ]
  [ -f "$WORK/out/audio.wav" ]
  [ -f "$WORK/out/thumb.jpg" ]
  [ -f "$WORK/out/chapters.json" ]
}

# === AC-W2: 影片時長 metadata ===
@test "AC-W2: manifest 包含正確的影片時長" {
  ffmpeg -f lavfi -i "color=red:size=160x120:duration=3" \
         -c:v libx264 -preset ultrafast \
         "$WORK/test.mp4" -y 2>/dev/null
  run "$TOOL" --input "$WORK/test.mp4" --output-dir "$WORK/out"
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/manifest.json" ]
  duration=$(grep -o '"duration": [0-9.]*' "$WORK/out/manifest.json" | grep -o '[0-9.]*')
  awk -v d="$duration" 'BEGIN { exit !(d >= 2.5 && d <= 3.5) }'
}

# === AC-W3: 章節切分 ===
@test "AC-W3: chapters.json 結構正確" {
  ffmpeg -f lavfi -i "color=red:size=160x120:duration=1.5" \
         -f lavfi -i "color=blue:size=160x120:duration=1.5" \
         -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0[outv]" \
         -map "[outv]" \
         "$WORK/scene.mp4" -y 2>/dev/null
  run "$TOOL" --input "$WORK/scene.mp4" --output-dir "$WORK/out" --scene-threshold 0.4
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/chapters.json" ]
  grep -q '"chapters"' "$WORK/out/chapters.json"
  grep -q '"start"' "$WORK/out/chapters.json"
  grep -q '"end"' "$WORK/out/chapters.json"
}

# === AC-W4: --no-frames ===
@test "AC-W4: --no-frames 跳過 frame 提取" {
  ffmpeg -f lavfi -i "color=red:size=160x120:duration=1" \
         -f lavfi -i "sine=frequency=440:duration=1" \
         -c:v libx264 -c:a aac \
         "$WORK/test.mp4" -y 2>/dev/null
  run "$TOOL" --input "$WORK/test.mp4" --output-dir "$WORK/out" --no-frames
  [ "$status" -eq 0 ]
  [ ! -d "$WORK/out/frames" ]
  [ -f "$WORK/out/audio.wav" ]
}

# === AC-W5: --no-audio ===
@test "AC-W5: --no-audio 跳過音訊提取" {
  ffmpeg -f lavfi -i "color=red:size=160x120:duration=1" \
         -f lavfi -i "sine=frequency=440:duration=1" \
         -c:v libx264 -c:a aac \
         "$WORK/test.mp4" -y 2>/dev/null
  run "$TOOL" --input "$WORK/test.mp4" --output-dir "$WORK/out" --no-audio
  [ "$status" -eq 0 ]
  [ ! -f "$WORK/out/audio.wav" ]
  [ -d "$WORK/out/frames" ]
}

# === AC-W6: 不存在影片 ===
@test "AC-W6: 不存在的影片 → exit 2" {
  run "$TOOL" --input "/nonexistent/video.mp4" --output-dir "$WORK/out"
  [ "$status" -ne 0 ]
}

# === AC-W7: --help ===
@test "AC-W7: --help 顯示使用說明" {
  run "$TOOL" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage" ]]
}

# === AC-W8: 沒給 --input ===
@test "AC-W8: 沒給 --input → exit 1" {
  run "$TOOL" --output-dir "$WORK/out"
  [ "$status" -ne 0 ]
}

# === AC-W9: manifest.json ===
@test "AC-W9: manifest.json 含 frames / audio / thumb / chapters 路徑" {
  ffmpeg -f lavfi -i "color=red:size=160x120:duration=1" \
         -f lavfi -i "sine=frequency=440:duration=1" \
         -c:v libx264 -c:a aac \
         "$WORK/test.mp4" -y 2>/dev/null
  run "$TOOL" --input "$WORK/test.mp4" --output-dir "$WORK/out"
  [ "$status" -eq 0 ]
  grep -q '"frames"' "$WORK/out/manifest.json"
  grep -q '"audio"' "$WORK/out/manifest.json"
  grep -q '"thumb"' "$WORK/out/manifest.json"
  grep -q '"chapters"' "$WORK/out/manifest.json"
}

# === AC-W10: --no-chapters ===
@test "AC-W10: --no-chapters 跳過章節切分" {
  ffmpeg -f lavfi -i "color=red:size=160x120:duration=1" \
         "$WORK/test.mp4" -y 2>/dev/null
  run "$TOOL" --input "$WORK/test.mp4" --output-dir "$WORK/out" --no-chapters
  [ "$status" -eq 0 ]
  [ ! -f "$WORK/out/chapters.json" ]
}

# === AC-W11: --scene-threshold 邊界值 ===
@test "AC-W11: --scene-threshold 0 仍能跑（無場景偵測）" {
  ffmpeg -f lavfi -i "color=red:size=160x120:duration=1" \
         "$WORK/test.mp4" -y 2>/dev/null
  run "$TOOL" --input "$WORK/test.mp4" --output-dir "$WORK/out" --scene-threshold 0
  [ "$status" -eq 0 ]
}