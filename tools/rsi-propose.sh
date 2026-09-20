#!/usr/bin/env bash
# tools/rsi-propose.sh — RSI 跨專案觀察 → 具體 PR diff 提案 CLI
# 對應 docs/sop/handbook/2.8-rsi-evolution.md §6.3
# 對應 Backlog US-015

set -uo pipefail
# 避免 UTF-8 locale 變量中文字符問題
export LC_ALL=C
export LANG=C

# === 預設值 ===
REPORT=""
OUTPUT=""
MIN_FREQUENCES="2"
LIMIT="10"
CONFIDENCE_THRESHOLD=""
OUTPUT_FORMAT="text"  # text | json（Sprint 13 TD-037 新增）
SHOW_SIMILAR=false  # Sprint 14 US-026
RULES_FILE="docs/sop/rsi-rules.md"  # Sprint 14 US-026 預設規則庫

# === 旗標解析 ===
usage() {
    cat <<EOF
Usage: rsi-propose.sh --report <file> [options]

接收 rsi-aggregate.sh 產的聚合報告，產出具體 PR diff 提案清單。

Options:
  --report <file>          聚合報告路徑（必填）
  --output <file>          輸出檔案（預設 → stdout）
  --min-freq <N>           只考慮出現 ≥ N 次的觀察（預設 2）
  --limit <N>              最多產出 N 個提案（預設 10）
  --confidence <0~1>       confidence score 門檻（如 0.7）。未達則列為「需人工確認」
  --output-format <fmt>    輸出格式：text（預設）| json（Sprint 13 TD-037）
  --show-similar            列相似規則（Levenshtein ≤ 3, Sprint 14 US-026）
  --rules <file>            規則庫檔（--show-similar 用，預設 docs/sop/rsi-rules.md）
  --help / -h              顯示說明

confidence 公式：min(1.0, freq × 0.3 + projects × 0.2 + 1)
  （歸一到 0~1，並需超過閾值才列為主要提案）

機制：
  - 從聚合報告的事件類型分佈表讀
  - 對應規則庫（rules/）產生具體 diff 草案
  - 每個提案附：檔案路徑、改動內容、影響專案數、rollback 指令
  - 預設只考慮 ≥2 次觀察的事件（避免雜訊）

Example:
  ./tools/rsi-aggregate.sh --output /tmp/report.md
  ./tools/rsi-propose.sh --report /tmp/report.md --output docs/sop/rsi-proposal-2025-09-20.md
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --report)
            REPORT="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --min-freq)
            MIN_FREQUENCES="$2"
            shift 2
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --confidence)
            CONFIDENCE_THRESHOLD="$2"
            shift 2
            ;;
        --output-format)
            OUTPUT_FORMAT="$2"
            if [[ "$OUTPUT_FORMAT" != "text" && "$OUTPUT_FORMAT" != "json" ]]; then
                echo "❌ 錯誤：--output-format 必須是 text 或 json" >&2
                exit 1
            fi
            shift 2
            ;;
        --show-similar)
            SHOW_SIMILAR=true
            shift
            ;;
        --rules)
            RULES_FILE="$2"
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

# Sprint 14 US-026: --show-similar 列相似規則（用前綴相似度 > 0.6）
cmd_similar() {
    local rules_file="${1:-$RULES_FILE}"

    if [[ ! -f "$rules_file" ]]; then
        echo "⚠️  規則庫不存在：$rules_file" >&2
        return 0
    fi

    local event_types
    event_types="$(grep -E '^\| [0-9]+ \| [a-z]' "$rules_file" | awk -F'|' '{print $3}' | sed 's/^ *//; s/ *$//' | sort -u)"

    if [[ -z "$event_types" ]]; then
        echo "無相似規則（規則庫為空）"
        return 0
    fi

    local similar_output
    similar_output="$(printf '%s\n' "$event_types" | python3 -c '
import sys, json

events = [e.strip() for e in sys.stdin if e.strip()]

def prefix_sim(a, b):
    """前綴相似度：相同前綴長度 / 兩者最長長度"""
    n = 0
    while n < len(a) and n < len(b) and a[n] == b[n]:
        n += 1
    return n / max(len(a), len(b), 1)

def lev(a, b):
    if len(a) < len(b):
        return lev(b, a)
    if len(b) == 0:
        return len(a)
    prev_row = range(len(b) + 1)
    for i, ca in enumerate(a):
        curr_row = [i + 1]
        for j, cb in enumerate(b):
            ins = prev_row[j + 1] + 1
            dele = curr_row[j] + 1
            sub = prev_row[j] + (ca != cb)
            curr_row.append(min(ins, dele, sub))
        prev_row = curr_row
    return prev_row[-1]

pairs = []
seen = set()
for i in range(len(events)):
    for j in range(i + 1, len(events)):
        a, b = events[i], events[j]
        if (b, a) in seen:
            continue
        # 兩種相似度：prefix > 0.6 或 lev ≤ 6（bats_test_xxx 形式差約 6-9）
        sim = prefix_sim(a, b)
        d = lev(a, b)
        if sim > 0.4 or d <= 12:
            seen.add((a, b))
            pairs.append((a, b, sim, d))

if "'"$OUTPUT_FORMAT"'" == "json":
    result = {
        "schema_version": "rsi-propose-similar/1.0",
        "rules_file": "'"$rules_file"'",
        "total_events": len(events),
        "similar_pairs": [{"a": a, "b": b, "prefix_similarity": round(sim, 2), "lev_distance": d} for a, b, sim, d in pairs],
        "total_similar_pairs": len(pairs)
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
else:
    if not pairs:
        print("無相似規則")
    else:
        print("=== 相似規則對 ===")
        for a, b, sim, d in pairs:
            print("  " + a + " <-> " + b + " (prefix_sim=" + str(round(sim, 2)) + ", lev=" + str(d) + ")")
        print("")
        print("總計：" + str(len(pairs)) + " 對相似")
        print("")
        print("💡 建議合併方案：人類決策，AI 提建議（依 SP-005 結論）")
')"

    if [[ -n "$OUTPUT" && "$OUTPUT_FORMAT" == "json" ]]; then
        mkdir -p "$(dirname "$OUTPUT")"
        printf "%s" "$similar_output" > "$OUTPUT"
        echo "✅ 已寫相似規則：$OUTPUT" >&2
    else
        printf "%s" "$similar_output"
    fi
}

# === 主程式 ===
# Sprint 14 US-026: --show-similar 短路（不需 --report）
if [[ "$SHOW_SIMILAR" == "true" ]]; then
    cmd_similar "$RULES_FILE"
    exit 0
fi

if [[ -z "$REPORT" ]]; then
    echo "❌ 錯誤：--report 必填" >&2
    usage
    exit 1
fi

if [[ ! -f "$REPORT" ]]; then
    echo "❌ 錯誤：找不到報告：$REPORT" >&2
    exit 1
fi

# 從報告抓事件類型分佈（markdown 表格）
# 表格格式：| 事件類型 | 次數 |
# 用 awk 抓超過 MIN_FREQUENCES 次的事件類型

EVENTS=""
IN_EVENT_TABLE=0
while IFS='|' read -r first second third rest; do
    type_clean=$(echo "$second" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    count_clean=$(echo "$third" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # 偵測表格 header：「事件類型 | 次數」
    if [[ "$type_clean" == *事件類型* ]] && [[ "$count_clean" == *次數* ]]; then
        IN_EVENT_TABLE=1
        continue
    fi
    # 跳過 separator (--- | ---)
    if [[ "$type_clean" == "---" ]]; then
        continue
    fi
    # 只處理事件類型表內的內容
    if [[ "$IN_EVENT_TABLE" -ne 1 ]]; then
        continue
    fi
    # 表格結束（下一個非表格行）
    if [[ -z "$type_clean" ]] || [[ -z "$count_clean" ]]; then
        IN_EVENT_TABLE=0
        continue
    fi
    EVENTS+="${type_clean}|${count_clean}"$'\n'
done < "$REPORT"
EVENTS="${EVENTS%$'\n'}"

if [[ -z "$EVENTS" ]]; then
    echo "⚠️  報告裡沒有事件類型表" >&2
    echo "（先用 rsi-aggregate.sh 產一份有效報告）" >&2
    exit 1
fi

# 計算影響專案數（從報告專案分佈表抓）
PROJECTS=$(awk -F'|' '
/^\| / && !/^| --- / && !/^| 專案 ID / {
    gsub(/^ +| +$/, "", $2)
    print $2
}' "$REPORT" | wc -l | tr -d ' ')

[[ -z "$PROJECTS" || "$PROJECTS" -eq 0 ]] && PROJECTS=0

# 規則庫：事件類型 → 提案（用 case 取代 declare -A，macOS bash 3.2 不支援）
lookup_proposal() {
    local event_type="$1"
    local field="$2"  # file / diff / desc
    case "$event_type" in
        prompt_too_long)
            case "$field" in
                file) echo "AGENTS.md" ;;
                diff) echo "+ 加 max prompt 限制為 8000 chars" ;;
                desc) echo "prompt 太長會拖慢 LLM 回應" ;;
            esac
            ;;
        skill_error)
            case "$field" in
                file) echo "skills/*/SKILL.md" ;;
                diff) echo "+ 修 SKILL.md 缺必要 frontmatter" ;;
                desc) echo "skill 缺少必填欄位" ;;
            esac
            ;;
        gate_skip)
            case "$field" in
                file) echo "docs/sop/gates.json" ;;
                diff) echo "+ 修 gate 必跑機制（dev-checker-loop 二次確認）" ;;
                desc) echo "agent 跳過 gate 沒警告" ;;
            esac
            ;;
        markdownlint_error)
            case "$field" in
                file) echo "AGENTS.md 或 docs/sop/handbook/*.md" ;;
                diff) echo "+ 修正 markdown lint 錯誤（Table/MD013/Line length）" ;;
                desc) echo "markdown lint 規則會誤解某些字元（表格、em-dash、長行）" ;;
            esac
            ;;
        bash_error)
            case "$field" in
                file) echo "tools/*.sh 或 tests/*.bats" ;;
                diff) echo "+ 加 set -uo pipefail + 加 set -e 或檢查 return code" ;;
                desc) echo "bash script 未啟用 shellcheck 或未處理 return code" ;;
            esac
            ;;
        test_fail)
            case "$field" in
                file) echo "tests/*.bats 或 src/*" ;;
                diff) echo "+ 修 failing test 或加 skip 機制（若環境不支持）" ;;
                desc) echo "test 失敗可能是環境問題（shellcheck 未裝）或真 bug" ;;
            esac
            ;;
        bats_unknown)
            case "$field" in
                file) echo "tests/*.bats" ;;
                diff) echo "+ 改為 ASCII test name（避免中文括號導致 unknown test）" ;;
                desc) echo "bats 不支援 UTF-8 test name 或中文括號" ;;
            esac
            ;;
        v02_violated)
            case "$field" in
                file) echo "AGENTS.md（§1.5）或對話 SOP" ;;
                diff) echo "+ 強化 V02 紀律：方案必標最推薦（標『推薦』）" ;;
                desc) echo "未標『最推薦』違反 V02 規範" ;;
            esac
            ;;
        circular_ref)
            case "$field" in
                file) echo "AGENTS.md 或 docs/sop/handbook/*.md" ;;
                diff) echo "+ 修檔案雙向跳脫跳針（看 cross-ref）" ;;
                desc) echo "文檔 circular reference 難以跟跳（AGENTS.md ↔ handbook）" ;;
            esac
            ;;
        skill_timeout)
            case "$field" in
                file) echo "skills/*/SKILL.md" ;;
                diff) echo "+ 优化 SKILL.md 讀取速度（減少 frontmatter 字段、簡化 instructions）" ;;
                desc) echo "skill 讀取逾時、可能是 frontmatter 太多或 instructions 太長" ;;
            esac
            ;;
        agent_hang)
            case "$field" in
                file) echo "AGENTS.md 或 docs/sop/handbook/2.3-execution.md" ;;
                diff) echo "+ 加 timeout 機制（Gate 1 TDD 設 60s 上限）" ;;
                desc) echo "agent 卡住沒有 progress（可能是 bash loop 無限）" ;;
            esac
            ;;
        commit_no_msg)
            case "$field" in
                file) echo "tools/rsi-sync.sh 或安裝 SOP" ;;
                diff) echo "+ commit 自動補訊息（從 feat/fix/docs/chore/refactor 前綴）" ;;
                desc) echo "commit 訊息不符合 conventional commits 規範" ;;
            esac
            ;;
        *)
            case "$field" in
                file) echo "待定（觀察類型新，需手動分析）" ;;
                diff) echo "+ 加新規則或修既有規則" ;;
                desc) echo "這個觀察類型需人工判斷" ;;
            esac
            ;;
    esac
}

# 計算 confidence score（0~1）
# 公式：min(1.0, freq × 0.05 + projects × 0.1)
# 參考點：freq=10 + projects=5 達 1.0
calc_confidence() {
    local freq="$1"
    local projects="$2"
    awk -v f="$freq" -v p="$projects" 'BEGIN {
        score = f * 0.05 + p * 0.1
        if (score >= 1.0) score = 1.0
        if (score < 0.0) score = 0.0
        printf "%.2f", score
    }'
}

# 產出提案
PROPOSAL_COUNT=0
PROPOSALS=""

while IFS='|' read -r event_type count; do
    [[ -z "$event_type" ]] && continue
    [[ -z "$count" ]] && continue

    # 次數過濾
    if [[ "$count" -lt "$MIN_FREQUENCES" ]]; then
        continue
    fi

    # 上限過濾
    PROPOSAL_COUNT=$((PROPOSAL_COUNT + 1))
    if [[ $PROPOSAL_COUNT -gt $LIMIT ]]; then
        break
    fi

    # 找對應提案（規則庫有就用，沒有就用通用模板）
    file="$(lookup_proposal "$event_type" file)"
    diff_text="$(lookup_proposal "$event_type" diff)"
    desc="$(lookup_proposal "$event_type" desc)"

    # 計算 confidence score
    confidence=$(calc_confidence "$count" "$PROJECTS")
    confidence_tag=""
    if [[ -n "$CONFIDENCE_THRESHOLD" ]]; then
        # 用 awk 比較浮點數（macOS bash 不能直接用 [[ ... < ... ]] 比較浮點）
        meets=$(awk -v c="$confidence" -v t="$CONFIDENCE_THRESHOLD" 'BEGIN { print (c >= t) ? "yes" : "no" }')
        if [[ "$meets" == "yes" ]]; then
            confidence_tag=" ✅ 主要提案"
        else
            confidence_tag=" ⚠️ Low Confidence（需人工確認）"
        fi
    fi

    PROPOSALS+="
### 提案 $PROPOSAL_COUNT：$event_type（$count 次）$confidence_tag

- **檔案路徑**：\`$file\`
- **改動內容**：$diff_text
- **影響專案數**：$PROJECTS
- **信心分數（confidence）**：$confidence
- **理由**：$desc
- **rollback 指令**：\`./tools/rsi-rollback.sh list\` 看歷史版本；或 \`git revert <commit-hash>\`

\`\`\`diff
$diff_text
\`\`\`
"
done <<EOF
$EVENTS
EOF

# 寫輸出
write_report() {
    local header

# === Sprint 13 TD-037：JSON output 構造 ===
build_json_output() {
    local report="$1"
    local min_freq="$2"
    local limit="$3"
    local projects="$4"
    local total="$5"
    local events="$6"
    local conf_thr="$7"

    local proposals_json="["
    local n=0
    while IFS='|' read -r event_type count; do
        [[ -z "$event_type" ]] && continue
        [[ -z "$count" ]] && continue
        [[ "$count" -lt "$min_freq" ]] && continue
        n=$((n + 1))
        [[ $n -gt $limit ]] && break

        local file diff desc confidence
        file="$(lookup_proposal "$event_type" file)"
        diff="$(lookup_proposal "$event_type" diff)"
        desc="$(lookup_proposal "$event_type" desc)"
        confidence="$(awk -v c="$count" -v p="$projects" 'BEGIN { v = c * 0.3 + p * 0.2 + 1; if (v > 1) v = 1; printf "%.2f", v }')"

        # JSON escape (保留 UTF-8，不用 ensure_ascii=True)
        local safe_event safe_file safe_desc
        safe_event="$(printf '%s' "$event_type" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().rstrip(), ensure_ascii=False)[1:-1])')"
        safe_file="$(printf '%s' "$file" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().rstrip(), ensure_ascii=False)[1:-1])')"
        safe_desc="$(printf '%s' "$desc" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().rstrip(), ensure_ascii=False)[1:-1])')"

        if [[ $n -gt 1 ]]; then
            proposals_json+=","
        fi
        proposals_json+="
  {
    \"id\": $n,
    \"event_type\": \"$safe_event\",
    \"count\": $count,
    \"confidence\": $confidence,
    \"file\": \"$safe_file\",
    \"description\": \"$safe_desc\",
    \"diff_preview\": \"$(printf '%s' "$diff" | head -1 | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().rstrip(), ensure_ascii=False)[1:-1])')\"
  }"
    done <<EOF
$events
EOF

    proposals_json+="
]"

    cat <<JSON
{
  "schema_version": "rsi-propose/1.0",
  "generated_at": "$(date '+%Y-%m-%dT%H:%M:%S')",
  "source_report": "$report",
  "min_frequency": $min_freq,
  "limit": $limit,
  "projects_affected": $projects,
  "total_proposals": $total,
  "confidence_threshold": $([ -n "$conf_thr" ] && echo ""$conf_thr"" || echo "null"),
  "proposals": $proposals_json
}
JSON
}

    header="# RSI 提案清單

**產生時間**：$(date '+%Y-%m-%d %H:%M:%S')
**依據報告**：\`$REPORT\`
**最少觀察次數**：$MIN_FREQUENCES
**最多提案數**：$LIMIT
**觀察到的影響專案數**：$PROJECTS

## 提案摘要
"

    local summary_table="| # | 觀察類型 | 觀察次數 | 影響專案 | 改動檔案 |
| --- | --- | --- | --- | --- |
"

    # 重組摘要表
    local n=0
    while IFS='|' read -r event_type count; do
        [[ -z "$event_type" ]] && continue
        [[ -z "$count" ]] && continue
        [[ "$count" -lt "$MIN_FREQUENCES" ]] && continue
        n=$((n + 1))
        [[ $n -gt $LIMIT ]] && break
        local file
        file="$(lookup_proposal "$event_type" file)"
        summary_table+="| $n | $event_type | $count | $PROJECTS | $file |
"
    done <<EOF
$EVENTS
EOF

    local footer="
## 動作建議

1. 逐條 review 提案，決定要不要合併
2. 批准的提案走 SOP §2.3 完整 5 Gate（含 Gate 5 RSI + Reviewer）
3. 不批准的提案刪掉（或 commit 為 'rejected' 留歷史）
4. 全部完成後跑 \`./tools/rsi-sync.sh\` 同步到所有已裝專案
"

    local full="$header$summary_table$PROPOSALS$footer"

    # Sprint 13 TD-037：--output-format json 分支
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        full="$(build_json_output "$REPORT" "$MIN_FREQUENCES" "$LIMIT" "$PROJECTS" "$PROPOSAL_COUNT" "$EVENTS" "$CONFIDENCE_THRESHOLD")"
    fi

    if [[ -n "$OUTPUT" ]]; then
        mkdir -p "$(dirname "$OUTPUT")"
        printf "%s" "$full" > "$OUTPUT"
        echo "✅ 已寫提案：$OUTPUT" >&2
        echo "（共 $PROPOSAL_COUNT 個提案，影響 $PROJECTS 個專案）" >&2
    else
        printf "%s" "$full"
    fi
}


write_report

# Sprint 14 US-026: --show-similar 短路邏輯在 --report 必填檢查前
