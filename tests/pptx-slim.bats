#!/usr/bin/env bats
#
# tests/pptx-slim.bats
#
# pptx-slim 工具鏈的**功能**探針（不是「檔案存在」那種空過）：
#   1. 用 ffmpeg + python-pptx 現場造一個含 2 支影片、3 頁的 pptx fixture
#   2. 跑 probe / shrink / repack / verify，斷言：真的變小、非媒體逐 byte 相同、時長不變
#   3. 種壞（mutant）證明 verify 咬得住 —— 防止「跑完都說 OK」的假綠
#
# 依賴：ffmpeg / ffprobe / python3 + python-pptx（CI 已安裝）。

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPTS="$REPO_ROOT/skills/pptx-slim/scripts"
  W="$BATS_TEST_TMPDIR/work"
  mkdir -p "$W"
  export REPO_ROOT SCRIPTS W

  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc=size=640x360:rate=25:duration=3" \
    -f lavfi -i "sine=frequency=440:duration=3" \
    -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac -shortest "$W/v1.mp4"
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc=size=320x180:rate=25:duration=1" \
    -c:v libx264 -crf 20 -pix_fmt yuv420p "$W/v2.mp4"
  # 一張真圖片：驗證「換掉的圖片不是非媒體 entry」（G2b 不能誤判）
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc=size=320x240:rate=1" -frames:v 1 "$W/img.png"

  python3 - "$W" <<'PY'
import sys
from pathlib import Path

from pptx import Presentation
from pptx.util import Inches

work = Path(sys.argv[1])
prs = Presentation()
for idx, movie in enumerate(("v1.mp4", "v2.mp4")):
    slide = prs.slides.add_slide(prs.slide_layouts[5])
    slide.shapes.title.text = f"movie {idx + 1}"
    slide.shapes.add_movie(str(work / movie), Inches(1), Inches(2),
                           Inches(6), Inches(3.4), mime_type="video/mp4")
last = prs.slides.add_slide(prs.slide_layouts[5])
last.shapes.title.text = "text + image"
last.shapes.add_picture(str(work / "img.png"), Inches(1), Inches(2), Inches(4), Inches(3))
prs.save(str(work / "deck.pptx"))
PY
}

file_size() {
  wc -c < "$1" | tr -d ' '
}

shrink_repack_verify() {
  # $1 = crf, $2 = 新檔路徑
  run python3 "$SCRIPTS/pptx-shrink-media.py" --src "$W/deck.pptx" --out "$W/enc-$1" --crf "$1"
  [ "$status" -eq 0 ]
  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$2" --media-dir "$W/enc-$1"
  [ "$status" -eq 0 ]
}

@test "PPTX-SLIM-1: the probe reads the media ratio and video specs (--specs)" {
  run python3 "$SCRIPTS/pptx-probe.py" "$W/deck.pptx" --top 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"分類"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:66: assertion failed' >&2; return 1; }
  [[ "$output" == *"video"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:68: assertion failed' >&2; return 1; }

  run python3 "$SCRIPTS/pptx-probe.py" "$W/deck.pptx" --specs
  [ "$status" -eq 0 ]
  # 不只看標題：要真的抓到兩支影片的顯示尺寸（640x360 / 320x180）
  [[ "$output" == *"640x360"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:74: assertion failed' >&2; return 1; }
  [[ "$output" == *"320x180"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:76: assertion failed' >&2; return 1; }
}

@test "PPTX-SLIM-2: shrink plus repack really shrinks and non-media stays byte-identical" {
  shrink_repack_verify 24 "$W/slim.pptx"
  [ "$(file_size "$W/slim.pptx")" -lt "$(file_size "$W/deck.pptx")" ]

  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/slim.pptx" \
    --media-dir "$W/enc-24" --fast
  [ "$status" -eq 0 ]
  [[ "$output" == *"[PASS] G2b"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:87: assertion failed' >&2; return 1; }
  [[ "$output" == *"四關全綠"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:89: assertion failed' >&2; return 1; }
}

@test "PPTX-SLIM-3: a larger result keeps the original (--crf 0 lossless) and matches its size" {
  run python3 "$SCRIPTS/pptx-shrink-media.py" --src "$W/deck.pptx" --out "$W/enc-0" --crf 0
  [ "$status" -eq 0 ]
  # 防呆必須在「轉碼那一步」就生效（不能等到 repack 才處理）：逐支退回原檔，不是留著更大的檔
  [[ "$output" == *"KEPT(bigger)"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:97: assertion failed' >&2; return 1; }

  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/keep.pptx" --media-dir "$W/enc-0"
  [ "$status" -eq 0 ]
  [ "$(file_size "$W/keep.pptx")" -eq "$(file_size "$W/deck.pptx")" ]

  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/keep.pptx" --fast
  [ "$status" -eq 0 ]
  [[ "$output" == *"被替換的媒體檔數：0"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:106: assertion failed' >&2; return 1; }
}

@test "PPTX-SLIM-4: verify catches tampered non-media files (mutant)" {
  python3 - "$W" <<'PY'
import sys
import zipfile
from pathlib import Path

work = Path(sys.argv[1])
with zipfile.ZipFile(work / "deck.pptx") as zin, zipfile.ZipFile(work / "bad-xml.pptx", "w") as zout:
    for info in zin.infolist():
        data = zin.read(info.filename)
        if info.filename == "ppt/slides/slide3.xml":
            data = data.replace(b"<a:t>", b"<a:t> ")
        zout.writestr(info, data)
PY
  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/bad-xml.pptx" --fast
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL] G2b"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:126: assertion failed' >&2; return 1; }
}

@test "PPTX-SLIM-5: verify catches broken rels chains (mutant)" {
  python3 - "$W" <<'PY'
import sys
import zipfile
from pathlib import Path

work = Path(sys.argv[1])
with zipfile.ZipFile(work / "deck.pptx") as zin:
    rels = [n for n in zin.namelist() if n.endswith(".rels")]
    victim = next(n for n in rels if b"slideLayout" in zin.read(n))
    original = zin.read(victim)
    # 只改 **Target**（不能改到 Type 屬性的 URL —— 那串也含 "slideLayout"，改了不會斷鏈）
    broken = original.replace(b'Target="../slideLayouts/slideLayout',
                              b'Target="../slideLayouts/MISSING-slideLayout', 1)
    assert broken != original, "fixture 裡找不到可改的 slideLayout Target"

with zipfile.ZipFile(work / "deck.pptx") as zin, zipfile.ZipFile(work / "bad-rels.pptx", "w") as zout:
    for info in zin.infolist():
        data = zin.read(info.filename)
        if info.filename == victim:
            data = broken
        zout.writestr(info, data)
PY
  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/bad-rels.pptx" --fast
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL] G3a"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:155: assertion failed' >&2; return 1; }
}

@test "PPTX-SLIM-6: repack refuses to overwrite the original (--dst equal to --src must be red)" {
  mkdir -p "$W/enc-x"
  cp "$W/v1.mp4" "$W/enc-x/media1.mp4"
  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/deck.pptx" --media-dir "$W/enc-x"
  [ "$status" -ne 0 ]
  [[ "$output" == *"不可與 --src 相同"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:164: assertion failed' >&2; return 1; }
}

@test "PPTX-SLIM-7: a replaced image is not misreported as tampered non-media (regression: P1 false red)" {
  run python3 "$SCRIPTS/pptx-shrink-media.py" --src "$W/deck.pptx" --out "$W/enc-img" --crf 24
  [ "$status" -eq 0 ]
  # 目錄裡多放一張「重壓過的」圖片：repack 會把影片與圖片一起換掉
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc=size=160x120:rate=1" -frames:v 1 "$W/enc-img/image1.png"

  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/reimg.pptx" --media-dir "$W/enc-img"
  [ "$status" -eq 0 ]

  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/reimg.pptx" \
    --media-dir "$W/enc-img" --fast
  [ "$status" -eq 0 ]
  [[ "$output" == *"[PASS] G2b"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:181: assertion failed' >&2; return 1; }
  [[ "$output" == *"[PASS] G2c"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:183: assertion failed' >&2; return 1; }
  [[ "$output" == *"image1.png"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:185: assertion failed' >&2; return 1; }
}

@test "PPTX-SLIM-8: an empty or wrong --media-dir must be red (no silent pass)" {
  shrink_repack_verify 24 "$W/slim2.pptx"
  mkdir -p "$W/empty"
  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/slim2.pptx" \
    --media-dir "$W/empty" --fast
  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL] G2c"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:195: assertion failed' >&2; return 1; }

  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/slim2.pptx" \
    --media-dir "$W/no-such-dir" --fast
  [ "$status" -eq 2 ]
  [[ "$output" == *"不是目錄"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:201: assertion failed' >&2; return 1; }
}

@test "PPTX-SLIM-9: repack does not overwrite an existing --dst by default (needs --force)" {
  mkdir -p "$W/enc-y"
  cp "$W/v1.mp4" "$W/enc-y/media1.mp4"
  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/out.pptx" --media-dir "$W/enc-y"
  [ "$status" -eq 0 ]

  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/out.pptx" --media-dir "$W/enc-y"
  [ "$status" -ne 0 ]
  [[ "$output" == *"已存在"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:213: assertion failed' >&2; return 1; }

  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/out.pptx" \
    --media-dir "$W/enc-y" --force
  [ "$status" -eq 0 ]
}

@test "PPTX-SLIM-10: --only prefers exact matches (media1 does not also select media10)" {
  # 真實案檔是 media1..media17：'media1' 正好是 media10-17 的前綴
  cp "$W/v1.mp4" "$W/media1.mp4"
  cp "$W/v2.mp4" "$W/media10.mp4"
  python3 - "$W" <<'PY'
import sys
import zipfile
from pathlib import Path

from pptx import Presentation
from pptx.util import Inches

work = Path(sys.argv[1])
prs = Presentation()
for movie in ("media1.mp4", "media10.mp4"):
    slide = prs.slides.add_slide(prs.slide_layouts[5])
    slide.shapes.title.text = movie
    slide.shapes.add_movie(str(work / movie), Inches(1), Inches(2),
                           Inches(6), Inches(3.4), mime_type="video/mp4")
tmp = work / "deck10-tmp.pptx"
prs.save(str(tmp))
# python-pptx 固定編 media1/media2：把 media2.mp4 改名成 media10.mp4（含 rels 與 Content_Types）
with zipfile.ZipFile(tmp) as zin, zipfile.ZipFile(work / "deck10.pptx", "w", zipfile.ZIP_DEFLATED) as zout:
    for info in zin.infolist():
        data = zin.read(info.filename)
        if info.filename == "ppt/media/media2.mp4":
            info.filename = "ppt/media/media10.mp4"
        elif not info.filename.endswith(".mp4"):
            data = data.replace(b"media2.mp4", b"media10.mp4")
        zout.writestr(info, data)
PY
  # 精確命中：只該選到 media1.mp4（子字串比對才會連 media10 一起選）
  run python3 "$SCRIPTS/pptx-shrink-media.py" --src "$W/deck10.pptx" --out "$W/enc-only" \
    --only media1 --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"待處理 1 支：media1.mp4"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:256: assertion failed' >&2; return 1; }
  [[ "$output" != *"media10.mp4"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:258: assertion failed' >&2; return 1; }
  [[ "$output" != *"改用子字串"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:260: assertion failed' >&2; return 1; }

  # 反面：真的沒有精確命中時才退回子字串，且必須把命中哪幾支講出來
  run python3 "$SCRIPTS/pptx-shrink-media.py" --src "$W/deck10.pptx" --out "$W/enc-any" \
    --only media --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"待處理 2 支"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:267: assertion failed' >&2; return 1; }
  [[ "$output" == *"改用子字串"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:269: assertion failed' >&2; return 1; }
  [[ "$output" == *"media10.mp4"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:271: assertion failed' >&2; return 1; }

  # --list 是「先看不跑」：不得留下空的 --out 目錄（副作用）
  [ ! -d "$W/enc-only" ]
  [ ! -d "$W/enc-any" ]

  # 打錯的第二個詞不得靜默丟掉（否則以為壓了兩支、其實只有一支）
  run python3 "$SCRIPTS/pptx-shrink-media.py" --src "$W/deck10.pptx" --out "$W/enc-typo" \
    --only media1,typo --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"待處理 1 支：media1.mp4"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:282: assertion failed' >&2; return 1; }
  [[ "$output" == *"沒命中任何影片：typo"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:284: assertion failed' >&2; return 1; }

  # 全部沒命中仍然要 FAIL（維持既有契約）
  run python3 "$SCRIPTS/pptx-shrink-media.py" --src "$W/deck10.pptx" --out "$W/enc-none" \
    --only typo --list
  [ "$status" -eq 1 ]
  [[ "$output" == *"指到不存在的影片"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:291: assertion failed' >&2; return 1; }
}

@test "PPTX-SLIM-11: a missing video in dst makes G4 decide FAIL itself (not a KeyError traceback)" {
  shrink_repack_verify 24 "$W/slim.pptx"
  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/slim.pptx"
  [ "$status" -eq 0 ]

  # 造一個「G2a 不齊全」的新檔：直接從好檔複製後刪掉一支媒體 entry
  python3 - "$W/slim.pptx" "$W/broken.pptx" <<'PY'
import sys
import zipfile

from pathlib import Path

src, dst = Path(sys.argv[1]), Path(sys.argv[2])
with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w") as zout:
    for info in zin.infolist():
        if info.filename == "ppt/media/media1.mp4":
            continue
        zout.writestr(info, zin.read(info.filename))
PY
  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/broken.pptx"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL] G2a"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:316: assertion failed' >&2; return 1; }
  # 重點：G4 自己要印判準行，不能讓 zipfile.KeyError 把後面的關卡炸掉
  [[ "$output" == *"[FAIL] G4 時長漂移"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:319: assertion failed' >&2; return 1; }
  [[ "$output" != *"Traceback"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:321: assertion failed' >&2; return 1; }
}
@test "PPTX-SLIM-12: verify catches a corrupted CRC in the new file (mutant)" {
  shrink_repack_verify 24 "$W/slim.pptx"
  # 造一個「zip 讀得完但某個 entry 的 CRC 對不上」的檔：把 STORED 媒體 payload 改一個 byte，
  # CRC 留在原處不動。這是 G1 存在的理由（開會才發現壞檔，代價最大），所以必須有探針咬住。
  python3 - "$W/slim.pptx" "$W/bad-crc.pptx" <<'PY'
import shutil
import struct
import sys
from pathlib import Path

src, dst = Path(sys.argv[1]), Path(sys.argv[2])
shutil.copyfile(src, dst)
buf = bytearray(dst.read_bytes())
patched = None
pos = 0
while True:
    pos = buf.find(b"PK\x03\x04", pos)
    if pos < 0:
        break
    _sig, _ver, _flag, method, _t, _d, _crc, csize, usize, nlen, elen = struct.unpack_from(
        "<IHHHHHIIIHH", buf, pos)
    name = bytes(buf[pos + 30:pos + 30 + nlen]).decode("utf-8", "replace")
    start = pos + 30 + nlen + elen
    # 只挑 ZIP_STORED（method 0）的媒體：改 byte 不會壞掉 deflate 串流，CRC 一定對不上
    if method == 0 and name.endswith(".mp4") and usize >= 4096 and csize == usize:
        buf[start + usize // 2] ^= 0xFF
        patched = name
        break
    pos += 4
assert patched, "fixture 裡找不到 ZIP_STORED 的媒體可改（repack 的輸出應該都是 STORED）"
dst.write_bytes(bytes(buf))
print("patched", patched)
PY
  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/bad-crc.pptx" --fast
  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL] G1 新檔 CRC"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:359: assertion failed' >&2; return 1; }
  # 不能只是「剛好壞掉」：G1 判準行要指出是哪個 entry
  [[ "$output" == *"壞 entry"* ]] || {
    echo 'FAIL: tests/pptx-slim.bats:362: assertion failed' >&2; return 1; }
}

