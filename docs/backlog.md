# Backlog — tree_monstor 5 條優化（Trust Mode）

> 來源：2026-09-23 用戶對話「in tree_monstor 現在你覺得什麼地方可以優化？」→「全部 #1 至 #5 都做」
> 模式：Trust Mode（deadline 2026-09-23 10:03）

---

## Backlog 清單

| ID | 主題 | 優先級 | 點數 | 狀態 | 依賴 |
|----|------|--------|------|------|------|
| TMO-001 | 清 .gitignore RSI 殘留 + 刪 .agents/tree_monstor/ 髒副本 | P0 | 1 | done (2026-09-23) | — |
| TMO-002 | install.sh 拆 lib/install/*.sh 子模組 | P1 | 5 | done (2026-09-23) | TMO-001 |
| TMO-003 | 補缺 wiki bats + 修 README badge 數字 | P2 | 3 | done (2026-09-23) | TMO-002 |
| TMO-004 | AGENTS.md §2.0/§2.6 重構 + Reviewer 二審 | P0 | 5 | done (2026-09-23) | TMO-001 |
| TMO-005 | tools/ 統一 logging（修正版：trap + 共用 log_*） | P2 | 3 | done | TMO-001 |
| TMO-006 | dav-planner AC 範本獨立化 + HTML 版本 | P1 | 8 | done | TMO-001 |
| TMO-007 | dav-planner 用戶背景收集機制（§2.7） | P1 | 8 | done | TMO-006 |
| TMO-008 | 減法：文件產出物精簡（v2.0） | P1 | 5 | done | TMO-007 |
| TMO-009 | 重結構：9 skill + AGENTS.md 任務導航 + 純文字引用 | P1 | 25 | done | TMO-008 |
| TMO-010 | docs/ 批量減法：5 檔、53KB（孤立檔 + 存量 HTML + 存量反思） | P1 | 3 | done (2026-09-26) | — |
| TMO-011 | regression-guard skill 升級：Jev Oracle PoC（M1-M4… | P1 | 8 | done (2026-09-28) | — |
| TMO-012 | M5 PoC 去 hardcode 化：fixture config + stale 限 AC + CLI 重構… | P1 | 8 | done | TMO-011 |
| TMO-013 | M3.1 Playwright Chrome driver 整合 | P2 | 5 | done | TMO-012 |
| TMO-014 | SKILL.md 整合：user-journey-as-test-spec 規範 | P1 | 3 | done | TMO-013 |
| TMO-015 | CI 整合：GitHub Actions + return code gate + branch… | P1 | 5 | done | TMO-013 |
| TMO-016 | M6 修正循環：Jev fix proposal CLI + SKILL.md Step 4 整合 | P1 | 3 | done | TMO-015 |
| TMO-017 | M6.1 LLM Relay：skill 本身 LLM 接力寫 fix 文字 | P1 | 5 | done | TMO-016 |
| TMO-018 | docs/cleanup 盤點腳本 + 套用减法 | P1 | 3 | done | TMO-017 |
| TMO-019 | M6.2 patch + re-validate 自動閉環 | P1 | 8 | done (2026-09-28) | TMO-017 |
| TMO-020 | M6.3 互動式 sandbox + flaky 驗證 + cleanup CI 定期 | P1 | 13 | done (2026-09-28) | TMO-019 |
| TMO-021 | M7 flaky→batch_report 整合 + gh pr comment | P1 | 5 | done (2026-09-28) | TMO-020 |
| TMO-022 | M8 CI matrix pipeline (多 story_id 並行) | P1 | 5 | done (2026-09-28) | TMO-021 |
| TMO-023 | 修 v2.1-jev-poc C 類探針 bug（8 紅：sandbox baseline fixture /… | P0 | 5 | done (2026-10-04) | — |
| TMO-024 | README 精簡（288→90 行）+ 導向 AGENTS.md / skills + 新增… | P2 | 3 | done (2026-10-04) | — |
| TMO-025 | 修 B 類 12 紅：pptx 文字改用 python-pptx（修靜默假成功）+ 裝 poppler + 新探針… | P1 | 5 | done (2026-10-04) | TMO-023 |
| TMO-026 | 修 A 類 12 紅：探針 retarget 到 skill 拆檔後的新家（+3 條 CJK 靜默假綠探針復活） | P1 | 5 | done (2026-10-04) | TMO-025 |
| TMO-027 | 廢棄守門：dav-planner §2.7 用戶背景收集（用戶已決策廢除）5 條探針轉負向斷言 | P2 | 3 | done (2026-10-04) | TMO-026 |
| TMO-028 | `skills/dav-wiki/SKILL.md` 151 → 129 行（V03.5 強制… | P2 | 3 | done (2026-10-04) | TMO-026 |
| TMO-029 | venv bootstrap：`PoC/requirements.txt` + setup 腳本 + CI… | P1 | 3 | done (2026-10-04) | TMO-026 |
| TMO-030 | 廢除麵包屑補齊：`docs/prd/02` 頂部加「已廢棄」狀態塊 + `docs/prd/03:104`… | P2 | 2 | done (2026-10-05) | TMO-027 |
| TMO-031 | `skills/dav-planner/SKILL.md:73` 殘留舊步驟名（「背景收集 / 最終目的」→ 現行… | P2 | 1 | done (2026-10-05) | TMO-027 |
| TMO-032 | 探針精準化：`refute_file_contains` 加檔案存在檢查（根除假綠）+ 負向斷言排除變動歷史列 +… | P2 | 3 | done (2026-10-05) | TMO-027 |
| TMO-033 | dav-wiki 子檔內容錨點：`output-structure.md` 需含… | P2 | 2 | done (2026-10-05) | TMO-028 |
| TMO-034 | 清同源死引用（指向已刪的 `docs/sop/handbook/dav-wiki-cleanup.md`）：`wik… | P2 | 1 | done (2026-10-05) | TMO-028 |
| TMO-035 | 文實矛盾對齊：`SKILL.md:97`「未裝時降級為純文字模式」vs 三支腳本 `require_tool()`… | P2 | 3 | done (2026-10-05) | TMO-028 |
| TMO-036 | 跨目錄探針覆蓋缺口：`restruct-zero-cross-read.bats` 動詞表不含… | P2 | 2 | done (2026-10-05) | TMO-028 |
| TMO-037 | 清 markdownlint 債（2026-10-05 實測 270 錯 / 127 檔；主類 MD013 201… | P2 | 8 | done (2026-10-05) | TMO-029 |
| TMO-038 | 探針強化：`poc-bootstrap.bats` ① 掃描範圍放寬到縮排（函式內 optional… | P2 | 3 | done (2026-10-05) | TMO-029 |
| TMO-039 | 首次真實 GitHub Actions 驗證（首跑 `37213235272` 全 job 紅 → 6 類真因… | P1 | 3 | done (2026-10-04) | TMO-029 |
| TMO-041 | 環境等價／「本機假綠」殘餘防線：①macOS 預設 bash 3.2 對「已宣告空陣列」做長度展開不報錯、CI… | P2 | 3 | done (2026-10-05) | TMO-039 |
| TMO-042 | 媒體探針未鎖 ffmpeg 版本 → 已修（2026-10-05）：新增… | P2 | 2 | done (2026-10-05) | TMO-039 |
| TMO-043 | 死碼清理（原：`probe_metadata()` SC2329）——擴大為系統性掃描後共 3… | P2 | 1 | done (2026-10-05) | TMO-039 |
| TMO-044 | `ci.yml` `Verify Python heredoc syntax` 恆綠假檢查 → **已換成真檢查**：新增 `scripts/ci/check-python-heredocs.sh`（抽 python3 heredoc → `ast.parse` 驗語法；未結束/語法錯/抽不到都會 rc=1），ci.yml step 改為呼叫它（全 ci.yml 已無 `\|\| true`）。順帶修好覆蓋缺口：原檢查只涵蓋 5/9 個 heredoc（漏 wiki-extract-media ×2 / wiki-merge-media / wiki-index），現為 9/9。新探針`tests/ci-heredoc-check.bats` H1-H5（含 3 種突變證明咬得住） | P2 | 2 | done (2026-10-05) | TMO-039 |
| TMO-045 | oracle 假綠的殘餘護欄（reviewer P2-B/C/D）… | P2 | 3 | done (2026-10-05) | TMO-039 |
| TMO-040 | 護欄設計邊界（Round-4 P2-2）：`POC_VENV_DIR` 指向合法的 ≥2 層絕對目錄（如… | P2 | 2 | done (2026-10-05) | TMO-029 |
| TMO-056 | 危險清單的「容器本體直接子項」缺口（TMO-040 Round-2 二審 P3-a 延伸）：現行清單列了… | P3 | 1 | done (2026-10-05) | TMO-040 |
| TMO-046 | `skills/tdd-test-writer/SKILL.md` 已 149/150 行（餘 1 行）… | P3 | 1 | done (2026-10-05) | TMO-041 |
| TMO-047 | skill 自帶探針從未被 CI 執行（round F P3-5）：`skills/dav-skill-create… | P2 | 1 | done (2026-10-05) | TMO-041 |
| TMO-048 | Gate 2 的 shellcheck 掃描面有洞（L5 量測）：原指令只列… | P2 | 2 | done (2026-10-05) | TMO-029 |
| TMO-049 | CI 沒有跑 shellcheck（Gate 2 只在開發者本機跑）：`ci.yml` 目前只有… | P2 | 2 | done (2026-10-05) | TMO-029 |
| TMO-050 | 空過測試＋檔尾換行（L7/L8 量測）：①`tests/ci-linux.bats` 的 `ci-linux:… | P2 | 2 | done (2026-10-05) | TMO-029 |
| TMO-051 | docs 相對連結沒有鎖（L9 量測）：naive 掃描 121 條相對連結，31 條解析不到，但逐條看多為… | P3 | 1 | done (2026-10-05) | TMO-029 |
| TMO-052 | CI 的 `Verify bash syntax` 步驟只 glob 硬編子集：`ci.yml` 的該步只跑… | P3 | 1 | done (2026-10-05) | TMO-029 |
| TMO-053 | secret 遮罩通則（NYH-2，2026-10-05 開票 → 2026-10-05… | P2 | 2 | done (2026-10-05) | TMO-045 |
| TMO-057 | 六支 dav-wiki 腳本的死引用：`wiki-extract-{audio,video}.sh`… | P3 | 1 | done (2026-10-05) | — |
| TMO-058 | **`wiki-media-describe.sh` real 模式假成功**（TMO-035 Round-1 二審 P1-1 揭露）→ **已修（2026-10-05）**：①real 未實作改用新碼 **`EXIT_NOTIMPL=5`**（原本借用的 4＝「必要工具缺失」語意錯：本檔根本沒工具檢查 → 一併刪除死常數）；②單檔 `process_single … \|\| exit $?`（原本 `set -uo pipefail` 無 `-e`，回傳值被 `exit 0` 蓋掉）；③批次改聚合計數（`ok`／`fail`／`truncated`，任一失敗→非零 rc，**不得**再印「✅ 批次完成」）；④順修（已揭露）：`echo > "$output"` 與 `mkdir -p "$outdir"` 原本不看 rc（寫不進去也印 `✓ wrote` ＋ ✅）→ 改用新碼 **`EXIT_WRITE=6`**；⑤探針 **AC-D19~D30**（Round-1 後補 D29＝非法 `--max-concurrency`、D30＝合法值不得誤擋）（real 單檔 rc=5 無產物／real 批次 rc≠0 且無 ✅／mock 批次仍 ✅ 回歸鎖／dry-run 不變／usage 有 5 無死 4／SKILL.md 靜態鎖／截斷 WARN／部分失敗可達 rc=6／單檔寫入失敗／output-dir 建不出來）＋突變 M1~M9 全咬住；⑥`SKILL.md` 限制表對齊（v2.2.2；Round-1 P1 處置：刪 v2.1 列回 134 行，符合「只留最近 3 條＋v2.0 錨點」）；⑦Round-1 P2-2 順修：`--max-concurrency` 限正整數（探針 AC-D29）；⑧文件數字同步（`install-reference.md` 612／615／569+43；Round-2 後每加一條探針再同步一次）。**未做**：`--max-concurrency` 被當「總處理上限」的語意 bug（另開 TMO-060，本票只把靜默丟檔變誠實 WARN）。原文：real `real_describe()`／`real_transcribe()` 印 `ERROR: real … not implemented yet` 後 `return 4`，單檔 `process_single` 回傳值沒接→最終 `exit 0`；批次 `continue` 後照樣印「✅ 批次完成」→ 零產出卻回報成功 | P2 | 2 | done (2026-10-05) | TMO-035 |
| TMO-054 | OpenRouter API key 輪替（人工項，僅用戶可執行）（NYH-1，2026-10-05 開票）：到… | P1 | 1 | ⏸️ 跳過（接受風險，2026-10-05） | — |
| TMO-055 | README 缺「本機開發前置」區塊（2026-10-05 Gate 3 紅燈事故）：新 clone 未… | P3 | 1 | done (2026-10-05) | — |
| TMO-059 | README CI badge owner 寫錯（`apple/tree_monstor`）：TMO-025… | P3 | 1 | done (2026-10-05) | — |
| TMO-060 | `--max-concurrency` 被當「總處理上限」用（TMO-058… | P3 | 3 | done (2026-10-05) | TMO-058 |
| TMO-061 | `install-reference.md` 的探針總數靠人工同步（同一票內就改過多次）(TMO-058／TMO-0… | P3 | 1 | done (2026-10-05) | TMO-060 |
| TMO-062 | 七支 dav-wiki 腳本第 2 行自述路徑過時（TMO-057 V03 二審 P2-3… | P3 | 1 | done (2026-10-05) | TMO-057 |
| TMO-063 | 新 skill：`pptx-slim`（PPTX 就地減重）（2026-10-05 用戶委託：「可以把上面的能力… | P2 | 8 | done (2026-10-05) | — |
| TMO-064 | pptx-slim 只減影片、圖片 139 MiB 全未動（2026-10-05 TMO-063 收尾自省揭露）… | P3 | 3 | done (2026-10-05) | TMO-063 |
| TMO-065 | 突變測試是一次性人工動作（2026-10-05 TMO-063／064 收尾揭露）→ 已完成：pptx-slim… | P3 | 3 | done (2026-10-05) | TMO-063, TMO-064 |
| TMO-066 | 其他 skill 的護欄沒有 mutant（TMO-065 限制①自陳）→ 已完成：把兩個 skill… | P2 | 3 | done (2026-10-05) | TMO-065 |
| TMO-068 | dav-trust 缺「中斷續跑 / 用戶叫停」機制（2026-10-23 dav-trust v2.3 交付報告… | P1 | 3 | done (2026-10-23) | — |
| TMO-069 | install.sh 不支援 Qoder（2026-10-23 用戶委託：「install.sh 可以為… | P1 | 3 | done (2026-10-23) | — |
| TMO-070 | M6.3-c／M6.3-e 間歇紅的真因是 process-randomized `hash()`（TMO-066… | P1 | 3 | done (2026-10-23 實作，2026-10-24 收尾) | TMO-066 |
| TMO-071 | 需求錨點檔（`docs/req/<US-ID>-requirement.md`） — 解決「用戶原話在多文件… | P1 | 3 | done (2026-10-26) | — |
| TMO-072 | 需求對帳機制（新 skill `dav-reconciler`） —… | P1 | 5 | done (2026-10-26) | TMO-071 |
| TMO-073 | 文件漂移探針（8 類字面對帳 D1..D8） — 解決「同一件事多份文件各說各話」：新增可攜 CI 腳本… | P2 | 5 | done (2026-10-26) | TMO-071 |
| TMO-074 | bats 1.14 在 bash 3.2（macOS 預設 /bin/bash）+ UTF-8 locale… | P1 | 3 | done (2026-10-26) | — |
| TMO-067 | 全域 SOP 未登錄 trust 這條第三路徑（2026-10-05 dav-trust v2.3 P0… | P1 | 3 | done (2026-10-23) | — |
| TMO-075 | 砍掉框架 meta 自我管理層（第一刀）：刪 meta 探針與歷史產物、補 D4/D8 守護 | P1 | 8 | done (2026-10-26) | — |
| TMO-076 | SOP 移出 AGENTS.md：只留萬事原則；Gate 定義改由各自的 skill 承載 | P1 | 5 | done (2026-10-26) | TMO-075 |
| TMO-077 | 文件數字漂移無探針守護：live 文件的自述數字會過期，改用探針重算比對 | P2 | 5 | done (2026-10-26) | TMO-076 |

> **本檔現況（2026-10-26）**：上表 77 列**全部已完成或已跳過**——沒有未決列。
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
> 注：`tests/backlog-trust-mode-completion.bats:48`（BACKLOG-005）禁止 trust mode 期間的票停在 `pending`；本表新票一律用 `todo`，不修改該探針。
> 相容舊值（漂移檢查腳本的 `STATUS_VALUE` 一併接受，僅為相容存量文件，不新增語意）：`pending` / `in_progress` / `deferred` / `cancelled` / `進行中` / `待辦`。
