# Dav Planner — CHANGELOG

> 本檔為 dav-planner 的完整變動歷史。引用：`SKILL.md` 變動歷史章節
>
> 從 SKILL.md v2.3 起，變動歷史外移到本檔；主檔只保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.6 | 2026-09-26 | +Step 1.5「來源抽取（複雜任務可選）」：位於 Step 1 後 Step 2 前；觸發條件 + 推薦調用 dav-wiki + 何時跳過 + dav-wiki 未裝 fallback | 用戶決策：複雜任務需求會多次更新、需要回原始來源；dav-wiki 已是 monorepo skill、軟引用而非強制耦合；V03 Reviewer 二審通過（verdict-3）；依賴 dav-wiki skill 需同套安裝 |
| v2.5 | 2026-09-26 | 本次自包含化：搬入 `examples/backlog.md`（原 monorepo 範例總目錄內的 docs 子目錄）；交叉引用段「見 monorepo 對應的 X」 → 「見本 skill 的 examples/backlog.md」 | skill 可離線讀、不綁定 monorepo；V03 Reviewer 二審通過 |
| v2.4 | 2026-09-26 | 清「Module 完整生命週期範例的具體 path 引用」 → 抽象詞「見 monorepo 對應的 X」 | 修 v2.2 跨目錄讀檔引用零容忍存量；V03 Reviewer 二審通過 |
| v2.3 | 2026-09-26 | +§4.3.1 Module 欄位範本 + §4.3.2 Module 級 sprint；backlog 表格欄位加 Module | v2.8 dav-designer / dev-checker-loop / regression-guard 鋪好 Module 基礎，本 skill 補完「backlog.md 怎麼寫」讓 Module 欄位到位 |
| v2.2 | 2026-09-26 | 拆檔：主檔瘦身到 ~95 行，§2/§3/§5 → `reference.md`，§4 → `backlog-rules.md`；v1.9 加註「（已廢棄）」 | 達 150 行上限；P2 同名混淆加註解 |
| v2.1 | 2026-09-26 | -§2.7 用戶背景收集整套（角色詢問）；定位收斂為「任務的背景 / 最終目的 / 驗收標準」 | 用戶決策：對話用戶角色對後續開發無實質幫助，反引導用戶進入「搞不清自己要什麼」的狀態 |
| v2.0 | 2026-09-26 | 重結構為「任務導航」5 段 | TMO-009 階段 3：LLM 注意力優化 |
| v1.9 | 2026-09-26 | +§2.7 用戶背景收集（角色詢問，已廢棄） | TMO-007：用戶決策（已被 v2.1 撤銷） |
| v1.8 | 2026-09-26 | AC 範本獨立化 + HTML 版本 | TMO-006：可讀性 / 列印友好 |
| v1.x | — | （舊版 7 維度 + SWOT + INVEST + Given-When-Then）| 詳見全域 SOP 變動歷史 v1.x |
