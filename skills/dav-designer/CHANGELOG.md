# Dav Designer — CHANGELOG

> 本檔為 dav-designer 的完整變動歷史。引用：`SKILL.md` 變動歷史章節
>
> 從 SKILL.md v2.5 起，變動歷史外移到本檔；主檔只保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.5 | 2026-09-26 | 本次自包含化：搬入 `examples/system-design.md`（原 monorepo 範例總目錄內的 docs 子目錄）；交叉引用段「見 monorepo 對應的 X」 → 「見本 skill 的 examples/system-design.md」 | skill 可離線讀、不綁定 monorepo；V03 Reviewer 二審通過 |
| v2.4 | 2026-09-26 | 清「具體 Module 完整生命週期範例的 path 引用」 → 抽象詞「見 monorepo 對應的 X」 | 修 v2.2 跨目錄讀檔引用零容忍存量；V03 Reviewer 二審通過 |
| v2.4 | 2026-09-26 | 拆檔：主檔瘦身到 ~75 行，Step 1-5 全剖細節 → `workflow.md` | 達 150 行上限；與 dav-planner v2.2 拆檔哲學一致 |
| v2.3 | 2026-09-26 | +Module 目的與切割原則（Step 1）+ Module 邊界即測試邊界（Step 3）| 用戶決策：Module 為「可獨立開發 / 增減 / 測試」的功能單位 |
| v2.2 | 2026-09-26 | +DoD 彈性化（DoD-Lite 預設 / DoD-Full 選用）+ Step 1 一次詢問 | Jevons 反思：避免 DoD 過重變成技術債 |
| v2.1 | 2026-09-26 | +Step 4.5 設計自審 + 用戶簽核 + 5 維度檢查 | 用戶決策：設計驗證環節 |
| v2.1 | 2026-09-26 | +PRD.md 強制追溯矩陣（FR ↔ US ↔ 畫面 ↔ 原型 ↔ 狀態）| 用戶決策：避免幽靈畫面 / 幽靈需求 |
| v2.1 | 2026-09-26 | +原型 DoD 5 種狀態（happy / loading / empty / error / edge）| 用戶決策：原型完成定義嚴謹化 |
| v2.1 | 2026-09-26 | +與 dav-planner 邊界規則（互不寫 US / Backlog）| 用戶提問確認：避免職責衝突 |
| v2.1 | 2026-09-26 | 拆 `prototype-quality.md` 子檔，SKILL.md 控 < 150 行 | 套用 150 行上限 |
| v2.0 | 2026-09-26 | 重結構為「任務導航」5 段 + 新增 §5 互動 HTML 原型 | TMO-009 階段 5 + 用戶決策 |
| v1.x | — | （舊版「Backlog 分析 + UX/UI + 架構 + PRD」雙 §3 結構）| 用戶體驗不佳 |
