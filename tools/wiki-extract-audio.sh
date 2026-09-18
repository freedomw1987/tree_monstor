#!/usr/bin/env bash
# tools/wiki-extract-audio.sh — Sprint 08 FR-2.4 dav-wiki 音訊處理
# 對應 docs/prd/03-knowledge-extraction.md FR-3.7 / docs/plan/2026-01-15-dav-wiki-sprint-08.md

set -uo pipefail

# === 預設值 ===
INPUT=""
OUTPUT_DIR="out"
NORMALIZE=true
SEGMENT_DURATION=0  # 0 = 不分段
SAMPLE_RATE=16000
CHANNELS=1

# === 錯誤碼 ===
EXIT_OK=0
EXIT_USAGE=1
EXIT_NOINPUT=2
EXIT_TOOLMISSING=4

# === 使用說明 ===
usage() {
    cat <<EOF
Usage: wiki-extract-audio.sh --input <audio> --output-dir <dir> [options]

音訊標準化 + metadata + 段落切分（給 Whisper 轉錄準備）。

Options:
  --input <file>              必填：來源音訊（wav / mp3 / m4a / flac）
  --output-dir <path>         輸出目錄（預設 ./out）
  --no-normalize              跳過標準化（保留原格式）
  --segment-duration <sec>    段落長度（0 = 不分段，預設 0）
  --sample-rate <hz>          標準化取樣率（預設 16000）
  --channels <N>              標準化聲道（預設 1 = mono）
  --help / -h                 顯示說明

Output:
  <output-dir>/
    audio.wav                 標準化後音訊（除非 --no-normalize）
    original.wav              保留原始（若 --no-normalize）
    segments/                 分段音檔（若 --segment-duration > 0）
    manifest.json             metadata（duration / codec / sample_rate / channels）

Exit codes:
  0  成功
  1  用法錯誤
  2  輸入檔案不存在
  4  必要工具缺失（ffmpeg / ffprobe）

對應手冊: docs/prd/03-knowledge-extraction.md (FR-3.7)
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

# === 取得音訊 metadata ===
get_audio_metadata() {
    local file="$1"
    local duration
    local codec
    local sample_rate
    local channels

    duration=$(ffprobe -v error -show_entries format=duration \
                      -of csv=p=0 "$file" 2>/dev/null)
    codec=$(ffprobe -v error -select_streams a:0 \
                   -show_entries stream=codec_name \
                   -of csv=p=0 "$file" 2>/dev/null)
    sample_rate=$(ffprobe -v error -select_streams a:0 \
                         -show_entries stream=sample_rate \
                         -of csv=p=0 "$file" 2>/dev/null)
    channels=$(ffprobe -v error -select_streams a:0 \
                     -show_entries stream=channels \
                     -of csv=p=0 "$file" 2>/dev/null)

    # 預設值（避免空字串）
    duration="${duration:-0}"
    codec="${codec:-unknown}"
    sample_rate="${sample_rate:-0}"
    channels="${channels:-0}"

    echo "DURATION=$duration"
    echo "CODEC=$codec"
    echo "SAMPLE_RATE=$sample_rate"
    echo "CHANNELS=$channels"
}

# === 標準化 ===
normalize_audio() {
    local input="$1"
    local output="$2"
    ffmpeg -i "$input" -acodec pcm_s16le \
           -ar "$SAMPLE_RATE" -ac "$CHANNELS" \
           "$output" -y 2>/dev/null
    echo "  ✓ Normalized: $output"
}

# === 分段 ===
segment_audio() {
    local input="$1"
    local outdir="$2"
    local segment_duration="$3"

    mkdir -p "$outdir"
    ffmpeg -i "$input" -f segment \
           -segment_time "$segment_duration" \
           -reset_timestamps 1 \
           "$outdir/segment-%03d.wav" -y 2>/dev/null

    local count
    count=$(find "$outdir" -type f -name "*.wav" 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✓ Segments: $count 段"
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
        --no-normalize)
            NORMALIZE=false
            shift
            ;;
        --segment-duration)
            SEGMENT_DURATION="$2"
            shift 2
            ;;
        --sample-rate)
            SAMPLE_RATE="$2"
            shift 2
            ;;
        --channels)
            CHANNELS="$2"
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
echo "→ 音訊處理：$INPUT"

metadata=$(get_audio_metadata "$INPUT")
duration=""
codec=""
sample_rate=""
channels=""
while IFS= read -r line; do
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
        DURATION)    duration="$value" ;;
        CODEC)       codec="$value" ;;
        SAMPLE_RATE) sample_rate="$value" ;;
        CHANNELS)    channels="$value" ;;
    esac
done <<< "$metadata"

# 預設值（避免空字串）
duration="${duration:-0}"
codec="${codec:-unknown}"
sample_rate="${sample_rate:-0}"
channels="${channels:-0}"

echo "→ 時長：${duration}s, codec=$codec, rate=${sample_rate}Hz, channels=$channels"
echo "→ 輸出：$OUTPUT_DIR"

# === 標準化 / 保留原始 ===
segments_dir=""
if [[ "$NORMALIZE" == true ]]; then
    output_audio="$OUTPUT_DIR/audio.wav"
    normalize_audio "$INPUT" "$output_audio"
else
    output_audio="$OUTPUT_DIR/original.wav"
    cp "$INPUT" "$output_audio"
    echo "  ✓ Original: $output_audio"
fi

# === 分段 ===
if [[ "$SEGMENT_DURATION" -gt 0 ]] && [[ -n "$output_audio" ]] && [[ -f "$output_audio" ]]; then
    segments_dir="$OUTPUT_DIR/segments"
    segment_audio "$output_audio" "$segments_dir" "$SEGMENT_DURATION"
fi

# === Manifest ===
cat > "$OUTPUT_DIR/manifest.json" <<EOF
{
  "source": "$INPUT",
  "type": "audio",
  "duration": $duration,
  "codec": "$codec",
  "sample_rate": $sample_rate,
  "channels": $channels,
  "normalized": $([ "$NORMALIZE" = "true" ] && echo "true" || echo "false"),
  "segment_duration": $SEGMENT_DURATION,
  "extracted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "audio": "$output_audio",
  "segments": "$segments_dir"
}
EOF

echo ""
echo "✅ 完成！"
echo "  - Audio: $output_audio"
echo "  - Segments: $segments_dir"
echo "  - Manifest: $OUTPUT_DIR/manifest.json"

exit "$EXIT_OK"