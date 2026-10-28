---
name: dav-wiki
description: >-
  統一文件資料提取與 Markdown 化。支援純文字、PDF/DOCX/PPTX、網頁 URL、圖片 OCR、影音字幕等多種來源，自動轉成結構化 Markdown 知識庫（含
  frontmatter、tag、概念、交叉引用）。用於把文件／網址／圖片／影音收錄成 wiki；純提問、不需存檔唔用。
---
# Dav Wiki

## TL;DR
1. **做什麼**：把任何來源（純文字／Office／網頁／OCR／字幕）統一轉成 Markdown 知識庫（存 `docs/wiki/` ＋ 概念入 `docs/concepts/`），可用 Obsidian `[[xxx]]`
交叉引用。
2. **何時觸發**：用戶給文件要轉 wiki／給網址要收錄／批次處理多份文件／更新既有 wiki。
3. **預設 SOP 路徑**：§2.3 執行（無單獨 SOP Gate，由同套 `dav-planner` skill 啟動後調用）。
4. **關鍵紀律**：V01 一次只問一個問題；V02 多選必標推薦（放第一）；純文字引用（skill 內不放跨檔 markdown 連結）；Trust 整合（`/trust <內容>` → 同套 `dav-trust` skill
自主模式）。
5. **必產出物**：`docs/wiki/{category}/{YYYY-MM}/{title}.md` ＋ `docs/concepts/{slug}.md` ＋ 更新
`_index.json`／`_tags.json`／`_concepts.json`／`docs/README.md`。
6. **子檔導航**：frontmatter schema → `./frontmatter-schema.md`；概念演進 → `./concept-evolution.md`；產出台帳 →
`./output-structure.md`；軟刪除 → `./soft-delete.md`；範例 → `./examples.md`。

## 觸發時機
- ✅ **觸發**：用戶給文件要轉 wiki／給網址要收錄／要批次處理多份／要更新既有 wiki（例：「把這份 PDF 變 wiki」）。
- ❌ **不觸發**：純提問／不需存檔。

## 流程（7 步主流程，FR-2 多模組擴充版；每步動作／產出／證據 → 同套 `./workflow.md`）
- **Step 1 來源識別** — 判斷來源類型（純文字／.md／PDF／DOCX／PPTX／URL／圖片／影片／音訊）
- **Step 2 內容處理（FR-2 多模組）** — 依來源類型調用對應模組（純文字直接讀、Office 用提取腳本、URL 用 fetch、圖片用 Vision、影音用 Whisper）
- **Step 3 Category 確認（AI 建議 ＋ 用戶確認）** — 給 2-3 個 category 候選（推薦放第一），用戶選／拒／自訂
- **Step 4 Tag 自動提取** — AI 給 3-8 個 tag（小寫、kebab-case）
- **Step 5 交叉引用（讀 `_index.json`）** — tags ＋ keywords 雙重比對找 2-5 篇相關（tag 重疊 ≥ 50% 為初步候選；keywords 重疊 ≥ 1 個才算真正相關）
- **Step 6 概念提取** — 提取 1-5 個 concept（語意命題，非 tag），每個獨立寫進 `docs/concepts/{slug}.md`
- **Step 7 寫入 ＋ 更新索引 ＋ 重建 README** — 寫 markdown → 更新 `_index.json`／`_tags.json`／`_concepts.json` → 重建 `docs/README.md`

## 規則 / 例外 / 限制
- **一次只問一個問題（V01）** — 例外：確認型問題可一次多個；限制：開放式問題必 1 題
- **多選必標推薦（V02）** — 例外：開放式問題無推薦；限制：必為第 1 個選項
- **純文字引用（v2.1）** — 例外：skill 自己的子檔可用 markdown 連結（含 `examples/` 內回指主檔嘅 `../`）；限制：不寫指向 **skill dir 以外** 嘅連結或讀檔引用
- **不真刪除檔案（軟刪除）** — 例外：90 天後 deprecated 可移到 `docs/wiki/_deprecated/`；限制：frontmatter 標
`deprecated: true`／`superseded_by` 保留可追溯（細節見 `./soft-delete.md`）
- **預測性 token < 2k** — 例外：大檔案例外可全文；限制：預設用 `_index.json` 比對
- **寫入失敗 rollback** — 例外：N/A；限制：temp file ＋ rename 模式
- **OCR／字幕為擴充模組** — 例外：預設僅支援核心三來源（純文字／Office／網頁）；限制：需另裝 tesseract／yt-dlp
- **FR-2 缺必要工具（poppler／ffmpeg／pandoc／python-pptx）** — 例外：**未裝就停**：該模組直接 `exit 4` + 安裝提示，不降級成純文字；唯一例外：OCR 未裝 tesseract →
自動用 mock placeholder（有 WARN，見 `./scripts/wiki-ocr.sh`）
- **Whisper／Vision 模組（`./scripts/wiki-media-describe.sh`）** — 例外：real 模式尚未實作：要 `--mock` 或 `DAV_WIKI_MOCK=1`；未實作就
`exit 5`（不產出、不回報成功；寫入失敗 `exit 6`）；限制：這與「未裝工具」無關，不要期待安裝提示

## 輸出結構 / 交叉引用
- **輸出結構**：`docs/` 為寫入目的地（專案約定），不是讀取來源；完整樹狀圖與各節點用途 → 同套本 skill 子檔（`./output-structure.md`）
- **交叉引用（純文字）**：互動設計系統／技術架構／PRD → 見 monorepo 對應的 design／system-design／PRD 文件（路徑由 monorepo 約定）
