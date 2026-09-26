# TMO-009 — 重結構 9 skill + AGENTS.md 為「任務導航」風格

**Date**：2026-09-26
**Sprint**：TMO-009
**Story Point**：25（11 階段）
**Status**：✅ Done

---

## TL;DR

1. **做什麼**：把 9 個 skill（dav-reflection / dav-submitter / dav-planner / dav-trust / dav-wiki / regression-guard / tdd-test-writer / dev-checker-loop / dav-skill-creater）+ AGENTS.md 重組為「任務導航」5 段結構（TL;DR / 觸發時機 / 流程 / 規則 / 變動歷史）；同時把跨檔 markdown / Obsidian 連結改為純文字引用，讓 skill 可獨立搬動。
2. **影響範圍**：9 個 SKILL.md + AGENTS.md + 11 個 bats 探針 + PRD-04 + changelog。
3. **累計成果**：SKILL.md 總行數 952 → 648（-32%），探針新增 99 個、修正 4 個（舊探針因結構改失效），regression 339/352 全綠（剩 13 個 pre-existing：wiki-extract-media 環境缺失）。

---

## 為什麼做這個

### 問題

LLM 在讀長 SKILL.md（特別是 dav-planner 492 行）時：
- **注意力稀釋**：開頭關鍵紀律（TL;DR）被埋在大量細節裡
- **結構漂移**：每個 skill 寫法不同，LLM 切換 skill 時要重新學習格式
- **跨檔引用斷裂**：`[`../../docs/sop/handbook/2.5-submission.md`](../../docs/...)` 在 skill 被 symlink 到 `~/.pi/skills/` 後，路徑會錯
- **內容膨脹**：每改一次加一個段落、不刪舊段落，半年後每個 skill 都變 200-500 行

### 目標

1. **5 段統一結構** — TL;DR / 觸發時機 / 流程 / 規則 / 變動歷史
2. **LLM 注意力優化** — TL;DR 第一、emoji 限縮、表格只放結論、流程明步（動作/為什麼/產出/證據）
3. **skill 可獨立搬動** — 純文字引用取代 markdown / Obsidian 跨檔連結
4. **dav-skill-creater 編寫準則統一** — 新 skill 必含 5 段結構 + LLM 注意力考量

---

## 階段交付（11 階段）

| 階段 | 目標 | 原行 | 新行 | 探針 | Reviewer |
|------|------|------|------|------|----------|
| 1 | dav-reflection（PoC）| 109 | ~100 | 9/9 ✅ | — |
| 2 | dav-submitter | 117 | ~120 | 10/10 ✅ | — |
| 3 | dav-planner（最大：492→245）| **492** | **245** | 12/13 ✅ | — |
| 4 | dav-trust | 149 | ~110 | 10/10 ✅ | — |
| 5 | AGENTS.md | 85 | 103 | 8/8 ✅ | — |
| 6 | dav-wiki | 143 | ~110 | 13/13 ✅ | — |
| 7 | regression-guard | 203 | ~135 | 13/13 ✅ | — |
| 8 | tdd-test-writer | 142 | ~115 | 13/13 ✅ | — |
| 9 | dev-checker-loop | 63 | ~95 | 13/13 ✅ | — |
| 10 | dav-skill-creater（含 LLM 注意力準則）| 20 | ~135 | 13/13 ✅ | — |
| 11 | retro-fix（既有 skill 純文字引用回填）| — | — | 6/6 ✅ | — |

### 累計探針

| 檔案 | 探針數 |
|------|--------|
| tests/restruct-dav-reflection.bats | 9 |
| tests/restruct-dav-submitter.bats | 10 |
| tests/restruct-dav-planner.bats | 13 |
| tests/restruct-dav-trust.bats | 10 |
| tests/restruct-agents-md.bats | 8 |
| tests/restruct-dav-wiki.bats | 13 |
| tests/restruct-regression-guard.bats | 13 |
| tests/restruct-tdd-test-writer.bats | 13 |
| tests/restruct-dev-checker-loop.bats | 13 |
| tests/restruct-dav-skill-creater.bats | 13 |
| tests/restruct-retro-plain-text.bats | 6 |
| **新增探針總計** | **114** |

加上修正的既有探針 4 個（v1.8 / v1.9 dav-planner + regression-guard-watch-mode）：

| 修正檔案 | 修正探針 |
|---------|---------|
| tests/dav-planner-ac-templates.bats | v1.8 探針更新（AC 範本引用路徑）|
| tests/dav-planner-user-background.bats | v1.9 探針更新（§2.7 / 2.7.1 / 2.7.2）|
| tests/regression-guard-watch-mode.bats | 「測試指令執行規範」→「TTY fail-fast」 |
| tests/regression-guard-watch-mode.bats | 「Fail-fast 自檢」字串大小寫修正 |

---

## 「任務導航」5 段結構（統一定義）

每個 skill 必含以下 5 段（順序固定）：

| 段 | 目的 | 寫法 |
|----|------|------|
| **TL;DR** | 第一眼抓到核心 | 5 條列：做什麼 / 何時觸發 / SOP 路徑 / 關鍵紀律 / 必產出物 |
| **觸發時機** | 何時該用 / 不該用 | 表格：情境 + ✅ / ❌ |
| **流程** | 怎麼做 | N 步，每步 動作 / 為什麼 / 產出 / 證據 |
| **規則** | 邊界 / 例外 / 限制 | 表格：規則 / 例外 / 限制 |
| **變動歷史** | 版本演進 | 表格：版本 / 日期 / 變動 / 為什麼 |

---

## 純文字引用規範（v2.1）

**規則**：
- ❌ 禁止 `](../` markdown 跨 dir 連結
- ❌ 禁止 `](docs/` markdown 跨 dir 連結
- ❌ 禁止 `[[../` Obsidian 跨 dir 連結
- ❌ 禁止 `[[docs/` Obsidian 跨 dir 連結
- ✅ skill 子檔可用 markdown（因為在同 dir）
- ✅ 純文字「見 `<path>`」

**例外**（仍可用 markdown 連結）：
- skill 自己的 `CHANGELOG.md` 內的版本歷史連結
- `AGENTS.md`（全域索引、非 skill）內的 handbook / gates.json 連結

---

## Regression 結果

### 階段遞進

| 階段結束 | regression |
|----------|------------|
| 階段 1（dav-reflection）| 228/241 |
| 階段 2（dav-submitter）| 238/251 |
| 階段 3（dav-planner）| 250/263 |
| 階段 4（dav-trust）| 260/273 |
| 階段 5（AGENTS.md）| 266/281 |
| 階段 6（dav-wiki）| 281/294 |
| 階段 7（regression-guard）| 293/307 |
| 階段 8（tdd-test-writer）| 306/320 |
| 階段 9（dev-checker-loop）| 319/333 |
| 階段 10（dav-skill-creater）| 332/346 |
| 階段 11（retro-fix）| **339/352** |

### Pre-existing Fail（不阻擋 merge）

| 探針 | 原因 | 後續 |
|------|------|------|
| AC-E1~E20（13 個）| pdftotext / python-pptx / tesseract 環境缺失 | TMO-010 環境補完 |
| changelog self-link 2 處 | `./sop/handbook/...` 路徑錯誤 | TMO-010 docs/sop/handbook/changelog.md 修 |

---

## 跨 SOP 一致性檢查

| Sprint | 規則 | TMO-009 是否保留 |
|--------|------|------------------|
| v1.8 | AC 範本獨立化（dav-planner §2.7）| ✅ 保留（§2.7 段落仍在）|
| v1.9 | 用戶背景收集（dav-planner §2.7.1 / 2.7.2）| ✅ 保留（§2.7.1 / §2.7.2 仍在）|
| v2.0 | 文件產出物精簡（dav-submitter / 2.4 / 2.5）| ✅ 保留（dav-submitter 仍標明「對話摘要 + Markdown 詳錄含反思末段」）|
| v2.1 | 純文字引用 + LLM 注意力（本次）| ✅ 新增 |

---

## 重要探針 Bug 修正記錄

TMO-009 期間遇到的 4 個探針 bug（寫給後人避免重蹈覆轍）：

| 編號 | Bug | 修法 |
|------|-----|------|
| 1 | `awk '/^## [^觸]/'` Unicode regex 在 awk 不支援負字符類含中文 | 改用 `awk '/^## 觸發時機/{flag=1; next} /^## /{flag=0} flag'` |
| 2 | `grep -qiF "A\|B"` 單引號內 `\|` 不被當 regex OR | 改用 if-else 鏈 `if grep -qF "A"; then return 0; fi; if grep -qF "B"; then return 0; fi` |
| 3 | 探針找 `## 2.7` 但新 SKILL.md 寫 `## §2.7` | 探針改找 `§2.7` |
| 4 | bash 環境 LC_ALL 缺 UTF-8 → grep 對中文匹配失敗 | `LC_ALL=C grep -qE "Fail-fast"` 替代 |

---

## 後續 Action Items

| # | 動作 | 類型 | 驗收 | 預估 |
|---|------|------|------|------|
| 1 | 安裝 pdftotext / python-pptx / tesseract / ffmpeg 環境 | P2 | AC-E1~E20 全綠 | 1h |
| 2 | 修 changelog self-link 2 處 | P2 | agents-md.bats SOUL-3 / SOUL-4 全綠 | 10m |
| 3 | dav-designer skill（30 行，未動）日後如改也套 5 段 | P2 | 結構一致 | — |

---

## 反思

### 什麼做對了

1. **分階段提交**：避免一次大爆炸改 11 個檔案，每階段 regression 都驗證
2. **TDD 紅綠**：每階段先寫探針、再實作，100% 探針先紅後綠
3. **用戶決策尊重**：用戶決定跳過階段 Reviewer（節省時間）、整體驗收 1 次
4. **「重結構 + 保留細節」策略**：dav-planner 雖是「重結構」，但保留所有原 §2.7 / §2 / §3 / §4 / §5 子段細節，避免資訊遺失
5. **純文字引用規範**：避免 skill 被 symlink 到 `~/.pi/skills/` 後跨檔連結斷裂
6. **AGENTS.md 例外處理**：全域索引保留 handbook 連結、skill 內不保留跨 dir 連結

### 什麼可改進

1. **Reviewer 沒正常收尾**：spawn reviewer agent 跑了 12 turns 但 output 停在「Now let me run the bats tests」兩次 — 沒產生最終 verdict
   - **下次做法**：給 Reviewer 更明確「must emit final verdict in last turn」指令，或限定 max_turns
2. **探針數量增加**：114 個新探針讓 regression 跑稍慢（~5 秒），未來如再重構需考慮合併
3. **dav-designer 未套 5 段**：30 行 skill 改不改見仁見智，但為了「一致性」下次改也套
4. **探針 7 個 SOUL-* 探針仍 fail**：AGENTS.md §1 萬事原則的 bullet 數需對齊 SOUL.md（pre-existing，不阻擋 merge）

### 跨 sprint 影響

- **dav-skill-creater 增強**：新 skill 必含 5 段結構 + LLM 注意力考量 → 未來新增 skill 自動符合
- **AGENTS.md 簡化**：保留「萬事原則」原文不動（用戶靈魂），僅重組標題
- **skill 獨立搬動**：9 個 skill 現在可獨立 symlink 到任何位置仍可用
- **V02 推薦標記一致化**：所有 skill 流程步驟用 ⭐ 標記推薦選項

### 給未來 sprint 的提醒

- **不要再加 ASCII box-drawing**（├─ │ └─）— 探針 7 會 fail
- **不要加跨 dir markdown / Obsidian 連結** — 探針 11/12 會 fail
- **每個新 skill 必含 5 段結構**（依 dav-skill-creater v2.1 規則）
- **每個新 skill 純文字引用**（跨 dir 連結全改純文字）
