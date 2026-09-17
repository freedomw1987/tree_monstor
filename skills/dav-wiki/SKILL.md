---
name: dav-wiki
description: 統一文件資料提取與 Markdown 化。支援純文字、PDF/DOCX/PPTX、網頁 URL、圖片 OCR、影音字幕等多種來源，自動轉成結構化 Markdown 知識庫（含 frontmatter、tag、概念、交叉引用）。
---

# dav-wiki — 統一文件資料提取與 Markdown 化

把任何來源的資料（純文字、Office 文件、網頁、OCR、字幕）統一轉成 Markdown 知識庫，存進 `docs/wiki/`，
並自動提取概念（concept）建立獨立概念庫 `docs/concepts/`，所有檔案可透過 Obsidian 雙向連結 `[[xxx]]` 交叉引用。

## 何時使用此 skill

| 情境 | 觸發詞範例 |
| --- | --- |
| 用戶給文件要轉 wiki | 「把這份 PDF 變 wiki」、「轉成 markdown 知識庫」 |
| 用戶給網址要收錄 | 「把這篇文章存進 wiki」、「收錄這個網頁」 |
| 用戶要批次處理 | 「把這 5 份報告都轉成 wiki」 |
| 用戶要更新既有 | 「更新這篇 wiki 的概念」 |

## 7 步主流程

```text
輸入 → [1] 來源識別 → [2] 內容處理 → [3] Category 確認 → [4] Tag → [5] 交叉引用 → [6] 概念提取 → [7] 寫入 + README → 完成
```

### [1] 來源識別

- 純文字 / .md → 直接讀
- PDF / DOCX / PPTX → pandoc / pdf2text
- URL → fetch_content
- 圖片 → OCR（擴充）
- 影片字幕 → yt-dlp（擴充）

### [2] 內容處理

清理格式噪音、加標題層級、提取 1-3 句摘要、標記圖表

### [3] Category 確認（AI 建議 + 用戶確認）

給 2-3 個 category 候選（推薦的放第一個），用戶選 / 拒 / 自訂

### [4] Tag 自動提取

AI 給 3-8 個 tag（小寫、kebab-case）

### [5] 交叉引用（讀 `_index.json` 並比對 `tags` + `keywords`）

讀 `docs/wiki/_index.json`，採用 **tags + keywords 雙重比對** 找 2-5 篇相關，用 `[[xxx]]` 標記：

1. **Tag 重疊 50%** 以上為初步候選（例：新 doc 有 `react`、`ssr`、舊 doc 也有 `react`、`ssr`，重疊 2/3 = 67%）
2. **再過濾**：候選中需要 keywords 重疊 ≥ 1 個才算真正相關
3. **限制**：最多推薦 5 篇、最少 0 篇（空陣列合法）
4. **反向索引**：當新 doc 加進去後，舊 doc 的 `related` 不自動更新（避免 index 傾斜）；下次那個舊 doc 被重新讀取才會發現新相關者

| 例子 | Tag 重疊 | Keyword 重疊 | 推薦 |
| --- | --- | --- | --- |
| 新 doc: react/ssr/perf + 舊 doc: react/ssr/perf + 關鍵詞「streaming」 | 100% | 「streaming」重疊 | ✅ 推薦 |
| 新 doc: react/ssr + 舊 doc: python/django | 0% | — | ❌ 不推薦 |
| 新 doc: react/ssr + 舊 doc: react/ssr + 關鍵詞完全不同 | 100% | 0 個 | ❌ 不推薦（keywords filter 掛掉） |

### [6] 概念提取

提取 1-5 個 concept（語意命題，非 tag），每個獨立寫進 `docs/concepts/{slug}.md`，參見 [[concept-evolution]]

### [7] 寫入 + 更新索引 + 重建 README

- 寫 `docs/wiki/{category}/{YYYY-MM}/{title}.md`
- 更新 `_index.json`、`_tags.json`、`_concepts.json`
- 重建 `docs/README.md` 導航頁

## 輸出結構

```text
docs/
├── README.md
├── wiki/
│   ├── _index.json, _tags.json
│   └── {category}/{YYYY-MM}/{title}.md
└── concepts/
    ├── _concepts.json
    └── {slug}.md
```

## Trust 整合

用戶輸入加 `/trust` 前綴 → 走 `dav-trust` 自主模式（不打擾用戶、自主完成、中間決策寫進 `docs/trust-log.md`）。
無前綴則正常逐步對話確認。

## 軟刪除

**不真刪除檔案**。用 frontmatter 標記：

- 文件：`deprecated: true` 或 `superseded_by: "<path>"`
- 概念：`deprecated: true` + `status: deprecated` + `superseded_by: "<slug>"` + 從 `_concepts.json` 移除

**磁碟清理**：deprecated 超過 90 天的檔案可用 `tools/wiki-cleanup.sh` 移到 `docs/wiki/_deprecated/{YYYY-Qn}/`，
從主索引移除但保留可追溯。詳細見 [dav-wiki-cleanup hand book](../../../sop/handbook/dav-wiki-cleanup.md)。

完整 schema 見 [[frontmatter-schema]]。

## 互動紀律

依 SOP §1.5：

- **V01**：一次只問一個問題
- **V02**：多選必標推薦（推薦放第一）

## 注意事項

- **OCR / 字幕為擴充模組**：需另外安裝 tesseract / yt-dlp；核心三來源（純文字 / Office / 網頁）預設就支援
- **預測性 token 用量**：索引式比對用 < 2k tokens（讀 `_index.json` 而非全文）
- **失敗安全**：寫入失敗 rollback（temp file + rename）

## 相關文件

- [[examples]] — 操作範例（至少 5 個）
- [[frontmatter-schema]] — frontmatter 欄位定義（文件 + 概念兩種）
- [[concept-evolution]] — 概念演進規則（derive / revise / merge / deprecate）
- [docs/DESIGN.md](../../../DESIGN.md) — 互動設計系統
- [docs/system-design.md](../../../system-design.md) — 技術架構
- [docs/prd/03-knowledge-extraction.md](../../../prd/03-knowledge-extraction.md) — PRD
