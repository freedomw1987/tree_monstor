# Backlog — tree_monstor 5 條優化（Trust Mode）

> 來源：2026-09-23 用戶對話「in tree_monstor 現在你覺得什麼地方可以優化？」→「全部 #1 至 #5 都做」
> 模式：Trust Mode（deadline 2026-09-23 10:03）

---

## Backlog 清單

| ID | 主題 | 優先級 | 點數 | 狀態 | 依賴 |
|----|------|--------|------|------|------|
| TMO-001 | 清 .gitignore RSI 殘留 + 刪 .agents/tree_monstor/ 髒副本 | P0 | 1 | pending | — |
| TMO-002 | install.sh 拆 lib/install/*.sh 子模組 | P1 | 5 | pending | TMO-001 |
| TMO-003 | 補缺 wiki bats + 修 README badge 數字 | P2 | 3 | pending | TMO-002 |
| TMO-004 | AGENTS.md §2.0/§2.6 重構 + Reviewer 二審 | P0 | 5 | pending | TMO-001 |
| TMO-005 | tools/ 統一 logging（修正版：trap + 共用 log_*） | P2 | 3 | done | TMO-001 |
| TMO-006 | dav-planner AC 範本獨立化 + HTML 版本 | P1 | 8 | done | TMO-001 |

---

## TMO-001 詳細

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

**問題**：993 行 install.sh 拆成主程式 + lib 子模組

**完成標準**：
- install.sh < 200 行只負責 args + dispatch
- lib/install/logging.sh / paths.sh / symlink.sh / agents.sh / sop.sh / agents_dir.sh / uninstall.sh
- 所有現有 bats 測試 100% 通過
- install --global / --local / --uninstall 行為不變

---

## TMO-003 詳細

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
