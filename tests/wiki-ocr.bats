#!/usr/bin/env bats
#
# tests/wiki-ocr.bats
#
# Black-box tests for tools/wiki-ocr.sh
# Sprint 09: dav-wiki OCR 補強 (FR-2.2.3)
#
# Coverage:
#   AC-O1: tesseract 直接 OCR 一張 PNG（mock fallback）
#   AC-O2: --input-dir 批次 OCR
#   AC-O3: 沒裝 tesseract → 警告 + 用 Vision mock 降級
#   AC-O4: 不存在的輸入 → 錯誤
#   AC-O5: --help
#   AC-O6: 沒給 --input
#   AC-O7: 輸出 JSON 含 text / confidence / source
#   AC-O8: --language eng / chi_tra
#   AC-O9: manifest.json 產出
#   AC-O10: 對純白圖（無文字）不報錯
#
# Usage:
#   bats tests/wiki-ocr.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TOOL="$REPO_ROOT/tools/wiki-ocr.sh"
  WORK="$(mktemp -d -t wiki-ocr-test-XXXXXX)"
  export WORK
  # 預設 mock 模式
  export DAV_WIKI_MOCK=1
}

teardown() {
  rm -rf "$WORK"
}

# === AC-O1: tesseract OCR 一張 PNG ===
@test "AC-O1: tesseract OCR 一張 PNG（mock 降級時也能跑）" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/ocr.json"
  [ "$status" -eq 0 ]
  [ -f "$WORK/ocr.json" ]
  grep -q '"text"' "$WORK/ocr.json"
}

# === AC-O2: --input-dir 批次 OCR ===
@test "AC-O2: --input-dir 批次 OCR" {
  mkdir -p "$WORK/batch"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch/"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/blue.png" "$WORK/batch/"
  run "$TOOL" --input-dir "$WORK/batch" --output-dir "$WORK/out"
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/red.ocr.json" ] || [ -f "$WORK/out/blue.ocr.json" ]
}

# === AC-O3: 沒裝 tesseract → mock 降級（不崩潰）===
@test "AC-O3: 沒裝 tesseract → mock 降級，不崩潰" {
  # 我們不真的移除 tesseract，而是測試 --force-mock 旗標
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/ocr.json" \
              --force-mock
  [ "$status" -eq 0 ]
  [ -f "$WORK/ocr.json" ]
  grep -q '"engine"' "$WORK/ocr.json"
  grep -q '"mock"' "$WORK/ocr.json"
}

# === AC-O4: 不存在的輸入 ===
@test "AC-O4: 不存在的輸入 → exit 2" {
  run "$TOOL" --input "/nonexistent/foo.png" --output-json "$WORK/ocr.json"
  [ "$status" -ne 0 ]
}

# === AC-O5: --help ===
@test "AC-O5: --help 顯示使用說明" {
  run "$TOOL" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage" ]]
}

# === AC-O6: 沒給 --input ===
@test "AC-O6: 沒給 --input → exit 1" {
  run "$TOOL" --output-json "$WORK/ocr.json"
  [ "$status" -ne 0 ]
}

# === AC-O7: 輸出 JSON 結構 ===
@test "AC-O7: 輸出 JSON 含 text / confidence / source / engine" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/ocr.json" \
              --force-mock
  [ "$status" -eq 0 ]
  grep -q '"text"' "$WORK/ocr.json"
  grep -q '"confidence"' "$WORK/ocr.json"
  grep -q '"source"' "$WORK/ocr.json"
  grep -q '"engine"' "$WORK/ocr.json"
}

# === AC-O8: --language 旗標 ===
@test "AC-O8: --language eng / chi_tra 被接受" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/ocr.json" \
              --force-mock \
              --language chi_tra
  [ "$status" -eq 0 ]
  grep -q '"language"' "$WORK/ocr.json"
  grep -q '"chi_tra"' "$WORK/ocr.json"
}

# === AC-O9: manifest.json（批次模式）===
@test "AC-O9: 批次模式產出 manifest.json" {
  mkdir -p "$WORK/batch"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch/"
  run "$TOOL" --input-dir "$WORK/batch" --output-dir "$WORK/out" --force-mock
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/manifest.json" ]
  grep -q '"count"' "$WORK/out/manifest.json"
}

# === AC-O10: 對純白圖（無文字）不報錯 ===
@test "AC-O10: 純白圖（無文字）不報錯" {
  # 用 ffmpeg 生一張純白 PNG
  ffmpeg -f lavfi -i "color=white:size=320x240:duration=0.04" \
         -frames:v 1 "$WORK/white.png" -y 2>/dev/null
  [ -f "$WORK/white.png" ]
  run "$TOOL" --input "$WORK/white.png" \
              --output-json "$WORK/ocr.json" \
              --force-mock
  [ "$status" -eq 0 ]
  [ -f "$WORK/ocr.json" ]
}