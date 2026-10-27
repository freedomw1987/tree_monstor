#!/usr/bin/env bash
# scripts/ci/hooks/pre-push.sh — pre-push 閘（本機 CI 等價）
#
# tree_monstor-local-ci-gate-v1
#
# 做咩：push 之前跑一次 `scripts/check-all.sh`（＝ CI 嘅檢查步驟喺本機跑一次），
#        紅就擋住 push。目的是**提早揭盲**：唔使 push 完先等 5–7 分鐘睇 Actions 先知死。
#
# 安裝：`bash scripts/install-local-hooks.sh`
# 移除：`rm -f "$(git rev-parse --git-path hooks)/pre-push"`
# 一次性繞過：`SKIP_LOCAL_CI=1 git push`（會印警告；CI 仍然會跑）
#
# ⚠️ 定位（TMO-084，2026-10-27）：CI 已**降級為偵測器**（唔阻 merge、唔係完成條件）→
#    **本機閘先係完成條件**。所以呢個 hook 擋你嘅理由唔係「CI 會紅」，
#    而係「你部機嘅閘紅咗」——即係唔會將壞嘢推上去。
#    CI 仍然會跑（跨 OS／跨版本／clean-clone 嗰啲**本機結構上做唔到**嘅嘢只有 CI 證得到），
#    但佢而家只係**通知**：CI 紅唔一定係你做錯（多數係環境差異），值得望一眼而已。

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
CHECK_ALL="$REPO_ROOT/scripts/check-all.sh"

if [ "${SKIP_LOCAL_CI:-0}" = "1" ]; then
  echo "⚠️  SKIP_LOCAL_CI=1 → 跳過本機 CI 等價閘（push 咗去；CI 仍然會跑，但**唔阻 merge**）" >&2
  exit 0
fi

if [ ! -f "$CHECK_ALL" ]; then
  # 唔擋：可能係 checkout 咗一個未有呢個檔嘅舊 commit。
  # 但要講清楚個閘**冇生效**（唔可以靜靜哋當自己跑咗）。
  echo "⚠️  搵唔到 ${CHECK_ALL} → 本機 CI 等價閘未生效（CI 仍然會跑）" >&2
  exit 0
fi

echo "── pre-push：本機 CI 等價閘（scripts/check-all.sh）──"
rc=0
bash "$CHECK_ALL" || rc=$?
if [ "$rc" -ne 0 ]; then
  echo "" >&2
  echo "❌ 本機 CI 等價閘未通過 → push 已中止。" >&2
  echo "   上面係紅嘅步驟同原因；修好再 push。" >&2
  echo "   確定知咗點解紅、仍然要 push：SKIP_LOCAL_CI=1 git push" >&2
  exit "$rc"
fi
exit 0
