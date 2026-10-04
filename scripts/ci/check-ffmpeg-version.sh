#!/usr/bin/env bash
# scripts/ci/check-ffmpeg-version.sh
#
# 用途（TMO-042）：把「ffmpeg 要能跑我們用的旗標」變成 CI 會擋的檢查，而不是靠人記得。
#
# 背景：CI 的 ubuntu（apt ffmpeg 6.x）與 macOS（brew ffmpeg 8.x）版本不同；
#   ffmpeg 8 已移除 `-vsync`（本 repo 已全面改用 `-fps_mode`，見 AC-V11）。
#   只驗版本號不夠（版本夠新也可能在 filter/flag 上有變動），所以本腳本驗兩層：
#     ① 版本底線：>= 5.1（`-fps_mode` 自 ffmpeg 5.1 起取代 `-vsync`）
#     ② 能力實測：真的用「本 repo 用到的旗標組合」跑一次 tiny transcode
#        （`-vf select=.../showinfo` + `-fps_mode vfr` + `-f null -`，見 wiki-extract-video.sh extract_chapters）
#
# 用法：scripts/ci/check-ffmpeg-version.sh
# 環境：FFMPEG_BIN / FFPROBE_BIN（預設 ffmpeg / ffprobe；測試用假殼可覆寫）
set -uo pipefail

FFMPEG_BIN="${FFMPEG_BIN:-ffmpeg}"
FFPROBE_BIN="${FFPROBE_BIN:-ffprobe}"
MIN_MAJOR=5
MIN_MINOR=1

fail() {
    echo "::error::$1"
    exit 1
}

command -v "$FFMPEG_BIN" >/dev/null 2>&1 || fail "找不到 ffmpeg（$FFMPEG_BIN）"
command -v "$FFPROBE_BIN" >/dev/null 2>&1 || fail "找不到 ffprobe（$FFPROBE_BIN）"

ff_line="$("$FFMPEG_BIN" -version 2>/dev/null | head -n1)"
[[ -n "$ff_line" ]] || fail "$FFMPEG_BIN -version 沒有輸出（工具可能壞掉）"

# 例：ffmpeg version 7.1 Copyright (c) 2000-2024 the FFmpeg developers
ver="$(printf '%s\n' "$ff_line" | sed -n 's/^ffmpeg version \([0-9][0-9]*\(\.[0-9][0-9]*\)\{0,2\}\).*/\1/p')"
[[ -n "$ver" ]] || fail "無法從版本字串解析版本號：$ff_line"

major="${ver%%.*}"
rest="${ver#*.}"
minor="${rest%%.*}"

if [[ "$major" -lt "$MIN_MAJOR" ]]; then
    fail "ffmpeg $ver 太舊（底線 $MIN_MAJOR.$MIN_MINOR：-fps_mode 自 5.1 起取代 -vsync）"
fi
if [[ "$major" -eq "$MIN_MAJOR" && "$minor" -lt "$MIN_MINOR" ]]; then
    fail "ffmpeg $ver 太舊（底線 $MIN_MAJOR.$MIN_MINOR：-fps_mode 自 5.1 起取代 -vsync）"
fi

# 能力實測：跟 extract_chapters() 同一組旗標；舊版／改名的話這裡會非 0
cap_out="$("$FFMPEG_BIN" -hide_banner -loglevel error \
    -f lavfi -i "testsrc=duration=0.5:size=64x64:rate=10" \
    -vf "select=gt(scene\,0.1),showinfo" \
    -fps_mode vfr \
    -f null - 2>&1)"
cap_rc=$?
if [[ $cap_rc -ne 0 ]]; then
    echo "$cap_out" >&2
    fail "ffmpeg $ver 無法執行本 repo 使用的旗標組合（-vf select/showinfo + -fps_mode vfr + -f null -），rc=$cap_rc"
fi

ffprobe_ver="$("$FFPROBE_BIN" -version 2>/dev/null | head -n1)"
[[ -n "$ffprobe_ver" ]] || fail "$FFPROBE_BIN -version 沒有輸出"

echo "OK: ffmpeg $ver (>= $MIN_MAJOR.$MIN_MINOR) 且旗標組合可用"
echo "  $ff_line"
echo "  $ffprobe_ver"