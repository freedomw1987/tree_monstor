#!/usr/bin/env bats
# TMO-035：dav-wiki「缺工具時的行為」文實一致鎖。
#
# 背景：`skills/dav-wiki/SKILL.md` 限制表原本寫「FR-2 多模組需 poppler / ffmpeg /
# Whisper｜未裝時降級為純文字模式」，但三支腳本（audio / media / video）的
# `require_tool()` 是**硬退 4**，沒有任何降級路徑 → 文件承諾了不存在的行為。
#
# 決策（2026-10-05 ask-me）：**改文件對齊現實**——缺必要工具就停（`exit 4` +
# 安裝提示），不降級成「純文字模式」；唯一真正的降級是 OCR 缺 tesseract 時
# 自動改用 mock placeholder（有 WARN）。走 V03 二審。
#
# 本檔三件事：
#   ① 實跑：audio / media / video 缺工具 → rc=4（不是降級成功、也不是崩潰）
#   ② 靜態：SKILL.md 限制表不得再承諾「降級為純文字模式」，且必須寫出 exit 4 契約
#   ③ 靜態：OCR 腳本自己也不得宣稱 exit 4（它真的沒有那條路徑），並保留 mock 例外說明
#
# 誠實申報：WTM-1~4 與 WTM-8/9 首輪即綠——它們鎖的是**既有正確行為**（腳本早就是硬退 4），
# 本票真正紅→綠的是「文件承諾了不存在的行為」（WTM-5/6/7）；敏感度由突變驗證佐證
# （MUT-A 回寫降級→WTM-5 紅、MUT-B 改成 exit 0→WTM-2 紅、MUT-G 拿掉 poppler→WTM-8 紅）。
#
# 已知落差（不在本票範圍，已開票 TMO-058）：`wiki-media-describe.sh` 的 real 模式
# （Whisper/Vision）目前**未實作**，修前失敗時印 ERROR 但 rc=0 且不產檔＝假成功；
# 它跟「缺工具安裝」無關，因此不能算進「缺工具就停」的契約，見 SKILL.md 限制表另列一列。
# 已修：TMO-058（2026-10-05）→ real 未實作改 `exit 5`、批次 fail-closed；本段描述為**修前狀態**。
load 'helpers/test-env'

WIKI="$REPO_ROOT/skills/dav-wiki"

# 造一個「一定沒有 ffmpeg / ffprobe / pandoc / tesseract」的 PATH：
# 只 symlink 核心工具，`require_tool` 的 `command -v` 必定落空，
# 不依賴宿主機／CI 裝了什麼（CI 真的有 ffmpeg，見 scripts/ci/check-ffmpeg-version.sh）。
isolated_bin() {
  local d="$1" t src
  mkdir -p "$d"
  for t in bash sh cat dirname basename mkdir date find grep sed tr head tail \
           mktemp mv rm awk sort wc; do
    src="$(command -v "$t" 2>/dev/null || true)"
    [ -n "$src" ] && ln -sf "$src" "$d/$t"
  done
  printf '%s' "$d"
}

@test "WTM-1: 隔離 PATH 可用且真的缺工具（正向＋反向對照，防空過）" {
  local bin
  bin="$(isolated_bin "$BATS_TEST_TMPDIR/bin")"
  run env PATH="$bin" bash "$WIKI/scripts/wiki-extract-audio.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"wiki-extract-audio.sh"* ]]
  # 反向對照：同一條 PATH 下真的沒有 ffmpeg / pandoc，否則下面幾條會假綠
  run env PATH="$bin" bash -c 'command -v ffmpeg; command -v pandoc; echo NO_TOOLS'
  [[ "$output" == *"NO_TOOLS"* ]]
  [[ "$output" != *"/ffmpeg"* ]]
  [[ "$output" != *"/pandoc"* ]]
}

@test "WTM-2: audio 缺 ffmpeg → rc=4 + 安裝提示，且不留半成品（不降級）" {
  local bin
  bin="$(isolated_bin "$BATS_TEST_TMPDIR/bin")"
  local inp="$BATS_TEST_TMPDIR/silence.wav"
  : > "$inp"
  run env PATH="$bin" bash "$WIKI/scripts/wiki-extract-audio.sh" \
      --input "$inp" --output-dir "$BATS_TEST_TMPDIR/out"
  [ "$status" -eq 4 ]
  [[ "$output" == *"required tool 'ffmpeg' not found"* ]]
  [[ "$output" == *"brew install ffmpeg"* ]]
  # 「降級」會留下 text.md / manifest.json 這類部分成果；契約是「什麼都不留」
  # （audio 連目錄都不建，對照 WTM-3 的 media 會留空目錄）
  [ ! -d "$BATS_TEST_TMPDIR/out" ]
}

@test "WTM-3: media（docx）缺 pandoc → rc=4 + 安裝提示（不留部分產出）" {
  local bin
  bin="$(isolated_bin "$BATS_TEST_TMPDIR/bin")"
  local inp="$BATS_TEST_TMPDIR/doc.docx"
  : > "$inp"
  run env PATH="$bin" bash "$WIKI/scripts/wiki-extract-media.sh" \
      --input "$inp" --output-dir "$BATS_TEST_TMPDIR/out-media"
  [ "$status" -eq 4 ]
  [[ "$output" == *"required tool 'pandoc' not found"* ]]
  [[ "$output" == *"brew install pandoc"* ]]
  # 與 audio 不同：media 的 `mkdir -p "$OUTPUT_DIR"` 早於 require_tool，所以會留下**空目錄**。
  # 契約只保證「不留部分**產出**」——不要在這條斷言「連目錄都沒有」。
  # 用 `find` 而非 `[ ! -e "$dir"/*.md ]`：後者一旦環境開了 nullglob 會靜默反轉。
  [ -z "$(find "$BATS_TEST_TMPDIR/out-media" -maxdepth 1 -type f 2>/dev/null)" ]
}

@test "WTM-8: media（pdf）缺 poppler → rc=4 + 安裝提示（doc 點名的工具之一）" {
  local bin
  bin="$(isolated_bin "$BATS_TEST_TMPDIR/bin")"
  local inp="$BATS_TEST_TMPDIR/scan.pdf"
  : > "$inp"
  run env PATH="$bin" bash "$WIKI/scripts/wiki-extract-media.sh" \
      --input "$inp" --output-dir "$BATS_TEST_TMPDIR/out-pdf"
  [ "$status" -eq 4 ]
  [[ "$output" == *"required tool 'pdfimages' not found"* ]]
  [[ "$output" == *"brew install poppler"* ]]
  [ -z "$(find "$BATS_TEST_TMPDIR/out-pdf" -maxdepth 1 -type f 2>/dev/null)" ]
}

@test "WTM-9: media（pptx）缺 python3 / python-pptx → rc=4 + 提示含 python-pptx" {
  local bin
  bin="$(isolated_bin "$BATS_TEST_TMPDIR/bin")"
  local inp="$BATS_TEST_TMPDIR/deck.pptx"
  : > "$inp"
  run env PATH="$bin" bash "$WIKI/scripts/wiki-extract-media.sh" \
      --input "$inp" --output-dir "$BATS_TEST_TMPDIR/out-pptx"
  [ "$status" -eq 4 ]
  # 隔離 PATH 下先落空的是 python3；提示同時涵蓋套件（python-pptx）
  [[ "$output" == *"required tool 'python3' not found"* ]]
  [[ "$output" == *"python-pptx"* ]]
}

@test "WTM-4: video 缺 ffmpeg → rc=4 + 安裝提示" {
  local bin
  bin="$(isolated_bin "$BATS_TEST_TMPDIR/bin")"
  local inp="$BATS_TEST_TMPDIR/clip.mp4"
  : > "$inp"
  run env PATH="$bin" bash "$WIKI/scripts/wiki-extract-video.sh" \
      --input "$inp" --output-dir "$BATS_TEST_TMPDIR/out-video"
  [ "$status" -eq 4 ]
  [[ "$output" == *"required tool 'ffmpeg' not found"* ]]
  [[ "$output" == *"brew install ffmpeg"* ]]
}

@test "WTM-5: SKILL.md 限制表對齊現實（不得承諾降級為純文字）" {
  local skill="$WIKI/SKILL.md"
  refute_file_contains "$skill" "降級為純文字模式"
  assert_file_contains "$skill" "exit 4"
}

@test "WTM-6: OCR 腳本自己不再宣稱 exit 4（決策：自動 mock，不硬退）" {
  # TMO-035 的第二個文實矛盾：usage 原本寫「4 必要工具缺失（且未啟 mock）」，
  # 但本檔根本沒有任何 `exit 4` 路徑（缺 tesseract 就走 mock）。決策是對齊現實。
  # 註：這裡把「常數不存在」也鎖住是刻意的——若未來真的要替 OCR 加硬退 4 路徑，
  # 那是**契約變更**（usage/exit codes 要一起改），改本探針（走 V03）是預期流程。
  local ocr="$WIKI/scripts/wiki-ocr.sh"
  refute_file_contains "$ocr" "EXIT_TOOLMISSING"
  refute_file_contains "$ocr" "必要工具缺失"
  assert_file_contains "$ocr" "自動降級為 mock"
}

@test "WTM-7: OCR 的 mock 降級是唯一例外——文件有寫，且實跑得到" {
  local skill="$WIKI/SKILL.md"
  assert_file_contains "$skill" "tesseract"
  assert_file_contains "$skill" "mock"

  local bin
  bin="$(isolated_bin "$BATS_TEST_TMPDIR/bin")"
  local img="$BATS_TEST_TMPDIR/page.png"
  : > "$img"
  run env PATH="$bin" bash "$WIKI/scripts/wiki-ocr.sh" \
      --input "$img" --output-json "$BATS_TEST_TMPDIR/page.ocr.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"falling back to mock"* ]]
  [ -f "$BATS_TEST_TMPDIR/page.ocr.json" ]
}
