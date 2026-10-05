#!/usr/bin/env bats
#
# tests/wiki-media-describe.bats
#
# Black-box tests for skills/dav-wiki/scripts/wiki-media-describe.sh
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

load 'helpers/test-env'

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  TOOL="$REPO_ROOT/skills/dav-wiki/scripts/wiki-media-describe.sh"
  WORK="$(mktemp -d -t wiki-describe-test-XXXXXX)"
  export WORK
  # 確保 mock 模式（測試環境不連真實 API）
  export DAV_WIKI_MOCK=1
}

teardown() {
  rm -rf "$WORK"
}

# ---------- AC-D1: mock 模式圖片描述 ----------
@test "AC-D1: --mode describe --input <png> --mock JSON" {
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
@test "AC-D2: --mode transcript --input <audio> --mock transcript" {
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
@test "AC-D3: --input-dir batch processing" {
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
@test "AC-D4: invalid --mode → exit 1" {
  run "$TOOL" --input "foo.png" --mock
  [ "$status" -ne 0 ]
}

# ---------- AC-D5: 不存在的輸入 ----------
@test "AC-D5: missing --input → exit 2" {
  run "$TOOL" --mode describe \
              --input "/nonexistent/foo.png" \
              --mock
  [ "$status" -ne 0 ]
}

# ---------- AC-D6: 不支援的 mode ----------
@test "AC-D6: bad mode value → exit 3" {
  run "$TOOL" --mode foo-bar \
              --input "foo.png" \
              --mock
  [ "$status" -ne 0 ]
}

# ---------- AC-D7: --dry-run ----------
@test "AC-D7: --dry-run" {
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
@test "AC-D8: --help shows usage" {
  run "$TOOL" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage" ]]
}

# ---------- AC-D9: describe 對非圖片副檔名 ----------
@test "AC-D9: describe rejects .txt" {
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
@test "AC-D10: transcript rejects .png" {
  run "$TOOL" --mode transcript \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/transcript.json" \
              --mock
  # 接受 0 或非 0，但不要 crash
  [ "$status" -ne 139 ]
  [ "$status" -ne 134 ]
}

# ---------- AC-D11: --max-concurrency 旗標 ----------
@test "AC-D11: --max-concurrency" {
  run "$TOOL" --mode describe \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/desc.json" \
              --mock \
              --max-concurrency 1
  [ "$status" -eq 0 ]
}

# ---------- AC-D12: --api-key 從命令列 ----------
@test "AC-D12: --api-key sk-test-xxx API" {
  run "$TOOL" --mode describe \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/desc.json" \
              --mock \
              --api-key "sk-test-fake"
  [ "$status" -eq 0 ]
}

# ---------- AC-D13: manifest 含時間戳 ----------
@test "AC-D13: manifest JSON has ISO 8601 timestamps" {
  run "$TOOL" --mode describe \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/desc.json" \
              --mock
  [ "$status" -eq 0 ]
  grep -qE '"extracted_at":\s*"[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$WORK/desc.json"
}

# ---------- AC-D14: manifest 含 mode 欄位 ----------
@test "AC-D14: manifest JSON includes mode field" {
  run "$TOOL" --mode describe \
              --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
              --output-json "$WORK/desc.json" \
              --mock
  [ "$status" -eq 0 ]
  grep -q '"mode"' "$WORK/desc.json"
  grep -q '"describe"' "$WORK/desc.json"
}

# ---------- AC-D15: input-dir 不存在 ----------
@test "AC-D15: missing --input-dir → exit 2" {
  run "$TOOL" --mode describe \
              --input-dir "/nonexistent/dir" \
              --mock
  [ "$status" -ne 0 ]
}

# ---------- AC-D16: --language 旗標 ----------
@test "AC-D16: --language zh accepted" {
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
# ---------- AC-D17: 批次 mode 過濾（describe 只吃圖片） ----------
@test "AC-D17: batch describe skips non-image files" {
  mkdir -p "$WORK/batch-img"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-img/"
  ffmpeg -f lavfi -i "sine=frequency=440:duration=1" \
         -ar 16000 -ac 1 "$WORK/batch-img/sine.wav" -y 2>/dev/null
  run "$TOOL" --mode describe \
              --input-dir "$WORK/batch-img" \
              --output-dir "$WORK/out-img" \
              --mock
  [ "$status" -eq 0 ]
  [ -f "$WORK/out-img/red.desc.json" ]
  [ ! -f "$WORK/out-img/sine.desc.json" ]
}

# ---------- AC-D18: 批次 mode 過濾（transcript 只吃音訊/影片） ----------
@test "AC-D18: batch transcript skips image files" {
  mkdir -p "$WORK/batch-aud"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-aud/"
  ffmpeg -f lavfi -i "sine=frequency=440:duration=1" \
         -ar 16000 -ac 1 "$WORK/batch-aud/sine.wav" -y 2>/dev/null
  run "$TOOL" --mode transcript \
              --input-dir "$WORK/batch-aud" \
              --output-dir "$WORK/out-aud" \
              --mock
  [ "$status" -eq 0 ]
  [ -f "$WORK/out-aud/sine.desc.json" ]
  [ ! -f "$WORK/out-aud/red.desc.json" ]
}

# ==========================================================================
# TMO-058：real 模式「零產出卻回報成功」修正（AC-D19~D30）
# 契約：任何沒產出的路徑不得回 0；批次摘要必須反映真實成功/失敗數。
# 注：setup() 設了 DAV_WIKI_MOCK=1，real 測試必須 `env -u DAV_WIKI_MOCK`
#     明確拔掉，否則會測到 mock 而「假綠」。
# ==========================================================================

# ---------- AC-D19: real 單檔未實作 → rc=5、不得有產物 ----------
@test "AC-D19: real mode single file → rc=5 and NO artifact" {
  run env -u DAV_WIKI_MOCK "$TOOL" --mode describe \
      --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
      --output-json "$WORK/real.json"
  [ "$status" -eq 5 ]
  [ ! -f "$WORK/real.json" ]
  [[ "$output" == *"not implemented"* ]]
  # 真的沒走 mock（防空過：若走 mock 就會有 [MOCK] 產物/字樣）
  [[ "$output" != *"[MOCK]"* ]]
}

# ---------- AC-D20: real 批次全失敗 → rc≠0、不得出現成功訊息 ----------
@test "AC-D20: real mode batch all-failed → rc≠0 and NO success message" {
  mkdir -p "$WORK/batch-real"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-real/"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/blue.png" "$WORK/batch-real/"
  run env -u DAV_WIKI_MOCK "$TOOL" --mode describe \
      --input-dir "$WORK/batch-real" \
      --output-dir "$WORK/out-real"
  [ "$status" -ne 0 ]
  [[ "$output" != *"✅ 批次完成"* ]]
  [[ "$output" == *"失敗"* ]]
  # 零產出（契約：不留部分產出）
  [ -z "$(find "$WORK/out-real" -maxdepth 1 -type f 2>/dev/null)" ]
}

# ---------- AC-D21: 批次 mock 全成功仍是 rc=0 + ✅（回歸鎖） ----------
@test "AC-D21: batch mock all-success stays rc=0 + ✅（回歸鎖）" {
  mkdir -p "$WORK/batch-ok"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-ok/"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/blue.png" "$WORK/batch-ok/"
  run "$TOOL" --mode describe --input-dir "$WORK/batch-ok" \
      --output-dir "$WORK/out-ok" --mock
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ 批次完成：2 個檔案"* ]]
  [ -f "$WORK/out-ok/red.desc.json" ]
  [ -f "$WORK/out-ok/blue.desc.json" ]
}

# ---------- AC-D22: real + --dry-run 仍 rc=0（不執行 ≠ 失敗） ----------
@test "AC-D22: real mode + --dry-run stays rc=0" {
  run env -u DAV_WIKI_MOCK "$TOOL" --mode describe \
      --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
      --output-json "$WORK/dry.json" --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$WORK/dry.json" ]
}

# ---------- AC-D23: usage 與實作一致（有 rc 5、無死碼 4） ----------
@test "AC-D23: usage/實作一致：有 5 未實作、無死的 4 必要工具缺失" {
  run "$TOOL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"5  未實作"* ]]
  [[ "$output" != *"必要工具缺失"* ]]
  assert_file_contains "$TOOL" "EXIT_NOTIMPL"
  refute_file_contains "$TOOL" "EXIT_TOOLMISSING"
}

# ---------- AC-D24: SKILL.md 不得再描述成「回 rc 0＝假成功」 ----------
@test "AC-D24: SKILL.md 限制表寫明 rc 5（不再是『回 rc 0＝假成功』）" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  # 用 body 版（排除 `## 變動歷史`）：歷史列本來就會提到「原本是假成功」的舊行為，
  # 那不該算違規；違規的是**現行說明**仍把它描述成現在式。
  refute_file_body_contains "$skill" "回 rc 0＝"
  # 正面錨點：必須寫出新的失敗碼（接受 `rc 5` 或 `exit 5` 兩種寫法）。
  # reviewer Round-1 P3-3：原本掃全檔，會被 `## 變動歷史` 的 v2.2.2 列滿足
  # （即使限制表把 exit 5 拿掉也照樣綠）→ 同樣改成 body-only，讓承重的正面鎖真的盯現行說明。
  if ! awk '/^## 變動歷史/{skip=1; next} /^## /{skip=0} !skip' "$skill" | grep -qE 'rc 5|exit 5'; then
    echo "FAIL: $skill does not document rc 5 / exit 5" >&2
    return 1
  fi
}

# ---------- AC-D25: 批次被 --max-concurrency 截斷 → 誠實 WARN（rc 仍 0） ----------
@test "AC-D25: batch truncated by --max-concurrency prints WARN, rc=0" {
  mkdir -p "$WORK/batch-many"
  local i
  for i in 1 2 3 4 5; do
    cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-many/img$i.png"
  done
  run "$TOOL" --mode describe --input-dir "$WORK/batch-many" \
      --output-dir "$WORK/out-many" --mock --max-concurrency 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ 批次完成：2 個檔案"* ]]
  [[ "$output" == *"未處理"* ]]
}

# ---------- AC-D26: 部分失敗可達（輸出寫不進去 → ❌ + rc=6） ----------
# TMO-058 順修（已揭露）：原版 `echo > "$output"` 不看 rc，寫入失敗照樣印「✓ wrote」+ ✅。
# 本探針讓「部分失敗」那條分支真的可達（原本 mock 全成功／real 全失敗 → 永遠是死碼）。
@test "AC-D26: batch partial failure (blocked output path) → rc=6 and ❌" {
  mkdir -p "$WORK/batch-mix" "$WORK/out-mix"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png"  "$WORK/batch-mix/"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/blue.png" "$WORK/batch-mix/"
  # 用同名目錄佔住 red 的輸出路徑 → 寫檔必失敗
  mkdir -p "$WORK/out-mix/red.desc.json"
  run "$TOOL" --mode describe --input-dir "$WORK/batch-mix" \
      --output-dir "$WORK/out-mix" --mock
  [ "$status" -eq 6 ]
  [[ "$output" == *"❌ 批次部分失敗"* ]]
  [[ "$output" != *"✅ 批次完成"* ]]
  [ -f "$WORK/out-mix/blue.desc.json" ]
}

# ---------- AC-D27: 單檔寫入失敗不得假成功 ----------
@test "AC-D27: single-file blocked output path → rc=6, no ✓ wrote" {
  mkdir -p "$WORK/blocked.desc.json"
  run "$TOOL" --mode describe \
      --input "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" \
      --output-json "$WORK/blocked.desc.json" --mock
  [ "$status" -eq 6 ]
  [[ "$output" != *"✓ wrote"* ]]
}

# ---------- AC-D28: 建不出 output-dir 不得假成功 ----------
@test "AC-D28: un-creatable --output-dir → rc=6, no batch success" {
  mkdir -p "$WORK/batch-dir"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-dir/"
  echo "not a dir" > "$WORK/a-file"
  run "$TOOL" --mode describe --input-dir "$WORK/batch-dir" \
      --output-dir "$WORK/a-file/sub" --mock
  [ "$status" -eq 6 ]
  # 收緊到「專屬訊息」：否則下游寫入失敗也會回 6，這條護欄就無法被隔離驗證
  [[ "$output" == *"無法建立 output-dir"* ]]
  [[ "$output" != *"✅ 批次完成"* ]]
}

# ---------- AC-D29: --max-concurrency 非法值不得「零產出＋回 0」 ----------
# reviewer Round-1 P2-2：0 → 每檔都算截斷（零產出卻印 ✅ 回 0）；2x → [[ ]] 算術報錯
# 走 false 分支（默默不限制）。兩者都要求正整數 → exit 1。
@test "AC-D29: --max-concurrency 0 / 非數字 → rc=1, no batch success" {
  mkdir -p "$WORK/batch-mc"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-mc/"
  run "$TOOL" --mode describe --input-dir "$WORK/batch-mc" \
      --output-dir "$WORK/out-mc0" --mock --max-concurrency 0
  [ "$status" -eq 1 ]
  [[ "$output" != *"✅ 批次完成"* ]]
  [ -z "$(find "$WORK/out-mc0" -maxdepth 1 -type f 2>/dev/null)" ]
  run "$TOOL" --mode describe --input-dir "$WORK/batch-mc" \
      --output-dir "$WORK/out-mc2" --mock --max-concurrency 2x
  [ "$status" -eq 1 ]
  [[ "$output" == *"需為正整數"* ]]
}

# ---------- AC-D30: --max-concurrency 合法值不得被新驗證誤擋 ----------
# reviewer Round-2 P3-6：AC-D29 只鎖「拒絕」方向，邊界缺「接受」證據（1000 應可通過）。
@test "AC-D30: --max-concurrency 合法值（10 / 1000）仍 rc=0" {
  mkdir -p "$WORK/batch-mc-ok"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-mc-ok/"
  for n in 10 1000; do
    run "$TOOL" --mode describe --input-dir "$WORK/batch-mc-ok" \
        --output-dir "$WORK/out-mc-$n" --mock --max-concurrency "$n"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅ 批次完成：1 個檔案"* ]]
  done
}
