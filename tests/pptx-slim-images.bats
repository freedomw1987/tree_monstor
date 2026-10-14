#!/usr/bin/env bats
#
# tests/pptx-slim-images.bats
#
# pptx-slim 的**圖片**管線功能探針：
#   1. 現場用 ffmpeg + python-pptx 造 fixture：8-bit PNG / 16-bit PNG / JPEG / TIFF + 1 支影片
#   2. 斷言 lossless 真的無損（像素逐點相同）、該跳過的格式真的跳過（不是靜默亂壓）
#   3. 斷言 lossy 的「長邊上限 / PSNR 門檻」是硬門檻，不是裝飾
#   4. 種壞證明 G2d 咬得住（lossy 產物拿去用 lossless 驗必須紅）
#
# 依賴：ffmpeg / python3 + python-pptx + Pillow（CI 已安裝）。

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPTS="$REPO_ROOT/skills/pptx-slim/scripts"
  W="$BATS_TEST_TMPDIR/work"
  mkdir -p "$W"
  export REPO_ROOT SCRIPTS W

  # 8-bit PNG（可無損壓）：故意比 --image-max-edge 大，才能驗有損縮圖
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i "testsrc=size=1200x900:rate=1" \
    -frames:v 1 "$W/png8.png"
  # 16-bit PNG：Pillow 讀入會降位深 → 必須被護欄擋下（不碰）
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i "testsrc=size=640x480:rate=1" \
    -frames:v 1 -pix_fmt rgb48be "$W/png16.png"
  # JPEG：無損重編不可能 → lossless 必須明示 SKIP
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i "testsrc=size=1000x750:rate=1" \
    -frames:v 1 "$W/photo.jpg"
  # TIFF：簡報掃描圖的典型情況（無壓縮）→ deflate 可省 9 成以上
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i "testsrc=size=1000x750:rate=1" \
    -frames:v 1 "$W/scan.tif"
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i "testsrc=size=320x180:rate=25:duration=1" \
    -c:v libx264 -crf 20 -pix_fmt yuv420p "$W/clip.mp4"

  python3 - "$W" <<'PY'
import sys
from pathlib import Path

from PIL import Image, ImageCms
from pptx import Presentation
from pptx.util import Inches

work = Path(sys.argv[1])
# 給 8-bit PNG 種一個 ICC profile：掉了不會被抓到（像素值不變），但顏色會靜默改變
icc = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
with Image.open(work / "png8.png") as im:
    im.save(work / "png8.png", icc_profile=icc)
prs = Presentation()
# 插入順序 = mediaN 編號：1=png8(png) 2=png16(png) 3=photo(jpg) 4=scan(tiff)
for name in ("png8.png", "png16.png", "photo.jpg", "scan.tif"):
    slide = prs.slides.add_slide(prs.slide_layouts[5])
    slide.shapes.title.text = name
    slide.shapes.add_picture(str(work / name), Inches(0.5), Inches(1.6),
                            Inches(6), Inches(4.5))
movie_slide = prs.slides.add_slide(prs.slide_layouts[5])
movie_slide.shapes.title.text = "movie + image 混合"
movie_slide.shapes.add_movie(str(work / "clip.mp4"), Inches(0.5), Inches(1.6),
                             Inches(6), Inches(3.4), mime_type="video/mp4")
prs.save(str(work / "deck.pptx"))
PY
}

file_size() {
  wc -c < "$1" | tr -d ' '
}

# 兩張圖解碼後像素是否逐點相同（0＝相同）；用 Pillow 而不是比檔案大小
pixels_same() {
  python3 - "$1" "$2" <<'PY'
import sys
from PIL import Image

with Image.open(sys.argv[1]) as a, Image.open(sys.argv[2]) as b:
    same = a.size == b.size and a.convert("RGBA").tobytes() == b.convert("RGBA").tobytes()
sys.exit(0 if same else 1)
PY
}

# 印出圖片長邊（給「縮圖上限」斷言用）
long_edge() {
  python3 -c 'import sys;from PIL import Image
with Image.open(sys.argv[1]) as im: print(max(im.size))' "$1"
}

# 圖片有沒有 ICC profile（yes/no）
has_icc() {
  python3 -c 'import sys;from PIL import Image
with Image.open(sys.argv[1]) as im: print("yes" if "icc_profile" in im.info else "no")' "$1"
}

media_bytes() {
  # pptx 內所有媒體 entry 的「未壓縮」總量（含影片／圖片）
  python3 -c 'import sys, zipfile
ext = {".mp4", ".mov", ".m4v", ".avi", ".mkv", ".png", ".jpg", ".jpeg", ".tif",
       ".tiff", ".gif", ".bmp", ".webp", ".emf", ".wmf", ".svg", ".mp3", ".wav"}
with zipfile.ZipFile(sys.argv[1]) as z:
    print(sum(i.file_size for i in z.infolist()
              if "/media/" in "/" + i.filename and i.filename.lower().endswith(tuple(ext))))' "$1"
}

shrink_images() {
  # $1 = --out 目錄，其餘參數往後傳
  local out="$1"
  shift
  run python3 "$SCRIPTS/pptx-shrink-images.py" --src "$W/deck.pptx" --out "$out" "$@"
  [ "$status" -eq 0 ]
}

@test "PPTX-SLIM-IMG-1: --list 列得出規格，且不會建輸出目錄" {
  run python3 "$SCRIPTS/pptx-shrink-images.py" --src "$W/deck.pptx" --out "$W/enc-list" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"1200x900"* ]]
  [[ "$output" == *"640x480"* ]]
  [ ! -d "$W/enc-list" ]
}

@test "PPTX-SLIM-IMG-2: 8-bit PNG 無損重壓 → 變小且像素逐點相同" {
  shrink_images "$W/enc-ls" --mode lossless
  [[ "$output" == *"image1.png"* ]]
  [[ "$output" == *"ENCODED"* ]]
  [ "$(file_size "$W/enc-ls/image1.png")" -lt "$(file_size "$W/png8.png")" ]
  pixels_same "$W/png8.png" "$W/enc-ls/image1.png"
  # 對照組：來源真的帶 ICC（不然這條會恒真），輸出必須也帶著
  [ "$(has_icc "$W/png8.png")" = "yes" ]
  [ "$(has_icc "$W/enc-ls/image1.png")" = "yes" ]
}

@test "PPTX-SLIM-IMG-3: 16-bit PNG 被護欄擋下（明示 SKIP，且原檔照抄）" {
  shrink_images "$W/enc-16" --mode lossless
  [[ "$output" == *"16-bit"* ]]
  cmp -s "$W/png16.png" "$W/enc-16/image2.png" || {
    echo "FAIL: 16-bit PNG 被動過（位深掉了）" >&2; return 1; }
}

@test "PPTX-SLIM-IMG-4: lossless 對 JPEG 明示 SKIP（無損不可能，不偷偷有損）" {
  shrink_images "$W/enc-jpg" --mode lossless
  [[ "$output" == *"JPEG 無損重編不可能"* ]]
  cmp -s "$W/photo.jpg" "$W/enc-jpg/image3.jpg" || {
    echo "FAIL: JPEG 在 lossless 模式被有損重編" >&2; return 1; }
}

@test "PPTX-SLIM-IMG-5: TIFF 無損改 deflate → 省 5 成以上且像素相同" {
  shrink_images "$W/enc-tif" --mode lossless
  local before after
  before=$(file_size "$W/scan.tif")
  after=$(file_size "$W/enc-tif/image4.tiff")
  [ "$after" -lt "$((before / 2))" ] || {
    echo "FAIL: TIFF 只從 $before 縮到 ${after}（不到 5 成）" >&2; return 1; }
  pixels_same "$W/scan.tif" "$W/enc-tif/image4.tiff"
}

@test "PPTX-SLIM-IMG-6: lossy 的 --image-max-edge 是硬上限（真的縮圖）" {
  shrink_images "$W/enc-edge" --mode lossy --image-max-edge 800 --image-quality 80
  # 只對「真的重編」的圖片要求上限：KEPT/SKIP 是刻意保留原檔，尺寸本來就可能超標。
  # （實測踩過：testsrc 的 1200x900 PNG 縮到 800x600 反而沒比較小，那張被 KEPT，
  #   把它算進「硬上限」就會誤紅 —— 這條要咬的是「有重編卻沒縮」。）
  local name _before _after st edge encoded=0
  while IFS=$'\t' read -r name _before _after st; do
    [ "$st" = "ENCODED" ] || continue
    encoded=$((encoded + 1))
    edge=$(long_edge "$W/enc-edge/$name")
    [ "$edge" -le 800 ] || { echo "FAIL: $name 長邊 $edge > 800" >&2; return 1; }
  done < "$W/enc-edge/image-log.tsv"
  [ "$encoded" -ge 2 ] || {
    echo "FAIL: 只有 $encoded 張真的重編（探針失去意義）" >&2; return 1; }
  [ "$(long_edge "$W/enc-edge/image4.tiff")" -eq 800 ]
}

@test "PPTX-SLIM-IMG-7: lossy 不換容器（檔名與魔術數字都不變）" {
  shrink_images "$W/enc-fmt" --mode lossy --image-max-edge 400
  # 4 張原圖都要在輸出目錄（檔名、副檔名一字不改）；影格的 poster 圖也會被處理，故不鎖總數
  local name
  for name in image1.png image2.png image3.jpg image4.tiff; do
    [ -f "$W/enc-fmt/$name" ] || { echo "FAIL: 缺 ${name}（改到檔名了）" >&2; return 1; }
  done
  python3 - "$W/enc-fmt" <<'PY'
import sys
from pathlib import Path

d = Path(sys.argv[1])
want = {"image1.png": b"\x89PNG\r\n\x1a\n", "image2.png": b"\x89PNG\r\n\x1a\n",
        "image3.jpg": b"\xff\xd8", "image4.tiff": b"II*\x00"}
bad = [name for name, sig in want.items()
       if not (d / name).read_bytes().startswith(sig)]
if bad:
    print(f"FAIL: 容器被換掉：{bad}")
    sys.exit(1)
PY
}

@test "PPTX-SLIM-IMG-8: --only 精確命中；打錯詞要出聲（WARN）" {
  shrink_images "$W/enc-only" --only "image1.png" --mode lossless
  [[ "$output" == *"待處理 1 張"* ]]
  [ -f "$W/enc-only/image1.png" ]
  [ ! -f "$W/enc-only/image4.tiff" ]

  run python3 "$SCRIPTS/pptx-shrink-images.py" --src "$W/deck.pptx" \
    --out "$W/enc-only2" --only "image1.png,imageNOPE" --mode lossless
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *"imageNOPE"* ]]
}

@test "PPTX-SLIM-IMG-9: 圖片與影片共用同一媒體目錄 → 一次 repack、四關含 G2d 全綠" {
  run python3 "$SCRIPTS/pptx-shrink-media.py" --src "$W/deck.pptx" --out "$W/enc-mix"
  [ "$status" -eq 0 ]
  shrink_images "$W/enc-mix" --mode lossless
  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/mix.pptx" \
    --media-dir "$W/enc-mix"
  [ "$status" -eq 0 ]
  # 媒體「內容」總量真的下降（1.74 MiB TIFF → 30 KiB）；用未壓縮大小比，才不會被
  # zip 的 store／deflate 選擇扭曲 —— 小 fixture 的原始 entry 本來就被 deflate 過，
  # 檔案層面再省一次不會反映在「整包大小」上（真實 deck 的贏面在未壓縮的影片）
  local before after
  before=$(media_bytes "$W/deck.pptx")
  after=$(media_bytes "$W/mix.pptx")
  [ "$after" -lt "$((before - 1000000))" ] || {
    echo "FAIL: 媒體總量沒降：$before → $after" >&2; return 1; }

  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/mix.pptx" \
    --media-dir "$W/enc-mix" --image-mode lossless --fast
  [ "$status" -eq 0 ]
  [[ "$output" == *"[PASS] G2b"* ]]
  [[ "$output" == *"[PASS] G2c"* ]]
  [[ "$output" == *"[PASS] G2d"* ]]
  [[ "$output" == *"四關全綠"* ]]
}

@test "PPTX-SLIM-IMG-10: G2d 咬得住畫質變化（lossy 產物用 lossless 驗必須紅）" {
  shrink_images "$W/enc-guard" --mode lossy --image-max-edge 400 --image-quality 60
  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/lossy.pptx" \
    --media-dir "$W/enc-guard"
  [ "$status" -eq 0 ]

  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/lossy.pptx" \
    --image-mode lossless --fast
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL] G2d"* ]]
  [[ "$output" == *"像素被動過"* ]]
}

@test "PPTX-SLIM-IMG-11: G2d 的 PSNR 門檻咬得住（同一個檔，門檻高紅、門檻低綠）" {
  shrink_images "$W/enc-q5" --mode lossy --image-quality 5 --image-max-edge 4000
  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/q5.pptx" \
    --media-dir "$W/enc-q5"
  [ "$status" -eq 0 ]

  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/q5.pptx" \
    --image-mode lossy --image-psnr 35 --fast
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL] G2d"* ]]
  [[ "$output" == *"PSNR"* ]]

  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/q5.pptx" \
    --image-mode lossy --image-psnr 20 --fast
  [ "$status" -eq 0 ]
  [[ "$output" == *"[PASS] G2d"* ]]
}

@test "PPTX-SLIM-IMG-12: 已壓過的圖再壓一次不會變大（保留原檔防呆）" {
  shrink_images "$W/enc-mix2" --mode lossless
  run python3 "$SCRIPTS/pptx-shrink-images.py" --src "$W/enc-mix2" --out "$W/enc-again" \
    --mode lossless
  [ "$status" -eq 0 ]
  [[ "$output" == *"KEPT(not smaller)"* ]]
  [ "$(file_size "$W/enc-again/image1.png")" -le "$(file_size "$W/enc-mix2/image1.png")" ]
}

@test "PPTX-SLIM-IMG-13: --min-bytes 讓小圖整批不動（不寫 log、不建半成品）" {
  shrink_images "$W/enc-min" --mode lossless --min-bytes 10000000
  [[ "$output" == *"小於 --min-bytes"* ]]
  [ ! -f "$W/enc-min/image-log.tsv" ]
}

@test "PPTX-SLIM-IMG-14: lossy 的長邊上限不誤殺刻意保留的原檔（G2d 要綠）" {
  # 只壓 image1.png；image3.jpg / image4.tiff 是 1000x750（> 800）但維持原樣。
  # 「刻意保留（KEPT／SKIP／沒選到）」不是「重編後超標」，把它算進硬上限就是誤紅。
  shrink_images "$W/enc-keep" --mode lossy --image-max-edge 800 --image-quality 80 --only image1.png
  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/keep.pptx" \
    --media-dir "$W/enc-keep"
  [ "$status" -eq 0 ]
  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/keep.pptx" \
    --media-dir "$W/enc-keep" --image-mode lossy --image-max-edge 800 --fast
  [ "$status" -eq 0 ]
  [[ "$output" == *"[PASS] G2d"* ]]
  [[ "$output" == *"保留的原檔"* ]]
}

@test "PPTX-SLIM-IMG-15: 真的重編過又超上限 → G2d 必須紅（豁免沒吃掉咬合力）" {
  mkdir -p "$W/enc-big"
  # 用 Pillow 把同一張圖以「同尺寸、不同 bytes、低壓縮」重存 = 重編了卻沒縮到上限
  python3 - "$W/deck.pptx" "$W/enc-big" <<'PY'
import sys
import zipfile
from pathlib import Path

from PIL import Image

src, out = Path(sys.argv[1]), Path(sys.argv[2])
with zipfile.ZipFile(src) as z:
    (out / "image1.png").write_bytes(z.read("ppt/media/image1.png"))
with Image.open(out / "image1.png") as im:
    im.convert("RGB").save(out / "image1.png", format="PNG", compress_level=1)
PY
  [ "$(long_edge "$W/enc-big/image1.png")" -eq 1200 ]
  cmp -s "$W/enc-big/image1.png" "$W/png8.png" && {
    echo "FAIL: 測試素材沒有真的改變 bytes（這條會失去意義）" >&2; return 1; }
  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/big.pptx" \
    --media-dir "$W/enc-big"
  [ "$status" -eq 0 ]
  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/big.pptx" \
    --image-mode lossy --image-max-edge 800 --fast
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL] G2d"* ]]
  [[ "$output" == *"長邊 1200 > 800"* ]]
}

@test "PPTX-SLIM-IMG-16: 壞圖（內容不是圖）→ rc=3 且不吐 traceback" {
  mkdir -p "$W/badimg"
  printf 'this is not an image' > "$W/badimg/image1.png"
  run python3 "$SCRIPTS/pptx-shrink-images.py" --src "$W/badimg" --out "$W/badout" --mode lossless
  [ "$status" -eq 3 ]
  [[ "$output" == *"圖片處理失敗"* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "PPTX-SLIM-IMG-17: --png-colors 真的量化 PNG（變調色板、省更多）" {
  shrink_images "$W/enc-pal" --mode lossy --png-colors 16 --image-max-edge 4000
  [ "$(awk -F'\t' '$1=="image1.png"{print $4}' "$W/enc-pal/image-log.tsv")" = "ENCODED" ]
  python3 - "$W/enc-pal/image1.png" <<'PY'
import sys

from PIL import Image

with Image.open(sys.argv[1]) as im:
    used = len(im.getcolors(1 << 20) or [])
    if im.mode != "P" or used > 16:
        print(f"FAIL: 量化沒生效（mode={im.mode}、用色 {used}）")
        sys.exit(1)
PY
  [ "$(file_size "$W/enc-pal/image1.png")" -lt "$(file_size "$W/png8.png")" ]
}

@test "PPTX-SLIM-IMG-18: 預設保留沒更小的原檔；--no-keep-original 才會硬換" {
  shrink_images "$W/enc-nk1" --mode lossy --image-max-edge 800 --image-quality 80
  shrink_images "$W/enc-nk2" --mode lossy --image-max-edge 800 --image-quality 80 --no-keep-original
  [ "$(awk -F'\t' '$1=="image1.png"{print $4}' "$W/enc-nk1/image-log.tsv")" = "KEPT(not smaller)" ]
  [ "$(awk -F'\t' '$1=="image1.png"{print $4}' "$W/enc-nk2/image-log.tsv")" = "ENCODED" ]
  # 硬換的代價：這張圖反而變大 —— 這就是為什麼預設要保留
  [ "$(file_size "$W/enc-nk2/image1.png")" -gt "$(file_size "$W/png8.png")" ]
}

@test "PPTX-SLIM-IMG-19: 只有向量圖（Pillow 解不開）不是壓縮問題 → G2d 明示不適用" {
  python3 - "$W" <<'PY'
import sys
import zipfile
from pathlib import Path

from pptx import Presentation

w = Path(sys.argv[1])
prs = Presentation()
prs.slides.add_slide(prs.slide_layouts[5]).shapes.title.text = "只有向量圖的 deck"
prs.save(str(w / "vec-only.pptx"))
# 塞一個沒有被任何 rels 指到的 .svg（向量圖成對出現是常態，Pillow 永遠解不開）
with zipfile.ZipFile(w / "vec-only.pptx", "a") as z:
    z.writestr("ppt/media/image1.svg",
               "<svg xmlns='http://www.w3.org/2000/svg' width='10' height='10'/>")
PY
  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/vec-only.pptx" --dst "$W/vec-only.pptx" \
    --image-mode lossless --fast
  [ "$status" -eq 0 ]
  [[ "$output" == *"G2d 沒有圖片可比"* ]]
  [[ "$output" != *"FAIL] G2d"* ]]
}

@test "PPTX-SLIM-IMG-20: PSNR 在縮圖尺寸比（不把縮圖放大回母帶 → 不誤殺降採樣）" {
  shrink_images "$W/enc-img20" --mode lossy --image-max-edge 400 --image-quality 85 \
    --only image3.jpg
  run python3 "$SCRIPTS/pptx-repack.py" --src "$W/deck.pptx" --dst "$W/img20.pptx" \
    --media-dir "$W/enc-img20"
  [ "$status" -eq 0 ]
  # 實測這張產物：舊語意（放大回母帶）24.8 dB、新語意（縮到小圖尺寸比）28.5 dB。
  # 27 dB 這條線因此是「語意」的守門員：改回舊語意就會紅。
  run python3 "$SCRIPTS/pptx-verify.py" --src "$W/deck.pptx" --dst "$W/img20.pptx" \
    --image-mode lossy --image-max-edge 400 --image-psnr 27 --fast
  [ "$status" -eq 0 ]
  [[ "$output" == *"[PASS] G2d"* ]]
}

@test "PPTX-SLIM-IMG-21: --src 與 --out 相同時直接擋（不原地覆蓋原圖）" {
  mkdir -p "$W/same"
  cp "$W/png8.png" "$W/same/image1.png"
  run python3 "$SCRIPTS/pptx-shrink-images.py" --src "$W/same" --out "$W/same" --mode lossless
  [ "$status" -eq 1 ]
  [[ "$output" == *"不可與 --src 相同"* ]]
  cmp -s "$W/png8.png" "$W/same/image1.png"
}
