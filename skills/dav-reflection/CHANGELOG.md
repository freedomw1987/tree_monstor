# Dav Reflection — CHANGELOG

> 本檔為 dav-reflection 的完整變動歷史。引用：`SKILL.md` 變動歷史章節
>
> 從 SKILL.md v2.1 起，變動歷史外移到本檔；主檔只保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.1 | 2026-09-26 | +可用性偵測（Step 1 / `which jev-use`）+6 維度 jev 逐項打分（僅 score 類型）+反思結果驗證（noul）+escalate 落 deliverable.md `## 反思` 段（**不寫 checklist.md**）+術語對齊說明（B2：本 skill 一類 vs dev-checker-loop 三類）+輕量路徑（S2：US 級別只打 2 維度）+ jev 內部失敗 fallback（S3）+M-Step 3 探針點名（B3：`bats tests/restruct-dav-reflection.bats`）+6 條新規則 +checklist.md 新增「## 7. jev_judge 對接表」（6 維度對應 jev_judge 問題模板）| 用戶決策：全面整合 jev-use；先出方案再啟動 Reviewer（V03）；escalate 降級為人類決策；軟性降級 + 提示安裝；Reviewer verdict = ⚠️ approve with suggestions、全部 3 必加 + 3 建議納入；S1（checklist.md 誤導）已修正 |
| v2.0 | 2026-09-26 | 重結構為「任務導航」5 段（TL;DR / 觸發 / 流程 / 規則 / 變動歷史）| TMO-009 階段 1 PoC：LLM 注意力優化 |
| v2.0 | 2026-09-26 | 反思併進 deliverable.md 末段（v2.0 規則）| TMO-008 減法：取消獨立反思檔 |
| v1.x | — | （舊版 6 維度流程 + 獨立反思檔）| 詳見全域 SOP 變動歷史 v1.x |
