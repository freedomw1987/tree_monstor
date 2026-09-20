#!/usr/bin/env bash
# tools/rsi-aggregate.sh — RSI 跨專案觀察聚合 CLI
# 對應 docs/sop/handbook/2.8-rsi-evolution.md §6.2
# 對應 Backlog US-015

set -u
# 避免 UTF-8 locale 變量中文字符問題
export LC_ALL=C
export LANG=C
# 注意：不用 pipefail（macOS bash 3.2 不支援 declare -A，需手動處理）

# === 預設值 ===
OBS_ROOT="${HOME}/.tree-monstor/observations"
OUTPUT=""
SINCE=""
PROJECT_FILTER=""

# === 旗標解析 ===
usage() {
    cat <<EOF
Usage: rsi-aggregate.sh [options]

聚合所有已裝 tree_monstor 專案的觀察記錄，產出 markdown 報告。

Options:
  --obs-root <path>       觀察記錄根目錄（預設 ~/.tree-monstor/observations）
  --output <file>         輸出檔案（預設 → stdout）
  --since <YYYY-MM-DD>     只看指定日期之後的記錄
  --project <project-id>  只看指定專案（SHA256[:8]）
  --help / -h             顯示說明

機制：
  - 掃描所有 {project-id}/{YYYY-MM-DD}.json 觀察檔
  - 去重（同類型跨日觀察合併）
  - 統計各類型發生次數
  - 排序（出現次數高的觀察類型排前面）
  - 產出可讀的 markdown 報告

Example:
  ./tools/rsi-aggregate.sh --output docs/sop/rsi-aggregated-2025-09-20.md
  ./tools/rsi-aggregate.sh --since 2025-09-01
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --obs-root)
            OBS_ROOT="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --since)
            SINCE="$2"
            shift 2
            ;;
        --project)
            PROJECT_FILTER="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# === 主程式 ===
if [[ ! -d "$OBS_ROOT" ]]; then
    echo "⚠️  觀察根目錄不存在：$OBS_ROOT" >&2
    echo "（第一次跑是正常的，tree_monstor 裝上後才會開始有觀察）" >&2
    if [[ -n "$OUTPUT" ]]; then
        mkdir -p "$(dirname "$OUTPUT")"
        {
            echo "# RSI 聚合報告（無觀察記錄）"
            echo ""
            echo "觀察根目錄：\`$OBS_ROOT\`"
            echo ""
            echo "**無資料可聚合**。要開始收集，需先在裝 tree_monstor 的專案跑一次。"
        } > "$OUTPUT"
        echo "已寫空報告：$OUTPUT"
    else
        echo "# RSI 聚合報告（無觀察記錄）"
        echo ""
        echo "觀察根目錄：\`$OBS_ROOT\`"
        echo ""
        echo "**無資料可聚合**。"
    fi
    exit 0
fi

# 掃描所有 observation 檔
TOTAL_FILES=0
# 用 plain 變數模擬關聯鍵（macOS bash 3.2 不支援 declare -A）
TYPE_COUNT_DATA=""
PROJECT_COUNT_DATA=""

# 計數 helper（用一個 separator 避免 base 錯誤）
count_type() {
    local key="$1"
    TYPE_COUNT_DATA="$TYPE_COUNT_DATA|$key"
}

count_project() {
    local key="$1"
    PROJECT_COUNT_DATA="$PROJECT_COUNT_DATA|$key"
}

# 用 for-loop 數目（避免 pipefail 觸發）
for project_dir in "$OBS_ROOT"/*/; do
    [[ ! -d "$project_dir" ]] && continue

    project_id=$(basename "$project_dir")

    # 專案過濾
    if [[ -n "$PROJECT_FILTER" && "$project_id" != "$PROJECT_FILTER" ]]; then
        continue
    fi

    count_project "$project_id"

    for obs_file in "$project_dir"*.json; do
        [[ ! -f "$obs_file" ]] && continue

        # 日期過濾（檔名 YYYY-MM-DD.json）
        file_date=$(basename "$obs_file" .json)
        if [[ -n "$SINCE" && "$file_date" < "$SINCE" ]]; then
            continue
        fi

        TOTAL_FILES=$((TOTAL_FILES + 1))

        # 從 gate_results 推導事件類型（每個失敗 gate 是一個事件類型）
        # 提取所有 gate 狀態
        gate_data=$(grep -oE '"gate-[0-9]+-[a-z]+"[[:space:]]*:[[:space:]]*"[a-z]+"' "$obs_file" 2>/dev/null)

        # 只取 fail 的 gate 作為 event_type
        while IFS= read -r gate_line; do
            [[ -z "$gate_line" ]] && continue
            if echo "$gate_line" | grep -q '"fail"'; then
                gate_name=$(echo "$gate_line" | sed -E 's/"(gate-[0-9]+-[a-z]+)".*/\1/')
                count_type "$gate_name"
            fi
        done <<< "$gate_data"
    done
done

# 統計類型數
TYPE_COUNT=${TYPE_COUNT_DATA:-|}
TYPE_COUNT=$(echo "$TYPE_COUNT" | tr '|' '\n' | grep -c '^[a-z]')
PROJECT_COUNT=$(echo "$PROJECT_COUNT_DATA" | tr '|' '\n' | grep -c '^[a-f0-9]')

# 寫報告
write_report() {
    if [[ -n "$OUTPUT" ]]; then
        mkdir -p "$(dirname "$OUTPUT")"
        {
            echo "# RSI 聚合報告"
            echo ""
            echo "**產生時間**：$(date '+%Y-%m-%d %H:%M:%S')"
            echo "**觀察根目錄**：\`$OBS_ROOT\`"
            [[ -n "$SINCE" ]] && echo "**過濾**：自 $SINCE 起"
            [[ -n "$PROJECT_FILTER" ]] && echo "**專案過濾**：$PROJECT_FILTER"
            echo ""
            echo "## 統計"
            echo ""
            echo "| 項目 | 數量 |"
            echo "| --- | --- |"
            echo "| 觀察檔總數 | $TOTAL_FILES |"
            echo "| 專案總數 | $PROJECT_COUNT |"
            echo "| 事件類型數 | $TYPE_COUNT |"
            echo ""

            echo "## 事件類型分佈（按次數排序）"
            echo ""
            # 檢查是否真有非 g 的資料（g是首個 prefix "|"，但 grep "^[a-z]" 排除空）
            if [[ -z "$(echo "$TYPE_COUNT_DATA" | tr '|' '\n' | grep '^[a-z]')" ]]; then
                echo "_（無失敗 gate，全部 pass）_"
            else
                # 計數每個事件類型
                echo "| 事件類型 | 次數 |"
                echo "| --- | --- |"
                echo "$TYPE_COUNT_DATA" | tr '|' '\n' | grep '^[a-z]' | sort | uniq -c | sort -rn | while IFS=' ' read -r cnt name; do
                    echo "| $name | $cnt |"
                done
            fi
            echo ""

            echo "## 專案分佈"
            echo ""
            # 用 pipe-delim 檢查（不一定空是實際資料）
            if [[ -z "$(echo "$PROJECT_COUNT_DATA" | tr '|' '\n' | grep '^[a-f0-9]')" ]]; then
                echo "_（無）_"
            else
                echo "| 專案 ID |"
                echo "| --- |"
                echo "$PROJECT_COUNT_DATA" | tr '|' '\n' | grep '^[a-f0-9]' | sort | while read -r pid; do
                    [[ -z "$pid" ]] && continue
                    echo "| $pid |"
                done
            fi
            echo ""

            echo "## 建議動作"
            echo ""
            echo "1. 用 \`./tools/rsi-propose.sh --report $OUTPUT\` 看準 diff 提案"
            echo "2. 用 \`./tools/rsi-metrics.sh\` 看量化指標"
            echo "3. 用 \`./tools/rsi-rollback.sh list\` 看可回滾版本"
        } > "$OUTPUT"
        echo "✅ 已寫報告：$OUTPUT" >&2
    else
        echo "# RSI 聚合報告"
        echo ""
        echo "**觀察根目錄**：\`$OBS_ROOT\`"
        [[ -n "$SINCE" ]] && echo "**過濾**：自 $SINCE 起"
        [[ -n "$PROJECT_FILTER" ]] && echo "**專案過濾**：$PROJECT_FILTER"
        echo ""
        echo "**觀察檔總數**：$TOTAL_FILES"
        echo "**專案總數**：$PROJECT_COUNT"
        echo "**事件類型數**：$TYPE_COUNT"
    fi
}

write_report