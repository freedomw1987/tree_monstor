#!/usr/bin/env bash
# tools/rsi-alert.sh — RSI 回歸警告工具（Sprint 12 US-022）
# 對應 docs/sop/handbook/2.8-rsi-evolution.md §9
# 對應 Backlog US-022

set -uo pipefail

# === 預設值 ===
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OBS_ROOT="${RSI_OBS_ROOT:-$HOME/.tree-monstor/observations}"
BASELINE_DAYS=7
WINDOW_DAYS=1
THRESHOLD=0.7
ALERT_LOG="${RSI_ALERT_LOG:-$HOME/.tree-monstor/alerts.log}"

# === 旗標解析 ===
usage() {
    cat <<EOF
Usage: rsi-alert.sh [options]

RSI 回歸警告工具。觀察數下降 30%+ 觸發告警。

Options:
  --obs-root <path>     觀察記錄根目錄（預設 ~/.tree-monstor/observations）
  --baseline-days <N>   基線天數（預設 7，看前 7 天平均）
  --window-days <N>     當前視窗天數（預設 1，看今天）
  --threshold <0~1>     告警閾值（預設 0.7，當前/基線 < 0.7 觸發）
  --alert-log <path>    告警 log 路徑（預設 ~/.tree-monstor/alerts.log）
  --help / -h           顯示說明

Example:
  ./tools/rsi-alert.sh
  ./tools/rsi-alert.sh --baseline-days 14 --threshold 0.6
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --obs-root) OBS_ROOT="$2"; shift 2 ;;
        --baseline-days) BASELINE_DAYS="$2"; shift 2 ;;
        --window-days) WINDOW_DAYS="$2"; shift 2 ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --alert-log) ALERT_LOG="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "未知旗標: $1" >&2; usage; exit 2 ;;
    esac
done

# === 計算基線平均觀察數 ===
calc_baseline() {
    local days="$1"
    if [[ ! -d "$OBS_ROOT" ]]; then
        echo "0"
        return
    fi

    local total=0
    local day_count=0
    for d in $(seq 1 "$days"); do
        local date_str
        date_str=$(date -v -${d}d '+%Y-%m-%d' 2>/dev/null || date -d "-${d}d" '+%Y-%m-%d' 2>/dev/null)
        local day_obs=0
        # 數當天所有 observation 檔
        for proj_dir in "$OBS_ROOT"/*/; do
            [[ -d "$proj_dir" ]] || continue
            if [[ -f "${proj_dir}${date_str}.json" ]]; then
                day_obs=$((day_obs + 1))
            fi
        done
        total=$((total + day_obs))
        day_count=$((day_count + 1))
    done

    if [[ $day_count -eq 0 ]]; then
        echo "0"
    else
        # 用 awk 算平均（macOS bash 沒支援浮點）
        echo "$total $day_count" | awk '{printf "%.2f\n", $1/$2}'
    fi
}

# === 計算當前視窗觀察數 ===
calc_current() {
    local days="$1"
    if [[ ! -d "$OBS_ROOT" ]]; then
        echo "0"
        return
    fi

    local total=0
    for d in $(seq 0 $((days - 1))); do
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

# === 主邏輯 ===
BASELINE=$(calc_baseline "$BASELINE_DAYS")
CURRENT=$(calc_current "$WINDOW_DAYS")
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S%z')

echo "RSI 回歸警告檢查（$(date '+%Y-%m-%d')）"
echo "  基線（前 ${BASELINE_DAYS} 天平均）：${BASELINE} obs/day"
echo "  當前（最近 ${WINDOW_DAYS} 天）：${CURRENT} obs"
echo "  閾值：${THRESHOLD}"

# 計算比值（用 awk 浮點）
RATIO=$(echo "$CURRENT $BASELINE" | awk '{ if ($2 > 0) printf "%.3f\n", $1/$2; else print "0" }')
echo "  比值：${RATIO}"

# 判斷是否觸發
ALERT="false"
if echo "$RATIO $THRESHOLD" | awk '{exit !($1 < $2)}'; then
    ALERT="true"
fi

if [[ "$ALERT" == "true" ]]; then
    MSG="[${TIMESTAMP}] 🚨 RSI 回歸警告：觀察數從基線 ${BASELINE} 降到 ${CURRENT}（比值 ${RATIO}，閾值 ${THRESHOLD}）"
    echo "$MSG" >&2
    echo "$MSG" >> "$ALERT_LOG"
    exit 1
else
    echo "✅ 觀察數正常（比值 ${RATIO} ≥ 閾值 ${THRESHOLD}）"
    exit 0
fi