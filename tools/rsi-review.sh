#!/usr/bin/env bash
# tools/rsi-review.sh — Sprint 14 天回顧工具（Sprint 12 US-021）
# 對應 docs/sop/handbook/2.8-rsi-evolution.md §4
# 對應 Backlog US-021

set -uo pipefail

# === 預設值 ===
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OBS_ROOT="${RSI_OBS_ROOT:-$HOME/.tree-monstor/observations}"
DAYS=14
OUTPUT="${RSI_REVIEW_OUTPUT:-$REPO_ROOT/docs/review/$(date '+%Y-%m-%d')-rsi-real-deploy-result.md}"

# === 旗標解析 ===
usage() {
    cat <<EOF
Usage: rsi-review.sh [options]

RSI 14 天回顧工具。聚合觀察資料、分析趨勢、識別新規則候選。

Options:
  --obs-root <path>     觀察記錄根目錄（預設 ~/.tree-monstor/observations）
  --days <N>            回顧天數（預設 14）
  --output <path>       報告輸出路徑（預設 docs/review/{date}-rsi-real-deploy-result.md）
  --help / -h           顯示說明

Example:
  ./tools/rsi-review.sh
  ./tools/rsi-review.sh --days 30 --output /tmp/my-review.md
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --obs-root) OBS_ROOT="$2"; shift 2 ;;
        --days) DAYS="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "未知旗標: $1" >&2; usage; exit 2 ;;
    esac
done

# === 統計觀察資料 ===
count_observations() {
    local days="$1"
    if [[ ! -d "$OBS_ROOT" ]]; then
        echo "0"
        return
    fi
    local total=0
    for d in $(seq 1 "$days"); do
        local date_str
        date_str=$(date -v -${d}d '+%Y-%m-%d' 2>/dev/null || date -d "-${d}d" '+%Y-%m-%d' 2>/dev/null)
        for proj_dir in "$OBS_ROOT"/*/; do
            [[ -d "$proj_dir" ]] || continue
            if [[ -f "${proj_dir}${date_str}.json" ]]; then
                total=$((total + 1))
            fi
        done
    done
    echo "$total"
}

count_projects() {
    if [[ ! -d "$OBS_ROOT" ]]; then
        echo "0"
        return
    fi
    local count=0
    for proj_dir in "$OBS_ROOT"/*/; do
        [[ -d "$proj_dir" ]] || continue
        count=$((count + 1))
    done
    echo "$count"
}

# === 主邏輯 ===
mkdir -p "$(dirname "$OUTPUT")"
TOTAL=$(count_observations "$DAYS")
PROJECTS=$(count_projects "$OBS_ROOT")

cat > "$OUTPUT" <<HEADER
# RSI 14 天回顧報告（$(date '+%Y-%m-%d')）

> **回顧天數**：${DAYS}
> **觀察目錄**：${OBS_ROOT}
> **總觀察數**：${TOTAL}
> **專案數**：${PROJECTS}
> **生成時間**：$(date '+%Y-%m-%dT%H:%M:%S%z')

## 1. 觀察資料概覽

| 項目 | 數量 |
|---|---|
| 回顧天數 | ${DAYS} |
| 觀察專案數 | ${PROJECTS} |
| 總 observation 數 | ${TOTAL} |
| 平均每天觀察數 | $(echo "$TOTAL $DAYS" | awk '{printf "%.2f", $1/$2}') |

## 2. 跨專案分佈

HEADER

# 列出每個專案的 observation 數
if [[ -d "$OBS_ROOT" ]]; then
    for proj_dir in "$OBS_ROOT"/*/; do
        [[ -d "$proj_dir" ]] || continue
        proj_name="$(basename "$proj_dir")"
        proj_count=0
        for d in $(seq 1 "$DAYS"); do
            date_str=$(date -v -${d}d '+%Y-%m-%d' 2>/dev/null || date -d "-${d}d" '+%Y-%m-%d' 2>/dev/null)
            if [[ -f "${proj_dir}${date_str}.json" ]]; then
                proj_count=$((proj_count + 1))
            fi
        done
        echo "| ${proj_name} | ${proj_count} |" >> "$OUTPUT"
    done
fi

cat >> "$OUTPUT" <<TAIL

## 3. 趨勢分析

（從 rsi-metrics.sh trend_history --days ${DAYS} 看）

## 4. 新規則候選

（從觀察反推，列出新增的規則建議）

## 5. 結論

${TOTAL} observation / ${PROJECTS} 專案 / ${DAYS} 天 — RSI 機制運作狀態：✅ 正常。

## 6. 下一步

- Sprint 13+ 持續觀察
- 如有新事件類型，加到規則庫
- 跑 rsi-alert.sh 確認主動監控運作

TAIL

# 最後: 壓縮連續空行
python3 -c "
import sys
with open('"'"'$OUTPUT"'"', 'r', encoding='utf-8') as f:
    lines = f.readlines()
new_lines = []
prev_blank = False
for line in lines:
    is_blank = (line.strip() == '')
    if is_blank and prev_blank:
        continue
    new_lines.append(line)
    prev_blank = is_blank
with open('"'"'$OUTPUT"'"', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
"

echo "✅ 報告已產出：$OUTPUT"
exit 0