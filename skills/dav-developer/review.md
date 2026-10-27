# Dav Developer — Reviewer 二審（Gate 4）

> 本檔為 `dav-developer` 的「Step 4 Reviewer 二審」子檔（取自原 `dav-developer` skill）。
> 目的：獨立 reviewer 捉「自己睇唔到」嘅盲點。

## 核心角色

- **dev**
  - 職責：領取任務 → 依 DESIGN.md / system-design.md / PRD 開發 → 保留探針 → 標記「等待校驗」
- **checker**
  - 職責：監控 backlog → 發現「等待校驗」→ 全面校驗 → 問題記錄 → dev 自動修復

## 循環終止條件

- **用戶手動終止**
  - 說明：由用戶決定何時停止
- **所有任務完成**
  - 說明：backlog 為空且所有狀態為「已完成」
- **循環上限**
  - 說明：任一問題超過 20 次循環仍未解決則中斷

## （續）循環終止條件

- **用戶手動終止**
  - 說明：由用戶決定何時停止
- **所有任務完成**
  - 說明：backlog 為空且所有狀態為「已完成」
- **循環上限**
  - 說明：任一問題超過 20 次循環仍未解決則中斷

## Gate 4 前置

- **前置**：Step 1 測試已紅、Step 2 已綠、Step 3 探針已埋好（否則 reviewer 會捉到「測試係假綠」）
- **角色分工**：dev 做實作 → checker subagent 做獨立校驗 → 有問題返 dev 修 → 重複
- **證據**：checker subagent **原文回傳**（唔准自己改寫成「已通過」）
