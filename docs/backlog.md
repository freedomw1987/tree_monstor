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
| TMO-010 | docs/ 批量減法：5 檔、53KB（孤立檔 + 存量 HTML + 存量反思）| P1 | 3 | done (2026-09-26) | — |
| TMO-011 | regression-guard skill 升級：Jev Oracle PoC（M1-M4 feat-jev-regression）| P1 | 8 | done (2026-09-28) | — |
| TMO-012 | M5 PoC 去 hardcode 化：fixture config + stale 限 AC + CLI 重構 + bats 探針 | P1 | 8 | done | TMO-011 |
| TMO-013 | M3.1 Playwright Chrome driver 整合 | P2 | 5 | done | TMO-012 |
| TMO-014 | SKILL.md 整合：user-journey-as-test-spec 規範 | P1 | 3 | done | TMO-013 |
| TMO-015 | CI 整合：GitHub Actions + return code gate + branch protection SOP | P1 | 5 | done | TMO-013 |
| TMO-016 | M6 修正循環：Jev fix proposal CLI + SKILL.md Step 4 整合 | P1 | 3 | done | TMO-015 |
| TMO-017 | M6.1 LLM Relay：skill 本身 LLM 接力寫 fix 文字 | P1 | 5 | done | TMO-016 |
| TMO-018 | docs/cleanup 盤點腳本 + 套用减法 | P1 | 3 | done | TMO-017 |
| TMO-019 | M6.2 patch + re-validate 自動閉環 | P1 | 8 | done (2026-09-28) | TMO-017 |
| TMO-020 | M6.3 互動式 sandbox + flaky 驗證 + cleanup CI 定期 | P1 | 13 | done (2026-09-28) | TMO-019 |
| TMO-021 | M7 flaky→batch_report 整合 + gh pr comment | P1 | 5 | done (2026-09-28) | TMO-020 |
| TMO-022 | M8 CI matrix pipeline (多 story_id 並行) | P1 | 5 | done (2026-09-28) | TMO-021 |
| TMO-023 | 修 v2.1-jev-poc C 類探針 bug（8 紅：sandbox baseline fixture / flaky batch fixture / 缺 `run` / `ls` dotfile 假斷言）| P0 | 5 | done (2026-10-04) | — |
| TMO-024 | README 精簡（288→90 行）+ 導向 AGENTS.md / skills + 新增 docs/install-reference.md | P2 | 3 | done (2026-10-04) | — |
| TMO-025 | 修 B 類 12 紅：pptx 文字改用 python-pptx（修靜默假成功）+ 裝 poppler + 新探針 AC-E21/E22 + CI 依賴 | P1 | 5 | done (2026-10-04) | TMO-023 |
| TMO-026 | 修 A 類 12 紅：探針 retarget 到 skill 拆檔後的新家（+3 條 CJK 靜默假綠探針復活）| P1 | 5 | done (2026-10-04) | TMO-025 |
| TMO-027 | 廢棄守門：dav-planner §2.7 用戶背景收集（用戶已決策廢除）5 條探針轉負向斷言 | P2 | 3 | done (2026-10-04) | TMO-026 |
| TMO-028 | `skills/dav-wiki/SKILL.md` 151 → **129 行**（V03.5 強制 ≤130）：輸出結構/軟刪除細節移子檔 + 指標存在探針 + 版本漂移鎖 | P2 | 3 | done (2026-10-04) | TMO-026 |
| TMO-029 | venv bootstrap：`PoC/requirements.txt` + setup 腳本 + CI trigger `[main, master]` + 探針「缺 venv 就大聲紅、靜態測試不誤紅」；驗收=本機 506/506（CI 首跑全綠待 TMO-039）| P1 | 3 | done (2026-10-04) | TMO-026 |
| TMO-030 | 廢除麵包屑補齊：`docs/prd/02` + `docs/prd/03:104` + backlog TMO-007 詳細段加「已廢棄」註 | P2 | 2 | todo | TMO-027 |
| TMO-031 | `skills/dav-planner/SKILL.md:73` 殘留舊步驟名（「背景收集 / 最終目的」→ 現行 Step 1/2）| P2 | 1 | todo | TMO-027 |
| TMO-032 | 探針精準化：`refute_file_contains` 加檔案存在檢查（根除假綠）+ 負向斷言排除變動歷史列 + v1.9 條目改列級錨定 + BACKLOG-005 大寫 `PENDING` 漏抓 | P2 | 3 | todo | TMO-027 |
| TMO-033 | dav-wiki 子檔內容錨點：`output-structure.md` 需含 `_index.json`/`_tags.json`/`_concepts.json`/`transcript.md`；`soft-delete.md` 需含 `deprecated_at`/`--older-than`/`--purge`（現僅 existence 鎖，子檔被掏空仍綠）| P2 | 2 | todo | TMO-028 |
| TMO-034 | 清同源死引用（指向已刪的 `docs/sop/handbook/dav-wiki-cleanup.md`）：`wiki-cleanup.sh:3`/`:39`、`CONTRIBUTING.md:48`（原 4 處，其中 `ci.yml:50` 已由 TMO-029 移除該 step）| P2 | 1 | todo | TMO-028 |
| TMO-035 | 文實矛盾對齊：`SKILL.md:94-95`「未裝時降級為純文字模式」vs 三支腳本 `require_tool()` 硬 `exit 4`（無降級路徑）——需決策改文或實作降級（走 V03）；來源 `docs/backlog.md:771` | P2 | 3 | todo | TMO-028 |
| TMO-036 | 跨目錄探針覆蓋缺口：`restruct-zero-cross-read.bats` 動詞表不含 `grep`，故 `dav-planner/SKILL.md:80`「先 grep `docs/concepts/`」實質跨目錄讀取抓不到 | P2 | 2 | todo | TMO-028 |
| TMO-037 | 清 markdownlint 債（實測 246 錯：MD013×184、MD047×18、其餘 14 種；含 `docs/backlog.md` 45、deliverable 檔 ~75、`changelog.md` 18、`skills/**` ~21）——現以 `ci.yml` lint-only `continue-on-error: true` 暫時不阻擋，清完須移除該行 | P2 | 8 | todo | TMO-029 |
| TMO-038 | 探針強化：`poc-bootstrap.bats` ① 掃描範圍放寬到縮排（函式內 optional import）與子目錄 `.py`、加 module→dist 映射；④ 靜態不變式的 helper 清單目前硬編 3 個（新增 helper → 漏抓）；⑤ CI 契約由字串改 PyYAML 語意斷言（含 `workflow_dispatch` 鎖、step 需排在 `bats tests/` 前）| P2 | 3 | todo | TMO-029 |
| TMO-039 | 首次真實 GitHub Actions 驗證：`ci.yml` 已加 `workflow_dispatch` 可手動觸發；需貼 run URL 確認（a）test job 全綠（b）runner 的 bats/python 版本假設（c）lint-only 紅燈以 annotation 呈現且不阻擋 | P1 | 2 | todo | TMO-029 |
| TMO-040 | 護欄設計邊界（Round-4 P2-2）：`POC_VENV_DIR` 指向合法的 ≥2 層絕對目錄（如 `$HOME`、`/private/tmp`）＋ `--force` 仍會 `rm -rf`；屬使用者明示操作、無法與真 venv 目錄區分，需決策（加 `$HOME` 排除？或改為只允許 `$POC_DIR` 之外的自訂目錄並加確認提示）| P2 | 2 | todo | TMO-029 |

> **狀態定義**：`done (日期)` = 已交付；`todo` = TMO-026 之後新開的後續票（已描述、尚未開工，**非** trust mode 未結項）。
> 注：`tests/backlog-trust-mode-completion.bats:48`（BACKLOG-005）禁止 trust mode 期間的票停在 `pending`；本表新票一律用 `todo`，不修改該探針。

---

## TMO-020 詳細

> 3 個收尾選項一次到位：互動式 sandbox (M6.3) + flaky 驗證 + cleanup 進 CI 定期。
> **狀態**：✅ 2026-09-28 完成（commit 下一個）

### 做法
1. **docs/ac/US-M63.md** + **docs/ac/US-M63.html**：M6.3 PENDING US，4 條 AC（sandbox 建立 / apply + re-validate / rollback / 探針守護）
2. **skills/regression-guard/PoC/sandbox_runner.py** 12.8KB / 379 行：
   - 6 步流程：建 sandbox → apply → 重跑 → re-validate → 自動 rollback（if regression）→ cleanup
   - safety 規則繼承 M6.2（ambiguous / not-found → abort + cleanup）
   - 主 repo 永遠不被改；只在 tmp/.sandbox-<ts>/ 隔離目錄
3. **skills/regression-guard/PoC/flaky_check.py** 6.4KB / 187 行：
   - 跑 N 次同一 journey，聚合 verdict 分布
   - 計算 flaky_likelihood = Σ range / (Σ max + 1)
   - 分類：stable / mildly_flaky / highly_flaky
4. **.github/workflows/regression-guard-jev-poc.yml**：
   - 加 schedule trigger (每周一 00:00 UTC)
   - 加 cleanup-scan job（條件：schedule 或 workflow_dispatch）
   - DELETE > 0 時發警告到 GITHUB_STEP_SUMMARY
5. **run_pipeline.sh**：加 M6.3 步驟 + JEV_SANDBOX_RUN=1 環境變數 + AC_FILE fallback
6. **SKILL.md v2.6**：M6.3 / Flaky / Cleanup-CI 3 小節 + 公式 + 3 種 flaky 分類表
7. **examples.md**：M6.3 範例 + flaky 實測 5 次跑表 + cleanup CI workflow 範例
8. **探針守護**：80 探針全綠（63 → 80，加 10 M6.3 + 4 flaky + 3 cleanup-CI）

### DoD
- ✅ AC01 / AC02 / AC03 / AC04 4 條全綠
- ✅ `JEV_SANDBOX_RUN=1 ./run_pipeline.sh US-M63` 一鍵跑通 M2→M6.3
- ✅ `bats tests/v2.1-jev-poc.bats` 80/80 探針全綠
- ✅ flaky_check US-M62 5 次跑 → stable (flaky_likelihood=0.0)
- ✅ workflow schedule trigger + cleanup-scan job 配好
- ✅ deliverable + 反思 + backlog 標 TMO-020 done

### 反思
- **快**：3 個收尾選項一次到位（sandbox / flaky / cleanup-CI），80 探針全綠
- **慢 1 點**：sandbox_runner 第一次在 pipeline 跑時因 AC_FILE unbound variable 中斷；用 `${AC_FILE:-$REPO_ROOT/docs/ac/${STORY_ID}.md}` fallback 解
- **影響**：regression-guard 從「完整閉環」升級為「**完整閉環 + 自動 sandbox + 穩定性量測 + 文件自動審查**」四合一
- **M6.3 的價值**：把 M6.2 的 3 步手動封裝成 1 步自動；reviewer 只需人工「把 sandbox 的 patch 拿回主 repo + commit」
- **flaky 的價值**：用 5 次實跑證明 M6.2 結果穩定（不 flaky），CI 訊號可信
- **cleanup-CI 的價值**：weekly 自動跑 cleanup-scan，DELETE > 0 時警告；不自動刪，仍需人工 review

---

## TMO-019 詳細

> M6.2 patch + re-validate：從 M6.1 LLM 接力文字 → 真的 patch → 重跑 journey 驗證。
> **狀態**：✅ 2026-09-28 完成（commit 下一個）

### 做法
1. **docs/ac/US-M62.md** + **docs/ac/US-M62.html**：M6.2 PENDING US 範本，4 條 AC
2. **skills/regression-guard/PoC/patch_parser.py** 8.2KB / 258 行：
   - 抽 unified diff 抽 (file, old, new)
   - fallback：describe_only 模式（描述型、無 diff code block）
   - 缺欄位 / 格式錯誤回傳明確錯誤（不拋 exception）
3. **playwright_patcher.py** 6.6KB / 213 行：
   - 4 種 action：dry_run / applied / aborted / describe_only / rolled_back
   - safety：old 不存在 / 多處 match → abort
   - 自動備份 `<file>.bak`
4. **re_validate.py** 6.2KB / 194 行：
   - 比較 before/after verdict 分布
   - 分類：improvement / regression / no_change
   - regression 時建議 rollback
5. **run_pipeline.sh**：M3_RC capture + JEV_PATCH_AND_REVALIDATE=1 開啟 M6.2
6. **SKILL.md v2.5**：M6.2 修正循環補充小節 + 三模組腳本 + safety 規則 + pipeline 整合
7. **examples.md**：M6.2 範例 + safety 表 + 為什麼不全自動說明
8. **探針守護**：13 個 M6.2 探針

### DoD
- ✅ AC01 / AC02 / AC03 / AC04 4 條全綠
- ✅ `JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 JEV_PATCH_AND_REVALIDATE=1 ./run_pipeline.sh US-M62` 一鍵跑通 M2→M3→M4→M6→M6.1→M6.2
- ✅ `bats tests/v2.1-jev-poc.bats` 50 → 63 探針全綠
- ✅ `patch_parser.py` / `playwright_patcher.py` / `re_validate.py` CLI 可獨立呼叫
- ✅ deliverable.md 完成
- ✅ backlog 標 TMO-019 done

### 反思
- **快**：三模組 + 13 探針一次到位、完整 pipeline 一鍵跑通
- **慢 1 點**：M3 在 US-M62 blocked=True → 原本會中斷 pipeline（set -e），加 M3_RC capture 解
- **影響**：regression-guard skill 從「給建議」升級為「**建議 → 真的 patch → 自動驗證**」完整閉環；雖仍 sandbox 內 apply，但 reviewer 只需人工 sandbox 內 3 步就能完成修正
- **為什麼不全自動 apply**：CI 環境不能無人工 commit；LLM 接力文字可能錯，需人工 review

---

## TMO-001 詳細

> **完成記錄**（2026-09-23）：見 `docs/trust-log.md` 2026-09-23 08:08 — `.gitignore` 28→17 行、刪 `.agents/tree_monstor/` 132 檔。狀態完成但 backlog 欄漏改、2026-09-26 補上。

**問題**：
1. `.gitignore` 還殘留 5 行 sop-evolver RSI 規則（commit 5db8c2e 移除 RSI 但 .gitignore 漏改）
2. `.agents/tree_monstor/` 是開發機跑 install.sh 留下的髒副本，雖然被 gitignore 但污染 IDE/Obsidian

**完成標準**：
- `.gitignore` 移除所有 sop-evolver 規則
- `.agents/` 維持整個被 gitignore 排除
- 跑 `git status` 確認 working tree clean
- regression-guard 確認安裝流程沒壞

---

## TMO-002 詳細

> **完成記錄**（2026-09-23）：見 `docs/trust-log.md` 2026-09-23 08:25 — install.sh 993→569 行、抽出 19 個函數到 6 個 lib 檔。狀態完成但 backlog 欄漏改、2026-09-26 補上。

**問題**：993 行 install.sh 拆成主程式 + lib 子模組

**完成標準**：
- install.sh < 200 行只負責 args + dispatch
- lib/install/logging.sh / paths.sh / symlink.sh / agents.sh / sop.sh / agents_dir.sh / uninstall.sh
- 所有現有 bats 測試 100% 通過
- install --global / --local / --uninstall 行為不變

---

## TMO-003 詳細

> **完成記錄**（2026-09-23）：見 `docs/trust-log.md` 2026-09-23 08:38 — 範圍縮小為「只修 README badge 數字 105→209」，不另建新 bats、不合併 cross-ref。狀態完成但 backlog 欄漏改、2026-09-26 補上。

**問題**：
1. 補上缺 bats 的工具（wiki-index / wiki-media-describe / wiki-extract-audio）
2. 合併 wiki-cross-ref-multimodal.bats → wiki-cross-ref.bats（內容重疊）
3. 修 README.md badge 從 105 → 實際 208

**完成標準**：
- 全部 @test 個數對得上 badge 數字
- 所有 bats 跑過
- 合併後的 wiki-cross-ref.bats 覆蓋兩邊的測試情境

---

## TMO-004 詳細

> **完成記錄**（2026-09-23）：見 `docs/trust-log.md` 2026-09-23 08:55 — §2.0 表格改為「以 §2.6 為準」+ §2.6 加升級觸發器 + AGENTS.md 頂版本 v1.3→v1.5 + Reviewer APPROVE。狀態完成但 backlog 欄漏改、2026-09-26 補上。

**問題**：AGENTS.md §2.0 與 §2.6 角色混淆，新人不知走哪條

**完成標準**：
- §2.6 升格為「一般任務 SOP（輕量版）」獨立入口
- §2.0 表格改為明確二分
- §2.6 內的「灰色地帶判斷表」改成「升級觸發器」
- Reviewer subagent 給「沒找到更多問題」
- changelog v1.5 同步更新

---

## TMO-005 詳細

**狀態變更**：2026-09-25 完成（v1.7 翻轉決策拆 `skills/dav-wiki/scripts/`；v1.7.1 順手修 wiki-cleanup.sh 中文 log 變數解析 bug）。原始決策紀錄保留（trust-log 2026-09-23 + v1.7 changelog）。

**問題**：原方案「加 set -e」已驗證是錯的（已用 set -uo pipefail 故意設計）

**完成標準**：
- 從 install.sh 抽出共用 lib/log.sh
- tools/wiki-*.sh 改 source lib/log.sh
- 加 trap 統一錯誤處理
- 把 tools/ 拆成 tools/wiki/ 子目錄
- 行為向後相容（不破壞現有 bats）
- file header 一致

---

## TMO-006 詳細（dav-planner AC 範本獨立化 + HTML 版本）

> **狀態**：✅ 2026-09-26 完成（v1.8 落地）
> **Reviewer verdict**：PASS（首次 FAIL 抓到 2 P0 blocker，修正後 PASS）
> **交付物**：`docs/deliverable/2026-09-26-dav-planner-ac-templates.md` / `.html` + `docs/reflection/v1.8-dav-planner-ac-templates-reflection.md`

來源：2026-09-25 用戶對話「我想優化 dav-planner 的在 Backlog 生成的同時，可以有帶有用戶的 User story 會有 AC 範本，AC 範本 是會獨立寫在 docs/ac 方便之後用戶做校對和閱讀，AC 要有 html 版本」

### 背景

dav-planner 目前 (§4.3) 把 AC（Given-When-Then + DoD）整段塞在 `docs/backlog.md` 的「交付價值與驗收標準 (AC)」表格 cell 內，閱讀體驗差、不利於利害關係人單獨校對 / 分享 / 列印。

### 目標

AC 從 backlog.md 表格 cell 抽出，每個 User Story 配一份獨立 AC 範本：
- `docs/ac/<US-ID>.md` — Markdown 版本（版本控管、可編輯）
- `docs/ac/<US-ID>.html` — HTML 版本（易閱讀、列印、分享）

backlog.md 表格 AC 欄位精簡為「AC 摘要 + 連結到獨立 AC 範本」，backlog.md 仍是 single source of truth（看進度用）。

### 範圍

**要做**：
1. `docs/ac/` 目錄結構（按 US 分檔）
2. AC 範本 .md 模板（Given-When-Then + DoD 結構）
3. AC 範本 .html 生成規則（Agent 寫 .md 同時生成 .html，同一 turn）
4. dav-planner SKILL.md §4.3 改動（AC 欄位精簡 + 連結 + AC 範本生成 SOP）
5. 既有 backlog 不動（過渡期兩格式共存）
6. bats 守護測試（防 SKILL.md 章節被靜默移除）
7. changelog v1.8 同步更新
8. Reviewer subagent 二審（V03 強制）

**不做**：
- 不動既有 backlog.md 的 US 條目（過渡期共存）
- 不做 AC 範本的自動 lint / 校對（屬後續 Sprint）
- 不做 docs/ac/ 的全文搜尋 / index 頁（屬後續 Sprint）

### 決策（已對齊）

| 項目 | 決定 |
|------|------|
| AC 架構 | A：兩者並存，backlog.md AC 欄位精簡為摘要+連結 |
| HTML 生成時機 | A：Agent 寫 .md 同時生成 .html（同一 turn）|
| 既有 backlog | A：不動既有 backlog，過渡期共存 |
| AC 範本內容 | A：只含 AC（Given-When-Then + DoD），不重複 US 內容 |
| Reviewer | A：走 dev-checker-loop 二審 |

### 完成標準

- [ ] `docs/ac/` 目錄存在 + 至少 1 個範例檔
- [ ] `dav-planner/SKILL.md` §4.3 新增 AC 範本產生 SOP（AC 摘要 + 連結規則）
- [ ] `dav-planner/SKILL.md` §4.6 新增 HTML 生成 SOP（Agent 寫 .md 同時生成 .html）
- [ ] `tests/dav-planner-ac-templates.bats` 守護新增章節不被移除（≥ 3 個探針）
- [ ] `tests/dav-planner-ac-templates.bats` 守護 docs/ac/ 範本檔案存在
- [ ] changelog v1.8 條目撰寫完成
- [ ] Reviewer verdict: PASS（無 blocker）
- [ ] `docs/backlog.md` 中 TMO-006 狀態更新為 done

### 預估 Story Point

| 子任務 | 點數 |
|--------|------|
| AC 範本 .md / .html 模板設計 | 2 |
| SKILL.md §4.3 改動（AC 摘要 + 連結規則）| 2 |
| SKILL.md §4.6 改動（HTML 生成 SOP）| 1 |
| bats 守護測試 | 2 |
| changelog v1.8 | 1 |
| **合計** | **8** |

---

## TMO-007 詳細（dav-planner 用戶背景收集機制）

### 背景

dav-planner skill 在 §2 提問技巧與 §3 思考維度中，目前**完全沒問過用戶自身的背景**（角色、經驗、技術棧），導致：

- Agent 對 PM 和開發者問同一句「你想要什麼效果？」，深度無差別
- Agent 不知道哪些維度對用戶有意義（給設計師問「目標市場」是浪費）
- 利害關係人首次使用時，缺乏破冰機制

### 目標

dav-planner 從 v1.9 起，在每次對話**開始**（§3 之前）先問 1 題「用戶角色」，並依角色動態選擇下一題追問（PM → 目標用戶/規模、Dev → 技術棧/團隊、Designer → 品牌規範、業務 → 目標市場/付款物流）。

### 範圍

#### In Scope（要做）

- SKILL.md §2.7「用戶背景收集」章節（含對應表 + §2.7.1 跳過規則 + §2.7.2 與 §3 Persona 區分）
- 5 個角色：PM/PO、開發者、設計師、業務/客戶、其他
- bats 守護（7 個探針）
- changelog v1.9 條目

#### Non-goals（不做）

- **不持久化**：純對話詢問、不寫任何檔
- **不混 §3 Persona**：§2.7 是對話用戶角色，§3 Persona 是產品目標用戶，兩者職責分開

### 決策紀錄

| 決策 | 選擇 | 理由 |
|------|------|------|
| 範圍 | 只問 1 個起步題 | 最低干擾 |
| 儲存 | 純對話詢問 | 不需維護元檔 |
| 對應表 | SKILL.md 內嵌 | 與 §2.6 SWOT 表風格一致、可被 bats 守護 |
| 整合位置 | §2.7（§2 末 §3 前）| 語意清楚、避免混 §3 Persona |

### 完成標準

- [x] SKILL.md 新增 §2.7 + §2.7.1 + §2.7.2
- [x] changelog v1.9 條目
- [x] docs/backlog.md TMO-007 (Story Point 8)
- [x] PRD-02 建立
- [x] tests/dav-planner-user-background.bats 7 探針全綠
- [x] Reviewer verdict: PASS
- [x] TMO-007 → done

### Story Point 估算（8）

| 工作項 | 點數 |
|-------|------|
| SKILL.md §2.7 章節（對應表 + 規則 + 對照表）| 2 |
| changelog v1.9 條目 | 1 |
| docs/backlog.md TMO-007 + 詳細段 | 1 |
| bats 守護（7 探針）| 2 |
| 測試 + Reviewer + 反省 + 提交 | 2 |
| **合計** | **8** |

## TMO-008 詳細（減法：文件產出物精簡 v2.0）

**背景**：v1.8 / v1.9 連續 2 個 sprint，每次都寫 6+ 個檔（changelog / PRD / reflection / deliverable.md / deliverable.html / tests）。文件產出物快速膨脹。

**目標**：未來 sprint 從「必寫 6 個檔」精簡為「必寫 2 個檔」。存量完全不動。

**範圍**：
- **In Scope**：AGENTS.md §2.4/§2.5 + dav-submitter SKILL/template + §2.4/§2.5 handbook + changelog v2.0 + TMO-008 + 6 探針
- **Non-goals**：v1.7.1/v1.8/v1.9 存量檔全部保留

**決策**：
1. 必寫：changelog + deliverable.md（含反思末段）
2. 不寫：deliverable.html、獨立 reflection.md、小任務 PRD
3. 視情境：PRD.md（架構/結構變才寫）、bats 探針（必要守護才加）
4. 範圍：只動未來 sprint 規則，不動存量
5. SOP 路徑：完整 §2.1-§2.5（V03 紀律）

**Story Point 5**（AGENTS.md §2.4/§2.5 精簡 1 + dav-submitter 三層→兩層 1 + changelog v2.0 條目 1 + tests 探針 1 + 測試 + Reviewer + 提交 1）

**完成標準（DoD）**：
- [x] changelog v2.0 條目
- [x] dav-submitter SKILL.md 三層→兩層 + 反思併進
- [x] §2.5-submission.md 移除 HTML 強制 + 新增反思 self-check
- [x] §2.4-reflection.md 反思併進 deliverable + 模板更新
- [x] dav-submitter/template.md 新增 `## 反思` 段
- [x] dav-reflection skill 改為「併進 deliverable.md」
- [x] PRD-03 In Scope #6 + DoD 改為 6 個探針
- [x] tests/v2-reduce-deliverables.bats 6/6 PASS
- [x] Reviewer verdict: PASS（修正 2 P0 + 2 P1 後）
- [x] TMO-008 → done

**Reviewer 二審結果**：首次 FAIL（2 P0）+ 順手修 2 P1 → PASS


## TMO-011 詳細

> **完成記錄**（2026-09-28）：branch `feat-jev-regression` 已 push origin，5 個 commit，2,148 行新增。詳見 `docs/deliverable/2026-09-28-feat-jev-regression-poc.md` 含「反思」末段。

**問題**：原 `regression-guard` skill 是「字串比對 pass/fail」，抓不到語意 regression（結果對了語意錯、flaky、AC 寫得模糊）。

**完成標準**：
- 用 OpenRouter `typesafe/jev-1.13` decisions model 當 oracle
- 4 個 milestone 跑通：Oracle → Journey Gen → Dry-Run Loop → Batch Report
- 一鍵 pipeline (`run_pipeline.sh`) 串接 M2→M3→M4
- Skill 本體零改動（不污染生產規範）
- 真 Jev API 驗證（US-101 4 條 AC）
- 完整 pipeline cost < $0.001（實測 $0.000390 live / $0 cache）
- `.gitignore` 確保 cache/ .env .venv/ report.* 不進 commit
- 5 個 commit 全部只動 `skills/regression-guard/PoC/`（已驗證 ✓）

**產出**：
- 11 個 source code 檔（核心 4 件 + 7 件輔助）
- 1 個 YAML spec（journeys/US-101.yaml）
- 1 個 pipeline shell
- 1 個完整 deliverable + 反思
- PR description 草稿（/tmp/pr-draft-feat-jev-regression.md）

---

## TMO-012 詳細

> **M5 PoC 去 hardcode 化**：把 TMO-011 留下的技術債清乾淨，等真實 PENDING US 出現時 PoC 能直接套用。
> **狀態**：✅ 2026-09-28 完成（commit `4ac566d`）
> **交付物**：`docs/deliverable/2026-09-28-feat-jev-regression-m5.md`（含反思末段）

**問題**：TMO-011 PoC 為快速驗證留下 4 個技術債，無法直接套用於新 US。

**完成標準**：
- ✅ `ac_aware_observe` fixture 改 config-driven（`fixtures/<story_id>.yaml` 自動載入）
- ✅ Stale detection 限「同一 AC 連續」（加 `current_ac_id` 狀態機）
- ✅ `--stale-test` 邏輯重構進 `runner.run_dry(stale_test=True)`，CLI 只負責 args + 印結果
- ✅ `tests/v2.1-jev-poc.bats` 16 探針守護：4 milestone + 2 runtime

**DoD**：
- ✅ 換別的 US（例如 US-201）只要新增 `fixtures/US-201.yaml` 就能直接跑 pipeline
- ✅ bats 探針 16/16 全綠
- ⏸ Skill 本體（SKILL.md / examples.md）整合 user-journey-as-test-spec 規範 → 順延至真實 PENDING US 出現（V02 用戶決策）

### 做法
1. **M5.1 fixture config-driven** — 把 `AC_AWARE_FIXTURES` 從 hardcoded dict 抽進 `fixtures/US-101.yaml`（1528 bytes），`ac_aware_observe(step, prev, story_id=...)` 從 YAML 自動載入。
2. **M5.2 stale 限同 AC** — `run_journey` 內加 `current_ac_id` 狀態機：進 step 前先比對 ac_id 變了沒，變了就 reset `consecutive_stale` 跟 `prev_signature`。同 AC 連續 3 步同 state 才 block（換 AC 重新計算）。
3. **M5.3 CLI 重構** — `run_dry(journey, story_acs, *, stale_test, story_id, stale_threshold)` 統一入口；`_run_dry_stale_test` + `mock_observe_static` 專門負責 stale-test 模式（force 同 state，threshold 降為 2 保證能觸發 block）。`run_journey.py` 從 ~50 行收縮到 ~20 行。
4. **M5.4 bats 探針** — 16 探針：4 區塊（fixture / stale / CLI / batch report）+ 2 runtime（真實跑 `_load_fixture` 跟 `run_dry` 證明 end-to-end 行為正確）。`@test` 名稱純英文（homebrew bats UTF-8 bug，見 wiki-merge-media.bats）。

### 反思
- **快 5 點**：16/16 探針一次紅轉綠、零迴歸（M3 行為完全一致）、commit 4ac566d 乾淨單一
- **慢 1 點**：一開始把 `--stale-test` 改完發現 `blocked: False`（因為 M5.2 改了限同 AC，stale-test 模式需要降 threshold 跟 static observer 兩招搭配）— 花了幾次迭代驗證
- **影響**：M5 落地後 PoC 對新 US 是 plug-in 模式：只加 `fixtures/<story_id>.yaml` 就能跑

---

## TMO-013 詳細

> 從 TMO-011 / TMO-012 一直延的下一個 milestone：M3.1 = PoC 換真的 Chrome driver。
> **狀態**：✅ 2026-09-28 完成（commit `83336eb`）
> **交付物**：`docs/deliverable/2026-09-28-feat-jev-regression-m31-skill.md`（同 TMO-014 合併）

### 做法
1. **playwright_observer.py 294 行**：lazy import playwright（不裝不 crash）、6 個 action handler（navigate / click / type / wait / observe / setup_state）、page session 共用（全域 `_session`）、DOM snapshot 摘要（main / article 文字 + 互動元素清單）
2. **journey_runner.py dispatcher**：`_select_observer()` 根據 `OBSERVER_BACKEND` env 選 `ac_aware` (預設) / `mock` / `playwright`；`mock_observe` 加 `story_id` kwarg 對齊介面
3. **graceful fail**：playwright 沒裝時 raise `RuntimeError`，runner dispatcher 不 crash
4. **探針守護**：5 個 M3.1 探針（file exists & 6 actions / dispatcher / import OK / playwright fail graceful / mock 簽名）

### DoD
- ✅ 換 `OBSERVER_BACKEND=playwright` 就能切 driver
- ✅ 不裝 playwright 整個 PoC 仍能跑（lazy import）
- ⏸ 真實 driver 跑 example.com（順延到「真實 PENDING US 出現時」）

---

## TMO-014 詳細

> SKILL.md 整合：把 M1-M5 的 PoC 成果提升為正式 skill 規範。
> **狀態**：✅ 2026-09-28 完成（commit `83336eb`）
> **交付物**：`docs/deliverable/2026-09-28-feat-jev-regression-m31-skill.md`（同 TMO-013 合併）

### 做法
1. **SKILL.md v2.2**：新增「Jev Oracle 補充（進階）」章節（+62 行），原 Steps 1-4 不動。章節內容：適用場景 / 不適用 / 怎麼試 / 3 種 observer backend / 實作成本預估 / 探針選名參考。
2. **examples.md**：新增「🧠 Jev Oracle 範例（進階）」章節（+111 行），4 個範例：journey YAML / dry-run / batch report / JSON 報告。
3. **changelog v2.2 entry**：標註 TMO-013 / TMO-014 整合。
4. **探針守護**：4 個 SKILL 探針（SKILL.md Jev 章節 / 3 backends / examples.md 4 範例 / v2.2 entry）

### DoD
- ✅ 閱讀 SKILL.md 的人能從「Jev Oracle 補充」章節找到 PoC 入口
- ✅ 閱讀 examples.md 的人能直接看到 4 個範例輸出（不需跑 PoC）
- ✅ Steps 1-4 結構不變（保證向後相容）

### 反思
- **快**：1 個 sprint 內 M3.1 + SKILL.md 整合 一起完成、25/25 探針、SKILL.md +63 行 + examples.md +111 行都是加法不破壞
- **慢 1 點**：bats 探針名稱含中文引號 `'` 被 homebrew bats UTF-8 bug 拒絕（unknown test name）— 改為不帶引號的探針名（跟 wiki-merge-media.bats 一樣純英文 workaround）
- **影響**：regression-guard skill 從「Steps 1-4 規範」升級為「Steps 1-4 規範 + 可選進階 Jev Oracle 章節」；要採用 Jev 的項目能直接看 SKILL + examples 評估實作成本

---

## TMO-015 詳細

> CI 整合：把 bats + run_pipeline.sh 接進 GitHub Actions，加 return code gate + branch protection SOP。
> **狀態**：✅ 2026-09-28 完成（commit `f0f6543`）

### 做法
1. **`.github/workflows/regression-guard-jev-poc.yml`** 149 行：2 個 jobs（bats + pipeline）、3 個 triggers（push / PR / dispatch）、paths filter 限 `skills/regression-guard/**` + `docs/ac/**`、workflow_dispatch 帶 `story_id` + `use_stale_test` 參數。
2. **Return code gate**：`set +e` + `PIPELINE_RC` capture → 0=green pass / 2=yellow warn / 1=red error blocks merge（`::error::` 標記）。
3. **Artifact upload**：`regression-report-<STORY>` JSON + MD 30 天保留。
4. **PR comment**：`$GITHUB_STEP_SUMMARY` 貼 markdown 報告。
5. **Secrets**：`secrets.OPENROUTER_API_KEY` 走 repo secret（不 hardcode）。
6. **`docs/ci/regression-guard-jev-poc.md`** 155 行：branch protection `gh api` 指令 + UI 步驟 + secrets 設定 + 本機 debug + 已知限制。

### DoD
- ✅ workflow YAML 語法正確（2 jobs / 14 steps / 3 triggers）
- ✅ bats 跑不靠 API（探針 25 → 37）
- ✅ pipeline 用真 API（OPENROUTER_API_KEY secret）
- ✅ Return code 0/1/2 對應 green/yellow/red 行為有寫進 workflow
- ✅ Branch protection 設定 SOP 完整（gh API + UI 雙路徑）
- ⏸ **實際在 GH 上啟用**（需 repo admin 手動設 branch protection；PoC 文件化但未實際接入）

### 反思
- **快**：一開始以為 GHA 不能透傳 python exit code，後來用 `set +e` + `PIPELINE_RC=$?` capture 解掉（pattern 跟 M4 學的）
- **慢 1 點**：`env.RETURN_CODE_RED` 寫錯（GitHub Actions 不能像 shell 一樣把 python exit code 自動變 env），改成手動 capture 變數
- **影響**：regression-guard 從「local-only PoC」升級為「CI-ready PoC」；開 branch protection 後 PR 自動被 real_bug verdict 擋下

---

## TMO-016 詳細

> M6 修正循環：把 Jev verdict 自動接上 fix proposal 產出（信心度報告 + 失敗走跡），SKILL.md Step 4 整合。
> **狀態**：✅ 2026-09-28 完成（commit `f0f6543`）

### 做法
1. **`fix_proposal.py` 311 行**：3 題 noul batch call（problem_summary / proposed_fix / verification_steps），跟 batch_report.py 同 cache-first pattern。**因 Jev v1.13 不支援 free_response 題型**（只有 choice / score / noul），改成「信心度報告」 — 3 維度 noul 概率 + 整體信心度 + 失敗走跡截錄 200 字。
2. **`FixProposal` dataclass**：3 conf 字段 + `overall_confidence` property + `_conf_label()` 評級（高/中/低/不可判定）+ `to_markdown()` 產人讀報告。
3. **`run_pipeline.sh` M6 步驟**：`JEV_FIX_PROPOSAL=1` 開啟；`M4_RC=0` + `|| M4_RC=$?` capture M4 return code（不然 M4 紅色時 set -e 會中斷 pipeline）。
4. **SKILL.md v2.3**：「修正循環補充（M6 自動 fix proposal）」+「CI 整合補充」小節（+55 行）。明確標 Jev v1.13 限制 + 0.5 信心度 gating 門檻 + M6.1 升級路徑。
5. **examples.md**：fix proposal 範例 markdown + reviewer workflow 3 步驟。
6. **探針守護**：7 個 M6 探針（schema / dataclass / JEV_FIX_PROPOSAL env / M4_RC / SKILL section / examples example / end-to-end CLI）。

### DoD
- ✅ JEV_FIX_PROPOSAL=1 一鍵跑完整 pipeline + 產出 fix_proposal.md
- ✅ fix_proposal.md 包含「整體信心度 / 信心度評估表 / 原始失敗走跡 / 上下文 / 下一步」5 區塊
- ✅ M4 紅色不會中斷 pipeline（M4_RC capture + 0.5 信心度 gating 雙保險）
- ✅ SKILL.md v2.3 + examples.md 給 reviewer 完整接手起點
- ⏸ **自動接 LLM 寫 fix 文字**（M6.1+ 升級路徑，需另起 sprint；Jev 信心度作為 gating）

### 反思
- **快**：3 題 noul schema 一次 OK、bats 探針一次 36/36、SKILL.md v2.3 +55 行純加法
- **慢 1 點**：一開始預期 Jev 給文字回應，結果只給 noul 概率（schema 不支援 free_response）；改為「信心度報告」模式意外更務實（reviewer 接手起點明確、不需 LLM 接力）
- **影響**：M6 落實「reviewer 接手 → Jev 給信心度 + 走跡 → reviewer 寫 fix」3-step 流程，PoC 不依賴 GPT/Claude；升級到 LLM 接力是 M6.1+ 顯而易見的下一步
- **踩坑**：`set -euo pipefail` 在 M4 red 時會提前中斷 pipeline → 學到「return code 設計的 step 要用 `||` 接住再用 $? capture」（pattern 通用）

---

## TMO-017 詳細

> M6.1 LLM Relay：讓 regression-guard skill 召喚時的 LLM（subagent / pi 本身）接力寫 fix 文字，不接外部 Claude/GPT。
> **狀態**：✅ 2026-09-28 完成（commit `224297c`）

### 做法
1. **prompts/fix_relay.md** 95 行：檔案型 prompt template（角色 / 輸入 / 產出 / 約束 / 範例 / gating），取代 hardcoded 字串。
2. **fix_proposal_v2.py 260 行**：v1 + LLM relay 素材打包。
   - `LLMRelayBundle` dataclass + `write_prompt_bundle()` 產 `.relay/prompt.md`
   - `build_final_report()` 拼裝 v1 信心度 + LLM 接力 + 走跡對照
   - `RELAY_GATING_THRESHOLD=0.5`：≥0.5 召喚、<0.5 跳過
3. **run_pipeline.sh**：`JEV_FIX_PROPOSAL_V2=1` 開啟 M6.1 步驟。
4. **SKILL.md v2.4**：M6.1 修正循環補充小節 + prompt template 位置 + gating 表 + 為什麼是 skill 本身 LLM 說明。
5. **examples.md**：fix proposal v2 範例 + 「為什麼是 skill 本身 LLM」說明 + gating 表。
6. **探針守護**：6 個 M6.1 探針。

### DoD
- ✅ JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 一鍵跑完整 pipeline + 產出 fix_proposal_v2.md
- ✅ 信心度≥0.5 時產 prompt bundle 到 .relay/prompt.md
- ✅ 信心度<0.5 時走「跳過 LLM relay」路徑，final report 標「reviewer 接手」
- ✅ Prompt template 是檔案可版本化、可由 skill 維護者迭代
- ⏸ CI 自動召喚 subagent（需 repo admin 設 gh action / 外部觸發）

### 反思
- **快**：prompt template 一次到位、fix_proposal_v2 純 import fix_proposal 模組化、bats 50 探針一次綠
- **慢 1 點**：一開始想用 `Path.match('**/.venv/**')` 排除 .venv，但 `**` 只匹配一個目錄層；改為 `/'.venv' in rel` 簡單避開
- **影響**：M6 從「產信心度報告 + 走跡」升級為「信心度達標時召喚 LLM 接力寫 fix 文字」；不再依賴外部 Claude/GPT / OpenAI API key；prompt 邏輯統一在 skill 內
- **為什麼是 skill 本身 LLM**：這才是 skill 精神的正確路 — 「skill 被召喚時」本身就是有 LLM 的（pi 本身 / subagent），讓它接力；不需另外維護一份 prompt 邏輯雙重來源

---

## TMO-018 詳細

> docs/cleanup 盤點腳本：掃描 docs/ + skills/ + tests/ 找孤立 .md，依 cross-link 數分類 KEEP / REVIEW / DELETE。
> **狀態**：✅ 2026-09-28 完成（commit `224297c`）

### 做法
1. **docs/cleanup/cleanup-scan.py** 246 行：
   - 4 類分類：KEEP（≥2 cross-link）/ REVIEW（1）/ DELETE（0）/ MERGE（待實作）
   - 排除 `.venv/` / `__pycache__/` / `node_modules/` / `.relay/` / `journeys/` / `fixtures/` / `cache/`
   - 保護所有 skill/ 目錄（dav-designer / dav-planner / ... / regression-guard）+ AGENTS.md / SKILL.md / handbook / ac/US-* / deliverable/ / backlog.md / ci/
   - 支援 `--json` 輸出 + `--apply` 自動刪 DELETE 類（需手動確認）
2. **本次掃描結果**：KEEP 63 / REVIEW 4 / DELETE 0
   - 4 個 REVIEW 都在 v2.0 規則下「保留為 audit trail」（PRD-04 / 2 個反思歷史 / testing-methods.md）
3. **探針守護**：7 個 CLEAN 探針（script 存在 / 4 分類 / .venv 排除 / skill 保護 / --json valid / 無 false positive / M6→M6.1 順序）。

### DoD
- ✅ 盤點腳本能跑 + 4 分類正確 + 無 .venv false positive
- ✅ 4 個 REVIEW 都給出 cross-link 來源
- ✅ --json 輸出可被 CI 讀（KEEP 63 / REVIEW 4 / DELETE 0）
- ⏸ 套用 --apply 自動刪：本次無 DELETE 類，未執行

### 反思
- **快**：盤點結果乾淨（KEEP 63 / REVIEW 4 / DELETE 0），掃 < 1 秒
- **慢 1 點**：`Path.match('**/.venv/**')` 不匹配 `.venv/lib/.../LICENSE.md`（** 只匹配一層），改為 `/'.venv' in rel` 簡單避開
- **影響**：未來 sprint / PR 都可跑 `cleanup-scan.py` 觀察「孤立檔趨勢」；TMO-008 / TMO-010 v2.0 規則（保留存量 audit trail）由本盤點驗證無違反

---

## TMO-021 詳細（M7 flaky 整合 + gh pr comment）

> 解鎖 review 流程：reviewer 不用離開 PR 就能看 regression 結果。
> **狀態**：✅ 2026-09-28 完成（trust mode）

### 做法
1. **docs/ac/US-M71.md**：M7 PENDING US，4 條 AC
2. **skills/regression-guard/PoC/flaky_integration.py** 6.1KB / 207 行：
   - 跑 N 次 journey（預設 2 次）+ 聚合
   - 寫回 `batch_report.batch_report.flaky_measured`
   - 高度 flaky 時降級 overall_health（red→yellow）
3. **skills/regression-guard/PoC/gh_pr_comment.py** 5.2KB / 174 行：
   - 構造 4 段 PR comment（journey / 信心度 / 問題摘要 / sandbox 建議）
   - 用 `gh pr comment` 推 PR
   - 失敗不中斷（best-effort）
4. **run_pipeline.sh**：M7-flaky 移到 M4 之後 + JEV_FLAKY_INTEGRATION=1 + JEV_GH_PR_COMMENT=1
5. **SKILL.md v2.7** + examples
6. **探針守護**：12 個 M7 探針全綠（80 → 92）

### DoD
- ✅ AC01 / AC02 / AC03 / AC04 4 條全綠
- ✅ flaky_integration.py + gh_pr_comment.py CLI 可獨立呼叫
- ✅ 12 個 M7 探針全綠
- ✅ `JEV_FLAKY_INTEGRATION=1 JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 ./run_pipeline.sh US-M62` 一鍵跑通
- ✅ 實測 flaky_measured=0.0 stable (US-M62 額外跑 2 次)
- ✅ deliverable + 反思 + backlog 標 TMO-021 done

### 反思
- **快**：flaky 整合跟 gh pr comment 兩個模組一次到位
- **慢 1 點**：M7-flaky 原本放在 M3 後，但 batch_report 那時還沒產出；移到 M4 後才正確
- **影響**：regression-guard 從「產報告」升級為「**產報告 + 推 PR comment + 動態驗證 flaky**」三合一
- **M7 解鎖 review**：reviewer 不用離開 PR 就能看 4 維度 + 信心度 + 建議

---

## TMO-022 詳細（M8 CI matrix pipeline）

> 多 US 並行：一次看 3 個 US 的 regression 結果。
> **狀態**：✅ 2026-09-28 完成（trust mode）

### 做法
1. **docs/ac/US-M81.md**：M8 PENDING US，4 條 AC
2. **.github/workflows/regression-guard-jev-poc.yml**：
   - pipeline job 加 `strategy.fail-fast: false` + `matrix.story_id: [US-101, US-M62, US-M63]`
   - 新增 `aggregate-matrix` job（needs pipeline, if workflow_dispatch）
   - download-artifact merge-multiple + matrix-summary.md 構造
3. **SKILL.md v2.8** + examples
4. **探針守護**：6 個 M8 探針全綠（92 → 98）

### DoD
- ✅ AC01 / AC02 / AC03 / AC04 4 條全綠
- ✅ workflow_dispatch 觸發可跑 3 個 matrix job
- ✅ 3 個 artifact 各自獨立 + matrix-summary.md
- ✅ 6 個 M8 探針全綠
- ✅ deliverable + 反思 + backlog 標 TMO-022 done

### 反思
- **快**：matrix 結構 + aggregate job 一次到位
- **慢 1 點**：awk 抓 job 範圍的探針跟 M8-d 撞了 2 次（修正 head -5 → head -10）
- **影響**：regression-guard CI 從「1 US / 1 run」升級為「3 US / 3 runs 並行 + 自動聚合」
- **M8 為什麼只在 workflow_dispatch**：push/PR 跑 3 個 matrix 浪費 CI minutes；手動 trigger 拿可控性
- **M8 為什麼 fail-fast: false**：reviewer 一次看 3 個結果比「1 個 fail 全部 cancel」更有用

---

## TMO-023 詳細（v2.1-jev-poc C 類探針修復）

> 來源：2026-10-04 用戶對話「README 精簡 → 順手盤點 bats 38 紅」→ 用戶決策「先修 C 類探針 bug」
> **狀態**：✅ 2026-10-04 完成

### 問題（8 個探針自己壞掉，與 product code 無關）

| 探針 | 病因 |
|------|------|
| M6.3-b/c/d/e/f（5） | 傳 `--before /tmp/US-M63-before.json`，但 repo 內**沒有任何步驟**產生該檔 → `sandbox_runner.py` 找不到就回 error |
| flaky-int-b | 少 `run` 前綴 → `$status` 未設 → `[: : integer expression expected` |
| flaky-int-c / M7-gating-a | 讀 `/tmp/m62-batch.json`，同樣沒有步驟產生 |
| M6.3-e（額外發現） | ① `$REPO_ROOT/tmp/` 不存在 ② **`ls` 不列 dotfile**，而 sandbox 目錄叫 `.sandbox-*` → 清理斷言結構上永遠不可能 fail（假保證）③ `grep -c … \|\| echo 0` 在 0 命中時輸出 `0\n0` |

### 做法（只改測試層，未動 product code）

1. `tests/v2.1-jev-poc.bats` 新增兩支共用 fixture helper：
   - `make_us_m63_before`：**真跑一次** US-M63 journey 當 patch 前 baseline（blocked → rc=2，只吞 rc、必驗檔案真的產出）
   - `make_m62_batch_report`：造 M7 flaky 整合所需 batch_report 最小 fixture
2. M6.3-b/c/d/e/f 改呼叫 `make_us_m63_before`；M6.3-e 另修 `ls -a` + `-ne` + 讀 `--json` 斷言 `classification=no_change` / `cleanup_ok=true`
3. flaky-int-b 補 `run`；flaky-int-c / M7-gating-a 補 `make_m62_batch_report`
4. `.gitignore` 加 `/tmp/`（sandbox_runner 在 repo root `tmp/` 建 `.sandbox-*`）

### AC / DoD

- ✅ AC1：M6.3-b/c/d/e/f 5 個探針綠（清空 `/tmp` fixture 後仍綠）
- ✅ AC2：flaky-int-b/c + M7-gating-a 3 個探針綠
- ✅ AC3：無新增失敗（全套 38 紅 → 30 紅，`comm -13` 為空）
- ✅ AC4：探針**真的會紅** — 突變測試：故意把 `_cleanup()` 改成 `return False` → M6.3-e 轉 `not ok`（`FAIL: sandbox dir not cleaned up (before=4 after=5)`）→ 還原後 `ok`

### 驗收證據

- Gate 1（紅→綠）：`bats tests/v2.1-jev-poc.bats --filter 'M6\.3|flaky-int|M7-gating'` 修改前 8 紅 / 16 → 修改後 16 ok / 0 紅
- Gate 3（regression）：`bats tests/` baseline（`git stash` 還原 + 清 `/tmp` fixture 量測）not ok 38 / ok 455 → 修改後 not ok 30 / ok 463
- Gate 4（reviewer，V03.6 二審 2 輪）：第 1 輪 approve-with-comments / risk low（抓出 M6.3-e 假斷言 P1）→ 修正後第 2 輪 approve-with-comments / risk low / 0 P0-P1

### 已知問題（本輪未修，另立後續）

- **A 類 18 紅**：skill 改版後探針過期（dav-planner §2.7、regression-guard TTY、SKILL-b/d/M6-e/M6.1-e、dav-wiki AC-2 因 SKILL.md 151 行 > 150）
- **B 類 12 紅**：11 個缺 poppler（`pdfimages`/`pdftotext`）；1 個**真缺陷** — pandoc 不支援 pptx reader，但 `wiki-extract-media.sh` 仍印「✓ PPTX 文字提取完成」並 exit 0（靜默假成功）
- **`sandbox_runner.py` error 路徑不 cleanup**：建立 sandbox 後 copy 失敗時直接 return，目錄洩漏（本輪實測重現，非探針範圍）
- **探針 P2 建議**：fixture 改 `$BATS_TEST_TMPDIR`、加 `timeout`、M6.3-f 應斷言 classification、M7-gating-b 恆真、flaky-int-c/M7-gating-a 只 grep key 存在
- **CI 從未跑過**：`.github/workflows/ci.yml` trigger 是 `branches: [main]`，但 repo 預設分支是 `master`（`gh run list` 0 筆）

### 反思

- **快**：8 個紅燈同一病因（測試前置 fixture 缺失），兩支 helper 一次解掉
- **慢 1 點**：第一版只「補 fixture 讓紅燈變綠」，被 reviewer 抓到 M6.3-e 是**假綠**（`ls` 不看 dotfile）；靠**突變測試**（故意破壞 `_cleanup`）才證明探針真的會紅
- **影響**：`bats tests/` 38 → 30 紅；這 8 個紅燈不再掩蓋 M6.3/M7 的真回歸
- **教訓**：「補前置資料讓紅燈變綠」必須分清**修探針** vs **放寬門檻**；能用突變測試證明「探針會紅」才算真修好

---

## TMO-024 詳細（README 精簡 + install-reference）

> 來源：2026-10-04 用戶對話「README 只留簡單安裝介紹，更多導向 AGENTS.md 與 skills」
> **狀態**：✅ 2026-10-04 完成

### 做法

- `README.md` 288 → 90 行：badges / 一行介紹 / Quick Start / 精簡 Usage 表（保留 `Usage`、`--global`、`--uninstall` 三字串，`tests/install.bats` AC-15 依賴）/ 新增「工作流程：看 AGENTS.md」（§1 / §1.5 V01–V03 / §2.0 / §2.1–§2.5 / §2.3 4 Gate / §2.7）/ 新增「Skills」表（11 個 skill 一行說明 + 連結）/ 進階指向 `docs/install-reference.md`
- 新增 `docs/install-reference.md`（296 行）：完整 flag 表、安裝後檔案結構、設計理由、環境變數、dev/test、6 題 troubleshooting
- 修正原 README 不實描述：`REGRESSION_MODE=true bash install.sh` 這個環境變數在 `install.sh` / `lib/` 內不存在 → 改為 `bash -x install.sh --dry-run --global`

### 驗收證據

- `markdownlint`：0 問題
- `bats tests/install.bats`：AC-15 綠；全套 `bats tests/` 無新增失敗（38 紅為 baseline）
- 14 個相對連結逐一確認存在

### 已知問題

- README 的 `bats | 209/209` badge 已過期（實際 493 測試 / 463 綠 / 30 紅），且 CI badge 指向從未執行的 workflow → 待用戶決定 badge 處理方式

---

## TMO-025 詳細（B 類 12 紅修復：pptx 假成功 + poppler）

### 問題（起始狀態：`bats tests/` 30 紅中的 B 類 12 紅）

| # | 症狀 | 根因 |
| --- | --- | --- |
| 1 | 11 個 PDF 探針紅（AC-E1/E2/E9/E10/E11/E12/E15/E16/E17/E19/E20） | 本機缺 poppler（`pdfimages` / `pdftotext` MISSING）→ `require_tool` exit 4。**不是產品 bug**，是環境缺件 |
| 2 | AC-E6（PPTX 文字）紅 | **真缺陷**：`extract_pptx_text()` 用 pandoc 讀 pptx，但 pandoc 3.8.2 無 pptx input format（`pandoc --list-input-formats` 只有 docx）→ pandoc rc=21 被忽略（`set -uo pipefail` 無 `-e`）→ 腳本印「✓ PPTX 文字提取完成」、rc=0、manifest 寫 text.md，但 text.md **從未產生** = **靜默假成功**。且 `docs/system-design.md:100` 設計本來就寫「PPTX → python-pptx」 |

### 做法

- **環境**：`brew install poppler`（另裝 `shellcheck` 作為 Gate 2 lint 工具）→ 11 個 PDF 探針真跑
- **產品碼** `skills/dav-wiki/scripts/wiki-extract-media.sh`：
  - `extract_pptx_text()` 改用 python-pptx 逐頁抽文字（`## Slide N` + 文字框），與設計文件一致
  - 新增 `verify_artifact <path> <label>`：**檔案不存在 → ERROR + exit 5**；**內容為空 → 只警告**（掃描件合法，改走圖片 + OCR FR-2.2.3）
  - 新增 `EXIT_EXTRACT=5`；usage/header 同步（並修掉 `tools/` 與 `docs/prd/03-knowledge-extraction.md` 兩處死引用）
  - `pdfimages` / `pdftotext` / `pandoc`(×2) / python heredoc(×2) 全部補 rc 檢查；python `sys.exit(4)`（缺 python-pptx）正確映射回 `exit 4`
- **探針** `tests/wiki-extract-media.bats`：
  - AC-E6 標題改為 implementation-agnostic（斷言一字未改）
  - **新增 AC-E21**：壞掉 `.pptx` → `status -eq 5`（釘住 exit code，區分「工具缺失 4」vs「提取失敗 5」）+ 不得留 text.md + 輸出含「無法讀取」
  - **新增 AC-E22**：新 fixture `tests/fixtures/pdf-scan/scan.pdf`（無文字層）→ exit 0 + 圖片保留 + 出現「掃描件」警告；探針開頭有 fixture 漂移守衛
- **文件 / CI**：`docs/install-reference.md` 新增「dav-wiki 測試依賴」表（明確寫「缺工具時探針直接失敗不 skip」）；`.github/workflows/ci.yml` 加 `actions/setup-python` + Linux/macOS 依賴安裝（poppler/pandoc/tesseract/python-pptx）+ `bash -n` 收錄本腳本

### AC / DoD

- ✅ `bats tests/wiki-extract-media.bats` → **22/22 綠**（修前 12 紅）
- ✅ `bats tests/` → **not ok 18 / ok 477**（對比 baseline 30 紅：**新增失敗 = 0**，修好 = 12）
- ✅ Gate 2：`bash -n` rc=0；`shellcheck` rc=0、0 issue（修改前版本亦 0 → 無新 lint 債）
- ✅ 可證偽：突變測試 3 次 → 移除 rc 檢查+`verify_artifact` 時 AC-E21 轉紅；移除空文字層警告時 AC-E22 轉紅；`cp` 還原後皆轉綠
- ✅ Gate 4：reviewer 兩輪（`approve-with-comments / risk low / 0 P0`），第二輪明示不需第三輪
- ✅ deliverable：`docs/deliverable/2026-10-04-tmo-025-b-class-probe-fix.md`

### Gate 4 期間發現並修掉的真 bug（自身）

二審建議「AC-E21 改釘 `status -eq 5`」後探針立刻轉紅，追出根因：**`${var}` 寫成 `$var` 且緊鄰全角括號** →
bash 在 UTF-8 locale 把 `$rc）` 解析成變數名 `rc）` → `set -u` 下 `rc: unbound variable`，exit code 變 1。
全 repo 掃描同型地雷共 7 處（本檔 6 + 探針 1），已全數改為 `${var}`；另確認其他腳本無此型問題。

### 已知問題

- `bats tests/` 仍有 **18 紅**（A 類探針過期，見 TMO-023 詳細）
- 評審 §4 建議以下升為 **P1** 另立票（本輪未動）：
  1. `.github/workflows/ci.yml` trigger `branches: [main]` vs repo 預設 `master` → CI 從未執行（修好當下會立刻紅，建議與 A 類清理、SKILL.md 瘦身同批）
  2. `skills/dav-wiki/SKILL.md` **151 行 > 150**（`tests/dav-wiki.bats:38` 已紅）+ `:95`「未裝時降級」與 `require_tool` 硬 `exit 4` 矛盾（需走 V03）
  3. bats 1.14.0 對「`@test` 名含 CJK」會靜默不執行：實測 3 條（`restruct-agents-md.bats` ×2、`restruct-dav-planner.bats` ×1），宣告 498 / 實跑 495；3 條斷言本身若跑會綠
- P2（report-only）：pptx 表格/群組文字未抽、CI badge owner 錯誤、sibling 死引用 8 腳本、scan.pdf 重建指令 macOS-only、`$var緊鄰全角字元` 未有 repo 級靜態守衛
- 未 commit：工作區同時有 TMO-023 / TMO-024 / TMO-025 三輪變更，建議分開 commit（**已於 2026-10-04 分成 3 個 commit**：`c2b036c` TMO-023 / `b3a9b49` TMO-024 / `5ed097e` TMO-025）

---

## TMO-026 詳細（A 類 12 紅 retarget + 3 條 CJK 假綠探針復活）

### 病因（兩類，刻意分開處理）

1. **探針落後重構**（12 紅）：v2.1–v2.9 各 skill 依「任務導航 + 子檔拆分」把內文從 `SKILL.md` 搬進同 skill 子檔
   （`backlog-rules.md` / `runner-cheatsheet.md` / `jev-oracle.md` / `CHANGELOG.md`），探針仍盯舊址找舊字串 → 一片紅。
   **處理原則：retarget 探針**（指向事實的新家 + 鎖住「主檔留有指標」），**不是**把內文搬回去迎合探針。
2. **探針根本沒在跑**（3 條）：`bats` 1.14.0 對「`@test` 名含 CJK」靜默不執行（宣告 498 / 實跑 495）。
   它們是「不在報告裡的守門人」＝最安靜的債。改名為 ASCII 使其真的執行且真的通過 → **宣告 498 == 實跑 498**。

### 處理範圍

| 檔 | 做什麼 |
| --- | --- |
| `tests/dav-planner-ac-templates.bats` | `AC 範本生成 SOP` → `backlog-rules.md`（+ 主檔指標斷言）|
| `tests/regression-guard-watch-mode.bats` | runner 對照表 → `runner-cheatsheet.md`；CROSS 改**段落級** awk 指標斷言 + 加 `gates.json` 斷言 |
| `tests/restruct-dav-planner.bats` | `v2.0` → `CHANGELOG.md` + **版本漂移鎖**；1 條 CJK 名改 ASCII |
| `tests/restruct-regression-guard.bats` | 同上（漂移鎖）；TTY：主檔斷 `watch|interactive`、子檔斷 `/dev/null` |
| `tests/v2.1-jev-poc.bats` | SKILL-b/d/M6-e/M6.1-e → `jev-oracle.md` + `CHANGELOG.md`（+ 主檔指標斷言）|
| `tests/restruct-agents-md.bats` | 2 條 CJK 名改 ASCII（改前未執行）|
| `skills/dev-checker-loop/SKILL.md` | `:41` 措辭精確化（明示「目標專案」→ 清 zero-cross-read 命中）；變動歷史表刷新 v2.5/v2.4/v2.3 |
| `skills/dev-checker-loop/CHANGELOG.md` | 新增 v2.5 列 |

### 驗收證據

- Gate 1（紅→綠）：逐檔 before/after = 1→0 / 3→0 / 2→1 / 2→0 / 1→0 / 4→0 / 0→0（後者 executed 8→10）；**7 次突變**證明探針會咬人
  （搬走 4 個子檔 → 3/1/3/3 紅；指標移出段落 → 1 紅；版本不一致 → 2 紅；拿掉 `gates.json` 字串 → 1 紅；全部還原後回綠）
- Gate 2：`bats` 逐檔 0 parse warning；`markdownlint` `SKILL.md` MD013 **2 → 1**（剩 `:51` 為既有未觸碰）；無 `.sh` 改動 → shellcheck N/A
- Gate 3：`bats tests/` **18 not ok / 477 ok（實跑 495）→ 6 not ok / 492 ok（實跑 498）**；集合差 **已修 12 / 新增 0**
- Gate 4（V03/V03.6 二審 2 輪）：兩輪均 **approve-with-comments / risk low / 0 P0-P1**；第 1 輪逐條附行號驗證 11 個新家字串存在；第 2 輪判「真強化、非化妝」＋「改寫為實質修正、非字面規避」

### 已知問題（本輪未處理，進 backlog）

- `bats tests/` 仍有 **6 紅**：5 條 → TMO-027（dav-planner §2.7 廢棄條款）、1 條 → TMO-028（`dav-wiki/SKILL.md` 151 行）
- P2-1：`restruct-zero-cross-read.bats` 的 `SKILLS` 陣列漏 `skills/ask-me/SKILL.md`（`:10`/`:36` 真實命中 `讀 \`docs/need-you-help.md\``）；`dev-checker-loop/module-rules.md:23,39` 同型。**刻意不修**（現加會製造新紅，違反本輪「0 新增」）→ 應與 reword 同批
- P2-2：`regression-guard/CHANGELOG.md:11,12` 兩列同為 `v2.10`（重複版本號）
- P2-3：③ 的「主檔→子檔指標」斷言仍為 whole-file grep（與 ① 同類弱點）
- P2-4：`restruct-dev-checker-loop.bats:44-56` 用 OR 分支（v2.x 列 **或** `CHANGELOG.md` 指標）→ **不會**抓到二審抓到的「主檔陳舊型態」；建議移植漂移鎖
- P2-5：`docs/sop/gates.json:62` / `docs/sop/handbook/2.3-execution.md:43` 仍指向 TMO-009 階段 7 已改名的「測試指令執行規範」章節

### 反思

- **「紅燈」有三種病：探針過期 / 守著廢棄功能 / 產品缺陷**；本輪只該治第一種。若把三者一起「弄綠」，會把「廢棄功能的守門人」偷刪（所以 TMO-027 需用戶決策：刪除 or 轉負向斷言）
- **retarget ≠ 放寬**，界線在「有沒有同時鎖住主檔→子檔指標」；沒有這一步，子檔被刪/改名時主檔仍漂漂亮亮
- **最安靜的債是沒在跑的探針**：紅燈會叫人，假綠不會；`宣告 == 實跑` 是可稽核的守門指標
- **二審第二次咬到作者自己**：引述自家規則字串（`讀 \`docs/…\``）而踩線 → 逼出「修正 vs 字面規避」判準（動詞是否移除 / 資訊是否隱藏 / 有無不可見字元）
- **未質問的根因**：重構 skill 的流程裡缺「探針同步」這一步；本輪只是事後補。建議 V03 檢查清單可加「本次是否搬動了被探針斷言的內文」

---

## TMO-027 詳細（dav-planner §2.7 廢棄守門）

### 病因與處置（用戶決策）

- v1.9「用戶背景收集」（dav-planner §2.7，問對話用戶角色 PM/開發者/設計師/業務）已由**用戶決策**於 v2.1 廢除
  （理由：對話用戶角色對後續開發無實質幫助，反引導用戶「搞不清自己要什麼」）。
- 但 5 條回歸探針仍斷言「§2.7 必須存在」→ 恆紅（4 條在 `tests/dav-planner-user-background.bats`、
  1 條在 `tests/restruct-dav-planner.bats`）。用戶在 §2.7 處置題選「**⭐ 轉「廢棄守門」探針**」。
- 本輪把 5 條存在型探針改寫成 4 條「廢棄守門」：**負向斷言**（功能不得回流）+ **定位句必須留著**
  + **廢除紀錄必須留著**（本地 CHANGELOG 列級錨定 + 全域 changelog）。新增 helper `refute_file_contains()`。

### 變更清單

| 檔 | 改動 |
| --- | --- |
| `tests/helpers/test-env.bash` | +`refute_file_contains <path> <substring>`（負向斷言，與 `assert_file_contains` 同構）|
| `tests/dav-planner-user-background.bats` | 4 條存在探針 → 3 條守門（7 tests → 6 tests）|
| `tests/restruct-dav-planner.bats` | 1 條存在探針 → 1 條守門（13 tests 不變）|
| `docs/backlog.md` | TMO-027/028/029 列 `pending` → `todo`（TMO-027 完成後改 `done (2026-10-04)`；TMO-028/029 維持 `todo`）＋ 表下「狀態定義」註（TMO-026 引入 BACKLOG-005 新紅的修法）|

### 驗收證據

- Gate 1（紅→綠）：`dav-planner-user-background` 4 紅/3 綠 → **0 紅/6 綠**；`restruct-dav-planner` 1 紅/12 綠 → **0 紅/13 綠**
- Gate 2：`bash -n` rc=0、`shellcheck` rc=0、`bats` 0 parse warning（測試名全 ASCII）
- Gate 3：`bats tests/` **1 not ok / 496 ok（宣告 497 / 實跑 497）**；集合差 **已修 5 / 新增 0**；剩 1 紅 = TMO-028
- 突變 11 次（全還原後回綠）：M1' SKILL +§2.7 用戶背景收集→2 紅、M7 reference +角色詢問→2 紅、
  M8 `reference.md` 被刪/改名→**1 紅**（P2-1 堵漏，修前為 0 紅）、M9 主題無關的合法 `§2.7` 編號→**0 紅**（P2-2，修前會誤紅）、
  M2 +PM/PO→1 紅、M3' 兩處定位句皆移除→2 紅、M4 v1.9 列「已廢棄」→1 紅、M5 全域 changelog→1 紅、M6 v2.1 列→1 紅、
  **M10 同內容換編號（`§3.5`）貼回→2 紅**（證 P2-2 替換屬覆蓋更廣）、**M11 同義詞改詞回流→0 紅**（已知缺口，進 TMO-032）
- Gate 4（V03.6 二審 **2 輪**）：第 1 輪（主體）**approve-with-comments / risk low / 0 P0 / 1 P1 / 4 P2**
  （P1 = 原始輸出未貼、P2-1 = refute 假綠、P2-2 = §2.7 誤紅、P2-3/P2-4 = 麵包屑與舊步驟名）；
  第 2 輪（delta，採納 P2-1/P2-2 後、依 reviewer 明示條件重開審）**approve-with-comments / risk low / 0 P0 / 0 P1 / 3 P2**
  （P2-a helper 假綠未根除、P2-b SKILL.md 變動歷史段會誤紅、P2-c 本檔帳目小誤）→ 全 report-only，折入 TMO-032，**不建議第三輪**

### 已知問題（本輪未處理，已切票）

- TMO-030：`docs/prd/02-dav-planner-user-background.md` / `docs/prd/03:104` / backlog TMO-007 詳細段仍把 §2.7 寫成現行規格
- TMO-031：`skills/dav-planner/SKILL.md:73` 殘留舊步驟名（「背景收集 / 最終目的」；pre-existing，v2.6 引入 Step 1.5 時即如此）
- TMO-032：探針精準化（第 2 輪 P2-a/P2-b 折入）— ① `refute_file_contains` helper 內加 `[[ -f "$p" ]]` 根除整類假綠；② `SKILL.md` 變動歷史段（`:119-138`）會被「撤銷章節不抹去」政策誤紅 → 負向斷言改掃 body（排除 `^| v` 列）；③ `dav-planner-user-background.bats` v1.9 條目仍為 whole-file grep；④ `BACKLOG-005` regex 是小寫 `pending`，大寫 `PENDING` 會漏抓；⑤ M11 缺口：同義詞改詞回流（不動定位句）目前抓不到
- **自首**：TMO-026 的 commit `3639d00` 在 backlog 加票時用了 `pending`，引入 `BACKLOG-005` 新紅（不在 TMO-026 Gate 3 證據內）；本輪發現並修掉，**不改探針**

### 反思

- **「紅燈」有三種病：探針過期 / 守著已廢棄功能 / 產品缺陷**。把三者一起「弄綠」= 偷刪「廢棄功能的守門人」；本輪只治第二種，且用「負向斷言 + 廢除紀錄錨定」把守門人升級成「防回流」。
- **廢棄守門要能咬人，必須三件套**：①功能字串不得回流 ②「為什麼廢除」的定位句必須留著 ③廢除紀錄必須留著。少任何一件，後人都可能「善意補回」。
- **負向斷言天生有假綠風險**：`grep` 對不存在的檔案 rc=2 → `refute` 回 0（PASS）。守門必須配**正向錨定**（reviewer P2-1 抓到，本輪修掉）。
- **守門標的要用「主題」而非「編號」**：`§2.7` 這種編號在 `§2.1–§2.6` 序列裡必然會被合法用到（P2-2），用編號當負向標的會製造未來誤紅。
- **別讓自己的行政動作製造新紅**：TMO-026 加票用 `pending` 撞上 BACKLOG-005；修法是「明列狀態定義 + 不動探針」，而不是放寬探針。

## TMO-028 詳細（dav-wiki 主檔瘦身 + 版本漂移鎖）

### 病因與處置

- `skills/dav-wiki/SKILL.md` 151 行 > 硬上限 150 → `tests/dav-wiki.bats` AC-2 恆紅（TMO-027 後全套唯一 1 紅）。
- 依 `skills/dav-skill-creater/editor-guide.md:102`（V03.5）「主檔 ≥150 → **必先瘦身至 ≤130 行**」，
  本輪做**內容無損外移**（細節進同 skill 子檔、主檔留導航 + 指針），不是「151 → 150 剛好過關」。

### 變更清單

| 檔 | 改動 |
| --- | --- |
| `skills/dav-wiki/SKILL.md` | 151 → **129 行**；`## 輸出結構` 樹狀圖 → 1 行指針；`## Trust 整合` 表格 → 1 條 bullet（同義）；`## 軟刪除規則` → 1 行摘要 + 指針；尾端重複 `---` 收斂；`## 變動歷史` +v2.2 列；`:107` 122 → 118 字元 |
| `skills/dav-wiki/output-structure.md` | 新增：樹狀圖（**逐字搬移**，diff 為空）+ 各節點用途表 |
| `skills/dav-wiki/soft-delete.md` | 新增：軟刪除規則（重組 + 補充；CLI 參數逐項對照 `wiki-cleanup.sh` usage 驗證） |
| `skills/dav-wiki/CHANGELOG.md` | 補 v2.2 列（原本缺，與主檔對齊） |
| `tests/restruct-dav-wiki.bats` | **+1 條**指標存在探針（防空過 `found >= 4`）；既有「變動歷史」測試**追加**版本漂移鎖（未新增測試條數） |
| `docs/deliverable/2026-10-04-tmo-028-dav-wiki-slim.md` | 本輪交付詳錄 |

### 驗收證據

- Gate 1（紅→綠）：`not ok 42 AC-2: SKILL.md is at most 150 lines`（151 行）→ `ok 6`（129 行）
- Gate 1（突變，全還原後回綠）：M-a 刪 `output-structure.md` → 1 紅；M-b 指標改裸名 → 1 紅（`found 3`）；
  M-c 主檔 v2.3 → 1 紅；M-d CHANGELOG v2.4 → 1 紅（c/d 皆 bats 級原始輸出）
- Gate 2：`markdownlint-cli2 skills/dav-wiki/*.md` = 2 error（`:10`/`:18`，與 HEAD 逐字相同 → 零新增 lint 債）
- Gate 3：`bats tests/` **0 not ok / 498 ok（宣告 498 / 實跑 498）**；集合差 已修 1 / 新增 0
- Gate 4（V03 + V03.6 二審 **2 輪**）：第 1 輪 **approve-with-comments / risk low / 0 P0 / 0 P1 / 6 P2**
  （判「真瘦身」、判「加嚴非放寬」；Q3 建議本輪補漂移鎖）；第 2 輪 delta **approve-with-comments / risk low /
  0 P0 / 0 P1 / 4 P2**、**明示不需第三輪**（並給出四個重審觸發條件）

### 已知問題（已切票）

- TMO-033 子檔內容錨點、TMO-034 四處同源死引用、TMO-035 `SKILL.md:94-95` 降級條款 vs `require_tool()` 硬 `exit 4`
  （首次立票；觀察早已在 `:771` 卻無票）、TMO-036 跨目錄探針動詞表缺口
- P2-2（漂移鎖訊息不可診斷，屬 fail-closed）→ 折入 TMO-032，dav-planner / regression-guard 三檔一起改

### 反思

- **行數上限要的是分層，不是砍字**：只砍重複 `---` 過關，下個小改動又撞牆；細節外移才是結構性降注意力成本。
- **搬移要能被證明是搬移**：`git show HEAD:…` 抽舊樹狀圖 vs 新子檔 fence 做 `diff` 得空輸出才算證據。
- **負向與空值都有假綠**：新探針 `found >= 4` 擋「擷取失效 → 0 筆」；漂移鎖 `[ -n "$v_skill" ]` 擋「兩側抽空 → `"" = ""`」。
- **最安靜的債是缺鎖**：dav-wiki 是三個拆檔家族中最後一個補上版本漂移鎖的 skill。
- **自傷當場說**：`git checkout` 誤還原整份瘦身（已重做）、`"v2\.0"` 誤打成 `"v\.0"`（已修回）—— 兩者皆未進最終 diff，仍主動揭露。

## TMO-029 詳細（venv bootstrap：CI 真的會跑 + 一行建環境 + 缺環境大聲紅）

### 背景（為什麼要做）

`tests/v2.1-jev-poc.bats` 有 38 條測試依賴 PoC venv（httpx / PyYAML）。
HEAD（`93ba04f`）狀態下：

1. **CI 從未真正執行**：`ci.yml` 只寫 `branches: [main]`，但 repo 預設分支是 `master` → push 從不觸發；`test` job 也從未安裝 httpx / PyYAML。
2. **clean clone 無法自己站起來**：repo 內沒有 requirements / setup 腳本，env 只在開發者腦中。
3. **缺環境時不是大聲紅而是噪音**：38 條會以 `command not found`（127）各自失敗，看不出是「環境沒建」還是「程式壞了」。

### 這一票做了什麼

| 檔 | 改動 |
| --- | --- |
| `skills/regression-guard/PoC/requirements.txt` | **新增**：`httpx>=0.27,<1` + `PyYAML>=6.0`（上下界都鎖）＋範圍聲明註解（本票只涵蓋 column-0 import）|
| `skills/regression-guard/PoC/setup-venv.sh` | **新增**（uv 優先、`python3 -m venv` + `ensurepip` 退路、`--force`、`POC_VENV_DIR` 測試縫、危險值護欄）|
| `skills/regression-guard/PoC/.gitignore` | 加 `.venv/`（uv 建的 venv 自帶 `*`，`python3 -m venv` 建的沒有）|
| `skills/regression-guard/PoC/README.md` | 安裝步驟改 `bash setup-venv.sh`；目錄樹補兩個新檔 |
| `.github/workflows/ci.yml` | triggers 加 `workflow_dispatch`；`push`/`pull_request` 分支 `[main, master]`；test job 加 `Build PoC venv` 步驟（排在 `bats tests/` 前）；lint-only 加 `continue-on-error: true`（→ TMO-037）|
| `.markdownlint-cli2.jsonc` | **新增**：ignores `**/.venv/**`、`**/node_modules/**`（venv 在 `skills/**` 內，site-packages 的 LICENSE.md 會被撈進來）|
| `tests/poc-bootstrap.bats` | **新增 8 條探針**（見下）|
| `tests/v2.1-jev-poc.bats` | 38 條 venv-dependent 測試加 `need_poc_venv()`（缺 venv → 一條清楚的紅＋修復指令，不再 38 條 127）；新增 `make_us101_run()` 讓 M6-g / M6.1-c 真的跑；flaky-d 先清 `/tmp` 殘檔 |
| `README.md` | 移除數字 badge（bats `209/209`、markdownlint `0 issues` 皆無鎖且已失真）→ 只留 CI run badge |
| `docs/install-reference.md` | 更正依賴說明：**38 / 98 條需 venv，其餘 60 條純靜態**（原誤寫「98 條全紅」）|

### 探針設計（`tests/poc-bootstrap.bats`，8 條）

| # | 鎖什麼 | 反空過設計 |
| --- | --- | --- |
| 1 | `requirements.txt` 涵蓋 PoC 腳本所有 column-0 非 stdlib import | `-ge 2` 防空過；範圍外（縮排／子目錄）明示 → TMO-038 |
| 2 | `setup-venv.sh` 存在、可執行、且真的從 `requirements.txt` 安裝 | 指名檔案（改讀 deps.txt 即紅）|
| 3 | uv 缺席時走 `python3 -m venv` 退路 | **真跑**：PATH 只放 shim、`POC_VENV_DIR` 導向暫存；斷言 `-m venv` 與 `-m pip install` 都在呼叫記錄內 |
| 4 | 每條 venv-dependent 測試都有 `need_poc_venv` | 靜態不變式（用到 `$PY`／helper 的測試數 == 有守門的測試數）＋ 同檔 `skip` 數必須 0 |
| 5 | `.venv` 被 gitignore | `git check-ignore` 行為驗證（非只看字串）|
| 6 | 可疑 `POC_VENV_DIR` 必須拒絕 | 9 個壞值（含 `/tmp/`、`//`、`/tmp/..`、`/tmp/.` 等價寫法）＋ 深層路徑正向對照；刻意不帶 `--force` |
| 7 | 護欄必須排在 `rm -rf` 之前 | 行號靜態比較（註解行已用 `^[^#]` 排除）|
| 8 | CI 在 `master` 觸發、且用 `setup-venv.sh` 建 venv | PyYAML 語意斷言 → TMO-038 |

### 驗收證據

- Gate 1（紅→綠）：`FAIL: 缺 PoC venv`（127 噪音）→ 38 條各自一條清楚紅；新探針 8 條紅→綠；突變 M10–M27c 逐條咬（含 M14 不咬 → TMO-038、M26b 咬 `/tmp/` 繞道）
- Gate 2：`shellcheck` rc=0、`bash -n` rc=0、`markdownlint` 改動檔 0 issue（`PoC/README.md` 3 issue 為既有，`git show HEAD:` 對照證明零新增）、PyYAML 解析 `ci.yml` 語意正確
- Gate 3：`bats tests/` **0 not ok / 506 ok / 0 skip**；隱藏 venv → **38 not ok / 468 ok / 0 skip / 0 個 `command not found`**
- Gate 4（V03.6 二審 **4 輪**）：R1 approve-with-comments（0 P0 / 1 P1 / 11 P2）→ R2（0/1/7）→ R3（0/2/4，抓出 `/tmp/` 繞過護欄）→ R4 **approve-with-comments / risk low / 0 P0 / 0 P1 / 3 P2**，並明示「可進入 §2.5」

### 已知問題（已切票）

- TMO-037 lint 債 246 處（lint-only 暫 `continue-on-error`，清完須移除）
- TMO-038 探針①④⑤ 範圍與語意強化
- TMO-039 首次真實 Actions 驗證（本機不可驗）
- TMO-040 護欄設計邊界（合法深層絕對路徑 + `--force`）

### 反思

- **「測試很多」不等於「測試會跑」**：真正致命的是 CI 從未觸發（`branches: [main]` vs 預設分支 `master`）—— 一個字的設定讓 209 條測試整年沒跑。
- **缺環境要大聲紅、不要噪音**：38 條 127 噪音會讓人以為「測試壞了」；改成每條一條清楚的紅＋修復指令，才指得動人。
- **假綠有兩種**：`skip`（永遠不跑）與空過斷言（跑了但什麼都沒驗）。本票各抓到一批，並用「本檔 skip 數必須 0」與「不變式等號」把它們鎖住。
- **護欄會寫錯，而且會錯在等價寫法**：`/tmp` 擋住了、`/tmp/` 卻繞過去（`case` 的 `*` 可跨 `/`）；是第 3 輪 reviewer 抓到的。教訓：**安全性檢查要拿「同義寫法矩陣」來測**，不是測一個代表值。
- **自傷當場說**：M10 第一次是假突變（awk 語法錯把檔案清空）、M17 第一次沒命中卻意外揭露探針③只是字串形狀、探針③第一版誤紅、`$status（` 全形括號 bug、以及**用 `git checkout` 還原突變時誤刪未 commit 的整批編輯**（已重做並改用 `cp` 備份）——四件事全部寫進證據包，其中最後一件由 reviewer 反向查出兩處漏補。
