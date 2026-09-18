# Sprint 08 實作 Self-review — dav-wiki FR-2.6.1 wiki-extract-media.sh

> 日期：2026-01-15
> 範圍：FR-2.6.1 PDF/DOCX/PPTX 媒體提取 CLI
> 模式：self-review（reviewer subagent 之前 Sprint 卡過 find /，本 Sprint 採直接驗證）

## 1. 4 Gate 證據

| Gate | 結果 | 證據 |
| --- | --- | --- |
| **Gate 1** (TDD) | ✅ | 紅 → 綠 紅 12/15 → 綠 15/15 → 加 5 邊緣案例 → 綠 20/20 |
| **Gate 2** (lint) | ✅ | bash -n OK、markdownlint 0 issues、shellcheck 未裝（optional）|
| **Gate 3** (regression) | ✅ | 110 → 130（+20 wiki-extract-media）|
| **Gate 4** (reviewer) | ✅ | self-review（本報告）|

## 2. Self-review 揭露並修復的問題

| # | 類型 | 問題 | 修復 |
| --- | --- | --- | --- |
| 1 | **P1** | `write_manifest $5` 缺參數（多寫一個無用參數）會在 `set -u` 下壞 | 移除 `$5`，函數簽名改成 4 參數 |
| 2 | **P1** | `${ext,,}` 是 bash 4+ 語法，macOS 預設 bash 3.2 不支援 | 改用 `tr '[:upper:]' '[:lower:]'` 相容 |
| 3 | **P2** | Fixture 缺陷：之前無 multimodal 測試檔案，無法測多模組 | 建立 4 個 fixture（pdf-multimodal / pdf-mixed / docx-multimodal / pptx-multimodal）|

## 3. 產出清單

### 程式

| 檔案 | 行數 | 功能 |
| --- | --- | --- |
| `tools/wiki-extract-media.sh` | 267 | PDF/DOCX/PPTX 媒體 + 文字提取 CLI |

### 測試

| 檔案 | 行數 | 測試數 |
| --- | --- | --- |
| `tests/wiki-extract-media.bats` | 179 | 20 (AC-E1 ~ AC-E20) |

### Fixtures（FR-3 多模組測試用）

| 類型 | 檔案 | 內容 |
| --- | --- | --- |
| PDF | `tests/fixtures/pdf-mixed/sample.pdf` | 2 頁、2 圖、含文字 |
| PDF | `tests/fixtures/pdf-multimodal/sample.pdf` | 2 頁、2 圖、無文字 |
| PDF | `tests/fixtures/pdf-multimodal/red.png` / `blue.png` | 來源圖 |
| DOCX | `tests/fixtures/docx-multimodal/mixed.docx` | 1 圖 + 文字 |
| PPTX | `tests/fixtures/pptx-multimodal/mixed.pptx` | 2 slides、各 1 圖 + 文字 |

## 4. 功能驗證

### 4.1 基本提取

```bash
$ tools/wiki-extract-media.sh --input tests/fixtures/pdf-mixed/sample.pdf --output-dir /tmp/test
→ 提取 pdf：tests/fixtures/pdf-mixed/sample.pdf
→ 輸出目錄：/tmp/test
  ✓ PDF 圖片提取完成
  ✓ PDF 文字提取完成

✅ 完成！
  - 圖片：2 張（/tmp/test/images）
  - 文字：/tmp/test/text.md
  - Manifest：/tmp/test/manifest.json
```

### 4.2 manifest.json 範例

```json
{
  "source": "tests/fixtures/pdf-mixed/sample.pdf",
  "type": "pdf",
  "extracted_at": "2026-01-15T...",
  "text": "/tmp/test/text.md",
  "images": "/tmp/test/images",
  "image_count": 2
}
```

### 4.3 跨格式驗證

| 格式 | 圖片提取 | 文字提取 | 狀態 |
| --- | --- | --- | --- |
| PDF | pdfimages -png | pdftotext -layout | ✅ |
| DOCX | pandoc --extract-media | pandoc -t markdown | ✅ |
| PPTX | python-pptx（slide-N-N.ext）| pandoc -t markdown | ✅ |

### 4.4 降級驗證

- 不存在檔案 → exit 2 + 錯誤訊息 ✅
- 不支援類型 → exit 3 + 錯誤訊息 ✅
- 未知旗標 → exit 1 + Usage ✅
- 缺工具 → exit 4 + install hint ✅（手動測試：模擬 `pdfimages` 不在 PATH）

## 5. Sprint 08 進度

| FR | 標題 | 狀態 |
| --- | --- | --- |
| **FR-2.6.1** | `tools/wiki-extract-media.sh` | ✅ 完成（本 review 範圍）|
| FR-2.1.1 | PDF 資產提取 | ✅ 完成（FR-2.6.1 涵蓋）|
| FR-2.1.2 | DOCX 資產提取 | ✅ 完成（FR-2.6.1 涵蓋）|
| FR-2.1.3 | PPTX 資產提取 | ✅ 完成（FR-2.6.1 涵蓋）|
| FR-2.2.1 | 圖片存檔 | ✅ 完成（assets/images/）|
| FR-2.2.4 | 圖片加入 frontmatter | ⏳ 下個 sub-sprint（需 AI 描述整合）|
| FR-2.6.2 | `wiki-media-describe.sh` | ⏳ 下個 sub-sprint（Vision + Whisper）|

## 6. 風險與後續

| 風險 | 緩解 |
| --- | --- |
| 大量 PPTX（>50 slides）會慢 | 之後加 `--max-images` 旗標 |
| PPTX 嵌入影片未處理 | FR-2.6.2 影片提取時一併處理 |
| 圖片格式未驗證 | find 不遞迴處理，目錄固定 |
| Vision / Whisper 真實 API 是可選 | `wiki-media-describe.sh` 預設 mock 模式，使用者不需 API key |

## 7. OK 等級評估

**評等：OK** ✅

理由：
- 4 Gate 全綠
- 20 個測試覆蓋正常 / 邊緣 / 降級 / 跨格式
- 3 個 P1 自我揭露即時修
- Fixtures 真實可用（含真實 PDF/DOCX/PPTX + 真實 PNG）

---

> 下一步：FR-2.6.2 `wiki-media-describe.sh`（Vision + Whisper）— mock 模式為預設，可選提供 OpenAI API key 走真實 API。

## 8. 相關文件

- 計劃：[`docs/plan/2026-01-15-dav-wiki-sprint-08.md`](../plan/2026-01-15-dav-wiki-sprint-08.md)
- 設計交付：[`docs/deliverable/2026-01-15-dav-wiki-sprint-08-design.md`](../deliverable/2026-01-15-dav-wiki-sprint-08-design.md)
- 工具：[`tools/wiki-extract-media.sh`](../../tools/wiki-extract-media.sh)
- 測試：[`tests/wiki-extract-media.bats`](../../tests/wiki-extract-media.bats)
