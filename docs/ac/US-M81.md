# US-M81 AC 範本 — regression-guard M8 CI matrix pipeline

> 對應 Backlog: TMO-022
> 最後更新: 2026-09-28
> 狀態: PENDING

## 背景

TMO-021 (M7) 完整閉環已完成，但 CI workflow 每次只能跑 1 個 story_id。本 US 加 matrix 策略：
- 同時跑 US-101 / US-M62 / US-M63 3 個 journey
- 每個產獨立 report + artifact
- 結果聚合到 `aggregate-matrix-reports` step

**為什麼要 matrix**：實務上多個 US 同時變更時，reviewer 需要一次看 3 個 US 的 regression 結果；matrix 讓 CI 一次產出。

## Given / When / Then

### AC01 — matrix job 結構

- **Given** workflow 需支援多 story_id 並行
  **When** workflow_dispatch 觸發
  **Then** 用 `matrix.story_id: [US-101, US-M62, US-M63]` 3 個並行
  **And** `fail-fast: false` 避免一個 fail 全部 cancel

### AC02 — 每個 story 產獨立 artifact

- **Given** matrix 跑 3 個 story_id
  **When** 每個 job 完成
  **Then** 產 `report-${story_id}.md` + `batch-${story_id}.json` 兩個 artifact
  **And** artifact 30-day retention

### AC03 — 結果聚合

- **Given** 3 個 matrix job 跑完
  **When** `aggregate-matrix-reports` step 跑
  **Then** 合併 3 個 batch_report 成 `matrix-summary.md` 表格
  **And** 標記整體 health（green/yellow/red）+ 個別 health

### AC04 — 探針守護

- **Given** 4 個 AC 都實作
  **When** `bats tests/v2.1-jev-poc.bats` 跑
  **Then** 6 個 M8 探針全綠（92 → 98）

## DoD

- [ ] AC01/02/03/04 全綠
- [ ] workflow_dispatch 觸發可跑 3 個 matrix job
- [ ] 3 個 artifact 各自獨立 + matrix-summary.md
- [ ] 6 個 M8 探針全綠
- [ ] deliverable + 反思 + backlog 標 TMO-022 done

## 風險

- **CI minutes 增 3x**：matrix 3 個並行 = 3 倍 minutes（但平行，所以 wall time 差不多）
- **rate limit**：Jev OpenRouter API 有 rate limit；3 個並行可能觸發；可用 Jev cache 緩解
