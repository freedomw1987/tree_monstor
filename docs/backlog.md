# Backlog — tree_monstor 5 條優化（Trust Mode）

> 來源：2026-09-23 用戶對話「in tree_monstor 現在你覺得什麼地方可以優化？」→「全部 #1 至 #5 都做」
> 模式：Trust Mode（deadline 2026-09-23 10:03）

---

## Backlog 清單

| ID | 主題 | 優先級 | 點數 | 狀態 | 依賴 |
|----|------|--------|------|------|------|
| TMO-054 | OpenRouter API key 輪替（人工項，僅用戶可執行）（NYH-1，2026-10-05 開票）：到… | P1 | 1 | ⏸️ 跳過（接受風險，2026-10-05） | — |
| TMO-089 | **清 flaky ＋ 存量文件統一術語**（2026-10-27 用戶決策「做您建議的 3-> 1」）：① `tests/install-qoder.bats` QODER-30 曾偶發紅（一次全套閃紅；之後 3 次全套 ＋ 3 次單跑全綠；該次閘跑嗰陣實作者正喺同一 repo 改檔 → 最可能係工作樹被改動）→ **已加失敗時印安裝器輸出**（可診斷）＋ 記為待觀察，未當真 bug 改；② **量度後**先定範圍：live 文件「別名」寫法共 791 處，但大部份係同一概念嘅短形（錨點 131／子檔 75／trust 242⋯）→ **唔做大範圍改寫**；只統一**會指錯嘢**嘅 34 處（驗收標準→驗收條件、子關卡→子閘、mutation row→mutant row、成熟度→需求成熟度），而「Gate 語意嘅完成條件（閘）」「docs/README.md 導航結構」（另一概念）唔改；③ `docs/glossary_list.md` 詞典分兩類：**同義寫法**（可接受短形）＋ **勿用寫法**（9 條 ＋ 點解會指錯）。錨點 `docs/req/TMO-089-requirement.md`；對帳 `docs/reconcile/TMO-089-reconcile.md` | P2 | 2 | doing (2026-10-27) | TMO-088 |
| TMO-091 | **docs 減磅 ＋ 閘提速（`--changed`）**（2026-10-27 用戶 3 條指示）：① `backlog.md` **只留未完成**（完成 row 移出 ＋ 記錄去交付摘要／需求錨點／git history），並喺**會改 backlog 嘅 skill** 寫明規範（`dav-planner` §4.5 ＋ `dav-submitter` Step 5）；② `docs/` 減磅：完成 US 嘅 ac／req／reconcile **一併**歸檔（保持 doc-drift D1/D6/D7 一致）、`prd/`（已完成專案）歸檔、`deliverable/` 只留最近一次交付（連帶引用鏈，因 D8 fail-closed 要求窗內有件可對帳）、SOP／CI／工具／術語表／設計文件 **全部保留**（ac 19→7、req 15→3、reconcile 14→3、deliverable 3→1、prd 2→0）；③ PoC 依賴嘅 AC fixture 搬入 `skills/dav-jev-oracle/PoC/fixtures/ac/` → **skill 自足**（目標專案都跑得）；④ `check-all.sh` 加 `--changed[=<base>]`：只跑受改動影響嘅探針 ＋ 收窄 mutant（閘 4 分 10 秒 → 改動範圍內 ~20-40 秒）。⚠️ 一律先 commit 入 git history 再刪（可追溯）。錨點 `docs/req/TMO-091-requirement.md`；對帳 `docs/reconcile/TMO-091-reconcile.md` | P1 | 5 | doing (2026-10-27) | TMO-090 |
| TMO-092 | **拆 Jev Oracle 做獨立 skill `dav-jev-oracle`**（2026-10-27 用戶「好，做 ②」）：`dav-developer` context **2,098 → 1,208 行（−42%；同口徑 2,678 → 1,208 ＝ −55%）**；`dav-jev-oracle` 自足（主檔 ＋ jev-oracle.md ＋ examples.md ＋ api-contract.md ＋ output-format.md ＋ `PoC/` 48 檔 ＋ `tests/` 4 支探針）；路徑大搬遷（CI／mutant 表／探針／docs／.gitignore）全部更新；新增 `dav-developer/tests/skill-contract.bats`（7 條結構契約）＋ `ENV-EQ-21`（frontmatter 合法性）；v2.8 規則改成 **baseline ratchet**（每個 skill 各自上限 ＋ 1,500 硬上限；原本「全部 ≤700」喺內容量面前冇人跟得到 = 假規則）。⚠️ 同場修好 8 個 skill 嘅 frontmatter 斷裂（description 跨行 → YAML 壞 → skill 讀唔到）。錨點 `docs/req/TMO-092-requirement.md`；對帳 `docs/reconcile/TMO-092-reconcile.md` | P1 | 5 | done (2026-10-28) | TMO-091 |

> **本檔現況（2026-10-27，docs 減磅後）**：本表**只保留未完成**（todo／doing／⏸️）嘅 row；
> 已完成嘅 row 已移出（記錄去交付摘要 ＋ 需求錨點 ＋ git history；規則見 `skills/dav-planner/backlog-rules.md` §4.5）。

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
