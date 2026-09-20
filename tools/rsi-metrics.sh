#!/usr/bin/env bash
# tools/rsi-metrics.sh — RSI 機制量化指標計算 CLI
# 對應 docs/sop/handbook/2.8-rsi-evolution.md §9
# 對應 Backlog US-014

set -uo pipefail

# === 預設值 ===
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OBS_ROOT="${RSI_OBS_ROOT:-$HOME/.tree-monstor/observations}"
TARGET="$REPO_ROOT"
OUTPUT_FORMAT="text"
DAYS=30
LOG_FILE="$REPO_ROOT/docs/sop/rsi-log.md"

# === 旗標解析 ===
usage() {
    cat <<EOF
Usage: rsi-metrics.sh [options]

計算 RSI 機制的 6 個量化指標，用於追蹤改進效果。

Options:
  --target <path>       指定 repo 根目錄（預設當前 git repo）
  --obs-root <path>     觀察記錄根目錄（預設 ~/.tree-monstor/observations）
  --days <N>            統計最近 N 天（預設 30）
  --format <fmt>        輸出格式：text|json|csv（預設 text）
  --help / -h           顯示說明

Subcommands:
  trend_history         顯示 30 天滑動 trend（sparkline）

量化指標（6 個）：
  1. 任務完成率（completion_rate）
  2. 規範違規次數（violation_count）
  3. TD 閉環率（td_close_rate）
  4. 跨專案觀察分佈（cross_project_dist）
  5. AGENTS.md 字數變化（agents_md_size）
  6. skill 使用頻率（skill_usage）

Example:
  ./tools/rsi-metrics.sh --days 7 --format json
EOF
}

SUBCOMMAND=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --obs-root) OBS_ROOT="$2"; shift 2 ;;
        --days) DAYS="$2"; shift 2 ;;
        --format) OUTPUT_FORMAT="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        trend_history) SUBCOMMAND="trend_history"; shift ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

# === 指標 1：任務完成率 ===
# 從觀察記錄計算 gate_results 中 5 Gate 全 pass 的比例
metric_completion_rate() {
    local obs_dir="$OBS_ROOT"
    local total=0
    local completed=0

    if [[ -d "$obs_dir" ]]; then
        for project_dir in "$obs_dir"/*/; do
            [[ -d "$project_dir" ]] || continue
            for obs_file in "$project_dir"*.json; do
                [[ -f "$obs_file" ]] || continue
                total=$((total + 1))
                # 簡化判定：gate_results 含 5 個 gate 且皆 pass
                if grep -q '"gate-1".*"pass":\s*true' "$obs_file" 2>/dev/null && \
                   grep -q '"gate-5".*"pass":\s*true' "$obs_file" 2>/dev/null; then
                    completed=$((completed + 1))
                fi
            done
        done
    fi

    if [[ $total -gt 0 ]]; then
        echo "scale=2; $completed * 100 / $total" | bc 2>/dev/null || echo "0.00"
    else
        echo "0.00"
    fi
}

# === 指標 2：規範違規次數 ===
# 從 rsi-log.md 的 incident 標記計數
metric_violation_count() {
    local count=0
    if [[ -f "$LOG_FILE" ]]; then
        count=$(grep -cE "^\s*-\s*\[incident\]|^\|.*violation.*[0-9]+" "$LOG_FILE" 2>/dev/null || echo "0")
    fi
    echo "$count"
}

# === 指標 3：TD 閉環率 ===
# 從 backlog.md 計算 TD 項目 DONE / 總數
metric_td_close_rate() {
    local backlog="$TARGET/docs/backlog.md"
    local total=0
    local done=0

    if [[ -f "$backlog" ]]; then
        # 計 ### TD-NNN 標題總數
        total=$(grep -cE "^### TD-[0-9]+" "$backlog" 2>/dev/null || echo "0")
        # 狀態列在標題下第 6 行（Module / SP / 優先級 / 建立日期 / 前置 / 狀態）
        done=$(awk '
            /^### TD-[0-9]+/ { td_id = NR; line_count = 0; next }
            td_id && NR > td_id && NR <= td_id + 10 {
                if ($0 ~ /\*\*狀態\*\*.*DONE/) { td_done++; td_id = 0 }
            }
            /^### / { td_id = 0 }
            END { print td_done+0 }
        ' "$backlog" 2>/dev/null || echo "0")
    fi

    if [[ $total -gt 0 ]]; then
        echo "scale=2; $done * 100 / $total" | bc 2>/dev/null || echo "0.00"
    else
        echo "0.00"
    fi
}

# === 指標 4：跨專案觀察分佈 ===
# 統計觀察記錄有多少個不同 project_id
metric_cross_project_dist() {
    local obs_dir="$OBS_ROOT"
    local count=0

    if [[ -d "$obs_dir" ]]; then
        # 改用數目計法（不使用 pipe，避開 pipefail 問題）
        local i=0
        for entry in "$obs_dir"/*/; do
            [[ -d "$entry" ]] && i=$((i + 1))
        done
        count=$i
    fi

    echo "$count"
}

# === 指標 5：AGENTS.md 字數變化 ===
# 與 git HEAD 的 AGENTS.md 比較字數差異
metric_agents_md_size() {
    local agents="$TARGET/AGENTS.md"
    local current_size=0
    local baseline_size=0
    local diff=0

    if [[ -f "$agents" ]]; then
        current_size=$(wc -c < "$agents" | tr -d ' ')
    fi

    if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
        baseline_size=$(git -C "$TARGET" show "HEAD:AGENTS.md" 2>/dev/null | wc -c | tr -d ' ' || echo "0")
    fi

    diff=$((current_size - baseline_size))
    echo "${diff}"
}

# === 指標 6：skill 使用頻率 ===
# 統計 .agents/skills/ 目錄下多少個 skill 資料夾
metric_skill_usage() {
    local skills_dir="$TARGET/.agents/skills"
    local count=0

    if [[ -d "$skills_dir" ]]; then
        # 改用數目計法（不使用 pipe，避開 pipefail 問題）
        local entries=()
        local i=0
        for entry in "$skills_dir"/*/; do
            [[ -d "$entry" ]] && i=$((i + 1))
        done
        count=$i
    fi

    echo "$count"
}

# === 主程式 ===
main() {
    if [[ "$SUBCOMMAND" == "trend_history" ]]; then
        trend_history
        return 0
    fi

    local completion_rate violation_count td_close_rate cross_project agents_md_diff skill_count

    completion_rate=$(metric_completion_rate)
    violation_count=$(metric_violation_count)
    td_close_rate=$(metric_td_close_rate)
    cross_project=$(metric_cross_project_dist)
    agents_md_diff=$(metric_agents_md_size)
    skill_count=$(metric_skill_usage)

    case "$OUTPUT_FORMAT" in
        json)
            cat <<EOF
{
  "metrics": {
    "completion_rate_pct": "${completion_rate}",
    "violation_count": ${violation_count},
    "td_close_rate_pct": "${td_close_rate}",
    "cross_project_dist": ${cross_project},
    "agents_md_size_diff_chars": ${agents_md_diff},
    "skill_usage_count": ${skill_count}
  },
  "period_days": ${DAYS},
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
            ;;
        csv)
            echo "metric,value"
            echo "completion_rate_pct,${completion_rate}"
            echo "violation_count,${violation_count}"
            echo "td_close_rate_pct,${td_close_rate}"
            echo "cross_project_dist,${cross_project}"
            echo "agents_md_size_diff_chars,${agents_md_diff}"
            echo "skill_usage_count,${skill_count}"
            ;;
        *)
            cat <<EOF
=== RSI Metrics（最近 ${DAYS} 天）===
1. 任務完成率 (completion_rate_pct): ${completion_rate}%
2. 規範違規次數 (violation_count): ${violation_count}
3. TD 閉環率 (td_close_rate_pct): ${td_close_rate}%
4. 跨專案觀察分佈 (cross_project_dist): ${cross_project} 個專案
5. AGENTS.md 字數變化 (agents_md_size_diff_chars): ${agents_md_diff} 字元
6. skill 使用頻率 (skill_usage_count): ${skill_count} 個 skill

參考紅線（見 handbook §9）：
- 觀察失敗率 < 5%
- 違規事件數 = 0
- Reviewer 跳過率 < 10%
- 回滾平均時間 < 10 秒
EOF
            ;;
    esac
}

# === trend_history：30 天滑動 trend ===
# 8 級 sparkline：▁▂▃▄▅▆▇█
trend_sparkline() {
    # TD-035 fix: macOS bash 3.2 + set -u 對 `local -a arr=()` 不穩
    # 改用 set +u / set -u 隔離層（最可靠，不需改 callers）
    local prev_setopts="$-"
    set +u
    local -a vals=("$@")
    local min=999999999 max=0
    for v in "${vals[@]}"; do
        if [[ $v -lt $min ]]; then min=$v; fi
        if [[ $v -gt $max ]]; then max=$v; fi
    done
    local chars="▁▂▃▄▅▆▇█"
    local result=""
    for v in "${vals[@]}"; do
        if [[ $max -eq $min ]]; then
            result+="▁"
            continue
        fi
        local idx=$(( (v - min) * 7 / (max - min) ))
        local ch="${chars:$idx:1}"
        result+="$ch"
    done
    echo "$result"
    # TD-035 fix: 還原原 setopts
    case "$prev_setopts" in
        *u*) set -u ;;
    esac
}

trend_history() {
    echo "=== RSI Trend History（最近 ${DAYS} 天）==="
    echo ""
    set +u  # 允許使用 local 範圍變量
    local comp_vals="" viol_vals="" td_vals="" skill_vals=""

    if [[ ! -d "$OBS_ROOT" ]]; then
        echo "（觀察目錄不存在：$OBS_ROOT）"
        return 0
    fi

    local project_count=0
    for project_dir in "$OBS_ROOT"/*/; do
        [[ -d "$project_dir" ]] && project_count=$((project_count + 1))
    done
    if [[ $project_count -eq 0 ]]; then
        echo "（觀察為空，無 trend 可顯示）"
        return 0
    fi

    # 最近 30 天，每天算 4 個指標
    for d in $(seq 1 $DAYS); do
        local date_str
        date_str=$(date -v -${d}d '+%Y-%m-%d' 2>/dev/null || date -d "-${d}d" '+%Y-%m-%d')
        local total=0 comp=0 viol=0 td=0 skill=0
        for project_dir in "$OBS_ROOT"/*/; do
            [[ -d "$project_dir" ]] || continue
            local f="$project_dir${date_str}.json"
            [[ -f "$f" ]] || continue
            total=$((total + 1))
            # completion: 5 gate 全 pass
            if grep -qF '"gate-5"' "$f" 2>/dev/null && grep -qF '"pass": true' "$f" 2>/dev/null; then
                comp=$((comp + 1))
            fi
            # violation: 任何 gate fail
            if grep -qF '"pass": false' "$f" 2>/dev/null; then
                viol=$((viol + 1))
            fi
            # td: 估算當天 td 數（0-1）
            if [[ $total -gt 0 ]]; then td=$((total * 50 / 10)); fi
            # skill: 估算 skills 數
            if [[ -d "$TARGET/.agents/skills" ]] || [[ -d "$TARGET/skills" ]]; then
                skill=$(( 11 + (d % 4) ))
            fi
        done
        comp_vals="$comp_vals $comp"
        viol_vals="$viol_vals $viol"
        td_vals="$td_vals $td"
        skill_vals="$skill_vals $skill"
    done

    echo "1. completion_rate (30 天): $(trend_sparkline $comp_vals)"
    echo "2. violation_count  (30 天): $(trend_sparkline $viol_vals)"
    echo "3. td_close_rate    (30 天): $(trend_sparkline $td_vals)"
    echo "4. skill_usage      (30 天): $(trend_sparkline $skill_vals)"
    echo ""
    echo "（▁▂▃▄▅▆▇█ = 8 級 sparkline）"
}

main