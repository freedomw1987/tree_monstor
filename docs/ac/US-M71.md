# US-M71 AC 範本 — regression-guard M7 flaky 整合 + gh pr comment

> 對應 Backlog: TMO-021
> 最後更新: 2026-09-28
> 狀態: PENDING

## 背景

TMO-020 已建 flaky_check.py 可獨立量測 journey 穩定性，但「跑多次」很貴、且結果沒自動整合進 batch_report。本 US 做兩件事：

1. **flaky 整合進 batch_report**：跑 1 次 pipeline 的同時，**額外跑 2 次** 算 flaky_likelihood，併入 `overall_health` 維度
2. **gh pr comment**：CI 在 PR 上自動推 fix_proposal + 信心度報告 + 建議，reviewer 不用離開 PR 就能看

**為什麼這次 sprint 選這兩個**：TMO-019 / TMO-020 反思的 5 個 Action Item 中，這 2 個最「解鎖 review 流程」（其他 3 個是 hardening / 整合，不解鎖流程）。

## Given / When / Then

### AC01 — flaky_likelihood 整合進 batch_report

- **Given** M3 跑 1 次 journey + flaky_likelihood 需 ≥ 3 次樣本
  **When** `flaky_integration.py` 跑（含 M3 + 額外 2 次）
  **Then** batch_report JSON 含 `overall_health.flaky_likelihood` 欄位（0~1）
  **And** 標記分類：stable / mildly_flaky / highly_flaky
  **And** 高度 flaky 時 `overall_health` 加 `⚠️` 警告

### AC02 — gh pr comment 模組

- **Given** fix_proposal_v2.md + batch_report.md 已產出
  **When** `gh_pr_comment.py` 跑
  **Then** 構造 PR comment 4 段：journey 標題 / 信心度 gating / fix proposal 摘要 / sandbox 建議
  **And** 透過 `gh pr comment` 推到當前 PR
  **And** comment 失敗不中斷 pipeline（best-effort）

### AC03 — pipeline 整合

- **Given** AC01/02 模組已實作
  **When** `JEV_GH_PR_COMMENT=1 ./run_pipeline.sh <STORY>` 跑
  **Then** 自動跑 M3 + flaky 額外 2 次 + 整合 batch_report
  **And** 自動 gh pr comment 推 PR

### AC04 — 探針守護

- **Given** 4 個 AC 都實作
  **When** `bats tests/v2.1-jev-poc.bats` 跑
  **Then** 12 個 M7 探針全綠（80 → 92）

## DoD

- [ ] AC01 / AC02 / AC03 / AC04 全綠
- [ ] `flaky_integration.py` + `gh_pr_comment.py` CLI 可獨立呼叫
- [ ] 12 個 M7 探針全綠
- [ ] pipeline 一鍵跑 M2→M3→flaky→M6→M6.1→M6.2→gh-pr-comment
- [ ] deliverable + 反思 + backlog 標 TMO-021 done

## 風險

- **CI minutes 增 3x**：原本 1 次 journey ~10s，flaky 額外 2 次 = ~30s；可接受
- **gh pr comment token**：需 `GITHUB_TOKEN` 自動提供（actions 預設有）
- **flaky 整合改 batch_report schema**：向後相容，新增欄位不破壞既有
