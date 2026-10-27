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
| TMO-078 | PNA-4 掃描器兩項技術債：①「縮排嘅 `}` 算唔算 test body 最後一句」——原版 glob 要求 `}` 喺**行首**，縮排嘅 `}` 會被當 violation（latent 假紅）；**唔可以用「剝前導空白」修**（會令真違規變 pass = 條件放寬 = 假綠），正解係**行首 `}` = test body 收尾**嘅 forward-scan 代理（V03 二審裁定：唔使真係計 brace depth，只需「行首 `}`」呢個原判準本身已在用嘅假設；屬語意變更 → 須另走 V03 + 另配 canary；殘餘邊界見 TMO-079）②`tests/helpers/probe-scan.bash` 嘅 `probe_strip_comment`／`probe_code_lines` 自 PNA-4 改用單 awk 行程後已無呼叫點（邏輯已複製入 `probe_find_standalone_assertions`）→ 清死碼 | P2 | 3 | done (2026-10-26) | TMO-074 |
| TMO-079 | PNA-4 規則⑦ 嘅殘餘邊界：行首 `}` 之後如果仲有 code（例如 `} \|\| {`）會被豁免。V03 二審裁定保留原語意（超集性質優先），理由：行首 `}` 喺 .bats 入面**必然**係關 test body，而 `} \|\| {` 喺 function 定義位置係**語法錯誤** → 實際唔可能出現。但若日後有人寫出非標準縮排嘅 .bats，呢個洞可能變成真·假綠。⚠️ 同一個「行首 `}` = test body 收尾」假設仲有第二個面：**行首 `}` 其實亦可能係 `setup()`／`teardown()` 函數嘅收尾**（唔一定係 test body）→ 呢個更實際嘅假綠面亦未記錄。**已做（2026-10-26）**：規則⑦ 改用**頂層區塊 kind 明確判定**——掃描器逐行追蹤 column-0 嘅 `{` / `}`，記低每行所屬區塊係 `test`（`@test` body）／`func`（setup/teardown/helper）／`other`；豁免而家要求「所屬區塊**確實係 `@test` body**」＋「掃描到嗰個區塊嘅**真實收尾行**」。→ 函式 body 嘅斷言**唔再**被「行首 `}`」意外豁免（呢個就係本票記低嘅更實際假綠面）。方向係**收緊**（豁免更少 → 報得更多）→ 唔會製造假綠。⚠️ 對真實 corpus **零影響**：全 corpus 依賴規則⑦ 豁免嘅斷言共 **9 條**，全部喺 `@test` body 內（setup/teardown/helper 內 0 條）→ 唔會假紅。canary：`PNA-4d`（函式 body 必須照報／`} \|\| {` 收尾必須唔報／對照組／裸 column-0 群組必須照報）。⚠️ **同時更正咗一個被實測推翻嘅前提**：原 PNA-4 註解寫「bats 裡獨立的 `[[ ]]` 失敗**不會中止 test body**」→ 重新量測（bats 1.14.0 同 1.11.1 嘅 `bats-exec-test` 都係 `set -eET`；bash 3.2／5.3 一致）證實**會中止** → PNA-4 現時定位為**風格／可讀性守門**（見 probe-name-ascii.bats 註解）。 | P2 | 2 | done (2026-10-26) | TMO-078 |
| TMO-080 | PNA-4c canary 欠一個方向：「之後**搵唔到**行首 `}`（例如斷言喺檔尾、冇收尾 `}`）→ 必須**照報**」。而家若日後有人改成「行到 EOF 就豁免」，PNA-4b／PNA-4c **都唔會紅** → 守門失效。**已做（2026-10-26）**：PNA-4c fixture 加**第 5 案**（`@test` body **冇收尾**、斷言喺檔尾）→ 必須**照報**；期望字串由 1 條改成 **2 條**（案例 A 行 4 ＋ 案例 E 行 20）。另加 **mutant `PNA-M3`**（`found_body_close = 0` → `found_body_close = (i >= n)` ＝「斷言喺**檔案最後一行**就豁免（案例 E 就係咁）」）→ 證明新 canary 真係咬得住（實測：mutant 下 PNA-4c 紅，死因係**案例 E 消失**嘅語意差，唔係 parse error）。全表 **58 支全部死亡**。 | P2 | 2 | done (2026-10-26) | TMO-078 |
| TMO-082 | Context 瘦身刀（A）＋ 框架體重守門（D）：支援檔（SKILL.md 以外嘅 skill .md）支援檔 7,950 → 5,743 行（−27.8%）；連主檔計嘅 context 總量 9,619 → 7,413（−22.9%；口徑：13 個 skill 合計、git tracked、唔含 CHANGELOG）＋ 新增 `scripts/ci/check-framework-weight.py`（context 預算／指標完整性／框架／產品行數比 ratchet）＋ `docs/ci/framework-weight.json` ＋ `tests/framework-weight.bats`（16 支，每種壞情境都有實測證明會紅）＋ CI 接線。錨點 `docs/req/TMO-082-requirement.md`；對帳 `docs/reconcile/TMO-082-reconcile.md` | P1 | 8 | done (2026-10-26) | TMO-075 |
| TMO-083 | Context 瘦身二輪 ＋ 產物線存量清理：9 支支援檔（8 個 skill）二輪瘦身（context 總量 7,413 → 7,063 行，−4.7%）＋ 刪 3 支零依賴嘅歷史交付摘要 ＋ 刪 7 支存量 `docs/ac/*.html`（保留 `US-101.html`）＋ `docs/ci/drift-whitelist.txt` 加 9 筆附理由嘅 D4 豁免＋ 被改動嘅 8 個 skill 嘅 CHANGELOG／主檔變動歷史同步。⚠️ 第二輪邊際收益遠低於第一輪（剩低嘅支援檔多數係格式範本，冇重複可剪）。錨點 `docs/req/TMO-083-requirement.md`；對帳 `docs/reconcile/TMO-083-reconcile.md` | P2 | 5 | done (2026-10-26) | TMO-082 |
| TMO-081 | PNA-4 存廢評估：PNA-4 嘅立論前提已被實測推翻（bats ≥1.11 嘅 `bats-exec-test` 用 `set -eET` → 獨立 `[[ ]]` 失敗**會**中止 test body）→ PNA-4 由「防假綠」降級為「風格／診斷品質守門」。**以實測數據評估**（唔用推測）：corpus 247 條獨立斷言（236 已 fail-fast 風格／9 靠規則⑦ 豁免／2 靠規則④⑥）｜PNA-4 現行 violations = **0**｜掃描器 376 行（刪規則可縮 177 行）｜mutant 58 → 55｜⚠️ repo 內**真係有 3 處 `set +e`**（`tests/v2.1-jev-poc.bats:153,348,366`）→ 該窗口內嘅裸斷言**真係會靜默**（唔係假設性）。方案：(A) 保留現狀（前提已更正，成本最低）(B) 刪規則但留 236 條改寫（失去「唔會回潮」保證）(C) **收窄成「只守 `set +e` 窗口內嘅裸斷言」**（理據最誠實：守住唯一真·會假綠嘅場景，且 repo 已在用該手法）(D) 全刪＋還原 181 條改寫（**唔建議**：拎走 `FAIL: <file>:<line>` 診斷訊息＋diff 巨大）。**已做（2026-10-26）**：評估結論＝**方案 A（保留現狀，唔改任何嘢）**。⚠️ 建議由初稿嘅 C **改為 A**：可行性檢查發現 ①`set +e` 係 bash 嘅 **shell 全域**開關（實測：function 內 `set +e` → 呼叫者隨後嘅 `false` 都唔會中止）→ 窗口結束點**無法靜態判定** → C 要嘛**漏報**（假綠方向）→ 違反 repo 核心原則 ②C **唔係簡化**（成本高於現行：同一套 ②④⑤⑥⑦ ＋ 再加 `set +e` 作用域追蹤）③**A ⊃ C**（現行規則已守住 `set +e` 窗口）。B／D 明確唔建議（失去對 `set +e` 窗口嘅保護；D 額外拎走 `FAIL: <file>:<line>` 診斷訊息）。**本票無實作改動** → 唔觸發 V03。附帶產出兩條被記錄嘅知識：PNA-4 守門價值**唔係零**（repo 已在用 `set +e`，該窗口內裸斷言真·會靜默）＋ 但「只守 `set +e` 窗口」**靜態不可靠** → 將來若想收窄，必須先有可靠嘅作用域機制。對帳表：`docs/reconcile/TMO-081-reconcile.md` | P2 | 3 | done (2026-10-26) | TMO-079 |
| TMO-084 | **CI 降級為「偵測器」＋ 落地本機等價閘**（2026-10-27 用戶決策）：本 repo 係平時自用嘅技能庫 → CI **唔再係完成條件**、**刻意唔開** branch protection（CI 紅都 merge 得，係有意識嘅選擇而唔係「未設定」）→ 閘改為**本機**：探針全綠 ＋ lint 0 issue ＋ mutant 全死 ＋ Reviewer 二審。新增 `scripts/check-all.sh`（13 步，2026-10-27 減法後 11 步；ci.yml 嘅 step 名／markdownlint glob／doc-drift `--from-date` 全部**執行時從 ci.yml 抽** → 唔會同 CI 漂移）＋ `scripts/hooks/pre-push.sh` ＋ `scripts/install-local-hooks.sh` ＋ `tests/local-ci-guard.bats`（LC-1..LC-9：**雙向**對齊 ci.yml ↔ 本機 runner ＋ 行為自證）＋ mutant `LC-M1`（失敗匯總唔可以吞）→ mutant 表 58 → 59。**閘放寬 → 依 V03 走 Reviewer 二審**（見交付對話）。⚠️ 代價已記錄：CI 捉到嘅跨 OS／跨版本差異（shellcheck apt 0.9 vs 本機 0.11、macOS runner bash 3.2 令 31 條測試被靜默丟棄、clean clone 缺未版控 fixture 令 34 條紅）而家**只係通知、唔阻** → 靠本機閘守住自己嗰邊。**＋ regression-guard 專屬 CI 完全改本機跑**（2026-10-27 用戶補充決策「regression-guard 的 ci 在本地跑都得，不用在 github 上跑」）：刪 `.github/workflows/regression-guard-jev-poc.yml` ＋ 新增 `skills/regression-guard/PoC/run_ci.sh`（`probes`／`pipeline`／`matrix`／`cleanup-scan`；綠 0／黃 2／紅 1／錯 3）＋ 探針改寫（CI-a..CI-f、CLEAN-CI-a..c、M8-a..d＋M8-f）＋ mutant `RG-CI-M1`（表 59 → 60；其後 TMO-085 減法再 → 49）。⚠️ 代價：cleanup-scan 冇自動每週跑（原本係 workflow 嘅 cron job）→ 自己排程或人手跑 | P1 | 5 | done (2026-10-27) | TMO-015 |
| TMO-085 | **測試體系減法 ＋ 探針 skill-local 化 ＋ 唔記歷史**（2026-10-27 用戶 5 條決策）：① 探針只保留真 python／shell 功能測試（刪 19 支「測文件」探針 ＋ 2 支舊 skill-local 探針；連帶刪死碼工具 `check-framework-weight.py`／`check-skill-size.sh`／`docs/ci/framework-weight.json`、mutant 11 列（RG-M4 改指向 skill-local 探針後補回）、CI／本機閘步驟 → **唔留死引用**）② 「文檔行數限制」寫入 `dav-skill-creater` 規範（主檔 ≤150／子檔 ≤300／context ≤700；取代機械守門）③ 全部 `CHANGELOG.md`（13 skill ＋ handbook）刪走、引用清零 ④ skill 主檔唔寫變動歷史（「任務導航」5 段 → 4 段）⑤ skill 相關探針搬入 `skills/<name>/tests/` ＋ 新增 `scripts/test-skill.sh`（淨跑單一 skill）。mutant 表 60 → 49（47 行為鎖 ＋ 2 文件／資料契約鎖）。⚠️ 代價已記錄：文件類規則（行數／結構／命名）冇機械守門 → 改由規範（agent 自律）承擔。錨點 `docs/req/TMO-085-requirement.md`；對帳 `docs/reconcile/TMO-085-reconcile.md` | P1 | 5 | done (2026-10-27) | TMO-084 |
| TMO-086 | **dav-planner 加「業務邏輯與依賴」提問維度**（2026-10-27 用戶指示）：`reference.md` §3 補充維度加第 6 條「業務邏輯與依賴」——含**何時必問**（有計算/規則、依賴其他模組或外部系統、US 之間有先後次序）＋**點樣問**（V01 一題一輪／V02 選項＋⭐ 推薦；建議最後問）＋**答案寫落邊**（業務規則 → AC 條款 ＋ Backlog 詳細段「業務規則」行；依賴 → Backlog「依賴」欄 ＋ 詳細段「依賴」行）。同時（依 dav-skill-creater v2.3 M-Step 2）清埋規範偏差：§3 名叫「7 個維度」但實際列咗 9 條（核心 4 ＋ 補充 5），而個「7」散落 4 處 → **改成唔寫總數**（加維度唔使再改 4 處名稱）；成熟度「涵蓋率」改按「觸發咗嘅補充維度」計；`backlog-rules.md` AC 詳細段範本加「**業務規則**」行 ＋ `examples/backlog.md` 示範同步。錨點 `docs/req/TMO-086-requirement.md`；對帳 `docs/reconcile/TMO-086-reconcile.md` | P2 | 2 | done (2026-10-27) | TMO-085 |
| TMO-087 | **dav-planner 產出專案術語表 ＋ 跨階段一致用語**（2026-10-27 用戶指示）：收集完用戶需求後整理一份專案層 `docs/glossary_list.md` —— **A-Z 排序**、**領域／專案專屬**（唔收通用詞）、**簡潔定義**（每條一句 ≤40 字）、**獨立頁**（唔塞入 SKILL.md，避免每個 skill 觸發都帶 context 成本）。規格寫入 `dav-planner/backlog-rules.md` §4.9（產出條件 ≥3 條先產、收錄標準、格式範本、排序規則、維護規則：其他階段發現新術語要插入同一張表、改名要同步引用文件）；`dav-planner/SKILL.md` 新增 **Step 3.5：產出術語表**（喺維度展開之後、寫 Backlog 之前 → Backlog/AC 天生用同一套術語）＋ TL;DR 必產出物 ＋ 規則表 ＋ 交叉引用；`dav-designer`／`dev-checker-loop`／`dav-submitter` 各加一條「術語一致」規則（專案層有術語表 → 一律用入面嘅術語，唔好用同義詞）；`docs/sop/handbook/2.1-planning.md` Plan Gate 產出物同步。目的：各階段同用戶用同一套詞語 → 減少理解落差 ＋ 令 LLM 唔使每階段重新對齊用語。錨點 `docs/req/TMO-087-requirement.md`；對帳 `docs/reconcile/TMO-087-reconcile.md` | P2 | 3 | done (2026-10-27) | TMO-086 |
| TMO-088 | **本 repo 套用自己：產出 `docs/glossary_list.md`**（2026-10-27 用戶決策，選項 1）：按 TMO-087 寫落嘅規格（`dav-planner/backlog-rules.md` §4.9）為本 repo 產出一份 A-Z 術語表 —— **35 條** tree_monstor 框架專屬術語（探針／mutant／閘／模組／需求錨點／對帳／成熟度⋯⋯）、每條一句 ≤40 字、含「別名」欄（統一用術語欄）；`README.md` ＋ `CONTRIBUTING.md` 接線（用呢套詞語、新術語 A-Z 插入同一張表）。**目的**：規格喺真實專案行一次（最低成本驗證）＋ 令用戶同 LLM 喺呢個 repo 都用同一套詞語。⚠️ 存量文件嘅舊寫法未逐份改（留待後續票，避免大 diff）。錨點 `docs/req/TMO-088-requirement.md`；對帳 `docs/reconcile/TMO-088-reconcile.md` | P2 | 2 | done (2026-10-27) | TMO-087 |

> **本檔現況（2026-10-27，TMO-088 收尾後）**：上表 88 列 —— **88 列全部已有結論**
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
