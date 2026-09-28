#!/bin/bash
# run_pipeline.sh — M1 → M2 → M3 → M4 一鍵跑完
#
# 用法:
#   ./run_pipeline.sh <story_id>           # 例如 ./run_pipeline.sh US-101
#   ./run_pipeline.sh <story_id> --stale   # 用 stale-test 模式證邏輯
#
# 環境變數：
#   REGRESSION_REPORT_PATH   報告輸出位置（預設 ./report）

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "用法: $0 <story_id> [--stale] [--source path/to/US.md]"
    echo ""
    echo "範例:"
    echo "  $0 US-101"
    echo "  REGRESSION_REPORT_PATH=./out/US-101-report $0 US-101"
    exit 1
fi

STORY_ID="$1"
shift

USE_STALE=""
SOURCE_ARG=""
while [ $# -gt 0 ]; do
    case "$1" in
        --stale) USE_STALE="--stale-test" ;;
        --source) SOURCE_ARG="--source $2"; shift ;;
    esac
    shift
done

# 找 AC 檔（支援兩種位置）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [ -n "$SOURCE_ARG" ]; then
    AC_PATH="${SOURCE_ARG#--source }"
elif [ -f "$REPO_ROOT/docs/ac/${STORY_ID}.md" ]; then
    AC_PATH="$REPO_ROOT/docs/ac/${STORY_ID}.md"
else
    echo "❌ 找不到 AC 檔：$REPO_ROOT/docs/ac/${STORY_ID}.md"
    echo "   用 --source 指定"
    exit 1
fi

# 報告位置
REPORT_PATH="${REGRESSION_REPORT_PATH:-$SCRIPT_DIR/report}"

echo "═══════════════════════════════════════════════"
echo "  regression-guard PoC pipeline — ${STORY_ID}"
echo "═══════════════════════════════════════════════"
echo "  AC:        $AC_PATH"
echo "  Report:    $REPORT_PATH (.json + .md)"
echo "═══════════════════════════════════════════════"
echo

cd "$SCRIPT_DIR"

# ── Step 1: M2 — generate journey YAML ──
echo "▶ M2  生成 journey YAML…"
if [ ! -f "journeys/${STORY_ID}.yaml" ] || [ "${REGEN_JOURNEY:-0}" = "1" ]; then
    .venv/bin/python journey_gen.py "$AC_PATH"
else
    echo "   (跳過：journeys/${STORY_ID}.yaml 已存在；REGEN_JOURNEY=1 可強制重跑)"
fi
echo

# ── Step 2: M3 — run journey (dry-run loop) ──
echo "▶ M3  跑 dry-run loop…"
RUN_JSON="/tmp/${STORY_ID}-run.json"
STALE_FLAG=""
if [ -n "$USE_STALE" ]; then
    STALE_FLAG="--stale-test"
fi
M3_RC=0
.venv/bin/python run_journey.py "journeys/${STORY_ID}.yaml" $STALE_FLAG --json-output "$RUN_JSON" || M3_RC=$?
echo "   (M3 return code: $M3_RC — 0=normal / 2=stale blocked)"
echo

# ── Step 3: M4 — batch report ──
echo "▶ M4  end-of-run batch report…"
# M4 return code 是 verdict (0=green / 2=yellow / 1=red)，原本設計；
# pipeline 不讓 set -e 拿走 (M4 後面還有 M6)，用 `|| true` 接住
M4_RC=0
.venv/bin/python run_report.py "$RUN_JSON" "${REPORT_PATH%.*}" || M4_RC=$?
echo "   (M4 return code: $M4_RC — 0=green / 2=yellow / 1=red)"
echo

# M7-flaky 整合：M4 後額外跑 2 次算 flaky_likelihood
if [ "${JEV_FLAKY_INTEGRATION:-0}" = "1" ]; then
    echo "▶ M7-flaky  額外跑 2 次算 flaky_likelihood…"
    .venv/bin/python flaky_integration.py \
        --batch-report "${REPORT_PATH%.*}.json" \
        --journey "journeys/${STORY_ID}.yaml" \
        --story-id "${STORY_ID}" \
        --source "${AC_FILE:-$REPO_ROOT/docs/ac/${STORY_ID}.md}" \
        --runs 2 || echo "   (M7-flaky failed but pipeline continues)"
    echo
fi

# ── Step 4: M6 — Jev fix proposal (opt-in) ──
if [ "${JEV_FIX_PROPOSAL:-0}" = "1" ]; then
    echo "▶ M6  Jev fix proposal (v1)…"
    FIX_OUT="${REPORT_PATH%.*}-fix-proposal.md"
    .venv/bin/python fix_proposal.py "$RUN_JSON" "$FIX_OUT" || \
        echo "   (M6 v1 failed but pipeline continues)"
    echo
    if [ "${JEV_FIX_PROPOSAL_V2:-0}" = "1" ]; then
        echo "▶ M6.1  Jev fix proposal v2 (LLM relay)…"
        FIX_OUT_V2="${REPORT_PATH%.*}-fix-proposal-v2.md"
        .venv/bin/python fix_proposal_v2.py "$RUN_JSON" "$FIX_OUT_V2" || \
            echo "   (M6.1 failed but pipeline continues)"
        echo
        if [ "${JEV_PATCH_AND_REVALIDATE:-0}" = "1" ]; then
            echo "▶ M6.2  patch + re-validate 閉環…"
            PATCH_OUT="${REPORT_PATH%.*}-patches.json"
            .venv/bin/python patch_parser.py "$FIX_OUT_V2" --json > "$PATCH_OUT" 2>&1 || \
                echo "   (M6.2 patch_parser failed but pipeline continues)"
            # Re-validate 也需要 playwright_patcher + re_validate 模組（可在 sandbox 外手動跑）
            if [ -s "$PATCH_OUT" ]; then
                echo "   patches: $(.venv/bin/python -c "import json; d=json.load(open('$PATCH_OUT')); print(len(d.get('patches', [])))" 2>/dev/null) extracted"
                echo "   → apply: .venv/bin/python playwright_patcher.py <FILE> --old ... --new ... --apply"
                echo "   → re-validate: .venv/bin/python re_validate.py <before.json> <after.json>"
                # M7 gh pr comment（opt-in，CI 環境需 GITHUB_TOKEN）
                if [ "${JEV_GH_PR_COMMENT:-0}" = "1" ]; then
                    echo "▶ M7-gh-pr-comment  推 PR comment…"
                    PR_COMMENT_OUT="${REPORT_PATH%.*}-pr-comment.md"
                    .venv/bin/python gh_pr_comment.py \
                        --batch-report "${REPORT_PATH%.*}.json" \
                        --fix-proposal "${REPORT_PATH%.*}-fix-proposal-v2.md" \
                        --pr-number "${GITHUB_PR_NUMBER:-}" \
                        --output "$PR_COMMENT_OUT" 2>&1 | tail -5 || \
                        echo "   (M7-gh-pr-comment failed but pipeline continues)"
                    echo
                fi
                # M6.3 sandbox 自動版（opt-in）
                if [ "${JEV_SANDBOX_RUN:-0}" = "1" ]; then
                    echo "▶ M6.3  sandbox 自動 apply + re-validate + rollback…"
                    SANDBOX_OUT="${REPORT_PATH%.*}-sandbox.md"
                    .venv/bin/python sandbox_runner.py \
                        --before "$RUN_JSON" \
                        --file fixtures/${STORY_ID}-sample.py \
                        --old 'return "before-patch"' \
                        --new 'return "after-patch"' \
                        --journey journeys/${STORY_ID}.yaml \
                        --story-id "${STORY_ID}" \
                        --source "${AC_FILE:-$REPO_ROOT/docs/ac/${STORY_ID}.md}" \
                        --output "$SANDBOX_OUT" 2>&1 | tail -15 || \
                        echo "   (M6.3 sandbox failed but pipeline continues)"
                    echo
                fi
            fi
            echo "   ⚠️  apply / re-validate 需人工 (sandbox 限制)；pipeline 只產素材"
            echo
        fi
    fi
fi

echo "═══════════════════════════════════════════════"
echo "  ✨ Pipeline 完成"
echo "═══════════════════════════════════════════════"
echo "  Journey YAML:    $SCRIPT_DIR/journeys/${STORY_ID}.yaml"
echo "  Run JSON:        $RUN_JSON"
echo "  Batch report:    ${REPORT_PATH}.json"
echo "  Markdown report: ${REPORT_PATH}.md"
if [ "${JEV_FIX_PROPOSAL:-0}" = "1" ]; then
    echo "  Fix proposal:    ${REPORT_PATH%.*}-fix-proposal.md"
    if [ "${JEV_FIX_PROPOSAL_V2:-0}" = "1" ]; then
        echo "  Fix proposal v2: ${REPORT_PATH%.*}-fix-proposal-v2.md"
        echo "  Relay bundle:    ${RUN_JSON%.*}.relay/"
    fi
fi
