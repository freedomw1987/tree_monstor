# 交付：dav-planner v2.6 引入 dav-wiki（Step 1.5「來源抽取」可選步驟）

| 項目 | 值 |
|------|-----|
| 日期 | 2026-09-26 |
| 對應 Backlog | TD-020（dav-planner 引入 dav-wiki）|
| Module | dav-planner（單一 skill）|
| Reviewer verdict | 🟡 修正後通過（3 P1 + 5 P2，8 項全修正）|
| V03 觸發 | ✅ 是 |

---

## 1. 為什麼做這個改動

### 1.1 問題

dav-planner v2.5 規劃階段只有「Step 1 背景收集（靠用戶口述）」。**複雜任務**（多文件 / 多來源 / 未來會多次更新）有以下痛點：
- **重複抄寫**：每次更新都要人工重讀 PDF / DOCX
- **易遺漏**：規劃時漏讀關鍵段落 → 後續階段才發現 → 返工
- **來源不可追溯**：未來某 US 要更新時，找不回原始來源

### 1.2 為什麼用 dav-wiki

dav-wiki 已是 monorepo skill、**功能完全對應需求**：
> 統一文件資料提取與 Markdown 化。支援純文字、PDF/DOCX/PPTX、網頁 URL、圖片 OCR、影音字幕等多種來源，自動轉成結構化 Markdown 知識庫（含 frontmatter、tag、概念、交叉引用）。

讓 dav-planner 調用 dav-wiki → 結構化 Markdown → dav-planner 讀該 Markdown → 規劃。**未來需求更新時**重新跑同一流程 → 自動標記「哪幾個 US 受影響」。

### 1.3 為什麼用「Step 1.5 可選」不是「強制 Step 1」

| 形式 | 優點 | 缺點 |
|------|------|------|
| 強制 Step 1 | 一致性高 | 簡單任務變慢、dav-wiki 變耦合依賴 |
| **Step 1.5 可選（推薦）** | 觸發條件明確、軟引用 dav-wiki | 用戶自判「複雜 vs 簡單」|
| 拆 sub-skill | 主檔不變 | 讀者不知道何時讀 |

---

## 2. 做了什麼

### 2.1 改動範圍總覽

| 類型 | 數量 | 細節 |
|------|------|------|
| SKILL.md 新章節 | 1 | Step 1.5「來源抽取（複雜開發任務可選）」|
| 觸發時機表新增 | 1 行 | 「複雜開發任務 → Step 1.5 推薦調用 dav-wiki」|
| 規則表新增 | 1 條 | 「複雜任務必走 Step 1.5」|
| 主檔變動歷史新增 | 1 條 | v2.6 |
| 主檔變動歷史瘦身 | v2.3 外移 | 觸發 v2.4 規範（> 3 條必外移）|
| CHANGELOG.md 新增 | 1 條 | v2.6（詳細紀錄）|
| 主檔行數變化 | 103 → 138 | +35 行（仍 < 150 上限 ✅）|

### 2.2 Step 1.5 完整內容

- **位置**：Step 1 後、Step 2 前觸發
- **觸發條件**（任一即符合「複雜任務」）：
  1. 既有文件分散在 monorepo `docs/` 多份檔案
  2. 來源檔案格式非 Markdown（PDF / DOCX / PPTX / URL）
  3. 需求來源跨多個工具（Obsidian / Notion / Confluence / GitHub Issues）
  4. 你預期未來會**多次更新需求**
  5. 既有 dav-wiki 知識庫已收錄相關概念（先 grep 再讀）
- **動作**：列來源 → 調用 dav-wiki（需同套安裝） → 回到 Step 1 附加來源清單
- **何時跳過**：用戶已提供結構化 Markdown / 簡單單檔任務 / 探索性原型
- **dav-wiki 未裝 fallback**：退回用戶口述 + 提示安裝（軟引用精神）

### 2.3 dav-submitter 之外的其他 skill 都不動

| 不動 | 為什麼 |
|------|-------|
| dav-wiki 本身 | 本次只引用、不動主檔 |
| 其他 4 個 skill | 不在變動範圍 |
| backlog 表格格式 | 用戶決策保留 |

---

## 3. Reviewer 二審 8 項修正

verdict-3 = 🟡 修正後通過，3 P1 + 5 P2 全部已修正：

| 編號 | 嚴重度 | 修正內容 |
|------|--------|----------|
| F1 | P1 | 變動歷史加 v2.6 後變 4 條 → v2.4 規範觸發：v2.3 條目外移到 CHANGELOG.md ✅ |
| F2 | P1 | v2.6「為什麼」補 V03 標記 + 依賴紀錄 ✅ |
| F3 | P1 | Step 1.5 觸發位置明示（Step 1 後、Step 2 前）✅ |
| F4 | P2 | 觸發條件加第 5 條「既有 dav-wiki 知識庫已收錄相關概念」✅ |
| F5 | P2 | Step 1.5「動作 3」措辭「改為」→「附加」（不取代口述）✅ |
| F6 | P2 | 規則表欄位改為「規則 / 例外 / 限制」（與既有慣例一致）✅ |
| F7 | P2 | 流程標題「4 階段」→「Step 1-5 + Step 1.5 可選」✅ |
| F8 | P2 | dav-wiki 未裝 fallback 行為明示 ✅ |

---

## 4. 驗收

| 探針 | 結果 |
|------|------|
| restruct-no-cross-dir-path.bats | ✅ 2/2 ok |
| check-examples-version-baseline.bats | ✅ 1/1 ok |
| **全部** | **3/3 ok ✅** |

| 5 項自驗收（dav-planner）| 結果 |
|----------|------|
| frontmatter（name + description）| ✅ name=1, desc=96 字 |
| 5 段任務導航 | ✅ |
| < 150 行 | ✅ 138 行 |
| 純文字引用（v2.2）| ✅ 0 違規 |
| description ≤ 200 字 | ✅ |

---

## 5. 反思

### 5.1 過程中發現的問題

1. **第一次 SKILL.md edit 失敗**（edit 工具合併衝突）
   - 第一個 edit 同時改兩處（觸發時機表 + 流程標題）失敗
   - **修正**：拆成 2 個 edit call
   - **教訓**：edit 工具的 `edits[]` 雖然支援批量，但若同時改兩處會有順序問題

2. **第二次 SKILL.md 變動歷史 edit 失敗**（oldText 不匹配）
   - 用「更新後」的內容做 oldText，但檔案還是舊的
   - **修正**：先讀檔確認內容、再 edit
   - **教訓**：edit 工具的 oldText 必須匹配「原始檔案內容」、不是「我預期內容」

3. **CHANGELOG.md 變動歷史 edit 第一次失敗**（oldText 用「原始內容」但前一次已 update）
   - 我先 edit SKILL.md 主檔，CHANGELOG 還沒改 → 第二次 edit CHANGELOG 用主檔新內容找 oldText 但 CHANGELOG 還是舊的
   - **修正**：讀 CHANGELOG 確認當前內容、用當前內容當 oldText
   - **教訓**：批次操作要小心狀態追蹤

### 5.2 規範層面的觀察

| # | 觀察 | 評估 |
|---|------|------|
| 1 | dav-planner 主檔 138/150 行，餘裕 12 行 | R4 殘留風險已實現、需監控 |
| 2 | Step 1.5 觸發條件 5 個 | 已涵蓋主要場景、未來視需要再加 |
| 3 | 「軟引用」dav-wiki 設計 | 符合「調用式而非耦合式」user 決策 |
| 4 | dav-wiki 獨立用在知識庫提取 | 用戶決策保持、不影響 |

### 5.3 自我反省

- **最大的反省**：對 edit 工具的狀態追蹤敏感度不夠。批次操作中間狀態容易出錯。
- **V03 觸發驗證**：本次走完「設計草案 → 用戶批准 → Reviewer 二審 → 修正後批准 → 套用 + 自驗收」完整鏈。Reviewer 抓到 8 項真實修正點（3 P1 + 5 P2），證明 V03 必要性。
- **協作效率**：本次任務約 6 輪對話（含 1 輪 Reviewer 背景跑）— 比 skill 自包含化任務有效率。原因：變動範圍小（單一 skill）、規範邊界明確（v2.6 已有先例 v2.5）。
- **軟引用設計**：依用戶決策「dav-planner 調用時才採用、dav-wiki 也會獨立去用」，實作為 Step 1.5 可選步驟 + 未裝 fallback，未來 dav-wiki 變動不會拖累 dav-planner。

### 5.4 給未來的建議

1. **未來若 dav-wiki 大改**：每季跑 1 次「引用同步檢查」（R1 緩解）
2. **「複雜任務」判斷無量化指標**：未來可加「SP > 13 必走 Step 1.5」自動化（R2 緩解）
3. **dav-wiki 抽取品質不穩定**：用戶跳過 Step 1 複查則品質無法保證 → 未來 dav-planner 可加 Step 1.5.1 「交叉驗證 dav-wiki `_index.json` 來源對應 Markdown
   條目存在」（R3 緩解）
4. **主檔行數累積**：138/150 餘裕 12 行，下次再加新章節需考慮外移到 sub-skill（R4 緩解）
5. **下個 V03 觸發時**：先把規範「v2.4 變動歷史外移」視為預設檢查項，避免再次漏掉

### 5.5 滿意度自評

| 項 | 評分 |
|----|------|
| 完成度 | 100%（Step 1.5 加完 + 規則表加 1 條 + 變動歷史加 v2.6 + 瘦身 + CHANGELOG）|
| 規範合規 | 95%（v2.1/v2.2/v2.4/V03 全合規）|
| 過程紀律 | 90%（3 次 edit 失敗但都主動修正）|
| Reviewer 價值 | 高（8 項修正全部完成）|
| 改進空間 | 對 edit 工具狀態追蹤敏感度需再加強 |

---

## 附錄 A：探針輸出

```
1..3
ok 1 each example file declares its skill version baseline
ok 2 no skill SKILL.md references banned monorepo cross-dir path token
ok 3 no skill SKILL.md contains ../path cross-dir markdown link in cross-reference section
```

## 附錄 B：Reviewer verdict 重點

- **整體 verdict**：🟡 修正後通過
- **必要修正項**：3 P1 + 5 P2，全部完成
- **殘留風險**：4 條（R1/R2/R3/R4）
- **完整 verdict**：`/tmp/skill-audit-2026-09-26/reviewer-verdict-3.md`（8.1 KB）

## 附錄 C：相關檔案

- 設計草案：`docs/deliverable/2026-09-26-dav-planner-introduce-dav-wiki-design.md`（已套用 8 項修正）
- dav-planner 主檔：`skills/dav-planner/SKILL.md`（+35 行）
- dav-planner CHANGELOG：`skills/dav-planner/CHANGELOG.md`（+v2.6）
