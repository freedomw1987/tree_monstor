#!/usr/bin/env python3
"""pptx-shrink-media：把 PPTX（或媒體目錄）內的影片逐支重編碼，輸出名稱與容器都不變。

為什麼「同名同容器」是硬規則：pptx 內的 rels／`[Content_Types].xml`／動畫時序全部指向
`ppt/media/mediaN.mp4` 這個名字；換名或換容器（mp4→webm）＝斷鏈，動畫與書籤直接失效。

為什麼「壓完更大就保留原檔」：極短或極低碼率的片段（實測 media1.mp4）重編碼只會更大，
硬壓等於花時間變大檔；預設自動退回原檔並在 log 標 KEPT。

用法：
  python3 pptx-shrink-media.py --src <file.pptx|media-dir> --out <dir> [options]

  --src PATH                 .pptx（逐支從 zip 解出）或已解壓的 media 目錄
  --out DIR                  輸出目錄（與來源同名檔）
  --crf N                    品質（預設 24；越小越好越大，18 近透明，28 明顯壓縮）
  --preset P                 x264 preset（預設 medium）
  --max-edge N               長邊上限（預設 1920）
  --audio-bitrate K          音訊 kbps（預設 128）
  --only a,b,c               只壓指定的檔名（精確優先；沒精確命中才退回子字串並 WARN）
                             （例：media4,media12）
  --no-keep-original         關掉「壓完更大就保留原檔」的防呆（通常不該關）
  --list                     只列規格與命令，不真的轉碼

退出碼：0 全部成功；1 參數／檔案問題；2 缺 ffmpeg；3 有檔案轉碼失敗（fail-fast）
"""

from __future__ import annotations

import argparse
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pptx_common import (  # noqa: E402
    VIDEO_EXT,
    extract_member,
    ffprobe_info,
    human_bytes,
    match_only,
    require,
    run,
    scale_filter,
    zip_entries,
)

DRIFT_WARN_SECONDS = 0.5


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="PPTX 內嵌影片重編碼（同名同容器）")
    p.add_argument("--src", required=True, type=Path)
    p.add_argument("--out", required=True, type=Path)
    p.add_argument("--crf", type=int, default=24)
    p.add_argument("--preset", default="medium")
    p.add_argument("--max-edge", type=int, default=1920)
    p.add_argument("--audio-bitrate", type=int, default=128)
    p.add_argument("--only", default="")
    p.add_argument("--no-keep-original", action="store_true")
    p.add_argument("--list", action="store_true", dest="list_only")
    return p.parse_args(argv)


def pick_sources(src: Path, only: str) -> list[str]:
    """回傳要處理的檔名清單（pptx 內是 entry 名，目錄則是檔名）。"""
    if src.suffix.lower() == ".pptx":
        names = [n for n, _, _ in zip_entries(src) if Path(n).suffix.lower() in VIDEO_EXT]
    elif src.is_dir():
        names = sorted(p.name for p in src.iterdir() if p.suffix.lower() in VIDEO_EXT)
    else:
        print(f"FAIL: --src 需為 .pptx 或目錄：{src}", file=sys.stderr)
        raise SystemExit(1)
    return match_only(names, only, "影片")


def encode_command(local: Path, dest: Path, args: argparse.Namespace) -> list[str]:
    # CRF 0 ＝無損，libx264 會改用 High 4:4:4 Predictive；此時硬塞 -profile:v high 會直接失敗。
    profile = ["-profile:v", "high"] if args.crf > 0 else []
    return [
        "ffmpeg", "-hide_banner", "-nostdin", "-loglevel", "error", "-y",
        "-i", str(local),
        # 不自己加 transpose：ffmpeg 依 display matrix 自動轉正（見 pptx_common.scale_filter）
        "-vf", scale_filter(args.max_edge),
        "-c:v", "libx264", "-preset", args.preset, "-crf", str(args.crf),
        "-pix_fmt", "yuv420p", *profile,
        # level 不硬編：由 libx264 依解析度自動選（硬編 4.2 在 >1080p 會失敗）
        "-c:a", "aac", "-b:a", f"{args.audio_bitrate}k", "-ar", "48000",
        "-movflags", "+faststart",
        str(dest),
    ]


def process_one(local: Path, dest: Path, args: argparse.Namespace, rows: list[tuple]) -> None:
    before = local.stat().st_size
    info_before = ffprobe_info(local)
    run(encode_command(local, dest, args))
    after = dest.stat().st_size

    status = "ENCODED"
    if not args.no_keep_original and after >= before:
        shutil.copyfile(local, dest)
        after = before
        status = "KEPT(bigger)"

    drift = abs(ffprobe_info(dest)["duration"] - info_before["duration"])
    if drift > DRIFT_WARN_SECONDS:
        print(f"WARN: 時長漂移 {drift:.2f}s > {DRIFT_WARN_SECONDS}s：{dest.name}", file=sys.stderr)

    rows.append((dest.name, before, after, status))
    saved = (1 - after / before) * 100 if before else 0.0
    print(f"  {dest.name:<20} {human_bytes(before):>10} → {human_bytes(after):>10}"
          f"  ({saved:>5.1f}%)  drift {drift:.2f}s  {status}")


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.src.is_dir() and args.src.resolve() == args.out.resolve():
        # 目錄模式最危險的誤用：來源目錄當成輸出目錄 ＝ 原地覆蓋原檔
        print("FAIL: --out 不可與 --src 相同（會原地覆蓋原檔）", file=sys.stderr)
        return 1
    # --list 只看規格（ffprobe）：不強迫裝 ffmpeg，免得「只想看一眼」也被工具鏈擋住
    names = pick_sources(args.src, args.only)
    require("ffprobe", "讀取規格" if args.list_only else "驗證時長")
    if not args.list_only:
        require("ffmpeg", "轉碼")
    if not names:
        print("沒有可轉碼的影片（沒有內嵌影片，或 --only 沒選到東西）")
        return 0

    # --list 只是「先看不跑」：不建 --out 目錄、不寫任何檔（避免留下空目錄）
    if not args.list_only:
        args.out.mkdir(parents=True, exist_ok=True)
    print(f"來源：{args.src}\n輸出：{args.out}\n"
          f"參數：CRF {args.crf}、preset {args.preset}、長邊 {args.max_edge}、音訊 {args.audio_bitrate}k")
    print(f"待處理 {len(names)} 支：" + ", ".join(Path(n).name for n in names))

    from_zip = args.src.suffix.lower() == ".pptx"
    rows: list[tuple] = []
    staged = Path(tempfile.mkdtemp(prefix="pptx-shrink-"))
    try:
        for name in names:
            dest = args.out / Path(name).name
            if from_zip:
                local = extract_member(args.src, name, staged)
            else:
                local = args.src / Path(name).name
            if args.list_only:
                info = ffprobe_info(local)
                print(f"  [list] {dest.name} {info['width']}x{info['height']} "
                      f"{info['duration']:.1f}s {human_bytes(local.stat().st_size)}")
            else:
                try:
                    process_one(local, dest, args, rows)
                except SystemExit:
                    print(f"FAIL: 轉碼失敗（已完成 {len(rows)} 支）：{dest.name}", file=sys.stderr)
                    return 3
            if from_zip:
                local.unlink()  # 峰值空間 = 單支最大影片
    finally:
        shutil.rmtree(staged, ignore_errors=True)

    if rows:
        before_total = sum(r[1] for r in rows)
        after_total = sum(r[2] for r in rows)
        log = args.out / "encode-log.tsv"
        with log.open("w", encoding="utf-8") as fh:
            fh.write("name\tbefore_bytes\tafter_bytes\tstatus\n")
            for row in rows:
                fh.write("\t".join(str(v) for v in row) + "\n")
        print(f"\n合計 {human_bytes(before_total)} → {human_bytes(after_total)}"
              f"（省 {(1 - after_total / before_total) * 100:.1f}%）")
        print(f"log：{log}（下一關 repack 用 --media-dir {args.out}）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
