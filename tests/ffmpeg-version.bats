#!/usr/bin/env bats
#
# tests/ffmpeg-version.bats
#
# TMO-042：媒體探針/腳本用的 ffmpeg 旗標沒有版本鎖。
#   背景：CI 兩平台版本不同（apt ffmpeg 6.x vs brew ffmpeg 8.x），ffmpeg 8 已移除 `-vsync`
#   （本輪已全面改用 `-fps_mode`）。下一批移除（編碼器/濾鏡改名）無法預期，
#   所以鎖要有兩層：①版本底線 ②用「本 repo 真的在用」的旗標組合實測能力。
#
# 本檔以假殼（FFMPEG_BIN/FFPROBE_BIN 覆寫）製造舊版/旗標失效情境，證明檢查不是空過。
#
# Usage:
#   bats tests/ffmpeg-version.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  CHECK="$REPO_ROOT/scripts/ci/check-ffmpeg-version.sh"
  CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
  CONTRIB="$REPO_ROOT/CONTRIBUTING.md"
  FAKE_BIN="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$FAKE_BIN"
  export REPO_ROOT CHECK CI_YML CONTRIB FAKE_BIN
}

# 造一個假的 ffmpeg：只回應 -version（回傳指定字串）
make_fake_ffmpeg() {
  local path="$1" version_line="$2"
  {
    printf '#!/bin/sh\n'
    printf 'if [ "$1" = "-version" ]; then\n'
    printf '  echo "%s"\n' "$version_line"
    printf '  exit 0\n'
    printf 'fi\n'
    printf 'exit 1\n'
  } > "$path"
  chmod +x "$path"
}

# 造一個假的 ffprobe（版本檢查用）
make_fake_ffprobe() {
  local path="$1"
  {
    printf '#!/bin/sh\n'
    printf 'echo "ffprobe version 6.0 Copyright"\n'
  } > "$path"
  chmod +x "$path"
}

@test "FV-1: local ffmpeg version and flag combo pass the check (and print the version)" {
  [ -x "$CHECK" ]
  run bash "$CHECK"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 本機 ffmpeg 未通過版本/能力檢查：$output" >&2
    return 1
  }
  [[ "$output" == *"OK: ffmpeg "* ]] || {
    echo 'FAIL: tests/ffmpeg-version.bats:56: assertion failed' >&2; return 1; }
  # 防空過：版本號必須解析得出來且 >= 5.1
  local ver major minor
  ver=$(printf '%s' "$output" | sed -n 's/^OK: ffmpeg \([0-9][0-9.]*\).*/\1/p')
  [ -n "$ver" ] || { echo "FAIL: 沒有印出解析到的版本號" >&2; return 1; }
  major="${ver%%.*}"
  minor="${ver#*.}"; minor="${minor%%.*}"
  [ "$major" -gt 5 ] || { [ "$major" -eq 5 ] && [ "$minor" -ge 1 ]; } || {
    echo "FAIL: 本機 ffmpeg $ver 低於底線 5.1" >&2
    return 1
  }
}

@test "FV-2: an ffmpeg that is too old (4.4.2) must be blocked with a reason" {
  make_fake_ffmpeg "$FAKE_BIN/ffmpeg-old" \
    "ffmpeg version 4.4.2 Copyright (c) 2000-2021 the FFmpeg developers"
  make_fake_ffprobe "$FAKE_BIN/ffprobe"
  run env FFMPEG_BIN="$FAKE_BIN/ffmpeg-old" FFPROBE_BIN="$FAKE_BIN/ffprobe" bash "$CHECK"
  [ "$status" -ne 0 ] || { echo "FAIL: 舊版 ffmpeg 竟然通過" >&2; return 1; }
  [[ "$output" == *"太舊"* ]] || {
    echo 'FAIL: tests/ffmpeg-version.bats:76: assertion failed' >&2; return 1; }
  [[ "$output" == *"4.4.2"* ]] || {
    echo 'FAIL: tests/ffmpeg-version.bats:78: assertion failed' >&2; return 1; }
}

@test "FV-3: 5.0 (one minor below) must also be blocked (the floor is 5.1, not 5)" {
  make_fake_ffmpeg "$FAKE_BIN/ffmpeg-50" "ffmpeg version 5.0 Copyright"
  make_fake_ffprobe "$FAKE_BIN/ffprobe"
  run env FFMPEG_BIN="$FAKE_BIN/ffmpeg-50" FFPROBE_BIN="$FAKE_BIN/ffprobe" bash "$CHECK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"太舊"* ]] || {
    echo 'FAIL: tests/ffmpeg-version.bats:87: assertion failed' >&2; return 1; }
}

@test "FV-4: new enough version but broken flag combo must be blocked (capability, not just version)" {
  # 版本 6.0 看起來沒問題，但實際跑我們的旗標組合時失敗
  make_fake_ffmpeg "$FAKE_BIN/ffmpeg-noflag" "ffmpeg version 6.0 Copyright"
  make_fake_ffprobe "$FAKE_BIN/ffprobe"
  run env FFMPEG_BIN="$FAKE_BIN/ffmpeg-noflag" FFPROBE_BIN="$FAKE_BIN/ffprobe" bash "$CHECK"
  [ "$status" -ne 0 ] || { echo "FAIL: 旗標失效竟然通過" >&2; return 1; }
  [[ "$output" == *"旗標組合"* ]] || {
    echo 'FAIL: tests/ffmpeg-version.bats:97: assertion failed' >&2; return 1; }
}

@test "FV-5: a missing ffmpeg or ffprobe must be blocked (not only the version)" {
  make_fake_ffprobe "$FAKE_BIN/ffprobe"
  run env FFMPEG_BIN="$BATS_TEST_TMPDIR/does-not-exist" FFPROBE_BIN="$FAKE_BIN/ffprobe" \
      bash "$CHECK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"找不到 ffmpeg"* ]] || {
    echo 'FAIL: tests/ffmpeg-version.bats:106: assertion failed' >&2; return 1; }

  make_fake_ffmpeg "$FAKE_BIN/ffmpeg-ok" "ffmpeg version 6.0 Copyright"
  run env FFMPEG_BIN="$FAKE_BIN/ffmpeg-ok" FFPROBE_BIN="$BATS_TEST_TMPDIR/no-ffprobe" \
      bash "$CHECK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"找不到 ffprobe"* ]] || {
    echo 'FAIL: tests/ffmpeg-version.bats:113: assertion failed' >&2; return 1; }
}

@test "FV-6: CI runs this check in the test job and it is not a || true fake green" {
  local block
  block=$(awk '/name: Verify ffmpeg version and flags/{flag=1} flag{print} /^      - name:/&&flag&&!/Verify ffmpeg version and flags/{exit}' "$CI_YML")
  # 防空過：真的要抓到含該腳本的 step（含 name 行）
  [[ -n "$block" ]] || { echo "FAIL: ci.yml 找不到跑 check-ffmpeg-version.sh 的 step" >&2; return 1; }
  [[ "$block" == *"check-ffmpeg-version.sh"* ]] || {
    echo 'FAIL: tests/ffmpeg-version.bats:122: assertion failed' >&2; return 1; }
  if printf '%s' "$block" | grep -q '|| true'; then
    echo "FAIL: 該 step 有 '|| true'（假綠）" >&2
    return 1
  fi
  # 必須在 test job（bats 那組）內、且在安裝依賴之後：以檔案順序檢查
  local step_line bat_line
  step_line=$(grep -n 'check-ffmpeg-version.sh' "$CI_YML" | head -1 | cut -d: -f1)
  bat_line=$(grep -n 'bats tests/' "$CI_YML" | head -1 | cut -d: -f1)
  [ -n "$step_line" ] && [ -n "$bat_line" ]
  [ "$step_line" -lt "$bat_line" ] || {
    echo "FAIL: 版本檢查應在跑 bats 之前（step#$step_line, bats#${bat_line}）" >&2
    return 1
  }
}

# 造一個假的 ffmpeg：版本夠新、第一組旗標可用，但碰到 `scale=`（第二組＝pptx-slim）就失敗。
# 用途：FV-4 的假殼（非 -version 一律 exit 1）在第一組就紅了，永遠走不到第二組；
# 這支要把第二組能力實測單獨咬住，否則刪掉它（或改壞）沒有任何探針會紅。
make_fake_ffmpeg_only_scale_fails() {
  local path="$1" version_line="$2"
  {
    printf '#!/bin/sh\n'
    printf 'if [ "$1" = "-version" ]; then\n'
    printf '  echo "%s"\n' "$version_line"
    printf '  exit 0\n'
    printf 'fi\n'
    printf 'for a in "$@"; do\n'
    printf '  case "$a" in *scale=*) echo "Unknown filter/encoder (simulated)" >&2; exit 1;; esac\n'
    printf 'done\n'
    printf 'exit 0\n'
  } > "$path"
  chmod +x "$path"
}

@test "FV-7: CONTRIBUTING documents the version floor and the -vsync removal list" {
  grep -q '5\.1' "$CONTRIB" || { echo "FAIL: CONTRIBUTING 未寫 ffmpeg 版本底線 5.1" >&2; return 1; }
  grep -q -- '-vsync' "$CONTRIB" || { echo "FAIL: CONTRIBUTING 未寫 -vsync 移除說明" >&2; return 1; }
  grep -q 'check-ffmpeg-version\.sh' "$CONTRIB" || {
    echo "FAIL: CONTRIBUTING 未說明版本檢查腳本" >&2
    return 1
  }
  # 第二組（pptx-slim）也要在文件裡，否則貢獻者只知道 wiki 那一組
  # （FV-8 已行為層咬住第二組；這行是靜態層的雙保險）
  grep -q -- '-movflags +faststart' "$CONTRIB" || {
    echo "FAIL: CONTRIBUTING 未列出 pptx-slim 轉碼旗標（-movflags +faststart）" >&2
    return 1
  }
}

@test "FV-8: first combo works but second (pptx-slim scale expression) fails -> blocked separately" {
  make_fake_ffmpeg_only_scale_fails "$FAKE_BIN/ffmpeg-noscale" "ffmpeg version 6.0 Copyright"
  make_fake_ffprobe "$FAKE_BIN/ffprobe"
  run env FFMPEG_BIN="$FAKE_BIN/ffmpeg-noscale" FFPROBE_BIN="$FAKE_BIN/ffprobe" bash "$CHECK"
  [ "$status" -ne 0 ] || { echo "FAIL: 第二組旗標失效竟然通過" >&2; return 1; }
  # 訊息必須指出是 pptx-slim 那一組（而不是第一組），否則診斷會指錯地方
  [[ "$output" == *"pptx-slim"* ]] || { echo "FAIL: 失敗訊息未指出 pptx-slim 旗標組合：$output" >&2; return 1; }
  [[ "$output" == *"旗標組合"* ]] || {
    echo 'FAIL: tests/ffmpeg-version.bats:180: assertion failed' >&2; return 1; }
  [[ "$output" != *"select/showinfo"* ]] || { echo "FAIL: 第一組也被判失敗（假殼設計錯）" >&2; return 1; }
}

# 為什麼需要 FV-9：FV-8 的假殼「一看到 scale= 就失敗」，所以檢查腳本若把 scale 表達式換成
# 別的、甚至整條 -vf 拿掉，FV-8 照樣會過 —— 第二組能力實測就退化成裝飾品。
# 這條直接比對「檢查腳本送的字串」與「pptx-slim 真正送給 ffmpeg 的字串」是不是同一份。
@test "FV-9: the second capability probe string equals the flags pptx-slim really uses" {
  local expr
  expr=$(python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/skills/pptx-slim/scripts')
from pptx_common import scale_filter
print(scale_filter(1920))
")
  [ -n "$expr" ] || { echo "FAIL: 取不到 scale_filter(1920) 的字串" >&2; return 1; }
  grep -qF "$expr" "$CHECK" || {
    echo "FAIL: 檢查腳本沒測到 pptx-slim 真的在用的 scale 表達式：$expr" >&2
    return 1
  }
  # 轉碼那組的其他關鍵旗標也要真的被測到，否則「能力實測」只是名字對得上
  local flag
  for flag in '-c:v libx264' '-c:a aac' '-movflags +faststart' '-pix_fmt yuv420p'; do
    grep -qF -- "$flag" "$CHECK" || { echo "FAIL: 檢查腳本沒測到 ${flag}" >&2; return 1; }
  done
}
