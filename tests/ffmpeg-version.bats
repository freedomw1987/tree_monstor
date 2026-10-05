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

@test "FV-1: 本機 ffmpeg 版本與旗標組合通過檢查（且印出版本）" {
  [ -x "$CHECK" ]
  run bash "$CHECK"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 本機 ffmpeg 未通過版本/能力檢查：$output" >&2
    return 1
  }
  [[ "$output" == *"OK: ffmpeg "* ]]
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

@test "FV-2: 太舊的 ffmpeg（4.4.2）必須被擋且說明原因" {
  make_fake_ffmpeg "$FAKE_BIN/ffmpeg-old" \
    "ffmpeg version 4.4.2 Copyright (c) 2000-2021 the FFmpeg developers"
  make_fake_ffprobe "$FAKE_BIN/ffprobe"
  run env FFMPEG_BIN="$FAKE_BIN/ffmpeg-old" FFPROBE_BIN="$FAKE_BIN/ffprobe" bash "$CHECK"
  [ "$status" -ne 0 ] || { echo "FAIL: 舊版 ffmpeg 竟然通過" >&2; return 1; }
  [[ "$output" == *"太舊"* ]]
  [[ "$output" == *"4.4.2"* ]]
}

@test "FV-3: 5.0（差一個 minor）也要擋（底線是 5.1 不是 5）" {
  make_fake_ffmpeg "$FAKE_BIN/ffmpeg-50" "ffmpeg version 5.0 Copyright"
  make_fake_ffprobe "$FAKE_BIN/ffprobe"
  run env FFMPEG_BIN="$FAKE_BIN/ffmpeg-50" FFPROBE_BIN="$FAKE_BIN/ffprobe" bash "$CHECK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"太舊"* ]]
}

@test "FV-4: 版本夠新但旗標組合失效 → 必須擋（能力層，不只比版本號）" {
  # 版本 6.0 看起來沒問題，但實際跑我們的旗標組合時失敗
  make_fake_ffmpeg "$FAKE_BIN/ffmpeg-noflag" "ffmpeg version 6.0 Copyright"
  make_fake_ffprobe "$FAKE_BIN/ffprobe"
  run env FFMPEG_BIN="$FAKE_BIN/ffmpeg-noflag" FFPROBE_BIN="$FAKE_BIN/ffprobe" bash "$CHECK"
  [ "$status" -ne 0 ] || { echo "FAIL: 旗標失效竟然通過" >&2; return 1; }
  [[ "$output" == *"旗標組合"* ]]
}

@test "FV-5: 缺 ffmpeg / ffprobe 要擋（不是只比版本）" {
  make_fake_ffprobe "$FAKE_BIN/ffprobe"
  run env FFMPEG_BIN="$BATS_TEST_TMPDIR/does-not-exist" FFPROBE_BIN="$FAKE_BIN/ffprobe" \
      bash "$CHECK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"找不到 ffmpeg"* ]]

  make_fake_ffmpeg "$FAKE_BIN/ffmpeg-ok" "ffmpeg version 6.0 Copyright"
  run env FFMPEG_BIN="$FAKE_BIN/ffmpeg-ok" FFPROBE_BIN="$BATS_TEST_TMPDIR/no-ffprobe" \
      bash "$CHECK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"找不到 ffprobe"* ]]
}

@test "FV-6: CI 在 test job 內跑這個檢查，且不是 || true 假綠" {
  local block
  block=$(awk '/name: Verify ffmpeg version and flags/{flag=1} flag{print} /^      - name:/&&flag&&!/Verify ffmpeg version and flags/{exit}' "$CI_YML")
  # 防空過：真的要抓到含該腳本的 step（含 name 行）
  [[ -n "$block" ]] || { echo "FAIL: ci.yml 找不到跑 check-ffmpeg-version.sh 的 step" >&2; return 1; }
  [[ "$block" == *"check-ffmpeg-version.sh"* ]]
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

@test "FV-7: CONTRIBUTING 寫明版本底線與 -vsync 移除清單" {
  grep -q '5\.1' "$CONTRIB" || { echo "FAIL: CONTRIBUTING 未寫 ffmpeg 版本底線 5.1" >&2; return 1; }
  grep -q -- '-vsync' "$CONTRIB" || { echo "FAIL: CONTRIBUTING 未寫 -vsync 移除說明" >&2; return 1; }
  grep -q 'check-ffmpeg-version\.sh' "$CONTRIB" || {
    echo "FAIL: CONTRIBUTING 未說明版本檢查腳本" >&2
    return 1
  }
}
