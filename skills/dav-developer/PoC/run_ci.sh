#!/usr/bin/env bash
# run_ci.sh — dav-developer「Jev CI」本機 runner
#
# 做咩：把原本放喺 GitHub Actions 嘅 4 個 job 搬返本機。
#   背景（2026-10-27 用戶決策）：「dav-developer 的 ci 在本地跑都得，不用在 github 上跑」
#   → `.github/workflows/dav-developer-jev-poc.yml` 已刪除（探針 CI-f 鎖住「唔准加返」）。
#   原本 4 個 job → 而家 4 個 subcommand：
#     probes       ← bats job        （跑本 repo 嘅 tests/v2.1-jev-poc.bats；唔使 API key）
#     pipeline     ← pipeline job    （跑 run_pipeline.sh <story>；要 OPENROUTER_API_KEY）
#     matrix       ← aggregate-matrix（跑多個 story + 匯總 matrix-summary.md）
#     cleanup-scan ← cleanup-scan job（跑 docs/cleanup/cleanup-scan.py；原本係每週 cron）
#
# 用法：
#   bash run_ci.sh list
#   bash run_ci.sh probes
#   bash run_ci.sh pipeline US-101 [--stale]
#   bash run_ci.sh matrix [US-101 US-M62 US-M63]
#   bash run_ci.sh cleanup-scan
#   bash run_ci.sh all
#
# 退出碼（verdict 碼同原本 GH workflow 一致；用法／環境錯誤另用 3，避免撞 verdict 碼）：
#   0 = 綠（全部 story 綠）
#   2 = 黃（有 story 黃 → 警告，唔擋）
#   1 = 紅（有 story 紅／步驟失敗 → 擋）
#   3 = 用法／環境錯誤（缺 key、缺 venv、缺檔案⋯⋯）
#
# 環境變數：
#   OPENROUTER_API_KEY   真 API key（pipeline／matrix 必需；冇 → rc 3，唔會靜靜哋跑假嘢）
#   RG_REPORT_DIR        報告輸出目錄（預設 <repo>/tmp/rg-reports；已 gitignore）
#   RG_CI_MOCK_VERDICT   **只供探針用**嘅 seam：green|yellow|red → 唔真跑 pipeline，
#                        直接用呢個 verdict 走 rc mapping（會大聲印「MOCK MODE」）
#
# ⚠️ 為咩 verdict 由 JSON 讀而唔靠 run_pipeline.sh 嘅離開碼：
#   `run_pipeline.sh` 會接住 M4 嘅 return code（0/1/2）但**最後以 echo 收尾 → 離開碼永遠係 0**。
#   → 原本 GH workflow 其實捉唔到紅燈；呢度改為讀 batch report JSON 嘅 `overall_health`
#     （同原本 aggregate job 一致）→ 紅燈真係會令 rc=1。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
REPORT_DIR="${RG_REPORT_DIR:-${REPO_ROOT}/tmp/rg-reports}"
PROBES_FILE="${REPO_ROOT}/skills/dav-developer/tests/v2.1-jev-poc.bats"
CLEANUP_SCAN="${REPO_ROOT}/docs/cleanup/cleanup-scan.py"
DEFAULT_STORIES=(US-101 US-M62 US-M63)

RC_USAGE=3

# cmd_pipeline 會寫低呢個全域變數畀 matrix 用
LAST_VERDICT="unknown"

usage() {
  cat <<'EOF'
用法：bash run_ci.sh <subcommand> [args...]

  list          列 subcommand（機械可比對）
  probes        跑本 skill 嘅 bats 探針（skills/dav-developer/tests/v2.1-jev-poc.bats；唔使 API key）
  pipeline      跑 run_pipeline.sh <story_id> [--stale]
  matrix        跑多個 story（預設 US-101 US-M62 US-M63）+ 匯總 matrix-summary.md
  cleanup-scan  跑 docs/cleanup/cleanup-scan.py（文件減法盤點）
  all           probes → matrix → cleanup-scan

退出碼：0 綠｜2 黃（警告）｜1 紅（擋）｜3 用法／環境錯誤
EOF
}

# ── verdict → 嚴重度（green=0、yellow=1、red=2、unknown=2 → fail-closed）────────
verdict_to_severity() {
  case "$1" in
    green)  printf '0\n' ;;
    yellow) printf '1\n' ;;
    red)    printf '2\n' ;;
    *)      printf '2\n' ;;
  esac
}

# ── 嚴重度 → 退出碼（黃=2、紅=1，同原本 GH workflow 嘅 gate 語義一致）──────────
severity_to_rc() {
  case "$1" in
    0) printf '0\n' ;;
    1) printf '2\n' ;;
    *) printf '1\n' ;;
  esac
}

# ── 由 batch report JSON 讀 verdict（讀唔到＝unknown＝當紅）───────────────────
verdict_from_json() {
  local json_file="${1:-}"
  local verdict="unknown"
  if [ -n "${json_file}" ] && [ -f "${json_file}" ] && command -v python3 >/dev/null 2>&1; then
    verdict="$(python3 -c 'import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        d = json.load(fh)
    print(d.get("batch_report", {}).get("overall_health", "unknown"))
except Exception:
    print("unknown")' "${json_file}")"
  fi
  [ -n "${verdict}" ] || verdict="unknown"
  printf '%s\n' "${verdict}"
}

# ── 由 batch report JSON 讀矩陣表其餘三欄（讀唔到＝?）────────────────────────
report_row_fields() {
  local json_file="${1:-}"
  local out="unknown|?|?|?"
  if [ -n "${json_file}" ] && [ -f "${json_file}" ] && command -v python3 >/dev/null 2>&1; then
    out="$(python3 -c 'import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        b = json.load(fh).get("batch_report", {})
    flaky = b.get("flaky_measured", {}) or {}
    print("|".join([
        str(b.get("overall_health", "unknown")),
        "%.2f" % float(b.get("fix_priority", 0)),
        "%.2f" % float(flaky.get("likelihood", 0)),
        str(b.get("regression_type", "?")),
    ]))
except Exception:
    print("unknown|?|?|?")' "${json_file}")"
  fi
  printf '%s\n' "${out}"
}

cmd_list() {
  printf 'list\nprobes\npipeline\nmatrix\ncleanup-scan\nall\n'
}

cmd_probes() {
  if [ ! -f "${PROBES_FILE}" ]; then
    echo "FAIL: 搵唔到 ${PROBES_FILE}（目標專案冇 repo 探針 → 只可以用 pipeline／matrix）" >&2
    return "${RC_USAGE}"
  fi
  if ! command -v bats >/dev/null 2>&1; then
    echo "FAIL: 本機冇 bats（安裝：brew install bats-core）" >&2
    return "${RC_USAGE}"
  fi
  echo "▶ probes：bats ${PROBES_FILE}"
  bats "${PROBES_FILE}"
}

cmd_pipeline() {
  local story=""
  local stale=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --stale) stale=1 ;;
      *) story="$1" ;;
    esac
    shift
  done
  if [ -z "${story}" ]; then
    echo "FAIL: pipeline 要 story_id（例如 US-101）" >&2
    usage
    return "${RC_USAGE}"
  fi

  local report_base="${REPORT_DIR}/${story}"
  local verdict="unknown"

  if [ -n "${RG_CI_MOCK_VERDICT:-}" ]; then
    verdict="${RG_CI_MOCK_VERDICT}"
    echo "⚠️ MOCK MODE（RG_CI_MOCK_VERDICT=${verdict}）：唔會真跑 pipeline —— 只供探針用"
  else
    if ! command -v python3 >/dev/null 2>&1; then
      echo "FAIL: 本機冇 python3" >&2
      return "${RC_USAGE}"
    fi
    if [ -z "${OPENROUTER_API_KEY:-}" ]; then
      echo "FAIL: 冇 OPENROUTER_API_KEY（pipeline 要真 API key；唔會靜靜哋跑假嘢）" >&2
      return "${RC_USAGE}"
    fi
    if [ ! -x "${SCRIPT_DIR}/.venv/bin/python" ]; then
      echo "FAIL: 缺 PoC venv → 跑 bash ${SCRIPT_DIR}/setup-venv.sh" >&2
      return "${RC_USAGE}"
    fi
    mkdir -p "${REPORT_DIR}"
    echo "▶ pipeline：run_pipeline.sh ${story}"
    local pipe_rc=0
    if [ "${stale}" -eq 1 ]; then
      REGRESSION_REPORT_PATH="${report_base}" bash "${SCRIPT_DIR}/run_pipeline.sh" "${story}" --stale || pipe_rc=$?
    else
      REGRESSION_REPORT_PATH="${report_base}" bash "${SCRIPT_DIR}/run_pipeline.sh" "${story}" || pipe_rc=$?
    fi
    echo "   (run_pipeline.sh rc=${pipe_rc}；注意：佢個離開碼永遠係 0 → verdict 改讀 JSON)"
    verdict="$(verdict_from_json "${report_base}.json")"
  fi

  local severity rc_out
  severity="$(verdict_to_severity "${verdict}")"
  rc_out="$(severity_to_rc "${severity}")"
  LAST_VERDICT="${verdict}"
  echo "   verdict=${verdict} → rc=${rc_out}"
  return "${rc_out}"
}

cmd_matrix() {
  local stories=()
  if [ $# -gt 0 ]; then
    stories=("$@")
  else
    stories=("${DEFAULT_STORIES[@]}")
  fi

  mkdir -p "${REPORT_DIR}"
  local summary="${REPORT_DIR}/matrix-summary.md"
  {
    echo "# dav-developer Matrix Summary"
    echo ""
    echo "**Generated**: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "## Per-Story Results"
    echo ""
    echo "| Story | Health | Fix Priority | Flaky | Type |"
    echo "|-------|--------|--------------|-------|------|"
  } > "${summary}"

  local worst=0
  local story rc severity health fp flaky rtype
  for story in "${stories[@]}"; do
    rc=0
    cmd_pipeline "${story}" || rc=$?
    case "${rc}" in
      0) severity=0 ;;
      2) severity=1 ;;
      *) severity=2 ;;
    esac
    if [ "${severity}" -gt "${worst}" ]; then
      worst="${severity}"
    fi
    health="${LAST_VERDICT}"
    fp="?"
    flaky="?"
    rtype="?"
    if [ -f "${REPORT_DIR}/${story}.json" ]; then
      IFS='|' read -r health fp flaky rtype <<< "$(report_row_fields "${REPORT_DIR}/${story}.json")"
    fi
    printf "| \`%s\` | %s | %s | %s | %s |\n" "${story}" "${health}" "${fp}" "${flaky}" "${rtype}" >> "${summary}"
  done

  {
    echo ""
    echo "---"
    echo "_本機跑（run_ci.sh matrix）；矩陣故事：${stories[*]}_"
  } >> "${summary}"

  echo "▶ 矩陣匯總：${summary}"
  local out_rc
  out_rc="$(severity_to_rc "${worst}")"
  echo "   最差 verdict severity=${worst} → rc=${out_rc}"
  return "${out_rc}"
}

cmd_cleanup_scan() {
  if [ ! -f "${CLEANUP_SCAN}" ]; then
    echo "FAIL: 搵唔到 ${CLEANUP_SCAN}（目標專案冇 docs/cleanup/ → 略過此步；rc 3 = 環境錯誤）" >&2
    return "${RC_USAGE}"
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "FAIL: 本機冇 python3" >&2
    return "${RC_USAGE}"
  fi
  echo "▶ cleanup-scan：${CLEANUP_SCAN} --json"
  local scan_json
  scan_json="$(python3 "${CLEANUP_SCAN}" --json)"
  # ⚠️ cleanup-scan.py --json 嘅輸出係**陣列**（每個檔一筆，欄位 `category`），
  #    唔係 {"summary": {...}} → 照實際結構統計（原本 GH workflow 當成 dict 讀 → 永遠讀唔到數）。
  printf '%s\n' "${scan_json}" | python3 -c 'import json, sys
items = json.load(sys.stdin)
counts = {}
for it in items:
    cat = it.get("category", "?")
    counts[cat] = counts.get(cat, 0) + 1
for k in sorted(counts):
    print(f"   {k}: {counts[k]}")
delete_count = counts.get("DELETE", 0)
if delete_count > 0:
    print(f"   ⚠️ 有 {delete_count} 個建議刪除文件 —— 請人手 review（cleanup-scan 唔會自動刪）")
'
}

cmd_all() {
  local rc=0
  echo "═══ [1/3] probes ═══"
  rc=0
  cmd_probes || rc=$?
  if [ "${rc}" -ne 0 ]; then
    echo "FAIL: probes 紅 → 唔跑 pipeline（探針唔綠，pipeline 結果無意義）" >&2
    return "${rc}"
  fi

  local matrix_rc=0
  echo "═══ [2/3] matrix ═══"
  cmd_matrix "$@" || matrix_rc=$?

  local scan_rc=0
  echo "═══ [3/3] cleanup-scan ═══"
  cmd_cleanup_scan || scan_rc=$?

  # ⚠️ rc 語義：子步驟回 **3（用法／環境錯誤，例如缺 API key）** → 整體回 3（唔當紅燈）
  #    只有真 verdict（1 紅／2 黃）先參與 worst 聚合。
  local worst=0 env_error=0
  case "${matrix_rc}" in
    0) worst=0 ;;
    2) worst=1 ;;
    3) env_error=1 ;;
    *) worst=2 ;;
  esac
  if [ "${scan_rc}" -eq 3 ]; then
    env_error=1
  elif [ "${scan_rc}" -ne 0 ] && [ "${worst}" -lt 2 ]; then
    worst=2
  fi
  local out_rc
  if [ "${env_error}" -eq 1 ]; then
    out_rc=3
  else
    out_rc="$(severity_to_rc "${worst}")"
  fi
  echo "   （matrix rc=${matrix_rc}／cleanup-scan rc=${scan_rc}）→ 整體 rc=${out_rc}"
  return "${out_rc}"
}

main() {
  local sub="${1:-}"
  if [ $# -gt 0 ]; then
    shift
  fi
  case "${sub}" in
    list)         cmd_list ;;
    probes)       cmd_probes "$@" ;;
    pipeline)     cmd_pipeline "$@" ;;
    matrix)       cmd_matrix "$@" ;;
    cleanup-scan) cmd_cleanup_scan "$@" ;;
    all)          cmd_all "$@" ;;
    -h|--help|help) usage ;;
    "")           usage; return "${RC_USAGE}" ;;
    *)            echo "未知 subcommand：${sub}" >&2; usage; return "${RC_USAGE}" ;;
  esac
}

main "$@"
