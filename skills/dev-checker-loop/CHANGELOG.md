# Dev Checker Loop — CHANGELOG

> 本檔為 dev-checker-loop 的完整變動歷史。引用：`SKILL.md` 變動歷史章節
>
> 從 SKILL.md v2.2 起，變動歷史外移到本檔；主檔只保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.5 | 2026-10-04 | Step 1「動作+為什麼」措辭精確化：明示 `docs/backlog.md` 與 system-design 取得皆屬「目標專案」、改寫為非跨目錄讀取式語法；主檔行數 127 → 127（不變）| TMO-026：A 類 18 紅清理附帶修正（探針 retarget 時發現 skill 文案有語意模糊）；V03 Reviewer 二審 approve-with-comments、0 P0/P1；P2 建議「應補 CHANGELOG 紀錄」已納入 |
| v2.4 | 2026-09-26 | +可用性偵測（Step 0 / `which jev-use`）+校驗前 jev 快篩（Module ≥5 檔）+校驗後 jev 驗證 +escalate 落校驗報告 +V03.5 主檔行數預警（B1：143 行黃區）+術語對齊說明（B2：本 skill 三類 vs dav-reflection 一類）+輕量路徑（S2：小 Module 跳過快篩）+ jev 內部失敗 fallback（S3）+M-Step 3 探針點名（B3：`bats tests/restruct-dev-checker-loop.bats`）+6 條新規則；**v2.4 二次更新**：主檔 148 行瘦身至 127 行（綠區）、Step 1/2/4/5「動作/為什麼/產出/證據」4 欄合併、觸發表格 6 列縮至 3 列、規則表 6 條 v2.4 規則濃縮為 1 行指向 workflow.md；workflow.md 新增「## jev 整合細節（v2.4 新增）」含 Step 0 程式碼 +校驗前/後 jev 步驟 +escalate 處理 +術語對齊 +6 條規則完整版 | 用戶決策：全面整合 jev-use；先出方案再啟動 Reviewer（V03）；escalate 降級為人類決策；軟性降級 + 提示安裝；Reviewer verdict = ⚠️ approve with suggestions、全部 3 必加 + 3 建議納入；TECH-003 瘦身：128 → 127 行、回到綠區 |
| v2.3 | 2026-09-26 | 自包含化：搬入 `examples/checklist.md`（原 monorepo 範例總目錄）；交叉引用段「見 monorepo 對應的 X」 → 「見本 skill 的 examples/checklist.md」 | skill 可離線讀、不綁定 monorepo；V03 Reviewer 二審通過 |
| v2.2 | 2026-09-26 | +Module 感知邏輯（派工綁 Module / 改檔不跨 Module / 探針 Module prefix / 校驗限 Module）+「Module 感知邏輯」章節拆分至 `module-rules.md` | 用戶決策：Module = 一組檔案；v2.6 dav-designer 鋪路，本 skill 把 Module 從設計變執行單位 |
| v2.1 | 2026-09-26 | 重結構為「任務導航」+ 純文字引用 | TMO-009 階段 9：LLM 注意力優化 + skill 獨立搬動 |
| v2.0 | 2026-09-26 | 文件產出物精簡規則適用 | TMO-008 減法 |
| v1.x | — | （舊版含 ASCII 流程圖）| 詳見全域 SOP 變動歷史 v1.x |
