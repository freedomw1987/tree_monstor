# US-M63 AC 範本 — regression-guard M6.3 互動式 sandbox

> 對應 Backlog: [US-M63 in docs/backlog.md](../backlog.md)
> 最後更新: 2026-09-28
> 狀態: PENDING

## 背景

M6.2（TMO-019）已實作 patch + re-validate 雙模組 + 3 步手動流程：
1. `playwright_patcher.py --apply`
2. `run_journey.py` 重跑
3. `re_validate.py` 比對

但這 3 步仍需人手動在 sandbox 跑。**M6.3** = 把這 3 步封裝成一個「互動式 sandbox」：
- 在隔離 working tree 跑（git worktree / tmp dir）
- 自動 patch → 自動 re-validate → 自動 rollback if regression
- 產出完整 sandbox report（含 diff、verdict 變化、最終建議）

**為什麼叫「互動式」**：dry-run 自動跑，apply 後的 patch 仍由人工 review + commit；但 sandbox 內的 apply + re-validate + rollback 全自動。

## Given / When / Then

### AC01 — sandbox 建立與隔離

- **Given** patch 素材 + 目標 repo 路徑
  **When** `sandbox_runner.py` 在 `--sandbox` 模式啟動
  **Then** 建立 `tmp/.sandbox-<ts>/` 隔離工作目錄（copy fixture + journey + source file）
  **And** 自動備份所有會被 patch 的檔案到 `<sandbox>/.pre-patch/`
  **And** 結束時不論成功失敗都 cleanup 隔離目錄（不留垃圾）

### AC02 — 自動 apply + 自動 re-validate

- **Given** sandbox 已建立 + (file, old, new) 已就緒
  **When** `sandbox_runner.py` apply patch in sandbox
  **Then** 用 playwright_patcher.py 在 sandbox 內 apply（不動主 repo）
  **And** 自動重跑 `journey_runner.py` 同一 journey 產 `after.json`
  **And** 自動呼叫 `re_validate.py` 比對 verdict 分類

### AC03 — 自動 rollback + 報告

- **Given** re-validate 分類完成
  **When** 分類為 `regression`
  **Then** 自動從 `.pre-patch/` 還原 sandbox 內所有被改的檔案
  **And** 重跑一次 journey 確認 verdict 回到 baseline（before）
  **And** 產出 `sandbox_report.md`：含 diff + verdict delta + 最終建議（keep/rollback）

### AC04 — 探針守護 + pipeline 整合

- **Given** 4 個 AC 都實作
  **When** `bats tests/v2.1-jev-poc.bats` 跑
  **Then** 8 個 M6.3 探針全綠（sandbox 建立 / apply / re-validate / rollback / 報告 / pipeline 整合）
  **And** `JEV_SANDBOX_RUN=1 ./run_pipeline.sh US-M63` 一鍵跑 M2→M3→M4→M6→M6.1→M6.2→M6.3

## DoD

- [ ] AC01 / AC02 / AC03 / AC04 全綠
- [ ] `sandbox_runner.py` CLI 介面可用（dry-run + apply-in-sandbox 模式）
- [ ] 8 個 M6.3 探針全綠（63 → 71）
- [ ] pipeline 一鍵跑完整閉環 M2→M6.3
- [ ] deliverable + 反思 + backlog 標 TMO-020 done

## 風險與限制

- **隔離等級**：M6.3 sandbox 是「目錄級隔離」（copy fixture + source file），不是「process / container 級隔離」
- **patch 範圍**：sandbox 只 patch 顯式列出的 (file, old, new)；不處理 transitive dependency
- **actor 仍是人工**：apply in sandbox + re-validate + rollback 都自動，但「要不要把 sandbox 的 patch 拿回主 repo + commit」仍人工決定
- **scope 控制**：sandbox 不做「自動 commit」；不污染 git history
