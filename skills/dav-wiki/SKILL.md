---
name: dav-wiki
description: 統一文件資料提取與 Markdown 化。支援純文字、PDF/DOCX/PPTX、網頁 URL、圖片 OCR、影音字幕等多種來源，自動轉成結構化 Markdown 知識庫（含 frontmatter、tag、概念、交叉引用）。
---

# Dav Wiki

## TL;DR

1. **做什麼**：把任何來源的資料（純文字、Office 文件、網頁、OCR、字幕）統一轉成 Markdown 知識庫，存進 `docs/wiki/`；自動提取概念到 `docs/concepts/`；可透過 Obsidian 雙向連結 `<教學範例>[[xxx]]</教學範例>` 交叉引用。
2. **何時觸發**：用戶給文件要轉 wiki / 給網址要收錄 / 批次處理多份文件 / 更新既有 wiki。
3. **預設 SOP 路徑**：§2.3 執行（無單獨 SOP Gate，由 dav-planner 啟動後調用）。
4. **關鍵紀律**：
   - **V01**：一次只問一個問題（互動階段）
   - **V02**：多選必標推薦（推薦放第一）
   - **純文字引用**：skill 內不放跨檔 markdown 連結，所有引用純文字描述
   - **Trust 整合**：用戶輸入加 `/trust` 前綴 → 走 `dav-trust` 自主模式
5. **必產出物**：`docs/wiki/{category}/{YYYY-MM}/{title}.md` + `docs/concepts/{slug}.md` + 更新 `_index.json` / `_tags.json` / `_concepts.json` / `docs/README.md`

## 觸發時機

| 情境 | 觸發 |
|------|------|
| 用戶給文件要轉 wiki | ✅ 「把這份 PDF 變 wiki」 |
| 用戶給網址要收錄 | ✅ 「把這篇文章存進 wiki」 |
| 用戶要批次處理 | ✅ 「把這 5 份報告都轉成 wiki」 |
| 用戶要更新既有 | ✅ 「更新這篇 wiki 的概念」 |
| 純提問 / 不需存檔 | ❌ 不觸發 |

## 流程（7 步主流程，FR-2 多模組擴充版）

### Step 1：來源識別

- **動作**：判斷來源類型（純文字 / .md / PDF / DOCX / PPTX / URL / 圖片 / 影片 / 音訊）
- **為什麼**：不同來源需不同處理工具
- **產出**：對話中明示「來源 = X」
- **證據**：選用對應處理方式

### Step 2：內容處理（FR-2 多模組）

- **動作**：依來源類型調用對應模組（純文字直接讀、Office 用提取腳本、URL 用 fetch、圖片用 Vision、影音用 Whisper）
- **為什麼**：FR-2 多模組統一介面
- **產出**：原始文字 + 媒體資產至 `assets/`
- **證據**：資產目錄有檔案、文字可讀

### Step 3：Category 確認（AI 建議 + 用戶確認）

- **動作**：給 2-3 個 category 候選（推薦的放第一個），用戶選 / 拒 / 自訂
- **為什麼**：避免 AI 自行分類、用戶實際需求不清楚
- **產出**：對話確認 category
- **證據**：對話有「Category = X」

### Step 4：Tag 自動提取

- **動作**：AI 給 3-8 個 tag（小寫、kebab-case）
- **為什麼**：自動標籤方便交叉引用
- **產出**：frontmatter tag 陣列
- **證據**：markdown frontmatter 有 tag 欄位

### Step 5：交叉引用（讀 `_index.json`）

- **動作**：tags + keywords 雙重比對找 2-5 篇相關
  - Tag 重疊 ≥ 50% 為初步候選
  - keywords 重疊 ≥ 1 個才算真正相關
  - 最多 5 篇、最少 0 篇
- **為什麼**：自動建立知識網絡，但避免 index 傾斜（舊 doc 不自動反向更新）
- **產出**：教學範例：markdown 內 `<教學範例>[[xxx]]</教學範例>` 標記 — 實際 wiki 內的 Obsidian 雙向連結由 dav-wiki 產生
- **證據**：frontmatter related 欄位 + 內文 `<教學範例>[[xxx]]</教學範例>` 數量（讀者不要誤判為跨檔連結）

### Step 6：概念提取

- **動作**：提取 1-5 個 concept（語意命題，非 tag），每個獨立寫進 `docs/concepts/{slug}.md`
- **為什麼**：概念獨立可重用、可演進（derive / revise / merge / deprecate）
- **產出**：`docs/concepts/{slug}.md` 1-5 個
- **證據**：concepts 目錄有對應檔案

### Step 7：寫入 + 更新索引 + 重建 README

- **動作**：寫 markdown → 更新 `_index.json` / `_tags.json` / `_concepts.json` → 重建 `docs/README.md`
- **為什麼**：保持索引同步、README 導航
- **產出**：markdown 檔 + 3 個索引檔 + README
- **證據**：所有索引 + README 都更新

## 規則 / 例外 / 限制

| 規則 | 例外 | 限制 |
|------|------|------|
| 一次只問一個問題（V01） | 確認型問題可一次多個 | 開放式問題必 1 題 |
| 多選必標推薦（V02） | 開放式問題無推薦 | 必為第 1 個選項 |
| 純文字引用（v2.1） | skill 自己的子檔可用 markdown 連結 | 不寫 `../` 或 `docs/` 跨檔連結 |
| 不真刪除檔案 | 90 天後 deprecated 可移到 `_deprecated/` | 保留可追溯 |
| 預測性 token < 2k | 大檔案例外可全文 | 預設用 `_index.json` 比對 |
| 寫入失敗 rollback | N/A | temp file + rename 模式 |
| OCR / 字幕為擴充模組 | 預設僅支援核心三來源（純文字 / Office / 網頁） | 需另裝 tesseract / yt-dlp |
| FR-2 多模組需 poppler / ffmpeg / Whisper | 未裝時降級為純文字模式 | 降級時必警告 |

## 輸出結構

```
docs/
  README.md
  wiki/
    _index.json
    _tags.json
    {category}/{YYYY-MM}/
      {title}.md
      assets/
        images/{n}.png
        videos/{n}.mp4
        videos/{n}.transcript.md
        audio/{n}.mp3
  concepts/
    _concepts.json
    {slug}.md
```

## Trust 整合

| 用戶輸入 | 模式 |
|---------|------|
| `/trust <內容>` | 走 `dav-trust` 自主模式（不打扰用戶、自主完成、中間決策寫進 `docs/trust-log.md`）|
| 普通輸入 | 正常逐步對話確認 |

## 軟刪除規則

**不真刪除檔案**。用 frontmatter 標記：
- **文件**：`deprecated: true` 或 `superseded_by: "<path>"`
- **概念**：`deprecated: true` + `status: deprecated` + `superseded_by: "<slug>"` + 從 `_concepts.json` 移除

**磁碟清理**：deprecated 超過 90 天的檔案可用 `scripts/wiki-cleanup.sh` 移到 `docs/wiki/_deprecated/{YYYY-Qn}/`，從主索引移除但保留可追溯。

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.1 | 2026-09-26 | 重結構為「任務導航」+ 純文字引用 | TMO-009 階段 6：LLM 注意力優化 + skill 獨立搬動 |
| v2.0 | 2026-09-26 | 文件產出物精簡規則適用 | TMO-008 減法 |
| v1.x | — | （舊版 7 步流程 + FR-2 多模組 + Obsidian 雙向連結）| 詳見全域 SOP 變動歷史 v1.x |

---

**交叉引用（純文字）**：
- 操作範例 → 同套本 skill 子檔（`./examples.md`）
- frontmatter schema → 同套本 skill 子檔（`./frontmatter-schema.md`）
- 概念演進規則 → 同套本 skill 子檔（`./concept-evolution.md`）
- 互動設計系統 → 見 monorepo 對應的 design 文件（路徑由 monorepo 約定）
- 技術架構 → 見 monorepo 對應的 system-design 文件（路徑由 monorepo 約定）
- PRD → 見 monorepo 對應的 PRD 文件（路徑由 monorepo 約定）
- 全域 SOP 變動歷史 → 見 monorepo 對應的 changelog 檔（路徑由 monorepo 約定）
