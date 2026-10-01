# Dev Checker Loop — CHANGELOG

> 本檔為 dev-checker-loop 的完整變動歷史。引用：`SKILL.md` 變動歷史章節
>
> 從 SKILL.md v2.2 起，變動歷史外移到本檔；主檔只保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.3 | 2026-09-26 | 自包含化：搬入 `examples/checklist.md`（原 monorepo 範例總目錄）；交叉引用段「見 monorepo 對應的 X」 → 「見本 skill 的 examples/checklist.md」 | skill 可離線讀、不綁定 monorepo；V03 Reviewer 二審通過 |
| v2.2 | 2026-09-26 | +Module 感知邏輯（派工綁 Module / 改檔不跨 Module / 探針 Module prefix / 校驗限 Module）+「Module 感知邏輯」章節拆分至 `module-rules.md` | 用戶決策：Module = 一組檔案；v2.6 dav-designer 鋪路，本 skill 把 Module 從設計變執行單位 |
| v2.1 | 2026-09-26 | 重結構為「任務導航」+ 純文字引用 | TMO-009 階段 9：LLM 注意力優化 + skill 獨立搬動 |
| v2.0 | 2026-09-26 | 文件產出物精簡規則適用 | TMO-008 減法 |
| v1.x | — | （舊版含 ASCII 流程圖）| 詳見全域 SOP 變動歷史 v1.x |
