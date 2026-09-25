#!/usr/bin/env bash
# tools/wiki-cross-ref.sh — TD-020 + Sprint 09 FR-2.5.2 dav-wiki 交叉引用
# 對應 SKILL.md §[5] 規則 + FR-3.9 / FR-3.10（多模組比對）
#
# 兩種模式：
#   1. 傳統：wiki-cross-ref.sh <index.json> <new-doc.json>
#   2. 增強：wiki-cross-ref.sh --input <doc.md> --index <_index.json>
#      支援 image / video / audio 共用 source 比對

set -uo pipefail

# === 預設值 ===
INDEX_FILE=""
NEW_DOC_FILE=""
INPUT_FILE=""
MAX_RESULTS=5
TAG_THRESHOLD_PCT=50
ENABLE_MULTIMODAL=true

# === 使用說明 ===
usage() {
    cat <<EOF
Usage:
  wiki-cross-ref.sh <index.json> <new-doc.json>            # 傳統模式
  wiki-cross-ref.sh --input <doc.md> [--index <idx.json>]  # 增強模式

規則：
  - tags 重疊 ≥ 50% 為初步候選
  - 候選中 keywords / image source / video source / audio source 任一重疊
    即算真正相關
  - 最多輸出 5 個相關文件 ID
  - 多模組比對（FR-2.5.2）：共用 image / video / audio source 也算相關

對應 SKILL.md §[5] / FR-3.9 / FR-3.10。
EOF
}

# === 旗標解析（向後相容）===
INPUT_MODE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)
            INPUT_FILE="$2"
            INPUT_MODE=true
            shift 2
            ;;
        --index)
            INDEX_FILE="$2"
            shift 2
            ;;
        --max-results)
            MAX_RESULTS="$2"
            shift 2
            ;;
        --no-multimodal)
            ENABLE_MULTIMODAL=false
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            echo "[ERROR] 未知旗標: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            # 向後相容：位置參數
            if [[ -z "$INDEX_FILE" ]]; then
                INDEX_FILE="$1"
            elif [[ -z "$NEW_DOC_FILE" ]]; then
                NEW_DOC_FILE="$1"
            else
                echo "[ERROR] 多餘參數: $1" >&2
                exit 2
            fi
            shift
            ;;
    esac
done

# === 增強模式 ===
if [[ "$INPUT_MODE" == true ]]; then
    if [[ -z "$INPUT_FILE" ]]; then
        echo "[ERROR] --input is required" >&2
        usage >&2
        exit 2
    fi
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "[ERROR] input file '$INPUT_FILE' does not exist" >&2
        exit 3
    fi

    INPUT_DIR="$(dirname "$INPUT_FILE")"
    if [[ -z "$INDEX_FILE" ]]; then
        # 自動往上找 _index.json
        check_dir="$INPUT_DIR"
        while [[ "$check_dir" != "/" ]]; do
            if [[ -f "$check_dir/_index.json" ]]; then
                INDEX_FILE="$check_dir/_index.json"
                break
            fi
            check_dir="$(dirname "$check_dir")"
        done
        if [[ -z "$INDEX_FILE" ]]; then
            INDEX_FILE="$INPUT_DIR/_index.json"
        fi
    fi
    if [[ ! -f "$INDEX_FILE" ]]; then
        echo "[ERROR] index file '$INDEX_FILE' does not exist" >&2
        echo "  hint: run skills/dav-wiki/scripts/wiki-index.sh --input-dir $INPUT_DIR first" >&2
        exit 3
    fi

    NEW_DOC_FILE="${NEW_DOC_FILE:-$(dirname "$INPUT_FILE")/$(basename "${INPUT_FILE%.md}").newdoc.json}"
    RECOMMENDATIONS_FILE="$(dirname "$INPUT_FILE")/$(basename "${INPUT_FILE%.md}").recommendations.json"
    OUTPUT_FILE="$RECOMMENDATIONS_FILE"

    # 抽取 input file 的 frontmatter → JSON
    python3 - "$INPUT_FILE" "$NEW_DOC_FILE" "$INDEX_FILE" <<'PYEOF'
import sys
import re
import os
import json

input_file = sys.argv[1]
new_doc_file = sys.argv[2]
index_file = sys.argv[3]

with open(input_file, 'r', encoding='utf-8') as f:
    content = f.read()

m = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
if not m:
    print(f"[ERROR] no frontmatter in {input_file}", file=sys.stderr)
    sys.exit(4)

fm_text = m.group(1)
# 簡化：直接把 frontmatter 解析為 JSON 友好的 dict
fm = {}
current_key = None
current_list = []
current_dict = None
for line in fm_text.split('\n'):
    stripped = line.rstrip()
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
    elif line.startswith('  - '):
        if current_dict is not None:
            current_list.append(current_dict)
            current_dict = None
        content = line[4:].strip()
        if ':' in content:
            k, v = content.split(':', 1)
            current_dict = {k.strip(): v.strip().strip('"').strip("'")}
        else:
            current_list.append(content.strip('"').strip("'"))
    elif line.startswith('    ') and current_dict is not None:
        content = line.strip()
        if ':' in content:
            k, v = content.split(':', 1)
            current_dict[k.strip()] = v.strip().strip('"').strip("'")
if current_key:
    if current_dict is not None:
        current_list.append(current_dict)
    if current_list:
        fm[current_key] = current_list
    elif current_dict:
        fm[current_key] = [current_dict]

# 輸出為 newdoc.json（給下面 bash + python 用）
fm['id'] = os.path.relpath(input_file, os.path.dirname(index_file))
with open(new_doc_file, 'w', encoding='utf-8') as f:
    json.dump(fm, f, ensure_ascii=False, indent=2)
PYEOF
fi

# === 傳統模式驗證 ===
if [[ -z "$INDEX_FILE" || -z "$NEW_DOC_FILE" ]]; then
    usage
    exit 2
fi

if [[ ! -f "$INDEX_FILE" ]]; then
    echo "[ERROR] index '$INDEX_FILE' does not exist" >&2
    exit 3
fi
if [[ ! -f "$NEW_DOC_FILE" ]]; then
    echo "[ERROR] new doc '$NEW_DOC_FILE' does not exist" >&2
    exit 3
fi

# === 跑比對 ===
# 如果 INPUT_MODE 設了 RECOMMENDATIONS_FILE，用它；否則用 old behavior
if [[ -z "${OUTPUT_FILE:-}" ]]; then
    OUTPUT_FILE="${NEW_DOC_FILE%.json}.recommendations.json"
fi

python3 - "$INDEX_FILE" "$NEW_DOC_FILE" "$MAX_RESULTS" "$TAG_THRESHOLD_PCT" "$ENABLE_MULTIMODAL" "$OUTPUT_FILE" <<'PYEOF'
import sys
import json
from collections import defaultdict

index_file = sys.argv[1]
new_doc_file = sys.argv[2]
max_results = int(sys.argv[3])
tag_threshold_pct = int(sys.argv[4])
enable_multimodal = sys.argv[5] == "true"
output_file = sys.argv[6]

with open(index_file, 'r', encoding='utf-8') as f:
    index = json.load(f)
with open(new_doc_file, 'r', encoding='utf-8') as f:
    new_doc = json.load(f)

new_tags = set(new_doc.get("tags", []))
new_keywords = set(new_doc.get("keywords", []))

# 多模組：收集所有 source
new_image_sources = set()
new_video_sources = set()
new_audio_sources = set()
for img in new_doc.get("images", []):
    if isinstance(img, dict) and "source" in img:
        new_image_sources.add(img["source"])
for vid in new_doc.get("videos", []):
    if isinstance(vid, dict) and "source" in vid:
        new_video_sources.add(vid["source"])
for aud in new_doc.get("audios", []):
    if isinstance(aud, dict) and "source" in aud:
        new_audio_sources.add(aud["source"])

results = []

# 跳過 self
new_id_guess = new_doc.get("id", "")

for doc in index.get("documents", []):
    if doc.get("id") == new_id_guess:
        continue

    doc_tags = set(doc.get("tags", []))
    doc_keywords = set(doc.get("keywords", []))

    # === Rule 1: tag overlap ≥ threshold ===
    # 語意：new_doc 的 tag 中有幾% 被 doc 涵蓋
    # tags=[] → 不推薦任何東西（不讓 keyword-only 推薦發生）
    if not new_tags:
        continue
    if doc_tags:
        overlap = len(new_tags & doc_tags)
        pct = overlap / len(new_tags) * 100
    else:
        pct = 0

    if pct < tag_threshold_pct:
        continue

    # === Rule 2: keyword / image / video / audio 任一重疊才算真正相關 ===
    kw_overlap = len(new_keywords & doc_keywords)

    img_overlap = 0
    vid_overlap = 0
    aud_overlap = 0
    if enable_multimodal:
        for img in doc.get("images", []):
            if isinstance(img, dict) and img.get("source") in new_image_sources:
                img_overlap += 1
        for vid in doc.get("videos", []):
            if isinstance(vid, dict) and vid.get("source") in new_video_sources:
                vid_overlap += 1
        for aud in doc.get("audios", []):
            if isinstance(aud, dict) and aud.get("source") in new_audio_sources:
                aud_overlap += 1

    total_overlap = kw_overlap + img_overlap + vid_overlap + aud_overlap

    if total_overlap == 0:
        continue

    results.append({
        "doc_id": doc.get("id"),
        "title": doc.get("title"),
        "tag_overlap_pct": round(pct, 1),
        "keyword_overlap": kw_overlap,
        "image_overlap": img_overlap,
        "video_overlap": vid_overlap,
        "audio_overlap": aud_overlap,
        "score": pct + (total_overlap * 20),  # 多模組權重
    })

# 排序：score > tag overlap > doc_id
results.sort(key=lambda r: (-r["score"], -r["tag_overlap_pct"], r["doc_id"]))

# 截斷
results = results[:max_results]

with open(output_file, 'w', encoding='utf-8') as f:
    json.dump({
        "source_doc": new_doc.get("title", ""),
        "recommendations": results,
        "multimodal_enabled": enable_multimodal,
        "max_results": max_results,
    }, f, ensure_ascii=False, indent=2)

# 向後相容：列印推薦 doc_ids 到 stdout
for r in results:
    print(r['doc_id'])

# progress 不列輸出，避免混入 bats $output
PYEOF

exit 0
