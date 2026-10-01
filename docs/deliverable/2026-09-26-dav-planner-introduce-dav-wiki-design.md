# 設計：dav-planner v2.6 引入 dav-wiki（Step 1.5「來源抽取」）

| 項目 | 值 |
|------|-----|
| 日期 | 2026-09-26 |
| 對應 Backlog | TD-020（dav-planner 引入 dav-wiki）|
| 變動範圍 | dav-planner 單一 skill（dav-wiki 不動）|
| V03 觸發 | ✅ 是（SKILL.md 結構性變更 → 必走 Reviewer 二審）|
| V01 觸發 | ✅ 是（一次一個問題，4 輪問答完成）|
| V02 觸發 | ✅ 是（每個選項都標推薦）|

---

## 1. 為什麼做這個改動

### 1.1 問題

dav-planner v2.5 規劃階段目前只有 Step 1「背景收集」（靠用戶口述）+ Step 2「最終目的」+ Step 3「驗收標準」。**複雜任務**（多文件 / 多來源 / 未來會多次更新）有以下痛點：

- **重複抄寫**：每次更新都要人工重讀 PDF / DOCX
- **易遺漏**：規劃時漏讀關鍵段落 → 後續階段才發現 → 返工
- **來源不可追溯**：未來某 US 要更新時，找不回原始來源 PDF / 網頁 / Notion 在哪

### 1.2 為什麼用 dav-wiki

dav-wiki 已是安裝在 monorepo 的 skill，**功能完全對應需求**：

> 統一文件資料提取與 Markdown 化。支援純文字、PDF/DOCX/PPTX、網頁 URL、圖片 OCR、影音字幕等多種來源，自動轉成結構化 Markdown 知識庫（含 frontmatter、tag、概念、交叉引用）。

讓 dav-planner 「規劃時」調用 dav-wiki 「抽取來源」 → 結構化 Markdown → dav-planner 讀該 Markdown → 規劃。**未來需求更新時**重新跑同一流程 → 自動標記「哪幾個 US 受影響」。

### 1.3 為什麼是「Step 1.5 可選步驟」不是「強制 Step 1」

| 形式 | 優點 | 缺點 |
|------|------|------|
| 強制 Step 1（每次都跑 dav-wiki） | 一致性高 | 簡單任務變慢、dav-wiki 變耦合依賴 |
| **Step 1.5 可選（推薦）** | 觸發條件明確、軟引用 dav-wiki | 用戶要自己判斷「複雜 vs 簡單」 |
| 拆 sub-skill（dav-planner-with-wiki.md） | 主檔不變 | 讀者不知道何時讀 sub-skill |

---

## 2. 改了什麼

### 2.1 dav-planner SKILL.md 改動

| 位置 | 改動 |
|------|------|
| TL;DR | 不變 |
| 觸發時機 | 加 1 行：「複雜開發任務（多文件 / 多來源 / 未來多次更新）→ Step 1.5 推薦調用 dav-wiki」 |
| **流程（Step 1-5 + Step 1.5 可選）** | **加 Step 1.5「來源抽取」章節（位於 Step 1 後、Step 2 前）** |
| 規則表 | 加 1 條：「複雜任務必走 Step 1.5」|
| 變動歷史 | 加 v2.6 條目 + **v2.3 條目外移至 CHANGELOG.md（v2.4 規範觸發）** |
| 字數 | 預估 +30 行 → 主檔 103 → 預估 133 行（仍 < 150 ✅）|

### 2.2 Step 1.5 完整內容（最終會寫進 SKILL.md）

```markdown
### Step 1.5：來源抽取（複雜開發任務可選）

> **位置**：Step 1.5 在 Step 1（背景收集）之後、Step 2（最終目的）之前觸發

**觸發條件**（以下任一即符合「複雜任務」）：
- 既有文件分散在 monorepo `docs/` 多份檔案（需求、決策、設變記錄）
- 來源檔案格式非 Markdown（PDF / DOCX / PPTX / 網頁 URL）
- 需求來源跨多個工具（Obsidian / Notion / Confluence / GitHub Issues）
- 你預期未來會**多次更新需求**（每次都要回到來源重新對照）
- 既有 dav-wiki 知識庫已收錄相關概念（先 grep `docs/concepts/` + `docs/wiki/_index.json`，命中 ≥ 1 條 → 直接讀、不需重新抽取）

**動作**：
1. 列出來源候選清單（檔案路徑 / URL / Obsidian Vault 位置）
2. 調用 **dav-wiki** skill（需同套安裝）：
   - 統一文件資料提取與 Markdown 化
   - 自動轉成結構化 Markdown 知識庫（含 frontmatter / tag / 概念 / 交叉引用）
3. 抽取完成後，**回到 Step 1**，**附加** Step 1 來源清單（既有口述 + 結構化 Markdown 並存、不取代口述）

**為什麼要這個步驟**：
- 規劃階段直接讀 PDF / DOCX 易遺漏關鍵段落
- dav-wiki 產出的結構化 Markdown 可被 dav-designer / dev-checker-loop / regression-guard 後續階段直接讀
- **未來需求更新時**：重新調用 dav-wiki 對照 → 自動標記「哪幾個 US 受影響」

**何時跳過**：
- 用戶已提供結構化 Markdown 來源
- 簡單單檔任務（單一 README.md / 單一 issue）
- 探索性原型（PoC）

**dav-wiki 未裝時的 fallback**：
- 退回「用戶口述」模式（同 Step 1 原有行為）
- 提示用戶「若本任務複雜、建議執行 install.sh 安裝 dav-wiki」
- 不報錯、只警告（軟引用精神）
```

### 2.3 規則表新增條目

| 規則 | 例外 | 限制 |
|------|------|------|
| **複雜任務必走 Step 1.5** | 用戶已主動提供結構化 Markdown 來源 | 推薦 dav-wiki、避免手動抄 PDF；dav-wiki 未裝則退回用戶口述 |

### 2.4 CHANGELOG.md 新條目

```markdown
| v2.6 | 2026-09-26 | +Step 1.5「來源抽取（複雜任務可選）」：位於 Step 1 後 Step 2 前；觸發條件 + 推薦調用 dav-wiki + 何時跳過 + dav-wiki 未裝 fallback | 用戶決策：複雜任務需求會多次更新、需要回原始來源；dav-wiki 已是 monorepo skill、軟引用而非強制耦合；V03 Reviewer 二審通過（verdict-3）；依賴 dav-wiki skill 需同套安裝 |
```

**主檔變動歷史瘦身**：當前 3 條（v2.5 / v2.4 / v2.3）→ 加 v2.6 後變 4 條 → **觸發 v2.4 規範 → v2.3 條目外移到 CHANGELOG.md**，主檔只留 v2.6 / v2.5 / v2.4 共 3 條。

### 2.5 不動的部分

| 不動 | 為什麼 |
|------|-------|
| dav-wiki 本身 | 本次只讓 dav-planner 引用、不動 dav-wiki 主檔 |
| 其他 4 個 skill | 不在本次變動範圍 |
| backlog 表格格式 | 用戶決策「保留現有 US/AC 表格」|
| Step 1-5 既有內容 | 只在 Step 1 後插入 Step 1.5、不破壞既有流程 |

---

## 3. 驗證

| 探針 | 預期結果 |
|------|---------|
| restruct-no-cross-dir-path.bats | 2/2 ok（不引入新跨目錄 path）|
| check-examples-version-baseline.bats | 1/1 ok（不動 examples/）|
| 5 項自驗收 | frontmatter / 5 段 / < 150 行 / 純文字引用 / description ≤ 200 字 全綠 |

---

## 4. 殘留風險

| # | 風險 | 評估 | 緩解 |
|---|------|------|------|
| R1 | dav-planner 主檔 +30 行 → 130+ 行（接近 150 上限）| 中 | 若未來再加 Step 1.6，需再次瘦身 |
| R2 | 「複雜任務」判斷無標準化指標 | 中 | Step 1.5 觸發條件列 4 個 — 用戶自判 |
| R3 | dav-wiki 抽取品質不穩定 | 中 | Step 1.5 「回到 Step 1」作為用戶複查關卡 |
| R4 | dav-wiki 與 dav-planner 版本耦合（dav-wiki 大改後 dav-planner 引用過時）| 低 | 用戶決策「軟引用」、兩 skill 可獨立演進 |

---

## 5. Reviewer 二審 6 點

請 Reviewer 必審：

1. **合規性**：Step 1.5 觸發條件是否合理？是否有遺漏場景？
2. **結構性**：SKILL.md 流程結構（5 段任務導航）是否仍合規？
3. **行數影響**：主檔 +30 行是否會突破 150 行上限？
4. **v2.6 條目**：CHANGELOG 變動歷史是否規範？
5. **dav-wiki 引用形式**：「推薦調用」vs「必須調用」的選擇是否合理？
6. **backlog 格式不變**：是否符合用戶決策？
