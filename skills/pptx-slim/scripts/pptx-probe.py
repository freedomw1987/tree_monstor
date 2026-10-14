#!/usr/bin/env python3
"""pptx-probe：PPTX 媒體偵察（唯讀，不改任何檔）。

為什麼需要它：媒體通常佔 PPTX 體積 90%+（實測案例：17 支影片 2,835 MiB ＝ 95%，
其餘 1,656 個 entry（含圖片）加起來只有 ~142 MiB）。先量出「誰是大戶」再壓，才不會壓錯對象。

用法：
  python3 pptx-probe.py <file.pptx> [--top N] [--specs] [--estimate] [--crf N] [--max-edge N]

  （預設）      只讀 zip 中央目錄 → 體積分佈 + Top N，秒級、零磁碟
  --specs       逐支 ffprobe（含畫面方向、時長、bitrate）；峰值臨時空間＝單支最大影片
  --estimate    抽樣 30 秒 CRF 試編碼並依時長外推（隱含 --specs，需 ffmpeg）

退出碼：0 正常（沒有影片也算正常）；1 參數／檔案問題；2 缺必要工具
"""

from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pptx_common import (  # noqa: E402
    category,
    extract_member,
    ffprobe_info,
    human_bytes,
    require,
    run,
    scale_filter,
    zip_entries,
)

SAMPLE_SECONDS = 30.0


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(add_help=True, description="PPTX 媒體偵察（唯讀）")
    p.add_argument("pptx", type=Path)
    p.add_argument("--top", type=int, default=20, help="Top N 大檔（預設 20）")
    p.add_argument("--specs", action="store_true", help="逐支 ffprobe 規格（會暫存解壓單支）")
    p.add_argument("--estimate", action="store_true", help="抽樣 30 秒估數（隱含 --specs）")
    p.add_argument("--crf", type=int, default=24, help="估數用的 CRF（預設 24）")
    p.add_argument("--max-edge", type=int, default=1920, help="估數用的長邊上限（預設 1920）")
    return p.parse_args(argv)


def report_layout(entries: list[tuple[str, int, int]], top: int) -> list[tuple[str, int]]:
    total_size = sum(size for _, size, _ in entries)
    buckets: dict[str, list[int]] = {"video": [0, 0], "image": [0, 0], "audio": [0, 0], "other": [0, 0]}
    videos: list[tuple[str, int]] = []
    for name, size, _ in entries:
        kind = category(name)
        buckets[kind][0] += 1
        buckets[kind][1] += size
        if kind == "video":
            videos.append((name, size))

    print(f"== 檔案 ==\n{len(entries)} 個 entry；解壓後合計 {human_bytes(total_size)}")
    print("\n== 分類 ==\n類別    檔案數   解壓後      佔比")
    for kind in ("video", "image", "audio", "other"):
        count, size = buckets[kind]
        share = (size / total_size * 100) if total_size else 0.0
        print(f"{kind:<7}{count:>7}   {human_bytes(size):>10}  {share:>5.1f}%")

    print(f"\n== Top {top} 大檔 ==")
    for name, size, comp in sorted(entries, key=lambda r: r[1], reverse=True)[:top]:
        print(f"{human_bytes(size):>10}  (壓縮 {human_bytes(comp):>9})  {name}")
    return videos


def report_specs(pptx: Path, videos: list[tuple[str, int]], args: argparse.Namespace) -> float:
    require("ffprobe", "列規格")
    want_estimate = args.estimate
    if want_estimate:
        require("ffmpeg", "抽樣估數")

    print(f"\n== 影片規格（{len(videos)} 支）==")
    if want_estimate:
        print(f"估數參數：CRF {args.crf}、長邊 {args.max_edge}、抽樣 {SAMPLE_SECONDS:.0f} 秒")
    print("名稱                             顯示尺寸    秒數    fps     bitrate    估數@CRF")

    estimate_total = 0.0
    with tempfile.TemporaryDirectory(prefix="pptx-probe-") as tmp:
        tmpdir = Path(tmp)
        for name, size in videos:
            local = extract_member(pptx, name, tmpdir)
            info = ffprobe_info(local)
            if want_estimate:
                sample = tmpdir / "sample.mp4"
                seconds = min(SAMPLE_SECONDS, info["duration"] or SAMPLE_SECONDS)
                run([
                    "ffmpeg", "-hide_banner", "-nostdin", "-loglevel", "error", "-y",
                    "-i", str(local), "-t", f"{seconds:.3f}",
                    "-vf", scale_filter(args.max_edge),
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", str(args.crf),
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k",
                    str(sample),
                ])
                sampled = sample.stat().st_size
                ratio = (info["duration"] / seconds) if seconds else 1.0
                est = min(sampled * max(ratio, 1.0), size)
                estimate_total += est
                est_text = human_bytes(est)
                sample.unlink()
            else:
                est_text = "-"
            local.unlink()
            mbps = f"{info['bitrate'] / 1e6:.1f} Mbps"
            print(
                f"{name:<33} {info['width']:>4}x{info['height']:<5} "
                f"{info['duration']:>6.1f}s {info['fps']:>5.2f} {mbps:>12} {est_text:>12}"
            )
    return estimate_total


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if not args.pptx.is_file():
        print(f"FAIL: 找不到檔案 {args.pptx}", file=sys.stderr)
        return 1

    entries = zip_entries(args.pptx)
    videos = report_layout(entries, args.top)
    total_size = sum(size for _, size, _ in entries)
    video_size = sum(size for _, size in videos)

    estimate_total = 0.0
    if args.specs or args.estimate:
        estimate_total = report_specs(args.pptx, videos, args)

    print("\n== 結論 ==")
    print(f"非影片部分（XML／圖片／其他）：{human_bytes(total_size - video_size)}"
          "（非影片不要動：XML 一改，動畫／時序／書籤就散）")
    if not videos:
        print("沒有內嵌影片 → 體積不是來自影片；改看圖片或嵌入物件，本工具的轉碼步驟不適用。")
    elif args.estimate:
        print(f"影片 {human_bytes(video_size)} → 估數合計 {human_bytes(estimate_total)}"
              f"（抽樣外推，僅供定 profile；實際以轉碼後量測為準）")
        print(f"整體粗估：{human_bytes(total_size - video_size + estimate_total)}")
    else:
        print(f"影片合計 {human_bytes(video_size)} → 想估數請加 --estimate"
              "（或直接跑 --specs 看規格決定壓哪幾支）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
