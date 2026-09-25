#!/usr/bin/env bash
# tools/wiki-extract-video.sh — Sprint 08 FR-2.3 dav-wiki 影片處理
# 對應 docs/prd/03-knowledge-extraction.md FR-3.6 / docs/plan/2026-01-15-dav-wiki-sprint-08.md

set -uo pipefail

# === 預設值 ===
INPUT=""
OUTPUT_DIR="out"
EXTRACT_FRAMES=true
EXTRACT_AUDIO=true
EXTRACT_CHAPTERS=true
SCENE_THRESHOLD=0.4
FRAME_RATE=1  # 每秒 1 frame

# === 錯誤碼 ===
EXIT_OK=0
EXIT_USAGE=1
EXIT_NOINPUT=2
EXIT_TOOLMISSING=4

# === 使用說明 ===
usage() {
    cat <<EOF
Usage: wiki-extract-video.sh --input <video> --output-dir <dir> [options]

從影片提取 frames、audio、thumbnail、章節切分。

Options:
  --input <file>           必填：來源影片（mp4 / mov / mkv）
  --output-dir <path>      輸出目錄（預設 ./out）
  --no-frames             跳過 frame 提取
  --no-audio              跳過音訊提取
  --no-chapters           跳過章節切分
  --scene-threshold <0-1> 場景偵測閾值（預設 0.4）
  --frame-rate <N>        每秒抽幾張 frame（預設 1）
  --help / -h             顯示說明

Output:
  <output-dir>/
    frames/                提取的 frames（每張 PNG）
    audio.wav              提取的音訊（WAV 16kHz mono）
    thumb.jpg              影片縮圖（中間時刻）
    chapters.json          章節切分 + 時間
    manifest.json           metadata（duration / codec / paths）

Exit codes:
  0  成功
  1  用法錯誤
  2  輸入檔案不存在
  4  必要工具缺失（ffmpeg / ffprobe）

對應手冊: docs/prd/03-knowledge-extraction.md (FR-3.6)
EOF
}

# === 工具檢查 ===
require_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo "ERROR: required tool '$1' not found in PATH" >&2
        echo "  install hint: $2" >&2
        exit "$EXIT_TOOLMISSING"
    fi
}

# === 取得影片 metadata ===
probe_metadata() {
    local file="$1"
    ffprobe -v error -show_entries format=duration:stream=codec_type,codec_name \
            -of csv=p=0 "$file" 2>/dev/null
}

get_duration() {
    ffprobe -v error -show_entries format=duration \
            -of csv=p=0 "$1" 2>/dev/null
}

# === Frame 提取 ===
extract_frames() {
    local input="$1"
    local outdir="$2"
    mkdir -p "$outdir"
    ffmpeg -i "$input" -vf "fps=$FRAME_RATE" \
           "$outdir/frame-%03d.png" -y 2>/dev/null
    local count
    count=$(find "$outdir" -type f -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✓ Frames: $count 張"
}

# === 音訊提取 ===
extract_audio() {
    local input="$1"
    local output="$2"
    # 先檢查是否有音軌
    local has_audio
    has_audio=$(ffprobe -v error -select_streams a \
                -show_entries stream=codec_name \
                -of csv=p=0 "$input" 2>/dev/null | head -1)
    if [[ -z "$has_audio" ]]; then
        echo "  ⚠ Audio: 來源影片無音軌，跳過"
        return 0
    fi
    ffmpeg -i "$input" -vn -acodec pcm_s16le \
           -ar 16000 -ac 1 "$output" -y 2>/dev/null
    if [[ -f "$output" ]]; then
        echo "  ✓ Audio: $output"
    else
        echo "  ⚠ Audio: 提取失敗"
    fi
}

# === Thumbnail ===
extract_thumb() {
    local input="$1"
    local output="$2"
    local duration
    duration=$(get_duration "$input")
    # 抓中間 1 秒當 thumbnail（若 duration < 1 則抓第 1 秒）
    local midpoint
    midpoint=$(awk -v d="$duration" 'BEGIN { printf "%.3f", d/2 }')
    if awk -v d="$duration" 'BEGIN { exit !(d < 1.0) }'; then
        midpoint="0.5"
    fi
    ffmpeg -ss "$midpoint" -i "$input" -vframes 1 \
           "$output" -y 2>/dev/null
    echo "  ✓ Thumbnail: $output"
}

# === 章節切分 ===
extract_chapters() {
    local input="$1"
    local output="$2"
    local threshold="$3"
    local duration
    duration=$(get_duration "$input")

    # 用 ffmpeg scene detect 找出切換時間
    local times_file="$output.tmp"
    ffmpeg -i "$input" \
           -vf "select=gt(scene\,$threshold),showinfo" \
           -vsync vfr \
           -f null - 2>&1 \
           | grep -oE 'pts_time:[0-9.]+' \
           | sed 's/pts_time://' \
           > "$times_file" 2>/dev/null

    local chapters="[]"
    if [[ -s "$times_file" ]]; then
        # 構造 chapters 陣列
        local prev="0"
        local chapter_num=1
        chapters="["
        while IFS= read -r t; do
            # 跳過重複時間
            [[ "$t" == "$prev" ]] && continue
            chapters+="{\"start\": $prev, \"end\": $t, \"title\": \"Chapter $chapter_num\"},"
            prev="$t"
            ((chapter_num++))
        done < "$times_file"
        chapters+="{\"start\": $prev, \"end\": $duration, \"title\": \"Chapter $chapter_num\"}"
        chapters+="]"
    else
        # 沒有場景變化 → 整部為一個 chapter
        chapters="[{\"start\": 0, \"end\": $duration, \"title\": \"Chapter 1\"}]"
    fi
    rm -f "$times_file"

    cat > "$output" <<EOF
{
  "source": "$input",
  "threshold": $threshold,
  "duration": $duration,
  "chapters": $chapters
}
EOF
    echo "  ✓ Chapters: $output"
}

# === Manifest ===
write_manifest() {
    local input="$1"
    local duration="$2"
    local frames_dir="$3"
    local audio_file="$4"
    local thumb_file="$5"
    local chapters_file="$6"

    cat > "$OUTPUT_DIR/manifest.json" <<EOF
{
  "source": "$input",
  "type": "video",
  "duration": $duration,
  "extracted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "frames": "$frames_dir",
  "audio": "$audio_file",
  "thumb": "$thumb_file",
  "chapters": "$chapters_file"
}
EOF
}

# === 旗標解析 ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)
            INPUT="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --no-frames)
            EXTRACT_FRAMES=false
            shift
            ;;
        --no-audio)
            EXTRACT_AUDIO=false
            shift
            ;;
        --no-chapters)
            EXTRACT_CHAPTERS=false
            shift
            ;;
        --scene-threshold)
            SCENE_THRESHOLD="$2"
            shift 2
            ;;
        --frame-rate)
            FRAME_RATE="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit "$EXIT_OK"
            ;;
        *)
            echo "ERROR: unknown flag: $1" >&2
            usage >&2
            exit "$EXIT_USAGE"
            ;;
    esac
done

# === 驗證 ===
if [[ -z "$INPUT" ]]; then
    echo "ERROR: --input is required" >&2
    usage >&2
    exit "$EXIT_USAGE"
fi

if [[ ! -f "$INPUT" ]]; then
    echo "ERROR: input file '$INPUT' does not exist" >&2
    exit "$EXIT_NOINPUT"
fi

# === 工具檢查 ===
require_tool ffmpeg "brew install ffmpeg"
require_tool ffprobe "brew install ffmpeg"

# === 建立輸出目錄 ===
mkdir -p "$OUTPUT_DIR"

# === 取得 metadata ===
duration=$(get_duration "$INPUT")

echo "→ 影片提取：$INPUT"
echo "→ 時長：${duration}s"
echo "→ 輸出：$OUTPUT_DIR"

# === 執行 ===
frames_dir=""
audio_file=""
thumb_file=""
chapters_file=""

if [[ "$EXTRACT_FRAMES" == true ]]; then
    frames_dir="$OUTPUT_DIR/frames"
    extract_frames "$INPUT" "$frames_dir"
fi

if [[ "$EXTRACT_AUDIO" == true ]]; then
    audio_file="$OUTPUT_DIR/audio.wav"
    extract_audio "$INPUT" "$audio_file"
fi

if [[ -n "$duration" ]] && awk -v d="$duration" 'BEGIN { exit !(d > 0) }'; then
    thumb_file="$OUTPUT_DIR/thumb.jpg"
    extract_thumb "$INPUT" "$thumb_file"
fi

if [[ "$EXTRACT_CHAPTERS" == true ]]; then
    chapters_file="$OUTPUT_DIR/chapters.json"
    extract_chapters "$INPUT" "$chapters_file" "$SCENE_THRESHOLD"
fi

# === Manifest ===
write_manifest "$INPUT" "$duration" "$frames_dir" "$audio_file" "$thumb_file" "$chapters_file"

echo ""
echo "✅ 完成！"
echo "  - Frames: $frames_dir"
echo "  - Audio: $audio_file"
echo "  - Thumb: $thumb_file"
echo "  - Chapters: $chapters_file"
echo "  - Manifest: $OUTPUT_DIR/manifest.json"

exit "$EXIT_OK"