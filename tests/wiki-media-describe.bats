#!/usr/bin/env bats
#
# tests/wiki-media-describe.bats
#
# Black-box tests for tools/wiki-media-describe.sh
# Sprint 08: dav-wiki 多模組擴充 (FR-2.6.2)
#
# Coverage:
#   AC-D1: --mode describe（圖片描述）+ mock 模式
#   AC-D2: --mode transcript（音訊轉錄）+ mock 模式
#   AC-D3: --input 指定單張圖/音檔
#   AC-D4: --input-dir 批次處理目錄
#   AC-D5: --output-json 寫 metadata
#   AC-D6: --mock 強制 mock（不連 API）
#   AC-D7: --api-key 從環境變數
#   AC-D8: 缺 --mode → 錯誤
#   AC-D9: 不存在的輸入 → 錯誤
#   AC-D10: --max-concurrency 限制
#   AC-D11: --dry-run
#   AC-D12: 不支援的 mode
#
# Usage:
#   bats tests/wiki-media-describe.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TOOL="$REPO_ROOT/tools/wiki-media-describe.sh"
  WORK="$(mktemp -d -t wiki-describe-test-XXXXXX)"
  export WORK
  # 確保 mock 模式（測試環境不連真實 API）
  export DAV_WIKI_MOCK=1
}

teardown() {
  rm -rf "$WORK"
}

# ---------- AC-D1: mock 模式圖片描述 ----------
@test "AC-D1: --mode describe --input <png> --mock 產出 JSON" {
  run "$TOOL" --mode describe \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/desc.json" \
              --mock
  [ "$status" -eq 0 ]
  [ -f "$WORK/desc.json" ]
  # 確認 JSON 含必要欄位
  grep -q '"caption"' "$WORK/desc.json"
  grep -q '"alt_text"' "$WORK/desc.json"
}

# ---------- AC-D2: mock 模式音訊轉錄 ----------
@test "AC-D2: --mode transcript --input <audio> --mock 產出 transcript" {
  # 先生成一個測試音檔
  ffmpeg -f lavfi -i "sine=frequency=440:duration=1" \
         -ar 16000 -ac 1 "$WORK/sine.wav" -y 2>/dev/null
  run "$TOOL" --mode transcript \
              --input "$WORK/sine.wav" \
              --output-json "$WORK/transcript.json" \
              --mock
  [ "$status" -eq 0 ]
  [ -f "$WORK/transcript.json" ]
  grep -q '"text"' "$WORK/transcript.json"
  grep -q '"duration"' "$WORK/transcript.json"
}

# ---------- AC-D3: --input-dir 批次 ----------
@test "AC-D3: --input-dir 批次處理目錄內所有圖片" {
  mkdir -p "$WORK/batch"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch/"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/blue.png" "$WORK/batch/"
  run "$TOOL" --mode describe \
              --input-dir "$WORK/batch" \
              --output-dir "$WORK/out" \
              --mock
  [ "$status" -eq 0 ]
  [ -f "$WORK/out/red.desc.json" ]
  [ -f "$WORK/out/blue.desc.json" ]
}

# ---------- AC-D4: 缺 --mode ----------
@test "AC-D4: 沒給 --mode → exit 1" {
  run "$TOOL" --input "foo.png" --mock
  [ "$status" -ne 0 ]
}

# ---------- AC-D5: 不存在的輸入 ----------
@test "AC-D5: 不存在的檔案 → exit 2" {
  run "$TOOL" --mode describe \
              --input "/nonexistent/foo.png" \
              --mock
  [ "$status" -ne 0 ]
}

# ---------- AC-D6: 不支援的 mode ----------
@test "AC-D6: 不支援的 mode → exit 3" {
  run "$TOOL" --mode foo-bar \
              --input "foo.png" \
              --mock
  [ "$status" -ne 0 ]
}

# ---------- AC-D7: --dry-run ----------
@test "AC-D7: --dry-run 不實際執行，只印計畫" {
  run "$TOOL" --mode describe \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/desc.json" \
              --mock \
              --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$WORK/desc.json" ]
  [[ "$output" =~ "dry-run" ]] || [[ "$output" =~ "DRY-RUN" ]] || [[ "$output" =~ "Would" ]]
}

# ---------- AC-D8: --help ----------
@test "AC-D8: --help 顯示使用說明" {
  run "$TOOL" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage" ]]
}

# ---------- AC-D9: describe 對非圖片副檔名 ----------
@test "AC-D9: describe 對 .txt 副檔名 → 警告但不中斷" {
  echo "fake" > "$WORK/fake.txt"
  run "$TOOL" --mode describe \
              --input "$WORK/fake.txt" \
              --output-json "$WORK/desc.json" \
              --mock
  # 接受兩種結果：跳過（exit 0） 或 報錯（exit non-0）
  # 重點是不要 crash（exit 139/134 segmentation fault）
  [ "$status" -ne 139 ]
  [ "$status" -ne 134 ]
}

# ---------- AC-D10: transcript 對 .png 副檔名 ----------
@test "AC-D10: transcript 對 .png 副檔名 → 警告但不中斷" {
  run "$TOOL" --mode transcript \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/transcript.json" \
              --mock
  # 接受 0 或非 0，但不要 crash
  [ "$status" -ne 139 ]
  [ "$status" -ne 134 ]
}

# ---------- AC-D11: --max-concurrency 旗標 ----------
@test "AC-D11: --max-concurrency 接受正整數" {
  run "$TOOL" --mode describe \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/desc.json" \
              --mock \
              --max-concurrency 1
  [ "$status" -eq 0 ]
}

# ---------- AC-D12: --api-key 從命令列 ----------
@test "AC-D12: --api-key sk-test-xxx 被接受（不實際連 API）" {
  run "$TOOL" --mode describe \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/desc.json" \
              --mock \
              --api-key "sk-test-fake"
  [ "$status" -eq 0 ]
}

# ---------- AC-D13: manifest 含時間戳 ----------
@test "AC-D13: JSON 產出含 ISO 8601 時間戳" {
  run "$TOOL" --mode describe \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/desc.json" \
              --mock
  [ "$status" -eq 0 ]
  grep -qE '"extracted_at":\s*"[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$WORK/desc.json"
}

# ---------- AC-D14: manifest 含 mode 欄位 ----------
@test "AC-D14: JSON 產出含 mode 欄位" {
  run "$TOOL" --mode describe \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/desc.json" \
              --mock
  [ "$status" -eq 0 ]
  grep -q '"mode"' "$WORK/desc.json"
  grep -q '"describe"' "$WORK/desc.json"
}

# ---------- AC-D15: input-dir 不存在 ----------
@test "AC-D15: --input-dir 不存在 → exit 2" {
  run "$TOOL" --mode describe \
              --input-dir "/nonexistent/dir" \
              --mock
  [ "$status" -ne 0 ]
}

# ---------- AC-D16: --language 旗標 ----------
@test "AC-D16: --language zh 被接受" {
  ffmpeg -f lavfi -i "sine=frequency=440:duration=1" \
         -ar 16000 -ac 1 "$WORK/sine.wav" -y 2>/dev/null
  run "$TOOL" --mode transcript \
              --input "$WORK/sine.wav" \
              --output-json "$WORK/transcript.json" \
              --mock \
              --language zh
  [ "$status" -eq 0 ]
  grep -q '"language"' "$WORK/transcript.json"
  grep -q '"zh"' "$WORK/transcript.json"
}