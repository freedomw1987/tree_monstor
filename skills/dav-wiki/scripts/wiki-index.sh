#!/usr/bin/env bash
# tools/wiki-index.sh — Sprint 09 FR-2.5.1 dav-wiki 多模組索引
# 對應 docs/prd/03-knowledge-extraction.md / docs/plan/2026-01-15-dav-wiki-sprint-09.md
#
# 從 wiki frontmatter 收集多模組索引（images / videos / audios）到 _index.json。

set -uo pipefail

# === 預設值 ===
INPUT=""
INPUT_DIR=""
OUTPUT_FILE=""

# === 錯誤碼 ===
EXIT_OK=0
EXIT_USAGE=1
EXIT_NOINPUT=2

# === 使用說明 ===
usage() {
    cat <<EOF
Usage: wiki-index.sh --input <md> | --input-dir <dir> [options]

從 wiki frontmatter 收集多模組索引（images / videos / audios / tags / source），
寫入 _index.json。

Options:
  --input <file>            單一 wiki 屬性
  --input-dir <dir>         掃描整個目錄（含子目錄）
  --output-file <file>      索引輸出（預設 ./<dir>/_index.json）
  --help / -h               顯示說明

Output _index.json 結構:
  {
    "version": 1,
    "documents": [
      { "id": "<path>", "title": "...", "tags": [...],
        "images": [...], "videos": [...], "audios": [...] }
    ],
    "images": [ { "source": "...", "docs": ["id1", "id2"] } ],
    "videos": [ { "source": "...", "docs": [...] } ],
    "audios": [ { "source": "...", "docs": [...] } ]
  }

Exit codes:
  0  成功
  1  用法錯誤
  2  輸入檔案 / 目錄不存在

對應手冊: docs/prd/03-knowledge-extraction.md (FR-3.9)
EOF
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
        --output-file)
            OUTPUT_FILE="$2"
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
if [[ -z "$INPUT" && -z "$INPUT_DIR" ]]; then
    echo "ERROR: --input or --input-dir is required" >&2
    usage >&2
    exit "$EXIT_USAGE"
fi

if [[ -n "$INPUT" && ! -f "$INPUT" ]]; then
    echo "ERROR: input file '$INPUT' does not exist" >&2
    exit "$EXIT_NOINPUT"
fi

if [[ -n "$INPUT_DIR" && ! -d "$INPUT_DIR" ]]; then
    echo "ERROR: input-dir '$INPUT_DIR' does not exist" >&2
    exit "$EXIT_NOINPUT"
fi

# === 用 Python 做實際索引（FR-2.5.1）===
# 原因：跨檔 frontmatter 解析 + JSON 構造在 bash 很亂
TARGET_DIR="${INPUT_DIR:-$(dirname "$INPUT")}"

# 若 --input 是單檔，輸出到工作目錄 + <basename>.index.json
if [[ -n "$INPUT" ]]; then
    OUTPUT_FILE="${OUTPUT_FILE:-./$(basename "${INPUT%.md}").index.json}"
else
    OUTPUT_FILE="${OUTPUT_FILE:-$TARGET_DIR/_index.json}"
fi

python3 - "$TARGET_DIR" "$OUTPUT_FILE" <<'PYEOF'
import sys
import os
import re
import json
from collections import defaultdict

target_dir = sys.argv[1]
output_file = sys.argv[2]

# 解析 frontmatter（簡化版正則，無需 PyYAML）
def parse_frontmatter(content):
    m = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
    if not m:
        return {}
    fm = {}
    fm_text = m.group(1)
    # 簡單 key: value / key: [list] / nested dict 解析
    current_key = None
    current_list = []
    current_dict = None
    for line in fm_text.split('\n'):
        stripped = line.rstrip()
        # 頂層欄位
        if re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*:', line):
            # flush previous
            if current_key:
                if current_dict is not None:
                    current_list.append(current_dict)
                    current_dict = None
                if current_list:
                    fm[current_key] = current_list
                    current_list = []
                elif current_dict:
                    fm[current_key] = [current_dict]
            if ':' in line:
                key, value = line.split(':', 1)
                value = value.strip()
                if value.startswith('[') and value.endswith(']'):
                    fm[key.strip()] = [v.strip().strip('"').strip("'") for v in value[1:-1].split(',') if v.strip()]
                    current_key = None
                elif value == '':
                    current_key = key.strip()
                    current_list = []
                    current_dict = None
                else:
                    fm[key.strip()] = value.strip('"').strip("'")
                    current_key = None
        # list 起始：'  - xxx' 或 nested dict entry
        elif line.startswith('  - '):
            # flush previous nested dict
            if current_dict is not None:
                current_list.append(current_dict)
                current_dict = None
            content = line[4:].strip()
            if ':' in content:
                # nested dict 開始
                k, v = content.split(':', 1)
                current_dict = {k.strip(): v.strip().strip('"').strip("'")}
            else:
                current_list.append(content.strip('"').strip("'"))
        # nested dict 的 sub-field
        elif line.startswith('    ') and current_dict is not None:
            content = line.strip()
            if ':' in content:
                k, v = content.split(':', 1)
                current_dict[k.strip()] = v.strip().strip('"').strip("'")
    # flush 最後
    if current_key:
        if current_dict is not None:
            current_list.append(current_dict)
        if current_list:
            fm[current_key] = current_list
        elif current_dict:
            fm[current_key] = [current_dict]
    return fm

# 找所有 .md
md_files = []
for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith('.md') and not f.startswith('_'):
            md_files.append(os.path.join(root, f))

documents = []
images_index = defaultdict(list)
videos_index = defaultdict(list)
audios_index = defaultdict(list)

for md in md_files:
    with open(md, 'r', encoding='utf-8') as f:
        content = f.read()
    fm = parse_frontmatter(content)
    doc_id = os.path.relpath(md, target_dir)
    doc_entry = {
        "id": doc_id,
        "title": fm.get("title", ""),
        "tags": fm.get("tags", []),
        "images": fm.get("images", []),
        "videos": fm.get("videos", []),
        "audios": fm.get("audios", []),
    }
    documents.append(doc_entry)

    # 多模組索引（每個 source 對應到哪些 doc）
    for img in fm.get("images", []):
        if isinstance(img, dict):
            src = img.get("source", "")
            if src:
                images_index[src].append(doc_id)
        elif isinstance(img, str):
            images_index[img].append(doc_id)
    for vid in fm.get("videos", []):
        if isinstance(vid, dict):
            src = vid.get("source", "")
            if src:
                videos_index[src].append(doc_id)
    for aud in fm.get("audios", []):
        if isinstance(aud, dict):
            src = aud.get("source", "")
            if src:
                audios_index[src].append(doc_id)

# 構造最終索引
index = {
    "version": 1,
    "type": "wiki-multimodal",
    "documents": documents,
    "images": [{"source": s, "docs": d} for s, d in images_index.items()],
    "videos": [{"source": s, "docs": d} for s, d in videos_index.items()],
    "audios": [{"source": s, "docs": d} for s, d in audios_index.items()],
}

with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(index, f, ensure_ascii=False, indent=2)

print(f"✓ Indexed {len(documents)} docs")
print(f"  - {len(images_index)} unique images")
print(f"  - {len(videos_index)} unique videos")
print(f"  - {len(audios_index)} unique audios")
print(f"  - Output: {output_file}")
PYEOF

exit "$EXIT_OK"