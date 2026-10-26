# Dav Reflection — CHANGELOG

> **2026-10-26 減法**：與本 skill 對應的 meta 探針（`tests/restruct-*.bats`）已刪除——
> meta 探針只驗「文字存在」，對產品事實無驗證力。下方歷史條目保留原樣（歷史記錄不回改）。
> 本檔為 dav-reflection 的完整變動歷史。引用：`SKILL.md` 變動歷史章節
>
> 從 SKILL.md v2.1 起，變動歷史外移到本檔；主檔只保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.5 | 2026-10-26 | `template.md` 200 → 192 行（Module 級協作／架構檢查合併、重構建議合行） | context 成本輕微下降；三級模板嘅必備段落一個唔少 |
| v2.4 | 2026-10-26 | 支援檔瘦身（TMO-082 A 刀）：`checklist.md` 194 → 141 行（6 維度重複嘅標記標準表合併成共用表 ＋ 每節門檻行）、`template.md` 217 → 200 行（3 個級別模板改用共用骨架 ＋ 每級差異） | context 成本由 534 行降至 463 行；6 維度嘅檢查問題一條唔少，⚠️／❌ 嘅數量門檻仍逐維度列明 |
| v2.3 | 2026-10-26 | 規則表加「需求對帳先於反省」（Gate 4.5 對帳產物是反省前提；對帳未過不得把未完成項當已完成來反省）| TMO-072：反省建立在未經驗證的「已完成」前提上，會把落差洗成「已反思」|
| v2.2 | 2026-10-23 | Step 5 加 trust 例外（trust mode 進行中：改記 need-you-help 檔）+ 規則列「Sprint / Module 必有用戶參與」例外欄 + 觸發時機表 Sprint / Module 列加註 | trust 內不得中途停下問用戶（TMO-067）；V03 Reviewer 二審結論見全域 handbook changelog v2.10 |
| v2.1 | 2026-09-26 | +可用性偵測（Step 1 / `which jev-use`）+6 維度 jev 逐項打分（僅 score 類型）+反思結果驗證（noul）+escalate 落 deliverable.md `## 反思` 段（**不寫 checklist.md**）+術語對齊說明（B2：本 skill 一類 vs dev-checker-loop 三類）+輕量路徑（S2：US 級別只打 2 維度）+ jev 內部失敗 fallback（S3）+M-Step 3 探針點名（B3：`bats tests/restruct-dav-reflection.bats`）+6 條新規則 +checklist.md 新增「## 7. jev_judge 對接表」（6 維度對應 jev_judge 問題模板）| 用戶決策：全面整合 jev-use；先出方案再啟動 Reviewer（V03）；escalate 降級為人類決策；軟性降級 + 提示安裝；Reviewer verdict = ⚠️ approve with suggestions、全部 3 必加 + 3 建議納入；S1（checklist.md 誤導）已修正 |
| v2.0 | 2026-09-26 | 重結構為「任務導航」5 段（TL;DR / 觸發 / 流程 / 規則 / 變動歷史）| TMO-009 階段 1 PoC：LLM 注意力優化 |
| v2.0 | 2026-09-26 | 反思併進 deliverable.md 末段（v2.0 規則）| TMO-008 減法：取消獨立反思檔 |
| v1.x | — | （舊版 6 維度流程 + 獨立反思檔）| 詳見全域 SOP 變動歷史 v1.x |
