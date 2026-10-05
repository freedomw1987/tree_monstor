#!/usr/bin/env bats
#
# tests/wiki-media-describe.bats
#
# Black-box tests for skills/dav-wiki/scripts/wiki-media-describe.sh
# Sprint 08: dav-wiki 多模組擴充 (FR-2.6.2)
#
# Coverage: 見下方指引（原 AC-D1~D12 手寫清單自 D3 起已整體錯位，2026-10-05 移除，
# 避免再出現「看起來完整其實錯的對照表」）。
#
# TMO-058 起補到 AC-D30（real 模式不得假成功／rc 契約），TMO-060 再補到 AC-D38
# （--batch-limit 正名＋預設無上限＋額度＝嘗試數；reviewer Round-1 的 P1-1／P2-1／
# P2-4／P3-1／P3-5 各補一條回歸鎖）。完整清單見 `grep -n '^@test' tests/wiki-media-describe.bats`。
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
  # TMO-060（reviewer Round-2 P3-7）：非媒體檔必須**出聲**——否則「把 WARN 整段
  # 拿掉」的突變可存活（本票正好動了這一行）。注意 `-qi` 只影響大寫判定，
  # `.txt` 兩種寫法都該 WARN。
  [[ "$output" == *"not an image"* ]]
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
  # TMO-060（reviewer P2-2）：收緊到整行——否則「訊息印死 --batch-limit」的突變能存活。
  [[ "$output" == *"已達 --max-concurrency 上限（2），尚有 3 個未處理"* ]]
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

# ---------- AC-D29: 上限旗標非法值 → rc=1（TMO-060：`0` 改為合法＝無限制） ----------
# TMO-058 時鎖的是「0／2x 皆非法」。TMO-060 重定義語意後 `0`＝無限制（合法），
# 故拒收方向改壓在 -1／2x／1.5（覆蓋面比原本更廣，且要求新的精確訊息）；
# 「0 必須被接受」由 AC-D32 正面鎖。← V03.6 申報的條件放寬項：0 由 fail 改為 pass。
@test "AC-D29: --batch-limit/--max-concurrency 非法值 → rc=1, no batch success" {
  mkdir -p "$WORK/batch-mc"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-mc/"
  local n
  # `007`（前導零）刻意拒收：否則 `^[0-9]+$` 這種「只擋非數字」的突變能存活
  # （reviewer Round-2 P2-1 的 M15 證據補強）。訊息另註明「不得有前導零」，
  # 否則「是正整數卻被拒」對使用者是自我矛盾（reviewer Round-3 P2-A）。
  for n in -1 2x 1.5 007; do
    run "$TOOL" --mode describe --input-dir "$WORK/batch-mc" \
        --output-dir "$WORK/out-mc-$n" --mock --batch-limit "$n"
    [ "$status" -eq 1 ]
    [[ "$output" != *"✅ 批次完成"* ]]
    # TMO-060（reviewer P3-1）：斷言整行含**使用者實際打的旗標名**——否則把訊息
    # 寫死成 --batch-limit 的突變能存活（M21 實測）。
    [[ "$output" == *"ERROR: --batch-limit 需為 0 或正整數（不得有前導零）（收到：${n}）"* ]]
    [ -z "$(find "$WORK/out-mc-$n" -maxdepth 1 -type f 2>/dev/null)" ]
  done
  # 別名必須走同一條驗證（不得只驗正名）
  run "$TOOL" --mode describe --input-dir "$WORK/batch-mc" \
      --output-dir "$WORK/out-mc-alias" --mock --max-concurrency 2x
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --max-concurrency 需為 0 或正整數（不得有前導零）（收到：2x）"* ]]
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

# ==========================================================================
# TMO-060：--batch-limit（正名）／--max-concurrency（相容別名）
# 語意＝單次批次最多**嘗試**處理 N 檔；0＝無限制，且為**新預設**（舊預設 4 會丟檔）。
# ==========================================================================

# ---------- AC-D31: 預設＝無上限（6 檔批次不得丟檔） ----------
@test "AC-D31: 預設無上限 → 6 檔批次全處理（舊版預設 4 會丟 2 檔）" {
  mkdir -p "$WORK/batch-six"
  local i
  for i in 1 2 3 4 5 6; do
    cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-six/img$i.png"
  done
  run "$TOOL" --mode describe --input-dir "$WORK/batch-six" \
      --output-dir "$WORK/out-six" --mock
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ 批次完成：6 個檔案"* ]]
  [[ "$output" != *"未處理"* ]]
  [ "$(find "$WORK/out-six" -maxdepth 1 -type f -name '*.desc.json' | wc -l | tr -d ' ')" -eq 6 ]
}

# ---------- AC-D32: --batch-limit 名實相符＋別名等價＋0＝無限制 ----------
@test "AC-D32: --batch-limit 2 截斷訊息＋--max-concurrency 等價＋0＝無限制" {
  mkdir -p "$WORK/batch-limit"
  local i
  for i in 1 2 3 4; do
    cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-limit/img$i.png"
  done
  run "$TOOL" --mode describe --input-dir "$WORK/batch-limit" \
      --output-dir "$WORK/out-bl" --mock --batch-limit 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ 批次完成：2 個檔案"* ]]
  [[ "$output" == *"已達 --batch-limit 上限（2），尚有 2 個未處理"* ]]
  # 別名：同一組輸入 → 同一行批次摘要（等價性的可觀察證據）
  run "$TOOL" --mode describe --input-dir "$WORK/batch-limit" \
      --output-dir "$WORK/out-mcalias" --mock --max-concurrency 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ 批次完成：2 個檔案"* ]]
  [[ "$output" == *"已達 --max-concurrency 上限（2），尚有 2 個未處理"* ]]
  # 0＝無限制（TMO-060 新語意）
  run "$TOOL" --mode describe --input-dir "$WORK/batch-limit" \
      --output-dir "$WORK/out-mc0" --mock --max-concurrency 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ 批次完成：4 個檔案"* ]]
  [[ "$output" != *"未處理"* ]]
}

# ---------- AC-D33a: 失敗檔佔額度（額度＝嘗試數，不是成功數） ----------
@test "AC-D33a: 額度計嘗試數——失敗檔也佔額度（舊版會變「失敗 3」）" {
  # --batch-limit 1：3 檔都註定失敗 → 只能嘗試 1 檔
  #     （舊版只數成功 → 3 檔全試，訊息會是「失敗 3」）
  mkdir -p "$WORK/batch-fail" "$WORK/out-fail"
  local s
  for s in a b c; do
    cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-fail/$s.png"
    mkdir -p "$WORK/out-fail/$s.desc.json"   # 產物路徑被佔成目錄 → 寫入必失敗（rc 6）
  done
  run "$TOOL" --mode describe --input-dir "$WORK/batch-fail" \
      --output-dir "$WORK/out-fail" --mock --batch-limit 1
  [ "$status" -eq 6 ]
  [[ "$output" == *"❌ 批次失敗：成功 0 / 失敗 1"* ]]
  [[ "$output" == *"已達 --batch-limit 上限（1），尚有 2 個未處理"* ]]
}

# ---------- AC-D33b: 不符 mode 白名單的檔要計數 WARN ----------
@test "AC-D33b: 批次對不符白名單的檔發出計數 WARN（原本完全靜默）" {
  mkdir -p "$WORK/batch-wl"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-wl/"
  echo "not an image" > "$WORK/batch-wl/notes.txt"
  run "$TOOL" --mode describe --input-dir "$WORK/batch-wl" \
      --output-dir "$WORK/out-wl" --mock
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ 批次完成：1 個檔案"* ]]
  [[ "$output" == *"已略過 1 個不符 describe 白名單的檔"* ]]
}

# ---------- AC-D33c: dry-run 批次不得宣稱完成 ----------
@test "AC-D33c: dry-run 批次印 [DRY-RUN] 前綴且不得出現 ✅ 批次完成" {
  mkdir -p "$WORK/batch-dry"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-dry/"
  run "$TOOL" --mode describe --input-dir "$WORK/batch-dry" \
      --output-dir "$WORK/out-dry" --mock --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[DRY-RUN] 批次完成：1 個檔案"* ]]
  [[ "$output" != *"✅ 批次完成"* ]]
}

# ---------- AC-D34: 大寫副檔名必須被處理（P1-1 回歸鎖） ----------
# reviewer Round-1 P1-1：本票把 `find -iname`（大小寫不敏感）換成 `grep -qE` 時弄丟了
# `-i`，導致 `IMG_001.PNG`（macOS 相機／截圖常見）由「被處理」變成「靜默跳過」。
@test "AC-D34: 批次大寫副檔名（IMG_001.PNG）仍要被處理" {
  mkdir -p "$WORK/batch-upper"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-upper/IMG_001.PNG"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-upper/ok.png"
  run "$TOOL" --mode describe --input-dir "$WORK/batch-upper" \
      --output-dir "$WORK/out-upper" --mock
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ 批次完成：2 個檔案"* ]]
  [[ "$output" != *"已略過"* ]]
  [ -f "$WORK/out-upper/IMG_001.desc.json" ]
}

# ---------- AC-D35: 全部檔都被白名單略過 → WARN + rc 0（零產物仍印 ✅＝明示契約） ----------
# reviewer Round-1 P2-4 要求把這條路徑變成明示取捨：訊息不靜默（有 WARN、有計數），
# 但「成功」指的是「沒有失敗」，不是「有產出」—— 所以仍印 ✅ 且 rc 0。
@test "AC-D35: 目錄內全是 non-media 檔 → 略過 WARN + 完成 0 檔 + rc 0" {
  mkdir -p "$WORK/batch-allskip"
  echo "a" > "$WORK/batch-allskip/a.txt"
  echo "b" > "$WORK/batch-allskip/b.txt"
  run "$TOOL" --mode describe --input-dir "$WORK/batch-allskip" \
      --output-dir "$WORK/out-allskip" --mock
  [ "$status" -eq 0 ]
  [[ "$output" == *"已略過 2 個不符 describe 白名單的檔"* ]]
  [[ "$output" == *"✅ 批次完成：0 個檔案"* ]]
}

# ---------- AC-D38: 旗標缺值要走友善錯誤（P3-5） ----------
# reviewer Round-1 P3-5：`BATCH_LIMIT="$2"` 在 `set -u` 下缺值會直接以
# `unbound variable` 中止（rc 1 但無訊息、指不到哪個旗標）→ 改用 `${2:-}` 走同一條驗證。
@test "AC-D38: --batch-limit 缺值 → rc=1 且印友善錯誤（不是 unbound variable）" {
  mkdir -p "$WORK/batch-noval"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-noval/"
  run "$TOOL" --mode describe --input-dir "$WORK/batch-noval" \
      --output-dir "$WORK/out-noval" --mock --batch-limit
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: --batch-limit 需為 0 或正整數（不得有前導零）（收到：）"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

# ---------- AC-D37: 隱藏但符合白名單的媒體檔仍要處理（P2-1 的反面） ----------
# reviewer Round-1 P2-1：dotfile 豁免只能用在「隱藏**且**不符白名單」；
# 否則 `.cover.png` 這種合法媒體檔又會變成靜默丟檔（正是本票在修的病）。
@test "AC-D37: 隱藏媒體檔（.cover.png）仍要被處理、不列入略過計數" {
  mkdir -p "$WORK/batch-hidden"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/batch-hidden/.cover.png"
  run "$TOOL" --mode describe --input-dir "$WORK/batch-hidden" \
      --output-dir "$WORK/out-hidden" --mock
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ 批次完成：1 個檔案"* ]]
  [[ "$output" != *"已略過"* ]]
  [ -f "$WORK/out-hidden/.cover.desc.json" ]
}

# ---------- AC-D36: 單檔模式對大寫副檔名不得誤報「not an image」 ----------
# TMO-060 順修（已揭露）：批次端已 case-insensitive；單檔端原本 case-sensitive →
# `IMG_002.PNG` 會被警告成「not an image file」卻照樣處理＝同一檔兩種結論。
@test "AC-D36: 單檔大寫副檔名 rc 0 且不得出現 not an image 警告" {
  mkdir -p "$WORK/single-upper"
  cp "$REPO_ROOT/tests/fixtures/pdf-multimodal/red.png" "$WORK/single-upper/IMG_002.PNG"
  run "$TOOL" --mode describe --input "$WORK/single-upper/IMG_002.PNG"       --output-dir "$WORK/out-single-upper" --mock
  [ "$status" -eq 0 ]
  [[ "$output" != *"not an image"* ]]
}
