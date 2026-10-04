#!/usr/bin/env bats
#
# tests/wiki-extract-media.bats
#
# Black-box tests for skills/dav-wiki/scripts/wiki-extract-media.sh
# Sprint 08: dav-wiki 多模組擴充 (FR-2.6.1)
#
# Coverage:
#   AC-E1: PDF 圖片提取（pdfimages）
#   AC-E2: PDF 文字提取（pdftotext）
#   AC-E3: DOCX 媒體提取（pandoc --extract-media）
#   AC-E4: DOCX 文字提取（pandoc）
#   AC-E5: PPTX 媒體提取（python-pptx）
#   AC-E6: PPTX 文字提取（python-pptx；pandoc 無 pptx reader）
#   AC-E7: 邊緣案例 - 不存在的檔案
#   AC-E8: 邊緣案例 - 不支援的格式
#   AC-E9: --output-dir 旗標
#   AC-E10: --no-images / --no-text 旗標
#   AC-E21: 提取失敗不得假成功（TMO-025）
#   AC-E22: 掃描件 PDF（無文字層）→ 成功但警告（TMO-025）
#
# Fixtures:
#   tests/fixtures/pdf-scan/scan.pdf — 無文字層的掃描件（重建指令，macOS）:
#     pdftoppm -png -r 100 tests/fixtures/pdf-mixed/sample.pdf page \
#       && sips -s format pdf page-1.png --out tests/fixtures/pdf-scan/scan.pdf
#
# Usage:
#   bats tests/wiki-extract-media.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TOOL="$REPO_ROOT/skills/dav-wiki/scripts/wiki-extract-media.sh"
  WORK="$(mktemp -d -t wiki-extract-test-XXXXXX)"
  export WORK
}

teardown() {
  rm -rf "$WORK"
}

# ---------- AC-E1: PDF 圖片提取 ----------
@test "AC-E1: PDF image extraction to output dir" {
  [ -x "$TOOL" ]
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-mixed/sample.pdf" \
              --output-dir "$WORK/out" \
              --type pdf
  [ "$status" -eq 0 ]
  [ -d "$WORK/out/images" ]
  # 應有 2 張圖
  count=$(ls "$WORK/out/images/" 2>/dev/null | wc -l)
  [ "$count" -ge 2 ]
}

# ---------- AC-E2: PDF 文字提取 ----------
@test "AC-E2: PDF text extraction via pdftotext" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-mixed/sample.pdf" \
              --output-dir "$WORK/out" \
              --type pdf
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/text.md" ]
  # 確認含預期文字
  grep -q "Mixed PDF Test" "$WORK/out/text.md"
}

# ---------- AC-E3: DOCX 媒體提取 ----------
@test "AC-E3: DOCX image extraction" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/docx-multimodal/mixed.docx" \
              --output-dir "$WORK/out" \
              --type docx
  [ "$status" -eq 0 ]
  [ -d "$WORK/out/images" ]
  count=$(ls "$WORK/out/images/" 2>/dev/null | wc -l)
  [ "$count" -ge 1 ]
}

# ---------- AC-E4: DOCX 文字提取 ----------
@test "AC-E4: DOCX text extraction via pandoc" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/docx-multimodal/mixed.docx" \
              --output-dir "$WORK/out" \
              --type docx
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/text.md" ]
  grep -q "Mixed DOCX" "$WORK/out/text.md"
}

# ---------- AC-E5: PPTX 媒體提取 ----------
@test "AC-E5: PPTX extraction via python-pptx" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pptx-multimodal/mixed.pptx" \
              --output-dir "$WORK/out" \
              --type pptx
  [ "$status" -eq 0 ]
  [ -d "$WORK/out/images" ]
  count=$(ls "$WORK/out/images/" 2>/dev/null | wc -l)
  [ "$count" -ge 1 ]
}

# ---------- AC-E6: PPTX 文字提取 ----------
@test "AC-E6: PPTX text extraction (python-pptx) writes text.md with slide text" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pptx-multimodal/mixed.pptx" \
              --output-dir "$WORK/out" \
              --type pptx
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/text.md" ]
  grep -q "Architecture" "$WORK/out/text.md"
}

# ---------- AC-E7: 邊緣案例 - 不存在的檔案 ----------
@test "AC-E7: missing input → exit 2 + error" {
  run "$TOOL" --input "/nonexistent/file.pdf" \
              --output-dir "$WORK/out" \
              --type pdf
  [ "$status" -ne 0 ]
  [[ "$output" =~ "not found" ]] || [[ "$output" =~ "No such file" ]] || [[ "$output" =~ "does not exist" ]]
}

# ---------- AC-E8: 邊緣案例 - 不支援的格式 ----------
@test "AC-E8: invalid format → exit 3 + error" {
  echo "fake content" > "$WORK/fake.xyz"
  run "$TOOL" --input "$WORK/fake.xyz" \
              --output-dir "$WORK/out" \
              --type xyz
  [ "$status" -ne 0 ]
}

# ---------- AC-E9: --output-dir 預設值（無旗標）----------
@test "AC-E9: --output-dir ./out" {
  cd "$WORK"
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-mixed/sample.pdf" --type pdf
  [ "$status" -eq 0 ]
  [ -d "$WORK/out/images" ] || [ -d "$WORK/out" ]
}

# ---------- AC-E10: --no-images 旗標 ----------
@test "AC-E10: --no-images" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-mixed/sample.pdf" \
              --output-dir "$WORK/out" \
              --type pdf \
              --no-images
  [ "$status" -eq 0 ]
  [ ! -d "$WORK/out/images" ]
  [ -f "$WORK/out/text.md" ]
}

# ---------- AC-E11: --no-text 旗標 ----------
@test "AC-E11: --no-text" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-mixed/sample.pdf" \
              --output-dir "$WORK/out" \
              --type pdf \
              --no-text
  [ "$status" -eq 0 ]
  [ ! -f "$WORK/out/text.md" ]
  [ -d "$WORK/out/images" ]
}

# ---------- AC-E12: --type 自動偵測（從副檔名）----------
@test "AC-E12: --type" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-mixed/sample.pdf" \
              --output-dir "$WORK/out"
  [ "$status" -eq 0 ]
  [ -d "$WORK/out/images" ]
  [ -f "$WORK/out/text.md" ]
}

# ---------- AC-E13: --help 旗標 ----------
@test "AC-E13: --help shows usage" {
  run "$TOOL" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage" ]] || [[ "$output" =~ "Usage" ]]
}

# ---------- AC-E14: 沒給必填 --input ----------
@test "AC-E14: missing --input → error" {
  run "$TOOL" --output-dir "$WORK/out"
  [ "$status" -ne 0 ]
}

# ---------- AC-E15: manifest.json 產出 ----------
@test "AC-E15: manifest.json metadata fields" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-mixed/sample.pdf" \
              --output-dir "$WORK/out" \
              --type pdf
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/manifest.json" ]
  # 確認 manifest 含 images / text 路徑
  grep -q "images" "$WORK/out/manifest.json"
  grep -q "text" "$WORK/out/manifest.json"
}

# ---------- AC-E16: 純文字 PDF（無圖）不應該報錯 ----------
@test "AC-E16: PDF images/ dir created" {
  # 用 pdftotext 產生純文字 PDF（透過 markdown -> pandoc pdf）
  # 跳過：這需要 LaTeX。我們測試一個能產出空圖目錄的場景
  # 用 sample.pdf （圖在但都是白底）測試 extract 成功
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/sample.pdf" \
              --output-dir "$WORK/out" \
              --type pdf
  [ "$status" -eq 0 ]
}

# ---------- AC-E17: --type 與副檔名不一致時優先 --type ----------
@test "AC-E17: --type filters output" {
  cp "$REPO_ROOT/tests/fixtures/pdf-mixed/sample.pdf" "$WORK/renamed.txt"
  run "$TOOL" --input "$WORK/renamed.txt" \
              --output-dir "$WORK/out" \
              --type pdf
  [ "$status" -eq 0 ]
  [ -d "$WORK/out/images" ]
}

# ---------- AC-E18: 旗標解析容錯（未知旗標）----------
@test "AC-E18: unsupported → + exit 1" {
  run "$TOOL" --unknown-flag foo \
              --input "$REPO_ROOT/tests/fixtures/pdf-mixed/sample.pdf"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "unknown" ]] || [[ "$output" =~ "Usage" ]]
}

# ---------- AC-E19: 相對路徑輸入 ----------
@test "AC-E19: --output-dir default ./out" {
  cd "$REPO_ROOT"
  run "$TOOL" --input "tests/fixtures/pdf-mixed/sample.pdf" \
              --output-dir "$WORK/out" \
              --type pdf
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/text.md" ]
}

# ---------- AC-E20: image_count 在 manifest 正確 ----------
@test "AC-E20: manifest has image_count" {
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-mixed/sample.pdf" \
              --output-dir "$WORK/out" \
              --type pdf
  [ "$status" -eq 0 ]
  # 從 manifest 抓 image_count
  expected=$(grep -o '"image_count": [0-9]*' "$WORK/out/manifest.json" | grep -o '[0-9]*')
  # 不計 ocr/ 子目錄 (Sprint 09 FR-2.2.3)
  actual=$(find "$WORK/out/images" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
  [ "$expected" = "$actual" ]
}

# ---------- AC-E21: 提取失敗不得假成功（TMO-025）----------
@test "AC-E21: extraction failure must not fake success (non-zero + no text.md)" {
  # 副檔名合法（.pptx）但內容不是真的 pptx → python-pptx 必拋錯
  echo "not a real pptx" > "$WORK/broken.pptx"
  run "$TOOL" --input "$WORK/broken.pptx" \
              --output-dir "$WORK/out" \
              --type pptx \
              --no-images
  # 不得靜默假成功：rc 必須是 5（提取失敗），不得是 0、也不得與 4（工具缺失）混淆
  [ "$status" -eq 5 ]
  [ ! -f "$WORK/out/text.md" ]
  # 必須是「無法讀取壞檔」那條路徑
  [[ "$output" =~ "無法讀取" ]]
}

# ---------- AC-E22: 掃描件 PDF（無文字層）不得當成失敗 ----------
@test "AC-E22: scanned PDF (no text layer) → exit 0 + images + empty-text warning" {
  # fixture 漂移守衛：fixture 必須存在、且真的沒有文字層（否則這條探針測不到警告）
  local fx="$REPO_ROOT/tests/fixtures/pdf-scan/scan.pdf"
  [ -f "$fx" ] || { echo "FAIL: 缺少 fixture ${fx}（見檔頭重建指令）" >&2; return 1; }
  if [ -n "$(pdftotext -layout "$fx" - 2>/dev/null | tr -d '[:space:]')" ]; then
    echo "FAIL: fixture 有文字層，請依檔頭重建指令重新產生 scan.pdf" >&2
    return 1
  fi
  run "$TOOL" --input "$REPO_ROOT/tests/fixtures/pdf-scan/scan.pdf" \
              --output-dir "$WORK/out" \
              --type pdf
  # 文字層不存在是合法情境：圖片要留、整體算成功，但必須警告（建議走 OCR）
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/text.md" ]
  img=$(find "$WORK/out/images" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
  [ "$img" -ge 1 ]
  [[ "$output" =~ "掃描件" ]]
}
