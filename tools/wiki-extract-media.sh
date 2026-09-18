#!/usr/bin/env bash
# tools/wiki-extract-media.sh — Sprint 08 FR-2.6.1 dav-wiki 多模組資產提取
# 對應 docs/prd/03-knowledge-extraction.md FR-3 / docs/plan/2026-01-15-dav-wiki-sprint-08.md

set -uo pipefail

# === 預設值 ===
INPUT=""
OUTPUT_DIR="out"
TYPE=""           # 自動偵測
EXTRACT_IMAGES=true
EXTRACT_TEXT=true

# === 錯誤碼 ===
EXIT_OK=0
EXIT_USAGE=1
EXIT_NOINPUT=2
EXIT_BADTYPE=3
EXIT_TOOLMISSING=4

# === 使用說明 ===
usage() {
    cat <<EOF
Usage: wiki-extract-media.sh --input <file> [options]

從 PDF / DOCX / PPTX 提取媒體（圖片）與文字至指定目錄。

Options:
  --input <file>          必填：來源檔案
  --output-dir <path>     輸出目錄（預設 ./out）
  --type <pdf|docx|pptx>  強制指定類型（預設從副檔名自動偵測）
  --no-images             跳過圖片提取
  --no-text               跳過文字提取
  --help / -h             顯示說明

Output:
  <output-dir>/
    images/               提取的圖片（PNG / JPG）
    text.md               提取的文字（Markdown）
    manifest.json         提取 metadata（type / counts / paths）

Exit codes:
  0  成功
  1  用法錯誤
  2  輸入檔案不存在
  3  不支援的檔案類型
  4  必要工具缺失

對應手冊: docs/prd/03-knowledge-extraction.md (FR-3)
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

# === 類型偵測 ===
detect_type() {
    local ext="${INPUT##*.}"
    # 小寫轉換（相容 bash 3.2+）
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
        pdf)  TYPE="pdf" ;;
        docx) TYPE="docx" ;;
        pptx) TYPE="pptx" ;;
        *)    return 1 ;;
    esac
    return 0
}

# === Manifest 寫入 ===
write_manifest() {
    local type="$1"
    local img_count="$2"
    local text_file="$3"
    local images_dir="$4"

    cat > "$OUTPUT_DIR/manifest.json" <<EOF
{
  "source": "$INPUT",
  "type": "$type",
  "extracted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "text": "$text_file",
  "images": "$images_dir",
  "image_count": $img_count
}
EOF
}

# === PDF 提取 ===
extract_pdf_images() {
    require_tool pdfimages "brew install poppler"
    mkdir -p "$OUTPUT_DIR/images"
    pdfimages -png "$INPUT" "$OUTPUT_DIR/images/img"
    echo "  ✓ PDF 圖片提取完成"
}

extract_pdf_text() {
    require_tool pdftotext "brew install poppler"
    pdftotext -layout "$INPUT" "$OUTPUT_DIR/text.md"
    echo "  ✓ PDF 文字提取完成"
}

# === DOCX 提取 ===
extract_docx_images() {
    require_tool pandoc "brew install pandoc"
    local media_dir="$OUTPUT_DIR/images"
    mkdir -p "$media_dir"
    # pandoc 提取 media 到指定目錄，會在 media_dir 下建 media/ 子目錄
    pandoc --extract-media="$media_dir" \
           "$INPUT" -t markdown -o "$OUTPUT_DIR/_pandoc_out.md"
    # 把 media/ 子目錄內的圖片移到 images/
    if [ -d "$media_dir/media" ]; then
        mv "$media_dir/media"/* "$media_dir/" 2>/dev/null || true
        rmdir "$media_dir/media" 2>/dev/null || true
    fi
    echo "  ✓ DOCX 媒體提取完成"
}

extract_docx_text() {
    require_tool pandoc "brew install pandoc"
    pandoc "$INPUT" -t markdown -o "$OUTPUT_DIR/text.md"
    echo "  ✓ DOCX 文字提取完成"
}

# === PPTX 提取 ===
extract_pptx_images() {
    require_tool python3 "install python3 + python-pptx (pip install python-pptx)"
    mkdir -p "$OUTPUT_DIR/images"
    python3 - "$INPUT" "$OUTPUT_DIR/images" <<'PYEOF'
import sys, os
try:
    from pptx import Presentation
except ImportError:
    print("ERROR: python-pptx not installed", file=sys.stderr)
    sys.exit(4)

src, out_dir = sys.argv[1], sys.argv[2]
prs = Presentation(src)
n = 0
for slide_idx, slide in enumerate(prs.slides, 1):
    for shape in slide.shapes:
        if shape.shape_type == 13:  # PICTURE
            n += 1
            ext = shape.image.ext
            out = os.path.join(out_dir, f"slide-{slide_idx}-{n}.{ext}")
            with open(out, "wb") as f:
                f.write(shape.image.blob)
sys.exit(0)
PYEOF
    echo "  ✓ PPTX 媒體提取完成"
}

extract_pptx_text() {
    require_tool pandoc "brew install pandoc"
    pandoc "$INPUT" -t markdown -o "$OUTPUT_DIR/text.md"
    echo "  ✓ PPTX 文字提取完成"
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
        --type)
            TYPE="$2"
            shift 2
            ;;
        --no-images)
            EXTRACT_IMAGES=false
            shift
            ;;
        --no-text)
            EXTRACT_TEXT=false
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
if [[ -z "$INPUT" ]]; then
    echo "ERROR: --input is required" >&2
    usage >&2
    exit "$EXIT_USAGE"
fi

if [[ ! -f "$INPUT" ]]; then
    echo "ERROR: input file '$INPUT' does not exist" >&2
    exit "$EXIT_NOINPUT"
fi

# 自動偵測類型
if [[ -z "$TYPE" ]]; then
    if ! detect_type; then
        echo "ERROR: cannot detect type from extension; please use --type" >&2
        exit "$EXIT_BADTYPE"
    fi
fi

# 驗證類型合法
case "$TYPE" in
    pdf|docx|pptx) ;;
    *)
        echo "ERROR: unsupported type '$TYPE' (supported: pdf, docx, pptx)" >&2
        exit "$EXIT_BADTYPE"
        ;;
esac

# === 建立輸出目錄 ===
mkdir -p "$OUTPUT_DIR"

# === 執行提取 ===
echo "→ 提取 $TYPE：$INPUT"
echo "→ 輸出目錄：$OUTPUT_DIR"

img_count=0
text_file=""
images_dir=""

if [[ "$EXTRACT_IMAGES" == true ]]; then
    images_dir="$OUTPUT_DIR/images"
    case "$TYPE" in
        pdf)  extract_pdf_images ;;
        docx) extract_docx_images ;;
        pptx) extract_pptx_images ;;
    esac
    img_count=$(find "$OUTPUT_DIR/images" -type f 2>/dev/null | wc -l | tr -d ' ')
fi

if [[ "$EXTRACT_TEXT" == true ]]; then
    text_file="$OUTPUT_DIR/text.md"
    case "$TYPE" in
        pdf)  extract_pdf_text ;;
        docx) extract_docx_text ;;
        pptx) extract_pptx_text ;;
    esac
fi

# === 寫 manifest ===
write_manifest "$TYPE" "$img_count" "$text_file" "$images_dir"

echo ""
echo "✅ 完成！"
echo "  - 圖片：$img_count 張（$images_dir）"
echo "  - 文字：$text_file"
echo "  - Manifest：$OUTPUT_DIR/manifest.json"

# === Sprint 09 FR-2.2.3：OCR 補強（若已安裝 wiki-ocr.sh） ===
if [[ "$img_count" -gt 0 ]]; then
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [[ -x "$REPO_ROOT/tools/wiki-ocr.sh" ]]; then
        echo ""
        echo "→ OCR 補強（FR-2.2.3）：對提取出的圖片跑 OCR"
        if "$REPO_ROOT/tools/wiki-ocr.sh" --input-dir "$images_dir" --output-dir "$images_dir/ocr" 2>&1; then
            echo "  ✓ OCR 完成 → $images_dir/ocr"
        else
            echo "  ⚠ OCR 失敗跳過 (FR-2.2.3 非阻塞)" >&2
        fi
    fi
fi

exit "$EXIT_OK"