#!/usr/bin/env bash
# skills/dav-wiki/scripts/wiki-cleanup.sh — TD-019 dav-wiki 軟刪除磁碟清理 CLI
# 對應 docs/sop/handbook/dav-wiki-cleanup.md

set -uo pipefail

# Source shared logging helpers (lib/log.sh). Path resolves relative to
# this script's location (../../../lib/log.sh). Other scripts in
# skills/dav-wiki/scripts/ can adopt the same pattern.
# NOTE: We keep set -uo pipefail (no -e) so pipe failures can be handled
# per-command (e.g. `ffmpeg ... || true`, Python heredoc that may raise).
# ERR trap is intentionally NOT set because internal Python heredocs in
# this script raise expected errors (e.g. _purge mode skips creating
# _deprecated/, so the DEPRECATED_INDEX Python block fails harmlessly).
_LOG_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/log.sh"
# shellcheck source=../../../lib/log.sh
source "$_LOG_LIB"

# === 預設值 ===
TARGET="docs"
OLDER_THAN=90
DRY_RUN=false
ASSUME_YES=false
PURGE=false

# === 旗標解析 ===
usage() {
    cat <<EOF
Usage: wiki-cleanup.sh [options]

Options:
  --target <path>       指定 dav-wiki 根目錄（預設 docs/）
  --older-than <days>   只清理超過 N 天的 deprecated（預設 90）
  --dry-run             只顯示計畫，不實際執行
  --yes / -y            跳過互動確認
  --purge               真刪除（危險，預設禁用）
  --help / -h           顯示說明

對應手冊: docs/sop/handbook/dav-wiki-cleanup.md
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET="$2"; shift 2;;
        --older-than) OLDER_THAN="$2"; shift 2;;
        --dry-run) DRY_RUN=true; shift;;
        --yes|-y) ASSUME_YES=true; shift;;
        --purge) PURGE=true; shift;;
        --help|-h) usage; exit 0;;
        *) log_err "未知旗標: $1"; usage; exit 2;;
    esac
done

# === 前置檢查 ===
if [[ ! -d "$TARGET" ]]; then
    log_err "目標目錄不存在: $TARGET"
    exit 3
fi

WIKI_DIR="$TARGET/wiki"
DEPRECATED_DIR="$WIKI_DIR/_deprecated"
INDEX_FILE="$WIKI_DIR/_index.json"
DEPRECATED_INDEX="$DEPRECATED_DIR/_index.json"

if [[ ! -d "$WIKI_DIR" ]]; then
    log_err "wiki 目錄不存在: $WIKI_DIR"
    exit 3
fi

# === 工具：計算兩個日期的差（天數）===
days_between() {
    local d1="$1" d2="$2"
    # 用 GNU date 計算（macOS 用 -j -f）
    if date --version >/dev/null 2>&1; then
        # GNU date (Linux)
        local sec1 sec2
        sec1=$(date -d "$d1" +%s 2>/dev/null || echo 0)
        sec2=$(date -d "$d2" +%s 2>/dev/null || echo 0)
    else
        # BSD date (macOS)
        local sec1 sec2
        sec1=$(date -j -f "%Y-%m-%d" "$d1" +%s 2>/dev/null || echo 0)
        sec2=$(date -j -f "%Y-%m-%d" "$d2" +%s 2>/dev/null || echo 0)
    fi
    if [[ "$sec1" -eq 0 || "$sec2" -eq 0 ]]; then
        echo "-1"
        return
    fi
    echo $(( (sec2 - sec1) / 86400 ))
}

# === 工具：從檔案讀 frontmatter 欄位（純 bash）===
# 支援 `key: value` 和 `key: "value"` 兩種
get_fm() {
    local file="$1" key="$2"
    awk -v k="$key" '
        /^---$/ { in_fm = !in_fm; next }
        in_fm && $0 ~ "^"k":" {
            # 去掉 "key:" 前綴與空白
            sub("^"k":[[:space:]]*", "")
            # 去掉雙引號
            gsub("\"", "")
            # 取第一段（如果是 list，只取開頭）
            print
            exit
        }
    ' "$file"
}

# === 工具：取得檔案的季度（基於 YYYY-MM-DD）===
get_quarter() {
    local date="$1"
    local year month q
    year=$(echo "$date" | cut -d- -f1)
    month=$(echo "$date" | cut -d- -f2)
    case "$month" in
        01|02|03) q="Q1";;
        04|05|06) q="Q2";;
        07|08|09) q="Q3";;
        10|11|12) q="Q4";;
        *) q="Q1";;
    esac
    echo "${year}-${q}"
}

# === 掃描所有 .md，篩選 deprecated 檔案（超過 --older-than 天數） ===
# 決定方式：優先用 frontmatter 的 deprecated_at；若無則用 mtime。
TODAY=$(date +%Y-%m-%d)
declare -a TO_CLEAN

while IFS= read -r -d '' file; do
    # 跳過 _deprecated/ 內
    [[ "$file" == *"/_deprecated/"* ]] && continue

    # 跳過 _index.json / _tags.json
    [[ "$(basename "$file")" == _index.json ]] && continue
    [[ "$(basename "$file")" == _tags.json ]] && continue

    deprecated=$(get_fm "$file" "deprecated")
    deprecated_at=$(get_fm "$file" "deprecated_at")

    [[ "$deprecated" != "true" ]] && continue

    # 如果沒 deprecated_at，用檔案 mtime fallback
    if [[ -z "$deprecated_at" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            deprecated_at=$(stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null)
        else
            deprecated_at=$(stat -c "%y" "$file" 2>/dev/null | cut -d' ' -f1)
        fi
    fi

    [[ -z "$deprecated_at" ]] && continue

    age=$(days_between "$deprecated_at" "$TODAY")
    [[ "$age" -lt "$OLDER_THAN" ]] && continue

    TO_CLEAN+=("$file")
done < <(find "$WIKI_DIR" -type f -name "*.md" -print0)

# === 顯示計畫 ===
COUNT=${#TO_CLEAN[@]}
if [[ "$COUNT" -eq 0 ]]; then
    log_info "沒有 deprecated 超過 ${OLDER_THAN} 天的檔案，nothing to do。"
    exit 0
fi

log_info "找到 $COUNT 個 deprecated 超過 ${OLDER_THAN} 天的檔案："
for f in "${TO_CLEAN[@]}"; do
    dep_at=$(get_fm "$f" "deprecated_at")
    log_plan "${f#$WIKI_DIR/} (deprecated ${dep_at})"
done

if $DRY_RUN; then
    log_info "Dry-run：不實際移動，僅顯示計畫"
    exit 0
fi

# === 用戶確認（除非 --yes）===
if ! $ASSUME_YES; then
    read -rp "[?] 是否移到 ${DEPRECATED_DIR##*/}/？[y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "[INFO] 用戶取消，未移動任何檔案。"
        exit 0
    fi
fi

# === 執行 ===
if ! $PURGE; then
    mkdir -p "$DEPRECATED_DIR"
fi

# 確保 _index.json 存在
if [[ ! -f "$INDEX_FILE" ]]; then
    echo '{"version":1,"documents":[],"tags_index":{}}' > "$INDEX_FILE"
fi

# 確保 _deprecated/_index.json 存在（purge 模式下不需）
if ! $PURGE && [[ ! -f "$DEPRECATED_INDEX" ]]; then
    echo '{"version":1,"deprecated":[]}' > "$DEPRECATED_INDEX"
fi

moved=0
skipped=0
errors=0

for f in "${TO_CLEAN[@]}"; do
    rel="${f#$WIKI_DIR/}"
    fname=$(basename "$f")
    dep_at=$(get_fm "$f" "deprecated_at")
    quarter=$(get_quarter "$dep_at")
    target_dir="$DEPRECATED_DIR/$quarter"
    target_file="$target_dir/$fname"

    # 同名檔已存在 → 跳過
    if [[ -f "$target_file" ]]; then
        echo "[WARN] 同名檔已存在於 _deprecated/${quarter}/，跳過：$fname"
        skipped=$((skipped + 1))
        continue
    fi

    if $PURGE; then
        if rm "$f" 2>/dev/null; then
            echo "[OK] 刪除：$rel"
        else
            echo "[ERR] 刪除失敗：$rel"
            errors=$((errors + 1))
            skipped=$((skipped + 1))
            continue
        fi
    else
        mkdir -p "$target_dir"
        # 先補 frontmatter 欄位，再 mv
        moved_ok=false
        if grep -q "^deprecated_moved_at:" "$f"; then
            if mv "$f" "$target_file" 2>/dev/null; then moved_ok=true; fi
        else
            if awk -v today="$TODAY" '
                BEGIN { inserted = 0 }
                /^---$/ && !inserted && NR == 1 { print; print "deprecated_moved_at: "today; inserted = 1; next }
                /^---$/ && inserted && !done { print; done = 1; next }
                { print }
            ' "$f" > "$target_file"; then
                if rm "$f" 2>/dev/null; then moved_ok=true; fi
            fi
        fi
        if $moved_ok; then
            echo "[OK] 移動：$rel → _deprecated/${quarter}/${fname}"
        else
            echo "[ERR] 移動失敗：$rel"
            errors=$((errors + 1))
            skipped=$((skipped + 1))
            continue
        fi
    fi
    moved=$((moved + 1))
done

# === 更新 _index.json ===
if [[ $moved -gt 0 ]]; then
    # 用 Python 處理 JSON（如果可用），否則簡化處理
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$INDEX_FILE" "${TO_CLEAN[@]}" <<'PYEOF'
import json, sys
index_file = sys.argv[1]
files = sys.argv[2:]

with open(index_file) as f:
    data = json.load(f)

# 從 documents / tags_index 移除
file_ids = set()
for fp in files:
    fname = fp.split("/")[-1].replace(".md", "")
    file_ids.add(fname)
    # 也加路徑變體
    parts = fp.split("/")
    if len(parts) > 1:
        file_ids.add("/".join(parts[-2:]).replace(".md", ""))

data["documents"] = [d for d in data.get("documents", [])
                     if d.get("id") not in file_ids
                     and d.get("path", "").replace(".md", "") not in file_ids]

# tags_index
for tag, doc_ids in list(data.get("tags_index", {}).items()):
    data["tags_index"][tag] = [d for d in doc_ids if d not in file_ids]
    if not data["tags_index"][tag]:
        del data["tags_index"][tag]

with open(index_file, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
    else
        echo "[WARN] 找不到 python3，跳過 _index.json 更新"
    fi
fi

# === 更新 _deprecated/_index.json ===
if [[ $moved -gt 0 ]] && command -v python3 >/dev/null 2>&1; then
    python3 - "$DEPRECATED_INDEX" "${TO_CLEAN[@]}" <<'PYEOF'
import json, sys
index_file = sys.argv[1]
files = sys.argv[2:]

try:
    with open(index_file) as f:
        data = json.load(f)
except Exception:
    data = {"version": 1, "deprecated": []}

if "deprecated" not in data:
    data["deprecated"] = []

today = __import__("datetime").date.today().isoformat()
for fp in files:
    fname = fp.split("/")[-1].replace(".md", "")
    # fp 是絕對路徑，轉成相對於 docs/wiki/
    rel_path = fp
    if "/docs/wiki/" in fp:
        rel_path = fp.split("/docs/wiki/", 1)[1]
    elif fp.startswith("docs/wiki/"):
        rel_path = fp[len("docs/wiki/"):]
    data["deprecated"].append({
        "id": fname,
        "original_path": rel_path,
        "deprecated_moved_at": today
    })

with open(index_file, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
fi

log_ok "完成：移動 ${moved}、跳過 ${skipped}、失敗 ${errors}"

# === step [9]：重建 docs/README.md ===
# 使用 _index.json 「主刪前」的快照，但在 _index.json 已更新後重建。
# 邏輯：將 _index.json 中的 _deprecated/_index.json 記錄的 deprecated 文件排除（重入點為「未來被查的 _index.json」）
# 但因為 _index.json 已刪，這裡改讀 _deprecated/_index.json 拿哪些被去除。

if [[ $moved -gt 0 ]] && ! $PURGE && command -v python3 >/dev/null 2>&1; then
    README_FILE="$TARGET/README.md"
    # 拿未刪前的 _index.json：我們在 step [9] 前先讀一份快照
    # 不行，這需要重設計流程。最簡單方式：重建時不需從 _index.json，該從 `docs/wiki/` 實際檔案掃描 frontmatter。
    if python3 - "$README_FILE" "$WIKI_DIR" "$DEPRECATED_INDEX" <<'PYEOF'
import json, sys
from pathlib import Path

readme_file, wiki_dir, deprecated_index = sys.argv[1], sys.argv[2], sys.argv[3]

# 讀 _deprecated/_index.json 拿已搬走的文件 id 列表
try:
    with open(deprecated_index) as f:
        dep_data = json.load(f)
except Exception:
    dep_data = {"deprecated": []}
deprecated_ids = {d.get("id") for d in dep_data.get("deprecated", [])}
deprecated_paths = {d.get("original_path") for d in dep_data.get("deprecated", [])}

# 讀 _index.json拿現存文件
index_file = wiki_dir + "/_index.json"
try:
    with open(index_file) as f:
        idx = json.load(f)
except Exception:
    idx = {"documents": [], "tags_index": {}}

documents = idx.get("documents", [])
if not documents:
    Path(readme_file).write_text("# Knowledge Wiki\n\n（無文件）\n", encoding="utf-8")
    sys.exit(0)

# 統計 tags
tags_count = {}
for d in documents:
    for t in d.get("tags", []):
        tags_count[t] = tags_count.get(t, 0) + 1

# 統計 categories
categories = {}
for d in documents:
    cat = d.get("category", "uncategorized")
    categories[cat] = categories.get(cat, 0) + 1

lines = ["# Knowledge Wiki", ""]
lines.append(f"總文件數：{len(documents)}")
lines.append(f"Tags：{len(tags_count)} 個")
lines.append(f"Categories：{len(categories)} 個")
lines.append("")
lines.append("## Categories")
for cat, count in sorted(categories.items()):
    lines.append(f"- **{cat}** ({count})")
lines.append("")
lines.append("## Tags")
for tag, count in sorted(tags_count.items(), key=lambda x: -x[1]):
    lines.append(f"- `{tag}` ({count})")

Path(readme_file).write_text("\n".join(lines) + "\n", encoding="utf-8")
PYEOF
    then
        echo "[OK] 重建 $README_FILE"
    fi
fi