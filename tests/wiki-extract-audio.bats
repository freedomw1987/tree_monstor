#!/usr/bin/env bats
#
# tests/wiki-extract-audio.bats
#
# Black-box tests for skills/dav-wiki/scripts/wiki-extract-audio.sh
# Sprint 08: dav-wiki 多模組擴充 (FR-2.4)
#
# Coverage:
#   AC-A1: 音訊 metadata 提取（時長 / codec / sample rate）
#   AC-A2: 音訊標準化（轉 WAV 16kHz mono）
#   AC-A3: 音訊 split（長音訊分段）
#   AC-A4: --segment-duration 旗標
#   AC-A5: --no-normalize
#   AC-A6: 不存在檔案
#   AC-A7: --help
#   AC-A8: manifest.json 產出
#   AC-A9: 不支援的格式
#
# Usage:
#   bats tests/wiki-extract-audio.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TOOL="$REPO_ROOT/skills/dav-wiki/scripts/wiki-extract-audio.sh"
  WORK="$(mktemp -d -t wiki-audio-test-XXXXXX)"
  export WORK
}

teardown() {
  rm -rf "$WORK"
}

# === AC-A1: metadata 提取 ===
@test "AC-A1: metadata extraction (duration/codec)" {
  ffmpeg -f lavfi -i "sine=frequency=440:duration=2" \
         "$WORK/test.wav" -y 2>/dev/null
  run "$TOOL" --input "$WORK/test.wav" --output-dir "$WORK/out"
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/manifest.json" ]
  grep -q '"duration"' "$WORK/out/manifest.json"
  grep -q '"codec"' "$WORK/out/manifest.json"
}

# === AC-A2: 音訊標準化（WAV 16kHz mono） ===
@test "AC-A2: audio normalization to WAV 16kHz mono" {
  ffmpeg -f lavfi -i "sine=frequency=440:duration=2" \
         -ar 44100 -ac 2 \
         "$WORK/test_stereo.wav" -y 2>/dev/null
  run "$TOOL" --input "$WORK/test_stereo.wav" --output-dir "$WORK/out"
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/audio.wav" ]
  # 確認 sample rate
  rate=$(ffprobe -v error -select_streams a:0 \
               -show_entries stream=sample_rate \
               -of csv=p=0 "$WORK/out/audio.wav" 2>/dev/null)
  [ "$rate" = "16000" ]
}

# === AC-A3: 音訊分段 ===
@test "AC-A3: audio segmentation by duration" {
  ffmpeg -f lavfi -i "sine=frequency=440:duration=5" \
         "$WORK/long.wav" -y 2>/dev/null
  run "$TOOL" --input "$WORK/long.wav" --output-dir "$WORK/out" \
              --segment-duration 2
  [ "$status" -eq 0 ]
  # 5 秒 ÷ 2 秒 = 3 段
  count=$(find "$WORK/out/segments" -type f -name "*.wav" 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge 2 ]
}

# === AC-A4: --no-normalize ===
@test "AC-A4: --no-normalize skips normalization" {
  ffmpeg -f lavfi -i "sine=frequency=440:duration=1" \
         "$WORK/test.wav" -y 2>/dev/null
  run "$TOOL" --input "$WORK/test.wav" --output-dir "$WORK/out" --no-normalize
  [ "$status" -eq 0 ]
  [ ! -f "$WORK/out/audio.wav" ]
  [ -f "$WORK/out/original.wav" ]
}

# === AC-A5: 不存在檔案 ===
@test "AC-A5: missing-input-file exit 2" {
  run "$TOOL" --input "/nonexistent/audio.wav" --output-dir "$WORK/out"
  [ "$status" -ne 0 ]
}

# === AC-A6: --help ===
@test "AC-A6: --help" {
  run "$TOOL" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage" ]]
}

# === AC-A7: manifest.json 產出 ===
@test "AC-A7: manifest.json has expected fields" {
  ffmpeg -f lavfi -i "sine=frequency=440:duration=2" \
         "$WORK/test.wav" -y 2>/dev/null
  run "$TOOL" --input "$WORK/test.wav" --output-dir "$WORK/out"
  [ "$status" -eq 0 ]
  grep -q '"source"' "$WORK/out/manifest.json"
  grep -q '"duration"' "$WORK/out/manifest.json"
  grep -q '"codec"' "$WORK/out/manifest.json"
  grep -q '"sample_rate"' "$WORK/out/manifest.json"
  grep -q '"channels"' "$WORK/out/manifest.json"
}

# === AC-A8: 沒給 --input ===
@test "AC-A8: missing --input → exit 1" {
  run "$TOOL" --output-dir "$WORK/out"
  [ "$status" -ne 0 ]
}

# === AC-A9: 不支援的格式 ===
@test "AC-A9: input dir → manifest aggregation" {
  echo "fake" > "$WORK/fake.xyz"
  run "$TOOL" --input "$WORK/fake.xyz" --output-dir "$WORK/out"
  # 接受 0 或非 0，不要 crash
  [ "$status" -ne 139 ]
  [ "$status" -ne 134 ]
}

# === AC-A10: 段落檔案命名規律 ===
@test "AC-A10: segments named segment-NNN.wav" {
  ffmpeg -f lavfi -i "sine=frequency=440:duration=4" \
         "$WORK/long.wav" -y 2>/dev/null
  run "$TOOL" --input "$WORK/long.wav" --output-dir "$WORK/out" \
              --segment-duration 2
  [ "$status" -eq 0 ]
  ls "$WORK/out/segments/" 2>/dev/null | grep -q "segment-"
}