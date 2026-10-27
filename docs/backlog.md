# Backlog — tree_monstor 5 條優化（Trust Mode）

> 來源：2026-09-23 用戶對話「in tree_monstor 現在你覺得什麼地方可以優化？」→「全部 #1 至 #5 都做」
> 模式：Trust Mode（deadline 2026-09-23 10:03）

---

## Backlog 清單

| ID | 主題 | 優先級 | 點數 | 狀態 | 依賴 |
|----|------|--------|------|------|------|
| TMO-044 | `ci.yml` `Verify Python heredoc syntax` 恆綠假檢查 → **已換成真檢查**：新增 `scripts/ci/check-python-heredocs.sh`（抽 python3 heredoc → `ast.parse` 驗語法；未結束/語法錯/抽不到都會 rc=1），ci.yml step 改為呼叫它（全 ci.yml 已無 `\|\| true`）。順帶修好覆蓋缺口：原檢查只涵蓋 5/9 個 heredoc（漏 wiki-extract-media ×2 / wiki-merge-media / wiki-index），現為 9/9。新探針`tests/ci-heredoc-check.bats` H1-H5（含 3 種突變證明咬得住） | P2 | 2 | done (2026-10-05) | TMO-039 |
| TMO-058 | **`wiki-media-describe.sh` real 模式假成功**（TMO-035 Round-1 二審 P1-1 揭露）→ **已修（2026-10-05）**：①real 未實作改用新碼 **`EXIT_NOTIMPL=5`**（原本借用的 4＝「必要工具缺失」語意錯：本檔根本沒工具檢查 → 一併刪除死常數）；②單檔 `process_single … \|\| exit $?`（原本 `set -uo pipefail` 無 `-e`，回傳值被 `exit 0` 蓋掉）；③批次改聚合計數（`ok`／`fail`／`truncated`，任一失敗→非零 rc，**不得**再印「✅ 批次完成」）；④順修（已揭露）：`echo > "$output"` 與 `mkdir -p "$outdir"` 原本不看 rc（寫不進去也印 `✓ wrote` ＋ ✅）→ 改用新碼 **`EXIT_WRITE=6`**；⑤探針 **AC-D19~D30**（Round-1 後補 D29＝非法 `--max-concurrency`、D30＝合法值不得誤擋）（real 單檔 rc=5 無產物／real 批次 rc≠0 且無 ✅／mock 批次仍 ✅ 回歸鎖／dry-run 不變／usage 有 5 無死 4／SKILL.md 靜態鎖／截斷 WARN／部分失敗可達 rc=6／單檔寫入失敗／output-dir 建不出來）＋突變 M1~M9 全咬住；⑥`SKILL.md` 限制表對齊（v2.2.2；Round-1 P1 處置：刪 v2.1 列回 134 行，符合「只留最近 3 條＋v2.0 錨點」）；⑦Round-1 P2-2 順修：`--max-concurrency` 限正整數（探針 AC-D29）；⑧文件數字同步（`install-reference.md` 612／615／569+43；Round-2 後每加一條探針再同步一次）。**未做**：`--max-concurrency` 被當「總處理上限」的語意 bug（另開 TMO-060，本票只把靜默丟檔變誠實 WARN）。原文：real `real_describe()`／`real_transcribe()` 印 `ERROR: real … not implemented yet` 後 `return 4`，單檔 `process_single` 回傳值沒接→最終 `exit 0`；批次 `continue` 後照樣印「✅ 批次完成」→ 零產出卻回報成功 | P2 | 2 | done (2026-10-05) | TMO-035 |
| TMO-054 | OpenRouter API key 輪替（人工項，僅用戶可執行）（NYH-1，2026-10-05 開票）：到… | P1 | 1 | ⏸️ 跳過（接受風險，2026-10-05） | — |
| TMO-079 | PNA-4 規則⑦ 嘅殘餘邊界：行首 `}` 之後如果仲有 code（例如 `} \|\| {`）會被豁免。V03 二審裁定保留原語意（超集性質優先），理由：行首 `}` 喺 .bats 入面**必然**係關 test body，而 `} \|\| {` 喺 function 定義位置係**語法錯誤** → 實際唔可能出現。但若日後有人寫出非標準縮排嘅 .bats，呢個洞可能變成真·假綠。⚠️ 同一個「行首 `}` = test body 收尾」假設仲有第二個面：**行首 `}` 其實亦可能係 `setup()`／`teardown()` 函數嘅收尾**（唔一定係 test body）→ 呢個更實際嘅假綠面亦未記錄。**已做（2026-10-26）**：規則⑦ 改用**頂層區塊 kind 明確判定**——掃描器逐行追蹤 column-0 嘅 `{` / `}`，記低每行所屬區塊係 `test`（`@test` body）／`func`（setup/teardown/helper）／`other`；豁免而家要求「所屬區塊**確實係 `@test` body**」＋「掃描到嗰個區塊嘅**真實收尾行**」。→ 函式 body 嘅斷言**唔再**被「行首 `}`」意外豁免（呢個就係本票記低嘅更實際假綠面）。方向係**收緊**（豁免更少 → 報得更多）→ 唔會製造假綠。⚠️ 對真實 corpus **零影響**：全 corpus 依賴規則⑦ 豁免嘅斷言共 **9 條**，全部喺 `@test` body 內（setup/teardown/helper 內 0 條）→ 唔會假紅。canary：`PNA-4d`（函式 body 必須照報／`} \|\| {` 收尾必須唔報／對照組／裸 column-0 群組必須照報）。⚠️ **同時更正咗一個被實測推翻嘅前提**：原 PNA-4 註解寫「bats 裡獨立的 `[[ ]]` 失敗**不會中止 test body**」→ 重新量測（bats 1.14.0 同 1.11.1 嘅 `bats-exec-test` 都係 `set -eET`；bash 3.2／5.3 一致）證實**會中止** → PNA-4 現時定位為**風格／可讀性守門**（見 probe-name-ascii.bats 註解）。 | P2 | 2 | done (2026-10-26) | TMO-078 |
| TMO-089 | **清 flaky ＋ 存量文件統一術語**（2026-10-27 用戶決策「做您建議的 3-> 1」）：① `tests/install-qoder.bats` QODER-30 曾偶發紅（一次全套閃紅；之後 3 次全套 ＋ 3 次單跑全綠；該次閘跑嗰陣實作者正喺同一 repo 改檔 → 最可能係工作樹被改動）→ **已加失敗時印安裝器輸出**（可診斷）＋ 記為待觀察，未當真 bug 改；② **量度後**先定範圍：live 文件「別名」寫法共 791 處，但大部份係同一概念嘅短形（錨點 131／子檔 75／trust 242⋯）→ **唔做大範圍改寫**；只統一**會指錯嘢**嘅 34 處（驗收標準→驗收條件、子關卡→子閘、mutation row→mutant row、成熟度→需求成熟度），而「Gate 語意嘅完成條件（閘）」「docs/README.md 導航結構」（另一概念）唔改；③ `docs/glossary_list.md` 詞典分兩類：**同義寫法**（可接受短形）＋ **勿用寫法**（9 條 ＋ 點解會指錯）。錨點 `docs/req/TMO-089-requirement.md`；對帳 `docs/reconcile/TMO-089-reconcile.md` | P2 | 2 | doing (2026-10-27) | TMO-088 |

> **本檔現況（2026-10-27，TMO-090 收尾後）**：上表 90 列 —— **89 列已有結論 ＋ 1 列進行中（TMO-089）**
> （**78 列已完成／已跳過** ＋ **3 列 done（TMO-079／TMO-080／TMO-081，2026-10-26）** ＋ **1 列 done（TMO-082，2026-10-26）**
> ＋ **1 列 done（TMO-083，2026-10-26）** ＋ **2 列 done（TMO-084／TMO-085，2026-10-27）**）＝ **全部 85 列已有結論**。
> 每一列的「詳細」段已移除（純歷史記錄，完整內容見 git history：
> `git log -p -- docs/backlog.md`）。要查某張票的原始設計，請用該 TMO ID 查 git。
>
> **主題欄是歷史記錄**：它記的是「當時做了什麼」，因此可能提到**其後已刪除**的檔案
> （例如 TMO-030 提到的 `docs/prd/02` 在 2026-10-26 減法中已被刪）。這不是死引用錯誤，
> 而是歷史的忠實記錄；要看當時脈絡請查 git history。

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
