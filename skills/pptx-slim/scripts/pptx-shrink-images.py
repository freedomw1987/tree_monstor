#!/usr/bin/env python3
"""pptx-shrink-images：壓 PPTX 內嵌圖片，**檔名與容器（格式）都不變**。

為什麼要跟影片分成兩支腳本：
  影片是「重編碼」，圖片是「重壓縮／重採樣」，兩者的風險與取捨完全不同
  （影片掉質感看不出來；圖片掉畫質在投影機上很明顯，而且截圖／圖表會糊）。
  合成一支＝逼使用者一次決定兩件事，所以拆開，讓「圖片要不要壓」變成獨立決定。

為什麼預設是 lossless：
  實測 29 MiB 的 TIFF 用 deflate 重壓後只剩 ~500 KiB（省 98%）而**一個像素都沒動**。
  無損就能拿到大部分好處時，不該先去掉畫質。

lossless 的兩道護欄（缺一不可）：
  1. **格式／模式白名單**：只碰 Pillow 能保證 round-trip 的 PNG / TIFF 8-bit；
     JPEG（無損不可能）、GIF（多幀語意）、WEBP、EMF/WMF/SVG（Pillow 讀不了）一律 SKIP 並說明原因。
  2. **像素自證**：重存後自己解碼比一次像素，不同就退回原檔（寧願沒省到，也不偷偷降畫質）。

用法：
  python3 pptx-shrink-images.py --src <file.pptx|media-dir> --out <dir> [options]

  --mode lossless|lossy     預設 lossless（只重壓 PNG/TIFF 8-bit，像素不變）
  --image-max-edge N        lossy 才生效：長邊上限（預設 1920）
  --image-quality Q         lossy 才生效：JPEG/TIFF 品質（預設 85）
  --png-colors N            lossy 才生效：PNG 量化到 N 色（0＝不量化）
  --min-bytes N             跳過小於 N bytes 的圖片（預設 0＝全做；縮圖不值得動）
  --only a,b,c              只壓指定檔名（精確優先；沒精確命中才退子字串並 WARN）
  --no-keep-original        關掉「壓完沒更小就保留原檔」的防呆（通常不該關）
  --list                    只列圖片規格，不寫任何檔

退出碼：0 全部成功；1 參數／檔案問題；2 缺 Pillow；3 有圖片處理失敗（fail-fast）
"""

from __future__ import annotations

import argparse
import io
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pptx_common import (  # noqa: E402
    IMAGE_EXT,
    LOSSLESS_IMAGE_EXT,
    LOSSLESS_IMAGE_MODES,
    extract_member,
    human_bytes,
    is_media,
    match_only,
    pillow,
    png_bit_depth,
    pixels_same,
    zip_entries,
)

# 有損模式可以處理的格式（仍**不換容器**）：JPEG 要壓就只能走這條路
LOSSY_IMAGE_EXT = {".png", ".jpg", ".jpeg", ".tif", ".tiff"}

# Pillow 能開但我們刻意不碰的格式：理由要講清楚，不能靜默跳過
SKIP_REASON = {
    ".jpg": "JPEG 無損重編不可能（要壓就得走 --mode lossy）",
    ".jpeg": "JPEG 無損重編不可能（要壓就得走 --mode lossy）",
    ".gif": "GIF 多幀動畫語意容易掉（簡報會動的那種），不碰",
    ".webp": "WEBP 非 PowerPoint 全版本支援，不碰",
    ".bmp": "BMP 無壓縮空間（重存只會一樣大或更大）",
    ".emf": "EMF 向量圖，Pillow 讀不了",
    ".wmf": "WMF 向量圖，Pillow 讀不了",
    ".svg": "SVG 是文字向量圖，不是位圖",
}


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="PPTX 內嵌圖片壓縮（同名同格式）")
    p.add_argument("--src", required=True, type=Path)
    p.add_argument("--out", required=True, type=Path)
    p.add_argument("--mode", choices=("lossless", "lossy"), default="lossless")
    p.add_argument("--image-max-edge", type=int, default=1920)
    p.add_argument("--image-quality", type=int, default=85)
    p.add_argument("--png-colors", type=int, default=0)
    p.add_argument("--min-bytes", type=int, default=0)
    p.add_argument("--only", default="")
    p.add_argument("--no-keep-original", action="store_true")
    p.add_argument("--list", action="store_true", dest="list_only")
    return p.parse_args(argv)


def pick_sources(src: Path, only: str) -> list[str]:
    """pptx 內圖片是 entry 名（ppt/media/imageN.png），目錄模式則是檔名。"""
    if src.suffix.lower() == ".pptx":
        # 只認 ppt/media/ 下的圖片：docProps/thumbnail.jpeg 之類不是簡報內容，
        # 搬進媒體目錄只會被 repack 忽略（白做），還可能誤導「壓了幾張」的數字。
        names = [n for n, _, _ in zip_entries(src)
                 if is_media(n) and Path(n).suffix.lower() in IMAGE_EXT]
    elif src.is_dir():
        names = sorted(p.name for p in src.iterdir() if p.suffix.lower() in IMAGE_EXT)
    else:
        print(f"FAIL: --src 需為 .pptx 或目錄：{src}", file=sys.stderr)
        raise SystemExit(1)
    return match_only(names, only, "圖片")


def skip_reason(local: Path, mode: str) -> str:
    """回傳不能處理的原因（空字串＝可以做）。"""
    ext = local.suffix.lower()
    allowed = LOSSLESS_IMAGE_EXT if mode == "lossless" else LOSSY_IMAGE_EXT
    if mode == "lossless" and ext not in allowed:
        return SKIP_REASON.get(ext, f"無損模式不處理 {ext}")
    if ext not in allowed:
        return SKIP_REASON.get(ext, f"本工具不處理 {ext}")

    Image, _ = pillow()
    with Image.open(local) as img:
        if mode == "lossless":
            if img.mode not in LOSSLESS_IMAGE_MODES:
                return f"色彩模式 {img.mode} 無法保證無損（會掉色版／位深），不碰"
            if ext == ".png" and png_bit_depth(local) not in (1, 2, 4, 8):
                # 1/2/4-bit 安全：Pillow 轉 RGBA 是精確映射，像素自證抓得住任何變化。
                # 9-bit 以上不安全：Pillow 讀入會降成 8-bit，而降位深在 RGBA 比對下
                # 可能「看起來一樣」（同一個 8-bit 值）—— 所以必須直接看檔頭擋下。
                bits = png_bit_depth(local)
                return f"PNG 位深 {bits}-bit：Pillow 讀入會降成 8-bit，降位深像素自證抓不到，不碰"
            if ext in (".tif", ".tiff"):
                bits = img.tag_v2.get(258, (8,))
                if max(bits) > 8:
                    return f"TIFF {max(bits)}-bit 樣本：重壓可能降位深，不碰"
        elif ext in (".tif", ".tiff") and img.mode not in ("RGB", "RGBA", "L"):
            return f"TIFF 色彩模式 {img.mode} 無法用 jpeg 壓縮，不碰"
    return ""


def reencode(local: Path, dest: Path, args: argparse.Namespace) -> None:
    """重存到 dest（同名同格式）；只做大小與格式的取捨，不改副檔名。"""
    Image, _ = pillow()
    ext = local.suffix.lower()
    with Image.open(local) as img:
        keep_meta = {}
        if "icc_profile" in img.info:
            keep_meta["icc_profile"] = img.info["icc_profile"]
        if ext in (".jpg", ".jpeg") and "exif" in img.info:
            # 不自己轉正：轉正會動像素與 EXIF，簡報的擺位由 XML 決定
            keep_meta["exif"] = img.info["exif"]
        # ICC 一定要帶：它不影響像素值（pixels_same 抓不到），但影響「顏色長什麼様」，
        # 掉了就是靜默變色 —— 無損模式更該保住它。

        if args.mode == "lossy":
            img.thumbnail((args.image_max_edge, args.image_max_edge), Image.LANCZOS)

        if ext in (".jpg", ".jpeg"):
            img.save(dest, format="JPEG", quality=args.image_quality, optimize=True, **keep_meta)
        elif ext == ".png":
            if args.mode == "lossy" and args.png_colors > 0:
                img = img.convert("RGBA" if img.mode in ("RGBA", "P", "LA") else "RGB")
                img = img.quantize(colors=args.png_colors)
            img.save(dest, format="PNG", optimize=True, compress_level=9, **keep_meta)
        elif ext in (".tif", ".tiff"):
            if args.mode == "lossy":
                # dpi 與無損分支對稱：實測 Pillow 即使不傳也會沿用來源的 resolution tag
                # （300 dpi 來源 → 300 dpi），這裡顯式傳是為了不依賴那個實作細節
                img.save(dest, format="TIFF", compression="tiff_jpeg",
                         quality=args.image_quality, dpi=img.info.get("dpi"), **keep_meta)
            else:
                img.save(dest, format="TIFF", compression="tiff_deflate",
                         dpi=img.info.get("dpi"), **keep_meta)


def process_one(local: Path, dest: Path, args: argparse.Namespace, rows: list[tuple]) -> None:
    before = local.stat().st_size
    reason = skip_reason(local, args.mode)
    if reason:
        shutil.copyfile(local, dest)   # 輸出目錄仍要有這一支（repack 是一支一支對）
        rows.append((dest.name, before, before, f"SKIP({reason})"))
        print(f"  {dest.name:<20} {human_bytes(before):>10}  SKIP  {reason}")
        return

    reencode(local, dest, args)        # 失敗會由 main 收斂成 rc=3
    after = dest.stat().st_size
    status = "ENCODED"

    if args.mode == "lossless" and not pixels_same(local, dest):
        # 自證不通過＝這條路徑不安全（例如某個格式的重存其實會降位深）→ 原檔照抄
        shutil.copyfile(local, dest)
        after = before
        status = "GUARD(pixels changed)"
    elif not args.no_keep_original and after >= before:
        # 小圖／已優化過的圖重存常「沒更小」：硬換等於白忙，還可能更大
        shutil.copyfile(local, dest)
        after = before
        status = "KEPT(not smaller)"

    rows.append((dest.name, before, after, status))
    saved = (1 - after / before) * 100 if before else 0.0
    print(f"  {dest.name:<20} {human_bytes(before):>10} → {human_bytes(after):>10}"
          f"  ({saved:>5.1f}%)  {status}")


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if not args.src.exists():
        print(f"FAIL: 找不到來源 {args.src}", file=sys.stderr)
        return 1
    names = pick_sources(args.src, args.only)
    pillow()                            # 缺 Pillow 一律提前擋（不靜默跳過整個任務）
    if args.src.is_dir() and args.src.resolve() == args.out.resolve():
        # 目錄模式最危險的誤用：來源目錄當成輸出目錄 ＝ 原地覆蓋原圖
        print("FAIL: --out 不可與 --src 相同（會原地覆蓋原圖）", file=sys.stderr)
        return 1
    if not names:
        print("沒有可處理的圖片（沒有內嵌圖片，或 --only 沒選到東西）")
        return 0
    if not args.list_only:
        args.out.mkdir(parents=True, exist_ok=True)

    print(f"來源：{args.src}\n輸出：{args.out}\n模式：{args.mode}"
          + (f"（長邊 {args.image_max_edge}、品質 {args.image_quality}、PNG 色數 "
             f"{args.png_colors or '不量化'}）" if args.mode == "lossy" else "（像素不變）"))
    print(f"待處理 {len(names)} 張：" + ", ".join(Path(n).name for n in names))

    from_zip = args.src.suffix.lower() == ".pptx"
    rows: list[tuple] = []
    staged = Path(tempfile.mkdtemp(prefix="pptx-shrink-img-"))
    try:
        for name in names:
            dest = args.out / Path(name).name
            if from_zip:
                local = extract_member(args.src, name, staged)
            else:
                local = args.src / Path(name).name
            if local.stat().st_size < args.min_bytes:
                print(f"  {dest.name:<20} {human_bytes(local.stat().st_size):>10}  SKIP  "
                      f"小於 --min-bytes {args.min_bytes}")
                if from_zip:
                    local.unlink()
                continue
            if args.list_only:
                Image, _ = pillow()
                with Image.open(local) as img:
                    print(f"  [list] {dest.name} {img.size[0]}x{img.size[1]} {img.mode} "
                          f"{human_bytes(local.stat().st_size)}")
            else:
                try:
                    process_one(local, dest, args, rows)
                except (SystemExit, OSError, ValueError) as exc:
                    # UnidentifiedImageError 是 OSError 子類。為什麼要接住：壞圖（副檔名對、
                    # 內容不是圖）、Pillow 解不開的格式都是「預期中的失敗」，應該給第幾張、
                    # 已完成幾張與 rc=3（文件寫死的契約），而不是 traceback + rc=1。
                    print(f"FAIL: 圖片處理失敗（已完成 {len(rows)} 張）：{dest.name}"
                          f"（{type(exc).__name__}）", file=sys.stderr)
                    return 3
            if from_zip:
                local.unlink()          # 峰值空間 = 單張最大圖
    finally:
        shutil.rmtree(staged, ignore_errors=True)

    if rows:
        before_total = sum(r[1] for r in rows)
        after_total = sum(r[2] for r in rows)
        log = args.out / "image-log.tsv"
        with log.open("w", encoding="utf-8") as fh:
            fh.write("name\tbefore_bytes\tafter_bytes\tstatus\n")
            for row in rows:
                fh.write("\t".join(str(v) for v in row) + "\n")
        base = before_total or 1
        print(f"\n合計 {human_bytes(before_total)} → {human_bytes(after_total)}"
              f"（省 {(1 - after_total / base) * 100:.1f}%）")
        print(f"log：{log}（下一關 repack 用 --media-dir {args.out}；可與影片同一目錄）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
