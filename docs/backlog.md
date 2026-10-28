# Backlog — tree_monstor 未完成項

> 來源：2026-09-23 用戶對話「in tree_monstor 現在你覺得什麼地方可以優化？」→「全部 #1 至 #5 都做」
> 模式：Trust Mode（deadline 2026-09-23 10:03）

---

## Backlog 清單

| ID | 主題 | 優先級 | 點數 | 狀態 | 依賴 |
|----|------|--------|------|------|------|
| TMO-054 | **OpenRouter API key 輪替（人工項，僅用戶可執行）**（NYH-1，2026-10-05 開票）：到 OpenRouter 撤銷舊 key、產生新 key 並更新本機 key 來源（PoC `.env` 檔，gitignore 內；或 `~/.zshrc` 環境變數）；完成後由 Agent 複驗 sha256 已變＋新值未出現在任何被追蹤檔／本輪 diff。**Agent 無法代為撤銷**（見 NYH-1）。**結案（2026-10-05）**：用戶改以系統環境變數（`~/.zshrc`）提供 key；Agent 比對該值 sha256 與 `.env` **完全相同**＝仍為原洩漏舊 key、**未輪替**。用戶決策＝**接受風險、不輪替、保留現狀**（舊 key 續用；兩處並存），故本票不處理。 | P1 | 1 | blocked (2026-10-05 接受風險；⏸️ 跳過 —— 只有用戶可執行) | — |

> **本檔現況（2026-10-28 收埋 TMO-089／TMO-091 後）**：本表**只保留未完成**（todo／doing／⏸️）嘅 row；
> 已完成嘅 row 已移出（記錄去交付摘要 ＋ 需求錨點 ＋ git history；規則見 `skills/dav-planner/backlog-rules.md` §4.5）。
> 收埋記錄：`docs/deliverable/2026-10-28-tmo-089-091-backlog-close.md`。

## 欄位說明

| 欄位 | 意義 |
|------|------|
| ID | Backlog 票號（TMO-xxx）；下游工具以此為 key |
| 主題 | 一行摘要（詳細設計見 git history）|
| 優先級 | P0 / P1 / P2 / P3 |
| 點數 | Story Point |
| 狀態 | `todo` / `doing (日期)` / `done (YYYY-MM-DD)` / `⏸️ 跳過` 等（**完整定義見下方「狀態定義」**）；**漂移檢查 D1/D7 依此欄判定** |
| 依賴 | 前置票號 |

> **狀態定義**（單一來源）：`todo` = 已描述、尚未開工（TMO-026 之後的新票，**非** trust mode 未結項）；`doing (日期)` = 進行中；`done (日期)` =
> 已交付；`blocked (原因)` = 被外部條件卡住；`待決（NYH-n）` = 決策已上呈 `docs/need-you-help.md` 第 n 項，等用戶裁決（round F P2-5 補定義）。
> 注：2026-10-27 減法：原本禁「trust mode 期間票停喺 `pending`」嘅 `tests/backlog-trust-mode-completion.bats` 已刪 → 本表新票一律用 `todo`（靠人手自律）。
> 相容舊值（漂移檢查腳本的 `STATUS_VALUE` 一併接受，僅為相容存量文件，不新增語意）：`pending` / `in_progress` / `deferred` / `cancelled` / `進行中` / `待辦`。
