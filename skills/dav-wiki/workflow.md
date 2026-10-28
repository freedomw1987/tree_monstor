# Dav Wiki — 7 步主流程（FR-2 多模組擴充版）

> 本檔為 `dav-wiki` 嘅流程子檔；主檔只留指標。每步格式：動作 → 產出 → 證據。

## Step 1 來源識別

- **動作**：判斷來源類型（純文字／.md／PDF／DOCX／PPTX／URL／圖片／影片／音訊）
- **產出**：對話中明示「來源 = X」；**證據**：選用對應處理方式

## Step 2 內容處理（FR-2 多模組）

- **動作**：依來源類型調用對應模組（純文字直接讀、Office 用提取腳本、URL 用 fetch、圖片用 Vision、影音用 Whisper）
- **產出**：原始文字 ＋ 媒體資產至 `assets/`；**證據**：資產目錄有檔案、文字可讀

## Step 3 Category 確認（AI 建議 ＋ 用戶確認）

- **動作**：給 2-3 個 category 候選（推薦的放第一個），用戶選／拒／自訂
- **產出**：對話確認 category；**證據**：對話有「Category = X」

## Step 4 Tag 自動提取

- **動作**：AI 給 3-8 個 tag（小寫、kebab-case）
- **產出**：frontmatter tag 陣列；**證據**：markdown frontmatter 有 tag 欄位

## Step 5 交叉引用（讀 `_index.json`）

- **動作**：tags ＋ keywords 雙重比對找 2-5 篇相關（tag 重疊 ≥ 50% 為初步候選；keywords 重疊 ≥ 1 個才算真正相關）
- **產出**：frontmatter `related` 欄位 ＋ 內文 `[[xxx]]` 標記；**證據**：related 欄位 ＋ 內文 `[[xxx]]` 數量

## Step 6 概念提取

- **動作**：提取 1-5 個 concept（語意命題，非 tag），每個獨立寫進 `docs/concepts/{slug}.md`
- **證據**：concepts 目錄有對應檔案

## Step 7 寫入 ＋ 更新索引 ＋ 重建 README

- **動作**：寫 markdown → 更新 `_index.json`／`_tags.json`／`_concepts.json` → 重建 `docs/README.md`
- **證據**：所有索引 ＋ README 都更新
