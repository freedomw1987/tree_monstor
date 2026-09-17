# Sprint 04 計劃 — dav-wiki 優化（2026-01-15）

> **Sprint 主題**：讓剛完工的 `dav-wiki` skill 從「規格通過」走到「實戰驗證 + 兩個 P1 技術債清除」
> **總 SP**：5-6 SP（中等）
> **前置**：US-009 ✅ DONE

## 1. Sprint 目標

把 US-009 完工的 `dav-wiki` skill：
1. **跑過 1 個真實場景**（驗證 7 步流程不會卡住）
2. **清掉 2 個 P1 技術債**（TD-019 軟刪除 + TD-020 交叉引用）

## 2. Sprint Backlog

| ID | 標題 | SP | 優先級 | 依賴 |
| --- | --- | --- | --- | --- |
| **US-010** | dav-wiki 實戰測試（PDF + URL） | 2 | P0 | US-009 ✅ |
| **TD-019** | 軟刪除磁碟清理機制 | 1.5 | P1 | US-010 揭露問題 |
| **TD-020** | 交叉引用品質改善 | 1.5 | P1 | US-010 揭露問題 |

### US-010：dav-wiki 實戰測試

**User Story**：
> **作為** tree_monstor 的使用者，
> **我想要** 拿真實的文件（1 個 PDF + 1 個 URL）跑 `dav-wiki` 流程，
> **以便** 驗證 7 步流程順暢、不會卡在某一個步驟，且產出的 wiki 真的有價值。

**驗收標準（AC）**：
- [ ] AC-1：拿 1 個真實 PDF（如某篇技術文章 PDF）跑 dav-wiki，順利完成 7 步，產出 1 篇 wiki + 1-5 個概念
- [ ] AC-2：拿 1 個真實 URL（如某個網頁）跑 dav-wiki，順利完成 7 步
- [ ] AC-3：發現 ≥ 2 個「規格沒說清楚」的問題（如 Category 建議給得不準、Tag 提取不夠好、概念提取太寬或太窄）
- [ ] AC-4：每個發現的問題登記成 TD 或更新 SKILL.md / frontmatter-schema.md
- [ ] AC-5：產出 smoke-test 紀錄文件（`docs/wiki/_smoke-test-2026-01-15.md` 或 deliverable）

**執行細節**：
- 跑在 `/tmp/dav-wiki-smoke/`（隔離真實 docs/wiki/）
- 兩個測試情境：
  - **PDF**：用既有的某份 PDF（如 `tests/fixtures/mock-tree-monstor/` 內，或自己找一份）
  - **URL**：用某個技術網頁（如 Wikipedia 或 React 官網）
- 結果寫進 `docs/deliverable/2026-01-15-us-010-smoke-test.md`

---

### TD-019：軟刪除磁碟清理機制

**User Story**：
> **作為** tree_monstor 的使用者，
> **我想要** 一個清理工具，把 `deprecated` 標記超過 N 天的檔案移到 `docs/wiki/_deprecated/` 子目錄隔離（或真正清理），
> **以便** 不會無限堆積過時 wiki 檔，又不會誤刪可追溯的歷史。

**問題**：
- US-009 reflection §2.3 揭露：deprecated 檔案永遠保留，無磁碟清理機制
- 風險：長期下來 `docs/wiki/` 會累積很多「過時但沒人看」的檔案

**提案方案**（請用戶選）：
1. **方案 A（推薦）**：保留檔案但移到 `docs/wiki/_deprecated/{YYYY-MM}/{title}.md`，從 `_index.json` 移除，加 `_deprecated/_index.json` 反向索引
2. **方案 B**：保留原位置，加 CLI `tools/wiki-cleanup.sh` 讓用戶手動清理（保留 N 天前的）
3. **方案 C**：每次 task 結束時自動清理 N 天前的 deprecated（需用戶設定 N）

**驗收標準（AC）**：
- [ ] AC-1：`docs/sop/handbook/dav-wiki-cleanup.md` 紀錄清理規則
- [ ] AC-2：`tools/wiki-cleanup.sh` CLI 實作（互動式 + `--dry-run` + `--older-than <days>`）
- [ ] AC-3：`tests/wiki-cleanup.bats` ≥ 5 個測試案例
- [ ] AC-4：dav-wiki SKILL.md §軟刪除章節更新，提到清理機制
- [ ] AC-5：`bats tests/` 全套不退步（76 → 81+）

---

### TD-020：交叉引用品質改善

**User Story**：
> **作為** tree_monstor 的使用者，
> **我想要** dav-wiki 的交叉引用更精準（不只看 tag，也看 summary 關鍵詞），
> **以便** 推薦的相關文件真的「相關」，而非只是 tag 重疊。

**問題**：
- US-009 reflection §2.3 揭露：`_index.json` 只有 `tags` 可比對，純 tag 比對容易推薦「tag 一樣但主題不同」的文件
- TD-020 已在 backlog 登記

**提案方案**：
1. **`_index.json` 結構擴充**：每個文件加 `keywords: [string]` 欄位（從 summary 提取 3-5 個關鍵詞）
2. **比對演算法**：tag 重疊 50% + keywords 重疊 ≥ 1 個才算相關
3. **`frontmatter-schema.md` 更新**：加 `keywords` 欄位規範

**驗收標準（AC）**：
- [ ] AC-1：`frontmatter-schema.md` §1.2 加 `keywords: string[]` 必填欄位（3-5 個、從 summary 提取）
- [ ] AC-2：`_index.json` schema 更新，含 keywords 欄位
- [ ] AC-3：`tests/wiki-cross-ref.bats` ≥ 4 個測試案例（驗證比對演算法）
- [ ] AC-4：dav-wiki SKILL.md §[5] 交叉引用章節更新演算法說明
- [ ] AC-5：examples.md 例 2（URL → wiki）補 keywords 提取步驟
- [ ] AC-6：既有 dav-wiki tests 全綠

---

## 3. 執行順序

```
[1] US-010 實戰測試（產出真實問題清單）
    ↓
[2] TD-019（基於 US-010 揭露問題 A：磁碟清理）
    ↓
[3] TD-020（基於 US-010 揭露問題 B：交叉引用品質）
    ↓
[4] Sprint 04 reflection + submitter
```

## 4. 風險

| 風險 | 影響 | 緩解 |
| --- | --- | --- |
| 真實 PDF / URL 跑 dav-wiki 時卡在某步 | US-010 可能拉長 | 用 fixture PDF 先測，跑通再上真實 |
| TD-019 清理策略與用戶預期不同 | 可能要返工 | 進執行階段前先跟用戶確認 A/B/C 方案 |
| TD-020 比對演算法設計錯誤 | 反而推薦不準 | 寫 4+ 測試案例覆蓋正反情境 |

## 5. 成功指標

- US-010 AC-1 ~ AC-5 全部 ✅
- TD-019、TD-020 標記 ✅
- `bats tests/` 全套不退步（76 → 81+）
- Sprint 04 reflection 報告 + deliverable 產出

---

## 6. 對話記錄（補充）

- 用戶決策：2026-01-15 選擇 dav-wiki 優化 Sprint（A 方案）
- 規劃模式：dav-planner（單輪決策，不需探索）
- 計劃產出：本檔 + 對應 backlog 更新