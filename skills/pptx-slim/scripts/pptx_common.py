#!/usr/bin/env python3
"""pptx-slim 共用工具：zip 唯讀列舉、媒體分類、ffprobe 規格、ffmpeg 濾鏡字串。

為什麼要共用一支：
  1. 偵察（probe）的「估數」與轉碼（shrink）的「實做」必須用**同一個** scale 濾鏡，
     否則估出來與壓出來會漂移（同一個 bug 修兩次）。
  2. ffprobe / 旋轉 / 大小格式化的解析只寫一次，四支腳本共用，行為一致。

設計立場：本模組只讀不寫（唯一的寫入是呼叫端明確要求的暫存解壓）。
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path, PurePosixPath

VIDEO_EXT = {".mp4", ".mov", ".m4v", ".avi", ".wmv", ".mkv", ".webm", ".mpg", ".mpeg", ".flv"}
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".gif", ".bmp", ".emf", ".wmf", ".svg", ".webp"}
AUDIO_EXT = {".mp3", ".wav", ".m4a", ".aac", ".wma", ".flac"}

# 圖片壓縮只碰「Pillow 能保證無損 round-trip」的格式；其餘（jpeg/gif/webp/emf/wmf/svg…）
# 一律 SKIP 並在 log 說明原因 —— 「沒壓到」比「偷偷掉畫質」便宜太多。
LOSSLESS_IMAGE_EXT = {".png", ".tif", ".tiff"}

# 這些 mode 的像素 Pillow 一定保住；I;16 / F / CMYK（降位深、色版轉換）一律不碰。
LOSSLESS_IMAGE_MODES = {"1", "L", "LA", "P", "RGB", "RGBA"}

# PPTX / DOCX / XLSX 的媒體一律放在 ppt|word|xl/media/ 之下。本工具只認「media/」這一層。
MEDIA_MARK = "/media/"


def die(msg: str, code: int = 1) -> None:
    """一致的失敗出口：訊息進 stderr，不回 traceback（Agent 讀 stderr 就夠）。"""
    print(f"FAIL: {msg}", file=sys.stderr)
    raise SystemExit(code)


def have(tool: str) -> bool:
    return shutil.which(tool) is not None


def require(tool: str, why: str = "") -> None:
    if not have(tool):
        hint = f"（{why}）" if why else ""
        die(f"缺必要工具 {tool}{hint}；請先安裝或改用不需要它的模式", 2)


def run(cmd: list[str], check: bool = True, text: bool = True) -> subprocess.CompletedProcess:
    proc = subprocess.run(cmd, capture_output=True, text=text)
    if check and proc.returncode != 0:
        tail = (proc.stderr or "").strip().splitlines()[-5:]
        die("命令失敗：" + " ".join(cmd[:3]) + " ...\n" + "\n".join(tail))
    return proc


def human_bytes(n: int | float) -> str:
    """人類可讀大小（1024 進位 → KiB/MiB/GiB；單位標籤要跟案例的 MiB 對得上）。"""
    value = float(n)
    for unit in ("B", "KiB", "MiB", "GiB"):
        if value < 1024 or unit == "GiB":
            return f"{value:.0f} {unit}" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    return f"{value:.1f} GiB"


def category(name: str) -> str:
    ext = PurePosixPath(name).suffix.lower()
    if ext in VIDEO_EXT:
        return "video"
    if ext in IMAGE_EXT:
        return "image"
    if ext in AUDIO_EXT:
        return "audio"
    return "other"


def is_media(name: str) -> bool:
    return MEDIA_MARK in f"/{name}" and category(name) != "other"


def match_only(names: list[str], only: str, what: str) -> list[str]:
    """--only 的共用語意：**精確優先**，沒精確命中才退回子字串並 WARN，打錯詞要出聲。

    為什麼不能只用子字串：`media1` 是 `media10`–`media17` 的前綴，純子字串會一次壓 8 支，
    與「精準打擊」的用法完全相反（實測踩過）。
    """
    if not only:
        return names
    wanted = [w.strip() for w in only.split(",") if w.strip()]

    def exact_hits(word: str) -> list[str]:
        return [n for n in names if word in (n, Path(n).name, Path(n).stem)]

    picked: list[str] = []
    fuzzy: list[str] = []
    fuzzy_words: list[str] = []
    no_hit: list[str] = []
    for word in wanted:
        hits = exact_hits(word)
        if hits:
            picked.extend(hits)
            continue
        loose = [n for n in names if word in Path(n).stem]
        if loose:
            fuzzy.extend(loose)
            fuzzy_words.append(word)
        else:
            no_hit.append(word)
    if no_hit:
        print(f"WARN: --only 有 {len(no_hit)} 個詞沒命中任何{what}：{', '.join(no_hit)}",
              file=sys.stderr)
    if fuzzy:
        print(f"WARN: --only {'/'.join(fuzzy_words)} 沒有精確命中，改用子字串，命中 "
              f"{len(set(fuzzy))} 支：{', '.join(sorted({Path(n).name for n in fuzzy}))}",
              file=sys.stderr)
    picked.extend(fuzzy)
    if not picked:
        print(f"FAIL: --only 指到不存在的{what}：{', '.join(wanted)}", file=sys.stderr)
        raise SystemExit(1)
    return [n for n in names if n in set(picked)]


def pillow() -> tuple:
    """延遲載入 Pillow：只有真的要碰圖片時才需要它（影片路徑不該被它擋住）。"""
    try:
        from PIL import Image, ImageOps
    except ImportError:
        die("缺 Pillow（python3 -m pip install Pillow）；圖片關需要它，或改用只壓影片的路徑", 2)
    return Image, ImageOps


def png_bit_depth(path: Path) -> int:
    """讀 PNG IHDR 的 bit depth（0 = 不是 PNG）。

    Pillow 讀 16-bit PNG 會**降位深**成 8-bit（肉眼看不出、但不再是無損），
    只靠解碼後比像素是抓不到的 —— 所以必須直接看檔頭。
    """
    with path.open("rb") as fh:
        head = fh.read(26)
    if head[:8] != b"\x89PNG\r\n\x1a\n" or len(head) < 26:
        return 0
    return head[24]


def pixel_bytes(img) -> bytes:
    """把圖轉成固定 RGBA 序列（跨 mode 才能比）；alpha 與色版都算進「像素」。"""
    return img.convert("RGBA").tobytes()


def pixels_same(path_a: Path, path_b: Path) -> bool:
    """兩張圖解碼後像素是否完全相同（無損宣稱的自證）。"""
    Image, _ = pillow()
    with Image.open(path_a) as ia, Image.open(path_b) as ib:
        # n_frames 只有多幀外掛（GIF／TIFF／WEBP）才有：JPEG 之類要用 getattr 取預設 1，
        # 否則單幀圖直接 AttributeError（實測踩過）
        if ia.size != ib.size or getattr(ia, "n_frames", 1) != getattr(ib, "n_frames", 1):
            return False
        return pixel_bytes(ia) == pixel_bytes(ib)


def psnr(path_a: Path, path_b: Path) -> float:
    """兩張圖的 PSNR（dB）；完全相同回 inf，尺寸不同時把**大的那張縮到小的尺寸**再比。

    為什麼是「縮到小的」而不是「把小圖放大回母帶尺寸」：母帶 → 1920 縮圖是合理的降採樣，
    放大回去比等於在懲罰每一次縮圖。實測（見 examples.md）：同一張 1000x750 高頻圖縮到
    400px 存 Q85，放大回母帶語意只有 24.8 dB（低於預設門檻 30 dB ＝ 誤殺），縮到小圖尺寸比
    是 28.5 dB。
    注意：PSNR 只比 RGB（alpha 不計），所以它是「有損模式」的輔助門檻，不是無損證明。
    """
    Image, _ = pillow()
    import math
    with Image.open(path_a) as ia, Image.open(path_b) as ib:
        ref = ia.convert("RGB")
        got = ib.convert("RGB")
    if got.size != ref.size:
        if ref.size[0] * ref.size[1] > got.size[0] * got.size[1]:
            ref = ref.resize(got.size, Image.LANCZOS)
        else:
            got = got.resize(ref.size, Image.LANCZOS)
    a, b = ref.tobytes(), got.tobytes()
    mse = sum((x - y) ** 2 for x, y in zip(a, b)) / len(a)
    return math.inf if mse == 0 else 10 * math.log10(255 ** 2 / mse)


def zip_entries(path: Path) -> list[tuple[str, int, int]]:
    """回傳 [(name, file_size, compress_size)]；目錄 entry 不含。"""
    if not zipfile.is_zipfile(path):
        die(f"{path} 不是有效的 zip / OOXML 檔")
    with zipfile.ZipFile(path) as zf:
        return [
            (i.filename, i.file_size, i.compress_size)
            for i in zf.infolist()
            if not i.is_dir()
        ]


def extract_from(zf: zipfile.ZipFile, name: str, dest_dir: Path) -> Path:
    """用已開好的 ZipFile 解出單一 entry；連續解多支時省掉重讀中央目錄。"""
    dest_dir.mkdir(parents=True, exist_ok=True)
    zf.extract(name, dest_dir)
    return dest_dir / name


def extract_member(zip_path: Path, name: str, dest_dir: Path) -> Path:
    """把單一 entry 解壓到 dest_dir，回傳實際路徑（峰值空間 = 單支檔案，不是全部）。"""
    with zipfile.ZipFile(zip_path) as zf:
        return extract_from(zf, name, dest_dir)


def stream_same_file(zf: zipfile.ZipFile, name: str, path: Path,
                     chunk: int = 1 << 20) -> bool:
    """分塊比較「zip entry」與「磁碟檔案」；不把 GB 級媒體讀進記憶體。"""
    if name not in zf.NameToInfo or zf.getinfo(name).file_size != path.stat().st_size:
        return False
    with zf.open(name) as fh, path.open("rb") as local:
        while True:
            block_zip = fh.read(chunk)
            block_local = local.read(chunk)
            if block_zip != block_local:
                return False
            if not block_zip:
                return True


def stream_same(zf_a: zipfile.ZipFile, zf_b: zipfile.ZipFile, name: str,
                chunk: int = 1 << 20) -> bool:
    """分塊比較兩個 zip 內的同名 entry；記憶體固定 1 MiB（不把 GB 級 entry 讀進 RAM）。"""
    if name not in zf_a.NameToInfo or name not in zf_b.NameToInfo:
        return False
    with zf_a.open(name) as fa, zf_b.open(name) as fb:
        while True:
            block_a = fa.read(chunk)
            block_b = fb.read(chunk)
            if block_a != block_b:
                return False
            if not block_a:
                return True


def scale_filter(max_edge: int) -> str:
    """長邊封頂、短邊交給 -2 自動取偶（豎屏不會被過度縮小）。

    注意：不要自己加 transpose。ffmpeg 預設會依 display matrix **自動轉正**（autorotate），
    轉正後 iw/ih 已是顯示方向，這個濾鏡直接成立；自己再轉一次就是歪的。
    """
    return (
        f"scale='if(gt(iw,ih),min({max_edge},iw),-2)':"
        f"'if(gt(iw,ih),-2,min({max_edge},ih))'"
    )


def _parse_fps(raw: str) -> float:
    try:
        num, _, den = raw.partition("/")
        return round(float(num) / float(den or 1), 2) if float(den or 1) else 0.0
    except (TypeError, ValueError):
        return 0.0


def ffprobe_info(path: Path) -> dict:
    """回傳 {width, height, duration, fps, bitrate, rotation}；width/height 是**顯示**方向。"""
    require("ffprobe", "讀取媒體規格")
    data = json.loads(
        run(["ffprobe", "-v", "error", "-print_format", "json",
             "-show_streams", "-show_format", str(path)]).stdout
    )
    streams = data.get("streams", [])
    video = next((s for s in streams if s.get("codec_type") == "video"), {})
    fmt = data.get("format", {})

    def as_float(value, default=0.0):
        try:
            return float(value)
        except (TypeError, ValueError):
            return default

    duration = as_float(fmt.get("duration") or video.get("duration"))
    bitrate = int(as_float(fmt.get("bit_rate") or video.get("bit_rate")))
    rotation = 0
    for side in video.get("side_data_list") or []:
        if "rotation" in side:
            rotation = int(as_float(side["rotation"]))
    if rotation == 0:
        rotation = int(as_float((video.get("tags") or {}).get("rotate")))

    width = int(as_float(video.get("width")))
    height = int(as_float(video.get("height")))
    if abs(rotation) % 180 == 90:  # 轉 90/270 度 → 顯示方向長寬互換
        width, height = height, width

    return {
        "width": width,
        "height": height,
        "duration": duration,
        "fps": _parse_fps(video.get("r_frame_rate", "")),
        "bitrate": bitrate,
        "rotation": rotation,
    }
