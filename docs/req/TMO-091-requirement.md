# TMO-091 需求錨點

> US: TMO-091 | 建立: 2026-10-27 | 來源: 用戶指示（docs 減磅 ＋ 閘提速）

## 用戶原話（唯讀）

- R1: 「docs目錄的 可能要減磅：1. backlog.md 只保留未完成的項目，因為完成的項目功能對應的用戶的需求和PRD 都是獨立文檔，
  項目代碼和功能理應就可以記錄到完成的功能項，不用保留；2. item 1 的要求，都在相應會改backlog.md的skill 中去定義這個保留和不保留的規範；
  3. 同樣地，我想您也看docs 有什麼是值得保留，因為我覺得docs 會累積太多舊記錄，反而浪費時間和LLM 的token」
- R2: 「回答您上面的問題：check-all.sh 做您1＋2的建議」（1 ＝ 按改動範圍跑；2 ＝ mutant 步驟按範圍收窄）
- R3: 「每一次行check-all.sh 都好慢，什麼原因？」（→ 原因：90% 時間係重複驗證，唔係 shell 慢）
- R4: 「docs 減磅刪多咗 PoC 要用嘅 AC fixture⋯⋯會不會放入skill 裡面」（→ 會：PoC fixture 入 skill，skill 自足）
- R5: 「2 , docs/deliverable/ 只留咗最近一次」（→ 該做法要**寫入 skill** 規格，唔可以只做一次）
- R6: 「b」（← 就上一輪建議「之後每次交收都應該跑 `--changed` 而唔係全閘」）→ 開發 loop 用 `--changed`、push 前全量

## 澄清後驗收句

- R1: `docs/backlog.md` **只保留未完成**（todo／doing／⏸️）嘅 row；完成嘅 row 要移出，
  並喺**會改 backlog.md 嘅 skill**（dav-planner §4.5 ＋ dav-submitter Step 5）寫明「保留／不保留」規範。
- R2: `docs/` 其餘內容要有一份「保留 vs 歸檔」判斷，並實際執行減磅（舊記錄靠 git history）。
- R4: PoC 依賴嘅 AC fixture 應**搬入 skill 內**（`skills/<skill>/PoC/fixtures/`），
  令 skill 自足（目標專案都跑得），唔使喺專案層 `docs/ac/` 養住歷史 AC。
- R3: `check-all.sh` 要有 `--changed` 模式：只跑受改動影響嘅探針 ＋ 只跑目標檔被改過嘅 mutant 列；
  skip 嘅步驟要明講原因（唔可以靜靜哋當通過）。
- R6: 開發 loop 要用 `--changed`（快 6-10 倍），push 前先跑全量；呢個分工要寫入 repo 規則
  （`CONTRIBUTING.md` ＋ handbook §2.3 ＋ 腳本頭註解），唔可以只係「習慣」。
- R5: 「交付摘要只留最近一次」嘅做法要**寫入 skill 規格**（`dav-submitter` 承載：交付摘要保留策略 ＋
  `docs/` 保留 vs 歸檔清單 ＋ 執行次序；`dav-planner` §4.5 指標去同一處，避免兩份規格漂移）。

## 執行約束（repo 既有規則，唔屬驗收句）

- 改 skill（dav-planner／dav-submitter／dav-developer）→ 依 `AGENTS.md` §1.5 V03 走獨立二審
- doc-drift D1..D8 機制本身唔放寬（完成票嘅 ac/req/reconcile **一併**歸檔，保持三方一致）

## 變更歷史

| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-10-27 | 初版 | 用戶 3 條指示整理成錨點 |
