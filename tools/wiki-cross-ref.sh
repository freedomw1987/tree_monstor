#!/usr/bin/env bash
# tools/wiki-cross-ref.sh — TD-020 dav-wiki 交叉引用比對演算法參考實作
# 對應 SKILL.md §[5] 規則：
#   1. tag 重疊 ≥ 50% 為初步候選
#   2. keywords 重疊 ≥ 1 個才算真正相關
#   3. 最多 5 篇、最少 0 篇

set -uo pipefail

INDEX_FILE=""
NEW_DOC_FILE=""
MAX_RESULTS=5
TAG_THRESHOLD_PCT=50

usage() {
    cat <<EOF
Usage: wiki-cross-ref.sh <index.json> <new-doc.json>

從 <index.json> 讀取既有文件，根據 <new-doc.json> 的 tags + keywords 找相關文件。

規則：
  - tags 重疊 ≥ 50% 為初步候選
  - 候選中 keywords 重疊 ≥ 1 個才算真正相關
  - 最多輸出 5 個相關文件 ID

對應 SKILL.md §[5] 交叉引用章節。
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage; exit 0;;
        -*) echo "[ERROR] 未知旗標: $1" >&2; usage; exit 2;;
        INDEX_FILE=*) ;;  # reserved for future
        *)
            if [[ -z "$INDEX_FILE" ]]; then INDEX_FILE="$1"
            elif [[ -z "$NEW_DOC_FILE" ]]; then NEW_DOC_FILE="$1"
            else echo "[ERROR] 多餘參數: $1" >&2; exit 2
            fi
            shift;;
    esac
done

if [[ -z "$INDEX_FILE" || -z "$NEW_DOC_FILE" ]]; then
    usage; exit 2
fi

if [[ ! -f "$INDEX_FILE" || ! -f "$NEW_DOC_FILE" ]]; then
    echo "[ERROR] 檔案不存在" >&2; exit 3
fi

python3 - "$INDEX_FILE" "$NEW_DOC_FILE" "$MAX_RESULTS" "$TAG_THRESHOLD_PCT" <<'PYEOF'
import json, sys

index_file = sys.argv[1]
new_doc_file = sys.argv[2]
max_results = int(sys.argv[3])
tag_threshold_pct = int(sys.argv[4])

with open(index_file) as f:
    index = json.load(f)
with open(new_doc_file) as f:
    new_doc = json.load(f)

new_tags = set(new_doc.get("tags", []))
new_keywords = set(new_doc.get("keywords", []))

if not new_tags:
    sys.exit(0)

results = []
for doc in index.get("documents", []):
    doc_id = doc.get("id")

    # Self-match 排除：新 doc 本身不在 _index.json，但同路徑 / 同名仍可能誤推
    # 如果新 doc 提供了 id，則排除同 id
    if new_doc.get("id") and doc_id == new_doc.get("id"):
        continue
    doc_tags = set(doc.get("tags", []))
    doc_keywords = set(doc.get("keywords", []))

    # Step 1: tag 重疊 ≥ 50%
    if not doc_tags:
        continue
    overlap = new_tags & doc_tags
    overlap_pct = (len(overlap) / len(new_tags)) * 100
    if overlap_pct < tag_threshold_pct:
        continue

    # Step 2: keywords 重疊 ≥ 1 個
    kw_overlap = new_keywords & doc_keywords
    if len(kw_overlap) < 1:
        continue

    results.append((doc_id, overlap_pct, len(kw_overlap)))

# 排序：overlap_pct 高 → kw_overlap 多 → doc_id 字母順序 (deterministic tie-break)
results.sort(key=lambda x: (-x[1], -x[2], x[0]))
results = results[:max_results]

for doc_id, pct, kw in results:
    print(doc_id)
PYEOF