# US-M62 AC 範本 — regression-guard M6.2 patch + re-validate 閉環

> 對應 Backlog: [US-M62 in docs/backlog.md](../backlog.md)
> 最後更新: 2026-09-28
> 狀態: PENDING

## 背景

M6.1 LLM Relay（TMO-017）已經能產出「LLM 接力的 fix 文字」。
但接力後仍需人手動開 editor 改 code、commit、重跑 pipeline 才能驗證 fix 是否真的修好。

**M6.2** = 把這條「LLM 文字 → 真的 patch → 重跑驗證」串起來。
讓 regression-guard skill 不只給建議，還能**自我修正 + 自我驗證**（在半 sandbox 環境內）。

## Given / When / Then

### AC01 — patch 文字 parser

- **Given** LLM Relay 產出的 fix_proposal_v2.md 包含 `### 建議修正` 段
  **When** `patch_parser.py` 解析該段
  **Then** 抽出 `(file_path, old_text, new_text)` 三元組，產出 structured JSON
  **And** 缺欄位 / 格式錯誤時回傳明確錯誤，不拋 exception

### AC02 — playwright patcher（dry-run safe）

- **Given** `(file, old, new)` 三元組
  **When** `playwright_patcher.py` 在 dry-run 模式 apply
  **Then** 不修改 source file，僅產出 diff 報告（unified diff 格式）
  **And** 自動備份原檔到 `.bak`（即使 dry-run 也要備份以便比對）

### AC03 — re-validate 迴圈

- **Given** patch 已 apply 且 backup 在 `.bak`
  **When** `re-validate` 重新跑 `journey_runner.py` 同一 journey
  **Then** 產出 `before.json` + `after.json`，diff verdict 分布
  **And** 若 verdict counts 的 `fail` 變少 → 標 `improvement`
  **And** 若 `fail` 變多 → 自動 rollback + 標 `regression`

### AC04 — 探針守護 + pipeline 整合

- **Given** 4 個 AC 都實作
  **When** `bats tests/v2.1-jev-poc.bats` 跑
  **Then** 8 個 M6.2 探針全綠（parser / patcher / re-validate / pipeline 整合）
  **And** `JEV_PATCH_AND_REVALIDATE=1 ./run_pipeline.sh US-M62` 一鍵跑 M2→M3→M4→M6→M6.1→M6.2

## DoD（Definition of Done）

- [ ] AC01 / AC02 / AC03 / AC04 4 條全綠
- [ ] `JEV_PATCH_AND_REVALIDATE=1 ./run_pipeline.sh US-M62` 一鍵跑通完整閉環
- [ ] `bats tests/v2.1-jev-poc.bats` 50 → 58 探針全綠
- [ ] `fix_proposal_v2.py --apply-patch --validate` CLI 介面可用
- [ ] deliverable.md 完成 + 反思 6 維度
- [ ] backlog 標 TMO-019 done

## 風險與限制

- **sandbox 環境**：M6.2 patch 只能在「受控環境」跑（fixture + 隔離工作樹），不能在 master 直接改
- **patch safety**：`old_text` 不存在 / 多處 match 時必須 abort，不可靜默套用
- **LLM 接力文字不可信**：LLM 給的 patch 可能是錯的；rollback 機制必須 100% 可靠
- **scope 控制**：M6.2 不做「自動 commit」；patch 驗證通過後只留報告，由 reviewer 決定要不要 commit
