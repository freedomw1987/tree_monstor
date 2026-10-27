# TMO-090 需求錨點

> US: TMO-090 | 建立: 2026-10-27 | 來源: 用戶決策（skill 減法：合併 3 個 TDD skill ＋ 刪 reflection ＋ 表格禁令）

## 用戶原話（唯讀）

- R1: 「其實tdd-test-writer & dev-checker-loop & regression-guard 都是做緊Test Driven development 相關的，
  我想他們是合成為一個叫dav-developer skill」
- R2: 「dav-developer skill 的SOP： 寫測試-> 開發由紅變綠(這裡是前dev-checker-loop部份)，
  regression-guard 可以不用全個項目跑探針，因為在dev-checker-loop 的reviewer agent 其實有做到同一件事，
  反而regression-guard 要做埋，但寫測試部份就最好要有regression-guard 的嚴謹性度」
- R3: 「dav-reflection 可以刪除」
- R4: 「另外我想項目中的markdown文件都不用table(包括skill生成的markdown)，
  因為table 的可閱讀性不高，用列表方式去做編寫，這個也寫在dav-skill-creater skill 的規範中」

## 澄清後驗收句

- R1: `tdd-test-writer` ＋ `dev-checker-loop` ＋ `regression-guard` 要合併成 **`dav-developer`**（單一 skill）。
- R2: `dav-developer` 嘅 SOP 順序要係「**寫測試 → 開發令紅變綠 → 探針與回歸 → Reviewer 二審**」；
  Gate 3（regression）**唔再要求全項目跑探針**（改跑改動範圍內；Reviewer agent 已覆蓋同一件事）；
  但「寫測試」部分要保留 **regression-guard 嘅嚴謹性**（fail-loud、帶修復建議、禁用 watch／interactive）。
- R3: `dav-reflection` 要刪除，內容（6 維度反省 + 三級別模板）併入 `dav-submitter`。
- R4: markdown **唔用表格**，改用列表；規則要寫入 `dav-skill-creater` 規範。

## 執行約束（repo 既有規則，唔屬驗收句）

- 改 skill／SOP／契約 → 依 `AGENTS.md` §1.5 **V03 走獨立 Reviewer 二審**
- 文檔行數限制（v2.8）：主檔 ≤150／子檔 ≤300／context ≤700（ratchet baseline 另有記錄）
- 探針／mutant／CI 路徑要同步（改路徑 = 改契約）

## 變更歷史

| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-10-27 | 初版 | 用戶 4 條決策逐字整理成錨點 |
