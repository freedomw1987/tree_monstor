#!/usr/bin/env python3
"""pptx-verify：四關驗證（這關唔過就唔准交件）。

四關為什麼是這四關：
  G1 CRC        —— 輸出是不是一個「讀得完」的 zip（開會才發現壞檔，代價最大）
  G2 entry 齊全 —— 非媒體 entry 必須逐 byte 相同（XML／rels 一動，動畫與時序就散）
  G3 rels 零斷鏈 —— 每個關係指向的 part 真的存在（換名／換容器就是在這裡出事）
  G4 時長漂移   —— 影片長度不變（書籤、動畫觸發時點全靠它）

  「四關」＝上面四關（G2 含 a 齊全／b 非媒體 byte 相同／c 媒體與 --media-dir 一致）；
  「播放器實開」是四關**之外**的最後一關，要人在有 PowerPoint／LibreOffice 的機器跑。
  媒體比對分兩層：這裡用「大小 + 小檔深度比對」省 I/O，嚴格逐 byte 核對走 --media-dir（G2c）。

用法：
  python3 pptx-verify.py --src <original.pptx> --dst <new.pptx> [options]

  --media-dir DIR   有給就逐 byte 核對「新檔媒體 == 目錄檔案」（證明換上去的真的是轉碼結果）；
                    目錄不存在、或一支都比不到＝FAIL（不看空目錄）
  --tol SECONDS     時長容忍（預設 0.5）
  --fast            跳過原檔的 CRC 掃描（2.9 GB 級原檔要解壓一遍，慢）
  --expect-slides N 明確期望頁數（有給就硬比對）

退出碼：0 四關全綠；1 有任何一關不過；2 參數／檔案問題
"""

from __future__ import annotations

import argparse
import posixpath
import sys
import tempfile
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pptx_common import (  # noqa: E402
    VIDEO_EXT,
    die,
    extract_from,
    ffprobe_info,
    human_bytes,
    is_media,
    require,
    stream_same,
    stream_same_file,
    zip_entries,
)

REL_NS = "{http://schemas.openxmlformats.org/package/2006/relationships}"

# 媒體 entry：大小不同即視為換過；大小相同且 <= 此值才會真的逐 byte 比一次
# （2.9 GB 級影片逐 byte 比對＝把兩份 GB 級媒體重讀一遍；嚴格核對走 G2c）
MEDIA_DEEP_COMPARE_BYTES = 8 << 20


class Report:
    def __init__(self) -> None:
        self.failures: list[str] = []

    def gate(self, name: str, ok: bool, detail: str) -> None:
        print(f"[{'PASS' if ok else 'FAIL'}] {name}：{detail}")
        if not ok:
            self.failures.append(name)


def check_crc(path: Path, label: str, skip: bool, report: Report) -> None:
    if skip and label == "原檔":
        print(f"[SKIP] G1 {label} CRC：--fast（新檔仍會驗）")
        return
    with zipfile.ZipFile(path) as zf:
        bad = zf.testzip()
    size = human_bytes(path.stat().st_size)
    report.gate(f"G1 {label} CRC", bad is None,
                f"{size}，{len(zip_entries(path))} entries" + ("，CRC 全綠" if bad is None else f"，壞 entry：{bad}"))


def check_entries(src: Path, dst: Path, media_dir: Path | None, report: Report) -> list[str]:
    src_rows = zip_entries(src)
    dst_rows = zip_entries(dst)
    src_names = [n for n, _, _ in src_rows]
    dst_names = [n for n, _, _ in dst_rows]
    same_set = set(src_names) == set(dst_names)
    report.gate("G2a entry 齊全", same_set and len(src_names) == len(dst_names),
                f"{len(dst_names)}/{len(src_names)} entries"
                + ("" if same_set else f"，差異：{sorted(set(src_names) ^ set(dst_names))[:5]}"))

    changed_non_media, changed_media = [], []
    with zipfile.ZipFile(src) as zs, zipfile.ZipFile(dst) as zd:
        for name in sorted(set(src_names) & set(dst_names)):
            if is_media(name):
                # 媒體本來就可以換（那就是本工具的目的）；換掉的判準是大小，小檔再深比一次。
                size_a = zs.getinfo(name).file_size
                size_b = zd.getinfo(name).file_size
                if size_a != size_b or (size_a <= MEDIA_DEEP_COMPARE_BYTES
                                         and not stream_same(zs, zd, name)):
                    changed_media.append(name)
                continue
            if not stream_same(zs, zd, name):
                changed_non_media.append(name)

    report.gate("G2b 非媒體 byte 相同", not changed_non_media,
                "0 個非媒體 entry 被動到" if not changed_non_media
                else f"被動到的非媒體 entry：{changed_non_media[:5]}")

    if media_dir is not None:
        check_media_dir(dst, src_names, media_dir, report)
    print(f"[INFO] 被替換的媒體檔數：{len(changed_media)}"
          + (f"（例：{changed_media[:3]}）" if changed_media else ""))
    return changed_media


def check_media_dir(dst: Path, src_names: list[str], media_dir: Path, report: Report) -> None:
    """G2c：逐 byte 核對新檔媒體與轉碼目錄。一支都比不到＝FAIL（防止打錯路徑假綠）。"""
    if not media_dir.is_dir():
        die(f"--media-dir 不是目錄（打錯路徑？）：{media_dir}", 2)
    media = sorted(n for n in src_names if is_media(n))
    mismatched, missing, checked = [], [], 0
    with zipfile.ZipFile(dst) as zd:
        for name in media:
            local = media_dir / Path(name).name
            if not local.is_file():
                missing.append(Path(name).name)
                continue
            checked += 1
            if not stream_same_file(zd, name, local):
                mismatched.append(Path(name).name)
    detail = f"{len(media)} 支媒體中實際逐 byte 比對 {checked} 支"
    if missing:
        detail += f"，目錄內找不到 {len(missing)} 支（{missing[:3]}；用過 --only 的話屬正常）"
    if mismatched:
        detail += f"，不符：{mismatched[:5]}"
    report.gate("G2c 媒體與 --media-dir 一致", bool(checked) and not mismatched, detail)


def media_names(names: list[str]) -> set[str]:
    """G4 時長關只認影片（圖片丟進 ffprobe 沒有意義）。"""
    return {n for n in names if is_media(n) and Path(n).suffix.lower() in VIDEO_EXT}


def check_rels_and_slides(dst: Path, expect_slides: int | None, report: Report) -> None:
    with zipfile.ZipFile(dst) as zf:
        names = set(zf.namelist())
        broken = []
        for rel_name in sorted(n for n in names if n.endswith(".rels")):
            base = posixpath.dirname(posixpath.dirname(rel_name))
            try:
                root = ET.fromstring(zf.read(rel_name))
            except ET.ParseError as exc:
                broken.append(f"{rel_name}（XML 壞：{exc}）")
                continue
            for rel in root.findall(f"{REL_NS}Relationship"):
                if rel.get("TargetMode") == "External":
                    continue
                raw = rel.get("Target", "")
                # OOXML 允許套件絕對路徑（/ppt/slides/slide1.xml）：lstrip 後才不會被誤判斷鏈
                target = posixpath.normpath(raw.lstrip("/") if raw.startswith("/")
                                            else posixpath.join(base, raw))
                if target not in names:
                    broken.append(f"{rel_name} → {rel.get('Target')}")
        report.gate("G3a rels 零斷鏈", not broken,
                    f"{len([n for n in names if n.endswith('.rels')])} 個 rels 全數指向存在的 part"
                    if not broken else f"斷鏈：{broken[:5]}")

        slides = 0
        if "ppt/presentation.xml" in names:
            root = ET.fromstring(zf.read("ppt/presentation.xml"))
            slides = len(root.findall(
                ".//{http://schemas.openxmlformats.org/presentationml/2006/main}sldId"))

    detail = f"{slides} 頁"
    ok = slides > 0
    if expect_slides is not None:
        ok = ok and slides == expect_slides
        detail += f"（期望 {expect_slides}）"
    try:
        from pptx import Presentation  # 選配：裝了就用真的解析器再開一次
    except ImportError:
        print("[INFO] G3b 未安裝 python-pptx → 只做 zip 層檢查（建議裝以取得真解析器驗證）")
    else:
        parsed = len(Presentation(str(dst)).slides)
        ok = ok and parsed == slides
        detail += f"，python-pptx 解析 {parsed} 頁"
    report.gate("G3b 開得起來 + 頁數", ok, detail)


def check_durations(src: Path, dst: Path, tol: float, report: Report) -> None:
    require("ffprobe", "量時長漂移")
    videos = sorted(media_names([n for n, _, _ in zip_entries(src)]))
    if not videos:
        print("[INFO] G4 沒有影片 → 時長關不適用（體積來源不是影片）")
        return
    worst = 0.0
    worst_name = "-"
    missing: list[str] = []
    # 兩個 zip 各開一次（不是每支重開）；每支解完立刻刪 → 峰值磁碟 = 2 支最大影片
    with tempfile.TemporaryDirectory(prefix="pptx-verify-") as tmp, \
            zipfile.ZipFile(src) as zs, zipfile.ZipFile(dst) as zd:
        tmpdir = Path(tmp)
        for name in videos:
            # G2a 不齊全時（dst 少一支）會讓 ZipFile.extract 直接 KeyError 炸掉後面的判準行；
            # 這裡改成「記下來、G4 自己不通過」，讓輸出維持「一 gate 一行」可讀
            if name not in zs.NameToInfo or name not in zd.NameToInfo:
                missing.append(Path(name).name)
                continue
            local_a = extract_from(zs, name, tmpdir / "a")
            local_b = extract_from(zd, name, tmpdir / "b")
            drift = abs(ffprobe_info(local_a)["duration"] - ffprobe_info(local_b)["duration"])
            local_a.unlink()
            local_b.unlink()
            if drift >= worst:
                worst, worst_name = drift, name
    if missing:
        report.gate("G4 時長漂移", False,
                    f"新檔缺少 {len(missing)} 支影片，無法比時長（{', '.join(missing[:5])}）")
        return
    report.gate("G4 時長漂移", worst <= tol,
                f"{len(videos)} 支影片最大漂移 {worst:.2f}s（容忍 {tol}s，最差：{Path(worst_name).name}）")


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description="PPTX 四關驗證")
    p.add_argument("--src", required=True, type=Path)
    p.add_argument("--dst", required=True, type=Path)
    p.add_argument("--media-dir", type=Path)
    p.add_argument("--tol", type=float, default=0.5)
    p.add_argument("--fast", action="store_true")
    p.add_argument("--expect-slides", type=int)
    args = p.parse_args(argv)

    for path, label in ((args.src, "原檔"), (args.dst, "新檔")):
        if not path.is_file():
            print(f"FAIL: 找不到{label} {path}", file=sys.stderr)
            return 2

    report = Report()
    print(f"原檔：{args.src}\n新檔：{args.dst}")
    check_crc(args.src, "原檔", args.fast, report)
    check_crc(args.dst, "新檔", False, report)
    check_entries(args.src, args.dst, args.media_dir, report)
    check_rels_and_slides(args.dst, args.expect_slides, report)
    check_durations(args.src, args.dst, args.tol, report)

    print("\n== 結論 ==")
    if report.failures:
        print(f"FAIL: {len(report.failures)} 關未過：{', '.join(report.failures)} → 不得交件")
        return 1
    print("四關全綠。仍要記得：最後一關「播放器實開」要在有 PowerPoint／LibreOffice 的環境人工跑一次"
          "（例如 LibreOffice 轉 PDF，PDF 頁數要等於投影片頁數）。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
