#!/usr/bin/env python3
"""pptx-repack：把轉碼後的媒體換回 PPTX，寫成**新檔**（原檔零改動）。

核心規則（為什麼這樣寫）：
  1. 非媒體 entry 一律**逐 byte 原樣**搬過去，並保留原本的壓縮方式與時間戳
     → XML／rels／時序／書籤全部不動，動畫不會散、投影片不會少。
  2. 媒體 entry 用 ZIP_STORED：影片本身已是壓縮格式，再 deflate 只會白花 CPU 且幾乎無效
     （實測大檔差 < 0.1%）。
  3. 缺檔即報：媒體目錄裡找不到對應檔就保留原媒體並列出，不靜默替換。

用法：
  python3 pptx-repack.py --src <original.pptx> --dst <new.pptx> --media-dir <dir>
  --deflate-media   媒體用 deflate（預設 ZIP_STORED，因為影片本身已壓縮）
  --force           允許覆蓋已存在的 --dst（預設拒絕，免得覆蓋上一輪已驗證的輸出）

退出碼：0 成功；1 參數／檔案問題
"""

from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pptx_common import VIDEO_EXT, die, human_bytes, zip_entries  # noqa: E402


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="用轉碼後的媒體重打包 PPTX（寫新檔）")
    p.add_argument("--src", required=True, type=Path)
    p.add_argument("--dst", required=True, type=Path)
    p.add_argument("--media-dir", required=True, type=Path)
    p.add_argument("--deflate-media", action="store_true", help="媒體用 deflate（預設 store）")
    p.add_argument("--force", action="store_true", help="允許覆蓋已存在的 --dst")
    return p.parse_args(argv)


def build_replacement_map(
    entries: list[tuple[str, int, int]], media_dir: Path
) -> tuple[dict[str, tuple[Path, int]], list[str], list[str]]:
    """以 basename 對應（單一 OOXML 檔內 `media/` 的檔名唯一）。

    只把**影片**當必要項：媒體目錄裡有圖片就換圖片，沒有就安靜跳過；
    影片檔在目錄裡找不到則列進 missing（不靜默替換）。
    """
    available = {p.name: p for p in media_dir.iterdir() if p.is_file()}
    mapping: dict[str, tuple[Path, int]] = {}
    missing: list[str] = []
    for name, size, _ in entries:
        if "/media/" not in f"/{name}" or name.endswith("/"):
            continue
        replacement = available.pop(Path(name).name, None)
        if replacement is not None:
            mapping[name] = (replacement, size)
        elif Path(name).suffix.lower() in VIDEO_EXT:
            missing.append(Path(name).name)
    unused = sorted(n for n in available if Path(n).suffix.lower() in VIDEO_EXT)
    return mapping, missing, unused


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if not args.src.is_file():
        die(f"找不到原檔 {args.src}")
    if not args.media_dir.is_dir():
        die(f"找不到媒體目錄 {args.media_dir}")
    if args.src.resolve() == args.dst.resolve():
        die("--dst 不可與 --src 相同（本工具絕不覆蓋原檔）")
    if args.dst.exists() and not args.force:
        die(f"--dst 已存在：{args.dst}（要覆蓋請加 --force；建議換新檔名保留上一輪）")

    entries = zip_entries(args.src)
    mapping, missing, unused = build_replacement_map(entries, args.media_dir)
    if not mapping:
        die("沒有可替換的媒體（檔名對不上？轉碼輸出的檔名必須與 zip 內一致）")
    if missing:
        print(f"WARN: {len(missing)} 支影片沒有對應檔案，保留原媒體："
              f"{', '.join(sorted(missing)[:10])}", file=sys.stderr)
    if unused:
        print(f"WARN: 媒體目錄有 {len(unused)} 支影片沒被用到（檔名對不上？）："
              f"{', '.join(unused[:5])}", file=sys.stderr)

    media_type = zipfile.ZIP_DEFLATED if args.deflate_media else zipfile.ZIP_STORED
    args.dst.parent.mkdir(parents=True, exist_ok=True)
    written = replaced = 0
    with zipfile.ZipFile(args.src) as zin, \
            zipfile.ZipFile(args.dst, "w", allowZip64=True) as zout:
        for info in zin.infolist():
            if info.is_dir():
                zout.writestr(info, b"")   # 目錄 entry 也原樣保留（不計入檔案數）
                continue
            if info.filename in mapping:
                replacement, original_size = mapping[info.filename]
                payload = replacement.read_bytes()
                # 大小沒變 ⇒ 內容就是原檔（shrink 的「壓完更大就保留原檔」）⇒
                # 保留原本的壓縮方式，否則「全部保留原檔」的輸出反而會比原檔大。
                if len(payload) != original_size:
                    info.compress_type = media_type
                replaced += 1
            else:
                payload = zin.read(info.filename)  # 逐 byte 原樣，連 metadata 都不動
            zout.writestr(info, payload)
            written += 1

    total = len(entries)
    if written != total:
        die(f"entry 數不符（{written} != {total}）→ 這個輸出不可信，請刪掉 {args.dst}")
    print(f"{written}/{total} entries written, {replaced} media replaced, "
          f"{len(missing)} missing")
    print(f"輸出 {args.dst}（{human_bytes(args.dst.stat().st_size)}）"
          f"；原檔 {args.src}（{human_bytes(args.src.stat().st_size)}）未改動")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
