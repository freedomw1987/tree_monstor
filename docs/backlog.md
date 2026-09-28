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
