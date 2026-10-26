# Examples — dav-wiki

> 操作範例集。每個範例：輸入 → 對話流程 → 產出。
> 配合 [SKILL.md](SKILL.md)、[frontmatter-schema.md](frontmatter-schema.md)、[concept-evolution.md](concept-evolution.md) 使用。
> 產出檔案嘅完整 frontmatter 範例 → [frontmatter-schema.md](frontmatter-schema.md)（本檔只列關鍵欄位）。

---

## 共通流程骨架（7 步）

所有來源（PDF / URL / 純文字 / 圖片 / 影音）都走同一條流程，只有 [1] 來源識別同 [2] 內容處理會分岔：

```
[1] 來源識別 → [2] 內容處理 → [3] Category 建議（用戶揀） → [4] Tag 自動提取
   → [4b] Keywords 提取 → [5] 交叉引用（讀 _index.json） → [6] 概念提取 → [7] 寫入 + 重建索引
```

**[3] 一定有互動**（A. 推薦 / B. 次選 / C. 自訂）；[5] 會報「推薦 / 刷掉」兩個清單。

---

## 範例 1：PDF → wiki（基本流程）

**輸入**：`把這份 PDF 變 wiki`（附檔 `rsc-deep-dive.pdf`）

```
⏳ [1/7] 來源識別：PDF，使用 pdf2text 提取
⏳ [2/7] 內容處理：清理 + 結構 + 摘要
⏳ [3/7] Category 建議：
  A. frontend（推薦 — 內容是 React 技術，與你既有的 frontend/ 同類）
  B. backend（次選 — 涉及 server-side 渲染）
  C. 自訂（輸入你的 category）
用戶: A
⏳ [4/7] Tag 自動提取：react, server-components, rsc, rendering
⏳ [4b/7] Keywords：serialization, hydration, bundle-size, streaming
⏳ [5/7] 交叉引用：讀 _index.json，比對 tag 重疊 ≥ 50% + keywords ≥ 1 個
  - nextjs-app-router-guide (tag 重疊 100% + keywords "streaming" 重疊) ✅
  - streaming-ssr-patterns (tag 重疊 100% + keywords "streaming" 重疊) ✅
⏳ [6/7] 概念提取：建立 1 個 concept [[server-component-serialization-boundary]]
⏳ [7/7] 寫入 + 更新索引 + 重建 docs/README.md
```

**產出**：

| 產物 | 路徑 |
|---|---|
| 文件 | `docs/wiki/frontend/2026-01/react-server-components-deep-dive.md` |
| 概念 | `docs/concepts/server-component-serialization-boundary.md` |
| 索引 | `_index.json` (+1)、`_tags.json` (+4 tags)、`_concepts.json` (+1) |
| 導航 | `docs/README.md` |

---

## 範例 2：網頁 URL → wiki + 概念提取

**輸入**：`把這篇文章存進 wiki https://martinfowler.com/articles/replaceThrowWithNotification.html`

```
⏳ [1/7] 來源識別：URL，使用 fetch_content 抓取
⏳ [2/7] 內容處理（2547 字 → 精簡為 890 字 + 結構）
⏳ [3/7] Category 建議：A. architecture（推薦 — 錯誤處理架構）/ B. patterns / C. 自訂
用戶: A
⏳ [4/7] Tag：error-handling, patterns, exception, notification
⏳ [4b/7] Keywords：throw, recover, signal, recoverability
⏳ [5/7] 交叉引用：
  - clean-architecture-chapter-7 (tag 100% + keywords "recover") ✅ 推薦
  - solid-principles-intro (tag 100%，keywords 無重疊) ❌ 刷掉
⏳ [6/7] 概念提取：建立 2 個 concepts
  - [[replace-throw-with-notification]]
  - [[exception-vs-notification-pattern]]
⏳ [7/7] 寫入
```

**產出**：`docs/wiki/architecture/2026-01/replace-throw-with-notification.md` + 概念 × 2

---

## 範例 3：純文字 → wiki（最快路徑）

**輸入**：`把這段筆記變 wiki`（內嵌 Q1 規劃會議筆記：重構 auth、PostgreSQL 15→16、audit log）

```
⏳ [1/7] 來源識別：純文字（內嵌輸入）
⏳ [2/7] 內容處理
⏳ [3/7] Category 建議：A. meeting-notes（推薦）/ B. planning / C. 自訂
用戶: A
⏳ [4/7] Tag：q1-planning, auth, database, audit
⏳ [5/7] 交叉引用：0 篇（這是第一篇 meeting-notes）
⏳ [6/7] 概念提取：建立 1 個 concept [[stride-threat-modeling-basics]]
⏳ [7/7] 寫入
```

**產出**：1 文件 + 1 概念

---

## 範例 4：/trust 模式 — 批次處理 5 份 PDF

**輸入**：`/trust 把這 5 份 PDF 都變 wiki，分類你決定，今天下班前告訴我結果`

```
[開始] 讀取 /trust 模式，啟動 dav-trust（Agent 自主完成，不打擾用戶）

[文件 1/5] rsc.pdf → frontend/2026-01/react-server-components.md
[文件 2/5] hooks.pdf → frontend/2026-01/react-hooks-cheatsheet.md
[文件 3/5] postgresql-migration.pdf → backend/2026-01/postgresql-15-to-16.md
[文件 4/5] stride.pdf → security/2026-01/stride-threat-modeling.md
[文件 5/5] audit-log.pdf → backend/2026-01/append-only-audit-log.md

[概念提取] 跨 5 份文件提取 8 個概念（5 新建 + 3 由既有 derive）
[交叉引用] 自動建立 12 個 [[xxx]] 連結
[完成] 寫入 docs/trust-log.md 紀錄所有決策
```

**用戶事後看到**：

```
✅ /trust 任務完成

產出：5 個 wiki 文件、8 個概念、12 個交叉引用、docs/README.md 自動更新
決策摘要（完整 log 在 docs/trust-log.md）：
  - Category 分類：frontend × 2, backend × 2, security × 1
  - Tag：共 28 個（去除重複後 19 個）；跳過 0 篇
下一步建議：檢視 docs/README.md 導航結構、進入概念庫檢視新建立的 8 個概念
```

---

## 範例 5：概念演進 — revise 決策

**觸發情境**：既有 `[[effect-shallow-compare]]`（Effect 依賴淺比較陷阱）；新文件講 React 18 `useMemo` 有同類問題 → 重疊 80%。

```
⏳ [1-5/7] 來源 / 處理 / Category (frontend) / Tag / 交叉引用
⏳ [6/7] 概念提取 —— 發現新概念與既有概念部分重疊，需要決策：

  候選 concept：1. "useMemo 依賴淺比較"（與既有 80% 重疊）
  建議動作：
  A. revise（推薦 — 在 [[effect-shallow-compare]] 加入 useMemo 案例）
  B. derive（次選 — 建立子概念 [[effect-shallow-compare-vs-usememo]]）
  C. 其他（說明你的想法）
用戶: A
⏳ [7/7] 寫入 + 更新既有概念
```

**產出**：

| 對象 | 變動 |
|---|---|
| `[[effect-shallow-compare]]` | definition 更新（加入 useMemo 案例）＋ history `+= {date, action: revised, note}` |
| 新文件 | `docs/wiki/frontend/2026-02/react-18-usememo-pitfalls.md`，`related: ["[[effect-shallow-compare]]"]` |

---

## 範例 6：概念合併（merge）

**觸發情境**：`[[react-state-batching]]` 與 `[[react-automatic-batching]]` 都建立過，新文件把兩者合講 → 重疊 > 80%。

```
⚠️ 兩個既有概念高度重疊（> 80%）：
  - [[react-state-batching]]（2026-01-15 建立）
  - [[react-automatic-batching]]（2026-01-20 建立）

  建議動作：
  A. merge（推薦 — 保留較早、較完整的 [[react-state-batching]] → 另一個標 deprecated + superseded_by）
  B. revise（次選 — 任選一個擴充涵蓋另一個）
  C. 保留兩個（維持現狀，不推薦）
用戶: A
```

**產出**：

| 對象 | 變動 |
|---|---|
| `[[react-state-batching]]` | definition 合併兩者精華 ＋ history `+= {merged, "合併自 [[react-automatic-batching]]"}` |
| `[[react-automatic-batching]]` | `deprecated: true`、`superseded_by`、`status: deprecated`、history `+= {merged}`、從 `_concepts.json` 移除（檔案保留）、從 `docs/README.md` 隱藏 |

---

## 範例 7：軟刪除文件

**觸發情境**：用戶要棄用一篇過時文件（`class-components-cheatsheet.md`，已全面轉用 hooks）。

```
用戶：把 docs/wiki/frontend/2025-12/class-components-cheatsheet.md 標棄用，
     因為我們已經全面轉用 hooks 了

Agent: 確認棄用動作：
  ⚠️ 將標記 … 為 deprecated
  影響：從 docs/wiki/_index.json 移除（檔案保留）、從 docs/README.md 隱藏、
        反向連結 [[class-components-cheatsheet]] 仍可被追溯
  建議是否同時 deprecate 相關概念？[[react-class-component-lifecycle]] → deprecated
確認棄用？(y/N)
用戶: y
```

**產出**：

| 對象 | 變動 |
|---|---|
| wiki 文件 | frontmatter 加 `deprecated: true`；從 `_index.json` 移除；README 隱藏；檔案保留可追溯 |
| 概念 | `status: deprecated` + `deprecated: true` + `superseded_by` + history `+= {action: deprecated}`；從 `_concepts.json` 移除；README 隱藏 |

---

## 範例 8：失敗處理 — OCR 圖片品質過低

**觸發情境**：用戶附一張模糊截圖 `image-blurry.png`。

```
⏳ [1/7] 來源識別：圖片，使用 tesseract OCR
⚠️ [2/7] OCR 失敗：圖片品質過低，無法提取文字

建議動作：
A. 跳過 OCR（推薦 — 產出文件標 `[需要人工 OCR]` 佔位）
B. 重試（換不同 OCR 設定，可能無效）
C. 中止（用戶手動處理後再來）
用戶: A

⏳ [3/7] Category 確認跳過（OCR 失敗為例外，產出標記 `needs-ocr`）
⏳ [4/7] Tag 自動提取：給予佔位 tag（`needs-ocr`、`placeholder`）以滿足 schema 必填
⏳ [5-7/7] 仍執行流程，但內容標 placeholder
```

## 範例 9：多模組來源（FR-3：圖片 + 影片 + 字幕）

> 單一步驟同上，但 **[2] 內容處理** 會分岔成多條子步驟（PDF / PPTX 偵測到圖片或影片時）。

| 子步驟 | 動作 | 產出 |
|---|---|---|
| **2a** | 圖片提取（`pdfimages` / PPTX slide 圖） | `assets/images/{1-N}.png` |
| **2b** | Vision API 描述（每張圖 1-3 句 caption） | frontmatter `images[].caption` / `alt_text` |
| **2c** | 影片提取（`ffmpeg`） | `assets/videos/demo.mp4` |
| **2d** | Whisper 字幕轉錄（每段影片一份） | `assets/videos/demo.transcript.md` |
| **2e** | 章節切分（場景偵測 + AI 摘要） | `assets/videos/demo.chapters.json` |

```
⏳ [2/7] 內容處理（多模組）：
   [2a] 圖片提取（pdfimages） → assets/images/{1-5}.png
   [2b] Vision API 描述：為每張圖生 1-3 句描述
   [2c] 影片提取（ffmpeg） → assets/videos/demo.mp4
   [2d] Whisper 字幕轉錄 → assets/videos/demo.transcript.md
   [2e] 章節切分（場景偵測 + AI 摘要） → demo.chapters.json
```

**PPTX 變體**：`[2a]` 提取 slide 圖片 → `[2b]` 提取嵌入影片 → `[2c]` 每段影片各轉一份字幕 → `[2d]` 提取每個 slide 嘅文字 + 表格。
**產出 frontmatter**：`images[]` / `videos[]`（含 `duration`、`transcript_path`、`chapters`）／`audio[]`
→ 欄位規範見同 skill 子檔（`./frontmatter-schema.md` §1.3-1.5）。
