#!/usr/bin/env bash
# tools/rsi-rules-review.sh — Sprint 14 TD-038
# 自動產生 tools/rules/REVIEW.md
# 對應 docs/prd/04-self-evolution.md §11.7
# 對應 docs/system-design.md ADR-027
# 對應 docs/sop/handbook/2.8-rsi-evolution.md §6.6
#
# 機制：
#   - 讀規則庫（markdown 表格）
#   - 統計（總規則數、按 event_type prefix 分類）
#   - 呼叫 rsi-propose --show-similar 找相似規則對
#   - 寫 REVIEW.md 含統計 + 相似對 + 建議合併方案
#   - 規則庫 ≥ threshold 時加警告（建議人類決策）

set -uo pipefail

# 避免 BATS_TEST_DIRNAME 未定義（bat 環境才有）
: "${BATS_TEST_DIRNAME:=}"

# === 預設值 ===
RULES_FILE="docs/sop/rsi-rules.md"
OUTPUT_DIR="tools/rules"
THRESHOLD=20  # Sprint 14 規則庫上限（依 SP-005 結論）

# === 旗標解析 ===
usage() {
    cat <<EOF
Usage: rsi-rules-review.sh [options]

自動產生 tools/rules/REVIEW.md，含：
  - 規則庫統計（總數、按前綴分類）
  - 相似規則對（Levenshtein ≤ 12 / prefix_sim > 0.4）
  - 建議合併方案（人類決策）

Options:
  --rules <file>           規則庫 markdown 檔（預設 docs/sop/rsi-rules.md）
  --output-dir <path>      輸出目錄（預設 tools/rules/）
  --threshold <N>          規則數警告閾值（預設 20）
  --help / -h              顯示說明

Example:
  ./tools/rsi-rules-review.sh
  ./tools/rsi-rules-review.sh --threshold 15
  ./tools/rsi-rules-review.sh --rules custom-rules.md --output-dir docs/review
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rules)
            RULES_FILE="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD="$2"
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
mkdir -p "$OUTPUT_DIR"
REVIEW_FILE="$OUTPUT_DIR/REVIEW.md"

if [[ ! -f "$RULES_FILE" ]]; then
    echo "⚠️  規則庫不存在：$RULES_FILE" >&2
    echo "（第一次跑是正常的，規則庫還沒建立）" >&2
    exit 0
fi

# === 1. 統計規則庫 ===
TOTAL=$(grep -cE '^\| [0-9]+ \|' "$RULES_FILE" 2>/dev/null || echo 0)
TOTAL=${TOTAL:-0}

# 抓 event_type 欄
EVENTS=$(grep -E '^\| [0-9]+ \|' "$RULES_FILE" | awk -F'|' '{print $3}' | sed 's/^ *//; s/ *$//')

# 按前綴分類（取 _ 前綴）
PREFIX_STATS=$(printf '%s\n' "$EVENTS" | awk -F'_' '{print $1}' | sort | uniq -c | sort -rn)

# === 2. 找相似規則 ===
# 解決路徑：先找 rsi-propose.sh
PROPOSE_SH=""
if [[ -f "$BATS_TEST_DIRNAME/../tools/rsi-propose.sh" ]] 2>/dev/null; then
    PROPOSE_SH="$BATS_TEST_DIRNAME/../tools/rsi-propose.sh"
fi
if [[ -z "$PROPOSE_SH" ]] && [[ -f "$(dirname "$0")/rsi-propose.sh" ]]; then
    PROPOSE_SH="$(dirname "$0")/rsi-propose.sh"
fi
if [[ -z "$PROPOSE_SH" ]] && [[ -f "./tools/rsi-propose.sh" ]]; then
    PROPOSE_SH="./tools/rsi-propose.sh"
fi

SIMILAR_OUTPUT=""
if [[ -n "$PROPOSE_SH" ]]; then
    SIMILAR_OUTPUT=$("$PROPOSE_SH" --show-similar --rules "$RULES_FILE" --output-format json 2>/dev/null || echo "")
fi

# 若無結果或不是 JSON，給預設
if [[ -z "$SIMILAR_OUTPUT" ]] || ! echo "$SIMILAR_OUTPUT" | python3 -c 'import sys, json; json.load(sys.stdin)' 2>/dev/null; then
    SIMILAR_OUTPUT='{"schema_version":"rsi-propose-similar/1.0","rules_file":"'"$RULES_FILE"'","total_events":0,"similar_pairs":[],"total_similar_pairs":0}'
fi

SIMILAR_COUNT=$(echo "$SIMILAR_OUTPUT" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("total_similar_pairs", 0))' 2>/dev/null || echo 0)

# === 3. 產生 REVIEW.md ===
WARNING_BLOCK=""
if [[ "$TOTAL" -gt "$THRESHOLD" ]]; then
    WARNING_BLOCK="## ⚠️ 警告

規則庫共 $TOTAL 條，超過閾值 $THRESHOLD。

依 SP-005 結論，建議人類決策合併、拆分或淘汰部分規則。
建議執行：
  1. 本檔下方「相似規則對」清單
  2. 判斷是否合併（保留相似中較精準的）
  3. 跑 rsi-rules-review.sh --threshold $((THRESHOLD - 5)) 重新評估
"
fi

# 組裝 REVIEW.md
REVIEW_CONTENT="# RSI 規則庫 Review

> 自動產生 by \`tools/rsi-rules-review.sh\`（Sprint 14 TD-038）
> 產生時間：$(date '+%Y-%m-%d %H:%M:%S')
> 規則庫：\`$RULES_FILE\`

## 統計

| 項目 | 數值 |
| --- | --- |
| 總規則數 | $TOTAL |
| 閾值 | $THRESHOLD |
| 相似規則對數 | $SIMILAR_COUNT |

### 按前綴分類

| 前綴 | 規則數 |
| --- | --- |
$(echo "$PREFIX_STATS" | awk '{printf "| %s | %s |\n", $2, $1}')

$WARNING_BLOCK

## 相似規則對

\`\`\`json
$SIMILAR_OUTPUT
\`\`\`

## 建議合併方案（人類決策）

依 SP-005 結論：AI 提建議，人類決策合併。

建議處理流程：
1. 上方 JSON 中 \`similar_pairs\` 每對都考慮是否合併
2. 合併原則：
   - 保留「描述較精準」的事件類型
   - 合併後要在 PRD §11 + rules/ 同步更新
   - 若規則觸發頻率差 > 5x，建議拆分而非合併
3. 決定後執行：
   - 修改 \`$RULES_FILE\`（刪除 / 合併 / 拆分）
   - 跑 \`./tools/rsi-rules-review.sh\` 重新驗證

## 何時該跑

依 docs/sop/handbook/2.8-rsi-evolution.md §6.6：
- 累積 5 個新事件後提醒 review（避免噪音）
- Sprint 結束時強制 review
- 規則庫 ≥ 20 條時強制 review

## 參考

- docs/prd/04-self-evolution.md §11.7 — Sprint 14 RSI 成熟化 PRD
- docs/system-design.md ADR-027 — 定期 review 原則
- docs/sop/rsi-rule-extension-2026-09-20.md — 規則庫擴展歷史
"

printf "%s" "$REVIEW_CONTENT" > "$REVIEW_FILE"

echo "✅ 已產生 REVIEW.md：$REVIEW_FILE" >&2
echo "（規則數 $TOTAL，相似對 $SIMILAR_COUNT，閾值 $THRESHOLD）" >&2

if [[ "$TOTAL" -gt "$THRESHOLD" ]]; then
    echo "⚠️  規則數超過閾值，建議 review" >&2
    exit 0  # 不 exit 1（不阻擋流程，僅警告）
fi

exit 0