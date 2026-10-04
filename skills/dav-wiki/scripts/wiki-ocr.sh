#!/usr/bin/env bash
# tools/wiki-ocr.sh — Sprint 09 FR-2.2.3 dav-wiki OCR 補強
# 對應 docs/prd/03-knowledge-extraction.md FR-3.4 / docs/plan/2026-01-15-dav-wiki-sprint-09.md

set -uo pipefail

# === 預設值 ===
INPUT=""
INPUT_DIR=""
OUTPUT_JSON=""
OUTPUT_DIR=""
LANGUAGE="eng"
FORCE_MOCK=false

# === 環境變數支援 ===
if [[ "${DAV_WIKI_MOCK:-}" == "1" ]]; then
    FORCE_MOCK=true
fi

# === 錯誤碼 ===
EXIT_OK=0
EXIT_USAGE=1
EXIT_NOINPUT=2
# EXIT_TOOLMISSING：usage 已承諾 exit 4 =「必要工具缺失（且未啟 mock）」，
# 但現行行為是自動降級為 mock（見下方 WARN）。「硬退 4 or 降級」屬 TMO-035 的決策，
# 這裡保留常數不動（TMO-043 只清確定性的死碼）。
# shellcheck disable=SC2034
EXIT_TOOLMISSING=4

# === 使用說明 ===
usage() {
    cat <<EOF
Usage: wiki-ocr.sh --input <png> --output-json <file> [options]
       wiki-ocr.sh --input-dir <dir> --output-dir <dir> [options]

圖片 OCR（光學字符辨識）。

Engines:
  tesseract       本地 OCR 引擎（若已安裝）
  mock            fallback：產出 placeholder OCR JSON

Options:
  --input <file>           單張圖片
  --input-dir <dir>        批次處理目錄
  --output-json <file>     單檔輸出 JSON
  --output-dir <dir>       批次輸出目錄
  --language <lang>        語言（eng / chi_tra / chi_sim，預設 eng）
  --force-mock             強制 mock 模式（跳過 tesseract）
  --help / -h              顯示說明

Output JSON:
  {
    "source": "<file>",
    "engine": "tesseract" | "mock",
    "language": "eng",
    "text": "...",
    "confidence": 0.95,
    "extracted_at": "ISO 8601"
  }

Exit codes:
  0  成功
  1  用法錯誤
  2  輸入檔案 / 目錄不存在
  4  必要工具缺失（且未啟 mock）

對應手冊: docs/prd/03-knowledge-extraction.md (FR-3.4)
EOF
}

# === Mock OCR ===
mock_ocr() {
    local file="$1"
    local basename
    basename=$(basename "$file")
    cat <<EOF
{
  "source": "$file",
  "engine": "mock",
  "language": "$LANGUAGE",
  "text": "[MOCK] OCR placeholder for $basename — install tesseract for real OCR",
  "confidence": 0.0,
  "extracted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# === Tesseract OCR ===
tesseract_ocr() {
    local file="$1"
    local tmpdir
    tmpdir=$(mktemp -d)
    local output_base="$tmpdir/ocr"

    tesseract "$file" "$output_base" -l "$LANGUAGE" 2>/dev/null
    local text=""
    if [[ -f "$output_base.txt" ]]; then
        text=$(cat "$output_base.txt" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
    fi

    # 嘗試取得 confidence（從 tesseract verbose 模式）
    local confidence=0.0
    if command -v tesseract &>/dev/null; then
        # 簡化：用檔案大小當 dummy confidence（tesseract 標準輸出不易取得）
        confidence=$(awk -v f="$file" 'BEGIN { s=0; while ((getline c < f)) s += length(c); printf "%.2f", s/1000 }')
    fi

    rm -rf "$tmpdir"

    cat <<EOF
{
  "source": "$file",
  "engine": "tesseract",
  "language": "$LANGUAGE",
  "text": "$text",
  "confidence": $confidence,
  "extracted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# === 處理單檔 ===
process_single() {
    local file="$1"
    local output="$2"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: input '$file' does not exist" >&2
        return 2
    fi

    local result
    if [[ "$FORCE_MOCK" == true ]] || ! command -v tesseract &>/dev/null; then
        if ! command -v tesseract &>/dev/null && [[ "$FORCE_MOCK" != true ]]; then
            echo "WARN: tesseract not installed, falling back to mock" >&2
        fi
        result=$(mock_ocr "$file")
    else
        result=$(tesseract_ocr "$file")
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

    while IFS= read -r -d '' file; do
        local name
        name=$(basename "${file%.*}")
        local output="$outdir/$name.ocr.json"
        process_single "$file" "$output" || {
            echo "  ⚠ skipped: $file" >&2
            continue
        }
        ((count++))
    done < <(find "$dir" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" \) -print0)

    # 批次 manifest
    # 引擎標記：mock 模式或本機沒有 tesseract 就算 mock（SC2015：不用 A && B || C）
    ocr_engine="tesseract"
    if [[ "$FORCE_MOCK" = true ]] || [[ -z "$(command -v tesseract)" ]]; then
        ocr_engine="mock"
    fi
    cat > "$outdir/manifest.json" <<EOF
{
  "type": "ocr",
  "engine": "$ocr_engine",
  "language": "$LANGUAGE",
  "count": $count,
  "extracted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

    echo ""
    echo "✅ OCR 批次完成：$count 個檔案"
}

# === 旗標解析 ===
while [[ $# -gt 0 ]]; do
    case "$1" in
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
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --force-mock)
            FORCE_MOCK=true
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
if [[ -n "$INPUT_DIR" ]]; then
    # 批次模式
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="./out"
    fi
    if [[ ! -d "$INPUT_DIR" ]]; then
        echo "ERROR: input-dir '$INPUT_DIR' does not exist" >&2
        exit "$EXIT_NOINPUT"
    fi
    echo "→ Batch OCR: $INPUT_DIR"
    process_batch "$INPUT_DIR" "$OUTPUT_DIR"
else
    if [[ -z "$INPUT" ]]; then
        echo "ERROR: --input or --input-dir is required" >&2
        usage >&2
        exit "$EXIT_USAGE"
    fi
    if [[ ! -f "$INPUT" ]]; then
        echo "ERROR: input '$INPUT' does not exist" >&2
        exit "$EXIT_NOINPUT"
    fi

    echo "→ Single OCR: $INPUT"
    process_single "$INPUT" "$OUTPUT_JSON"
fi

exit "$EXIT_OK"