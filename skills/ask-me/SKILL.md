---
name: ask-me
description: >-
  把 trust mode 期間寫進 need-you-help.md 的「待確認擔憂」逐題跟用戶確認，同步回寫 need-you-help.md 的抉擇欄 + 雙寫進 docs/backlog.md 對應 US 的狀態（✅ 繼續做 /
  📝 改設計 / ⏸️ 跳過）。不適用於：trust mode 進行中（會打斷 trust）、一般對話提問（用 ask_user_question）、純諮詢。
---

# Ask Me

## TL;DR

1. **做什麼**：trust mode 結束後，讀 `docs/need-you-help.md`（專案端路徑）把 ☐ 未確認的擔憂**一個一個**問用戶、確認後**雙寫**
   （`need-you-help.md` + `docs/backlog.md`），全部處理完才退出。
2. **何時觸發**：用戶說「處理 need-you-help」「ask-me」「跑完需要我幫的子問題」、trust mode 自然結束後有遺留擔憂。
3. **不適用於**：trust mode 進行中（打斷 trust）、一般對話提問（用 ask_user_question 就好）、純諮詢（用戶只是問問題不需決策）。
4. **關鍵紀律**：**逐題確認**（一次只問 1 個擔憂，V01 一次一個問題）；**雙寫必齊**（用戶回答後 `need-you-help.md` 同 `backlog.md` 必須同步更新，缺一不可）；
   **退出條件**（全部 ☐ 都變 ☑ 才輸出 `🏁 ask-me 結束`）；**不自動延伸**（結束後不自動做事、等用戶指示，見同套上游 skill 結束後行為規範，需同套安裝）。
5. **必產出物**：`docs/need-you-help.md` ☐→☑ 全確認 + `docs/backlog.md` 對應 US 狀態更新 + 對話輸出處理總結。

## 觸發時機

- **用戶說「ask-me」「處理 need-you-help」「跑一下要問我的」** → ✅ 必須
- **Trust Mode 自然結束（deadline 到）+ `need-you-help.md` 有 ☐** → ✅ 自動建議（不在對話中自動啟動）；**Trust Mode 結束標記後用戶說「看看要問的」** → ✅ 觸發
- **Trust Mode 進行中用戶提問** → ❌ 不觸發（打斷 trust，走普通對話）
- **一般任務的單次提問** → ❌ 用 `ask_user_question`；**純諮詢（用戶只是問、不需決策）** → ❌ 用普通對話回應

## 流程（4 步；每步動作／為什麼／產出／證據見 [`workflow.md`](./workflow.md)）

- **Step 1 讀 need-you-help.md** → 列舉全部 ☐ 未確認條目（跳過 ☑）；0 個 ☐ 就輸出「無未確認擔憂」＋退出
- **Step 2 逐題問用戶** → 用 `ask_user_question` 問 4 選項（⭐ 最推薦 繼續做／改設計／跳過／自訂，V02 必標推薦）；只問 1 題
- **Step 3 雙寫紀錄（必齊）** → `need-you-help.md` ＋ `docs/backlog.md` 同步更新、缺一不可；格式範本見 [`examples.md`](./examples.md)；
  任一寫入失敗 → 不勾 ☑、標 `⚠️ 雙寫半完成（需人工修）`、不繼續下一題
- **Step 4 下一題或退出** → 仲有 ☐ 就回 Step 2；冇 ☐ 就輸出 `🏁 ask-me 結束` ＋處理總結（N/M 項、每項決定、orphan 數、建議下一步）

## 規則 / 例外 / 限制

- **一次只問 1 題；雙寫必齊（need-you-help + backlog）** — 例外：N/A；限制：V01 紀律、批量會增加決策疲勞；缺一即視為 ask-me 未完成
- **全部 ☐ 變 ☑ 才退出；不動 `need-you-help.md` 以外的需求檔** — 例外：用戶中途叫停可提早退出；限制：退出時標 `⏸️ 用戶中斷`；只動 need-you-help + backlog，不改需求／設計文件
- **不自動延伸（結束後不做事）；退出後不重做 trust mode** — 例外：用戶說「繼續 trust」可重啟；限制：見同套上游 skill 結束後行為規範（需同套安裝）；trust 重啟由用戶決定
- **信任標記 `✅/📝/⏸️` 三選一；抉擇理由必含日期** — 例外：不用其他 emoji 保持一致性／N/A；限制：與 backlog 既有 emoji 對齊；`YYYY-MM-DD ask-me：...` 格式便於 grep
- **對應 US 在 backlog.md 找不到** — 例外：標 `⚠️ orphan` 在 need-you-help、不阻塞流程；限制：結束時提醒用戶手動處理
- **唔走完整 SOP** — 例外：N/A；限制：ask-me 係輔助 skill，走簡化流程

## 交叉引用

- 上游 trust skill：trust mode 進行中 → 本 skill ❌ 不觸發（上游 skill 寫 ☐ 條目）；結束後 → ✅ 等用戶說「ask-me」（上游結束標記輸出見同套上游 skill 結束後行為規範，需同套安裝）
- 本 skill 結束後 → 對話輸出 `🏁 ask-me 結束`，等用戶說「繼續 trust」或新指示；本 skill 係獨立 skill、唔屬上游 trust skill 嘅一部分，
  雙方透過 monorepo 約定嘅待辦檔案介接（路徑由 monorepo 約定）
