#!/usr/bin/env bash
# tools/wiki-media-describe.sh — Sprint 08 FR-2.6.2 dav-wiki 多模組 AI 描述
# 對應 docs/prd/03-knowledge-extraction.md FR-3 / docs/plan/2026-01-15-dav-wiki-sprint-08.md

set -uo pipefail

# === 預設值 ===
MODE=""
INPUT=""
INPUT_DIR=""
OUTPUT_JSON=""
OUTPUT_DIR=""
API_KEY=""
MOCK=false
DRY_RUN=false
MAX_CONCURRENCY=4
LANGUAGE="auto"

# === 環境變數支援 ===
if [[ "${DAV_WIKI_MOCK:-}" == "1" ]]; then
    MOCK=true
fi
API_KEY="${API_KEY:-${OPENAI_API_KEY:-}}"

# === 副檔名白名單（單一來源，reviewer P2-6）===
# describe 只吃圖片、transcript 只吃音訊/影片；批次（process_batch）與單檔白名單共用這份。
# ⚠️ 合約邊界：`.webm` / `.flac` / `.tiff` 從未在本檔白名單內（單檔模式一直會發 WARN），
#    故批次也只略過不處理；若產品要支援，請同時改這裡與 usage 說明。
IMAGE_EXTS="png|jpg|jpeg|gif|webp"
AUDIO_EXTS="mp3|wav|m4a|mp4|mov|mkv"

# === 錯誤碼 ===
EXIT_OK=0
EXIT_USAGE=1
EXIT_NOINPUT=2
EXIT_BADMODE=3
EXIT_TOOLMISSING=4

# === 使用說明 ===
usage() {
    cat <<EOF
Usage: wiki-media-describe.sh --mode <describe|transcript> [options]

呼叫 Vision / Whisper API 生成圖片描述或音訊/影片轉錄。

Modes:
  describe       圖片描述（Vision API）
  transcript     音訊/影片轉錄（Whisper API）

Options:
  --input <file>           單一輸入檔案
  --input-dir <dir>        批次處理目錄
  --output-json <file>     describe mode 單檔輸出 JSON 路徑
  --output-dir <dir>       batch mode 輸出目錄
  --mock                   強制 mock 模式（不連真實 API）
  --api-key <key>          API key（也可從 OPENAI_API_KEY 環境變數讀）
  --language <zh|en|auto>  語言（預設 auto）
  --max-concurrency <N>    平行處裡數（預設 4）
  --dry-run                只印計畫不執行
  --help / -h              顯示說明

Output JSON (describe):
  { "mode": "describe", "source": "<file>", "caption": "...",
    "alt_text": "...", "extracted_at": "ISO 8601", "mock": true/false }

Output JSON (transcript):
  { "mode": "transcript", "source": "<file>", "text": "...",
    "duration": <seconds>, "language": "zh", "extracted_at": "..." }

Exit codes:
  0  成功
  1  用法錯誤
  2  輸入檔案 / 目錄不存在
  3  不支援的 mode
  4  必要工具缺失

對應手冊: docs/prd/03-knowledge-extraction.md (FR-3.4 / FR-3.7)
EOF
}

# === Mock 描述生成 ===
mock_describe() {
    local file="$1"
    local basename
    basename=$(basename "$file")
    local color="colored image"
    case "$basename" in
        red*)   color="red square diagram" ;;
        blue*)  color="blue square diagram" ;;
        *)      color="generic image" ;;
    esac
    cat <<EOF
{
  "mode": "describe",
  "source": "$file",
  "caption": "[MOCK] A $color used for testing the dav-wiki pipeline",
  "alt_text": "[MOCK] $color",
  "model": "mock-vision-v1",
  "extracted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mock": true
}
EOF
}

# === Mock 轉錄 ===
mock_transcribe() {
    local file="$1"
    local duration
    if command -v ffprobe &>/dev/null; then
        duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null || echo "0")
    else
        duration="0"
    fi
    cat <<EOF
{
  "mode": "transcript",
  "source": "$file",
  "text": "[MOCK] This is a placeholder transcript for $file",
  "duration": $duration,
  "language": "$LANGUAGE",
  "model": "mock-whisper-v1",
  "extracted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mock": true
}
EOF
}

# === Real API describe（未實作，留 TODO） ===
real_describe() {
    local file="$1"
    echo "ERROR: real Vision API not implemented yet" >&2
    echo "  set DAV_WIKI_MOCK=1 or pass --mock for testing" >&2
    return "$EXIT_TOOLMISSING"
}

# === Real API transcript（未實作，留 TODO） ===
real_transcribe() {
    local file="$1"
    echo "ERROR: real Whisper API not implemented yet" >&2
    echo "  set DAV_WIKI_MOCK=1 or pass --mock for testing" >&2
    return "$EXIT_TOOLMISSING"
}

# === 處理單檔 ===
process_single() {
    local file="$1"
    local output="$2"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: input '$file' does not exist" >&2
        return 2
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would process: mode=$MODE file=$file output=$output"
        return 0
    fi

    local result
    if [[ "$MOCK" == true ]]; then
        case "$MODE" in
            describe)   result=$(mock_describe "$file") ;;
            transcript) result=$(mock_transcribe "$file") ;;
        esac
    else
        case "$MODE" in
            describe)   real_describe "$file" || return $? ;;
            transcript) real_transcribe "$file" || return $? ;;
        esac
    fi

    if [[ -n "$output" ]]; then
        echo "$result" > "$output"
        echo "  ✓ wrote: $output"
    else
        echo "$result"
    fi
}

# === 批次處理 ===
process_batch() {
    local dir="$1"
    local outdir="$2"

    if [[ ! -d "$dir" ]]; then
        echo "ERROR: input-dir '$dir' does not exist" >&2
        return 2
    fi

    mkdir -p "$outdir"
    local count=0

    # 依 mode 決定接受哪些副檔名。
    # 2026-10-05 TMO-043：原 `ext_pattern` 算完從未使用（shellcheck SC2034），
    # `find` 反而寫死「圖片 + 音訊/影片」全部副檔名 → describe 模式會誤吃 .wav/.mp4，
    # transcript 模式會誤吃 .png（真 bug，見 AC-D17/AC-D18）。
    local ext_pattern=""
    case "$MODE" in
        describe)   ext_pattern="$IMAGE_EXTS" ;;
        transcript) ext_pattern="$AUDIO_EXTS" ;;
        *)
            echo "ERROR: unsupported --mode '$MODE' for --input-dir" >&2
            return 3
            ;;
    esac

    local find_args=()
    local first_ext=1
    local ext
    while IFS= read -r ext; do
        [[ -n "$ext" ]] || continue
        if [[ $first_ext -eq 1 ]]; then
            find_args+=( -iname "*.$ext" )
            first_ext=0
        else
            find_args+=( -o -iname "*.$ext" )
        fi
    done < <(printf '%s\n' "$ext_pattern" | tr '|' '\n')

    while IFS= read -r -d '' file; do
        local name
        name=$(basename "${file%.*}")
        local output="$outdir/$name.desc.json"
        process_single "$file" "$output" || {
            echo "  ⚠ skipped: $file" >&2
            continue
        }
        ((count++))
        if [[ $count -ge $MAX_CONCURRENCY ]]; then
            break
        fi
    done < <(find "$dir" -maxdepth 1 -type f \( "${find_args[@]}" \) -print0)

    echo ""
    echo "✅ 批次完成：$count 個檔案"
}

# === 旗標解析 ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --input)
            INPUT="$2"
            shift 2
            ;;
        --input-dir)
            INPUT_DIR="$2"
            shift 2
            ;;
        --output-json)
            OUTPUT_JSON="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --mock)
            MOCK=true
            shift
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --max-concurrency)
            MAX_CONCURRENCY="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
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
if [[ -z "$MODE" ]]; then
    echo "ERROR: --mode is required (describe | transcript)" >&2
    usage >&2
    exit "$EXIT_USAGE"
fi

case "$MODE" in
    describe|transcript) ;;
    *)
        echo "ERROR: unsupported mode '$MODE' (supported: describe, transcript)" >&2
        exit "$EXIT_BADMODE"
        ;;
esac

# === 執行 ===
if [[ -n "$INPUT_DIR" ]]; then
    # 批次模式
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="./out"
    fi
    if [[ ! -d "$INPUT_DIR" ]]; then
        echo "ERROR: input-dir '$INPUT_DIR' does not exist" >&2
        exit "$EXIT_NOINPUT"
    fi
    echo "→ Batch mode: $MODE in $INPUT_DIR"
    process_batch "$INPUT_DIR" "$OUTPUT_DIR" || exit $?
else
    # 單檔模式
    if [[ -z "$INPUT" ]]; then
        echo "ERROR: --input or --input-dir is required" >&2
        usage >&2
        exit "$EXIT_USAGE"
    fi
    if [[ ! -f "$INPUT" ]]; then
        echo "ERROR: input '$INPUT' does not exist" >&2
        exit "$EXIT_NOINPUT"
    fi

    # describe 對非圖、副檔名警告（mock 仍執行）；白名單來自單一來源常數（不用 case 展開，免 SC2254）
    if [[ "$MODE" == "describe" ]]; then
        if ! printf '%s\n' "${INPUT##*.}" | grep -qE "^($IMAGE_EXTS)$"; then
            echo "WARN: input '$INPUT' is not an image file" >&2
        fi
    fi
    if [[ "$MODE" == "transcript" ]]; then
        if ! printf '%s\n' "${INPUT##*.}" | grep -qE "^($AUDIO_EXTS)$"; then
            echo "WARN: input '$INPUT' is not an audio/video file" >&2
        fi
    fi

    echo "→ Single mode: $MODE"
    process_single "$INPUT" "$OUTPUT_JSON"
fi

exit "$EXIT_OK"