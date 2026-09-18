# Examples — dav-wiki

> 5+ 操作範例。每個範例展示：輸入 → 對話流程 → 產出。
> 配合 [SKILL.md](SKILL.md)、[frontmatter-schema.md](frontmatter-schema.md)、[concept-evolution.md](concept-evolution.md) 使用。

---

## 範例 1：PDF → wiki（基本流程）

### 輸入

```
用戶：把這份 PDF 變 wiki
     （附檔：rsc-deep-dive.pdf）
```

### 對話流程

```
Agent: 開始執行 dav-wiki：將 rsc-deep-dive.pdf 轉成 wiki 文件

⏳ [1/7] 來源識別：PDF，使用 pdf2text 提取
⏳ [2/7] 內容處理：清理 + 結構 + 摘要
⏳ [3/7] Category 建議（選擇或自訂）：

  我建議的 category（推薦放第一）：
  A. frontend（推薦 — 內容是 React 技術，與你既有的 frontend/ 同類）
  B. backend（次選 — 涉及 server-side 渲染）
  C. 自訂（輸入你的 category）

請選 A / B / C？

用戶: A

⏳ [4/7] Tag 自動提取：react, server-components, rsc, rendering
⏳ [4b/7] Keywords（從 summary 提取）：serialization, hydration, bundle-size, streaming
⏳ [5/7] 交叉引用：讀 _index.json，比對 tag 重疊 ≥ 50% + keywords ≥ 1 個
  - nextjs-app-router-guide (tag 重疊 100% + keywords "streaming" 重疊) ✅
  - streaming-ssr-patterns (tag 重疊 100% + keywords "streaming" 重疊) ✅
⏳ [6/7] 概念提取：建立 1 個 concept [[server-component-serialization-boundary]]
⏳ [7/7] 寫入 + 更新索引 + 重建 docs/README.md

✅ 完成！
  - 產出文件：docs/wiki/frontend/2026-01/react-server-components-deep-dive.md
  - 產出概念：docs/concepts/server-component-serialization-boundary.md
  - 更新索引：_index.json (+1), _tags.json (+4 tags), _concepts.json (+1)
  - 重建導航：docs/README.md
```

### 產出檔案

**docs/wiki/frontend/2026-01/react-server-components-deep-dive.md**：

```markdown
---
title: "React Server Components 深入解析"
source:
  type: pdf
  original: "rsc-deep-dive.pdf"
  url: null
extracted_at: 2026-01-15
category: frontend
tags: [react, server-components, rsc, rendering]
summary: "深入講解 RSC 的運作原理、與 SSR 的差異、效能影響"
related:
  - "[[nextjs-app-router-guide]]"
  - "[[streaming-ssr-patterns]]"
concepts:
  - "[[server-component-serialization-boundary]]"
deprecated: false
superseded_by: null
---

# React Server Components 深入解析

## 簡介
React Server Components (RSC) 是 React 18 引入的新元件類型...

## 與 SSR 的差異
...

## 序列化邊界
<!-- 圖：RSC 序列化流程示意 -->

{{ ... AI 整理後的內容 ... }}
```

---

## 範例 2：網頁 URL → wiki + 概念提取

### 輸入

```
用戶：把這篇文章存進 wiki
     https://martinfowler.com/articles/replaceThrowWithNotification.html
```

### 對話流程

```
Agent: 開始執行 dav-wiki：抓取並轉換網頁

⏳ [1/7] 來源識別：URL，使用 fetch_content 抓取
⏳ [2/7] 內容處理（2547 字 → 精簡為 890 字 + 結構）
⏳ [3/7] Category 建議：

  A. architecture（推薦 — 內容是錯誤處理架構）
  B. patterns（次選 — 內容是設計模式）
  C. 自訂

用戶: A

⏳ [4/7] Tag：error-handling, patterns, exception, notification
⏳ [4b/7] Keywords（從 summary 提取）：throw, recover, signal, recoverability
⏳ [5/7] 交叉引用：讀 _index.json，比對 tag 重疊 ≥ 50% + keywords ≥ 1 個
  - clean-architecture-chapter-7 (tag 重疊 100% + keywords "recover" 重疊) ✅ 推薦
  - solid-principles-intro (tag 重疊 100%，但 keywords 無重疊) ❌ 刷掉
⏳ [6/7] 概念提取：建立 2 個 concepts
  - [[replace-throw-with-notification]]
  - [[exception-vs-notification-pattern]]
⏳ [7/7] 寫入

✅ 完成！
  - 文件：docs/wiki/architecture/2026-01/replace-throw-with-notification.md
  - 概念 × 2
```

---

## 範例 3：純文字 → wiki（最快路徑）

### 輸入

```
用戶：把這段筆記變 wiki

"""
今天開會討論 Q1 規劃：

1. 重構 auth 模組
2. 升級 PostgreSQL 15 → 16
3. 新增 audit log

決策：
- 用 STRIDE 威脅模型
- DB 升級排 3 月
- audit log 用 append-only table
"""
```

### 對話流程

```
Agent: 開始執行 dav-wiki：純文字筆記轉 wiki

⏳ [1/7] 來源識別：純文字（內嵌輸入）
⏳ [2/7] 內容處理
⏳ [3/7] Category 建議：

  A. meeting-notes（推薦 — 看起來是會議記錄）
  B. planning（次選 — 涉及 Q1 規劃）
  C. 自訂

用戶: A

⏳ [4/7] Tag：q1-planning, auth, database, audit
⏳ [5/7] 交叉引用：0 篇（這是第一篇 meeting-notes）
⏳ [6/7] 概念提取：建立 1 個 concept
  - [[stride-threat-modeling-basics]]
⏳ [7/7] 寫入

✅ 完成！1 文件 + 1 概念
```

---

## 範例 4：/trust 模式 — 批次處理 5 份 PDF

### 輸入

```
用戶：/trust 把這 5 份 PDF 都變 wiki，分類你決定，今天下班前告訴我結果
     （附 5 份 PDF）
```

### 對話流程（Agent 自主完成，不打擾用戶）

```
[開始] 讀取 /trust 模式，啟動 dav-trust

[文件 1/5] rsc.pdf → frontend/2026-01/react-server-components.md
[文件 2/5] hooks.pdf → frontend/2026-01/react-hooks-cheatsheet.md
[文件 3/5] postgresql-migration.pdf → backend/2026-01/postgresql-15-to-16.md
[文件 4/5] stride.pdf → security/2026-01/stride-threat-modeling.md
[文件 5/5] audit-log.pdf → backend/2026-01/append-only-audit-log.md

[概念提取] 跨 5 份文件提取 8 個概念：
  - [[server-component-serialization-boundary]] ← 新建
  - [[effect-shallow-compare]] ← 新建
  - [[postgres-major-version-upgrade]] ← 新建
  - [[stride-threat-modeling]] ← 新建
  - [[append-only-audit-log]] ← 新建
  - [[react-hooks-vs-class]] ← 從既有 derive
  - [[database-migration-blueprint]] ← 新建
  - [[audit-log-immutability]] ← 新建

[交叉引用] 自動建立 12 個 [[xxx]] 連結

[完成] 寫入 docs/trust-log.md 紀錄所有決策
```

### 用戶事後看到的結果

```
✅ /trust 任務完成

產出：
  - 5 個 wiki 文件
  - 8 個概念
  - 12 個交叉引用
  - docs/README.md 自動更新

決策摘要（完整 log 在 docs/trust-log.md）：
  - Category 分類：frontend × 2, backend × 2, security × 1
  - Tag：共 28 個（去除重複後 19 個）
  - 跳過 0 篇（無錯誤）

下一步建議：
  - 檢視 docs/README.md 確認導航結構
  - 進入概念庫檢視新建立的 8 個概念
```

---

## 範例 5：概念演進 — revise 決策

### 觸發情境

```
既有概念：
  [[effect-shallow-compare]]: Effect 依賴淺比較陷阱

新文件進來，內容講 React 18 的 useMemo 也有類似問題
```

### 對話流程

```
Agent: 開始處理新文件：react-18-usememo-pitfalls.pdf

⏳ [1-5/7] 來源 / 處理 / Category (frontend) / Tag / 交叉引用
⏳ [6/7] 概念提取

AI 發現新概念與既有概念部分重疊，需要決策：

  候選 concept：
  1. "useMemo 依賴淺比較"（與既有 80% 重疊）

  建議動作：
  A. revise（推薦 — 在 [[effect-shallow-compare]] 加入 useMemo 案例）
  B. derive（次選 — 建立子概念 [[effect-shallow-compare-vs-usememo]]）
  C. 其他（說明你的想法）

請選 A / B / C？

用戶: A

⏳ [7/7] 寫入 + 更新既有概念

✅ 完成！

修改：
  - [[effect-shallow-compare]] 的 definition 更新：
    原："Effect 依賴淺比較"
    新："Effect / useMemo 依賴淺比較，物件參考變化就重算"
  - history 增加：
    - {date: 2026-02-03, action: revised, note: "加入 useMemo 案例"}
  
新文件：
  - docs/wiki/frontend/2026-02/react-18-usememo-pitfalls.md
  - related: ["[[effect-shallow-compare]]"]
```

---

## 範例 6：概念合併（merge）

### 觸發情境

```
既有概念（兩個都建立過）：
  [[react-state-batching]]: 同一個事件中多次 setState 會被合併
  [[react-automatic-batching]]: React 18+ 在非同步中也會自動批次

新文件進來，內容把兩個主題合在一起討論，AI 判定重疊度 > 80%
```

### 對話流程

```
Agent: 概念提取時發現重疊，需要決策：

  ⚠️ 兩個既有概念高度重疊（> 80%）：
    - [[react-state-batching]]（2026-01-15 建立）
    - [[react-automatic-batching]]（2026-01-20 建立）

  建議動作：
  A. merge（推薦 — 保留較早、較完整的 [[react-state-batching]]）
     → 另一個標 deprecated + superseded_by
  B. revise（次選 — 任選一個擴充涵蓋另一個）
  C. 保留兩個（維持現狀，不推薦）

請選 A / B / C？

用戶: A

✅ 完成 merge：

  [[react-state-batching]]:
    - definition 更新（合併兩者精華）
    - history += {merged, "合併自 [[react-automatic-batching]]"}
    
  [[react-automatic-batching]]:
    - deprecated: true
    - superseded_by: "[[react-state-batching]]"
    - status: deprecated
    - history += {merged, "被合併到 [[react-state-batching]]"}
    - 從 _concepts.json 移除（檔案保留）
    - 從 docs/README.md 隱藏
```

---

## 範例 7：軟刪除文件

### 觸發情境

```
用戶發現一篇 wiki 文件已經過時，要棄用
```

### 對話流程

```
用戶：把 docs/wiki/frontend/2025-12/class-components-cheatsheet.md 標棄用，
     因為我們已經全面轉用 hooks 了

Agent: 確認棄用動作：

  ⚠️ 將標記 docs/wiki/frontend/2025-12/class-components-cheatsheet.md 為 deprecated
  
  影響：
  - 從 docs/wiki/_index.json 移除（檔案保留）
  - 從 docs/README.md 隱藏
  - 反向連結 [[class-components-cheatsheet]] 仍可被追溯
  
  建議是否同時 deprecate 相關概念？
  - [[react-class-component-lifecycle]] → deprecated
  
確認棄用？(y/N)

用戶: y
       也順便 deprecate 那個 lifecycle 概念

✅ 完成軟刪除：

  docs/wiki/frontend/2025-12/class-components-cheatsheet.md
    - frontmatter 加 deprecated: true
    - 從 _index.json 移除
    - README 隱藏
    - 檔案保留可追溯

  docs/concepts/react-class-component-lifecycle.md
    - status: deprecated
    - deprecated: true
    - superseded_by: "[[react-hooks-lifecycle]]"
    - history += {date: 2026-XX-XX, action: deprecated, note: "被 hooks 取代"}
    - 從 _concepts.json 移除
    - README 隱藏
```

---

## 範例 8：失敗處理 — OCR 圖片品質過低

### 觸發情境

```
用戶給了一張模糊的截圖
```

### 對話流程

```
用戶：把這張截圖變 wiki
     （附 image-blurry.png）

Agent: 開始執行 dav-wiki：OCR 提取圖片

⏳ [1/7] 來源識別：圖片，使用 tesseract OCR
⚠️ [2/7] OCR 失敗：圖片品質過低，無法提取文字

建議動作：
A. 跳過 OCR（推薦 — 產出文件標 `[需要人工 OCR]` 佔位）
B. 重試（換不同 OCR 設定，可能無效）
C. 中止（用戶手動處理後再來）

請選 A / B / C？

用戶: A

⏳ [3/7] Category 確認跳過（OCR 失敗為例外，產出標記 `needs-ocr`）

⏳ [4/7] Tag 自動提取：給予佔位 tag（`needs-ocr`、`placeholder`）以滿足 schema 必填

⏳ [5-7/7] 仍執行流程，但內容標 placeholder

✅ 完成（部分）：

  產出：docs/wiki/uncategorized/2026-01/image-blurry.md
  內容：
    <!-- 此文件 OCR 失敗，需要人工識別 -->
    <!-- 原始圖片：image-blurry.png -->

  概念：0 個（無內容可提取）
  Tag：[needs-ocr, placeholder]

  下次建議：
  - 提供更清晰的截圖
  - 或直接輸入文字內容
```

---

## 範例 9：重建 docs/README.md

### 觸發時機

每次 dav-wiki 任務完成（寫入 + 索引更新後）自動觸發。

### 流程

```
⏳ [7/7] 重建 docs/README.md（步驟 7 子動作）

讀取：
  - _index.json（N 個文件）
  - _concepts.json（M 個概念）
  - _tags.json（T 個 tag）

組裝結構：
  ## 📁 文件庫（N 篇）
    - frontend (n1)
      - [title](path) · tags · date
    - backend (n2)
    - ...
  ## 💡 概念庫（M 個）
    - [[concept-slug]] — 一句話定義
  ## 🏷️ 熱門標籤
    - tag1 (c1 篇)
```

### 產出範例

```markdown
# 📚 知識庫導航

最後更新：2026-01-15

## 📁 文件庫（12 篇）
- **frontend** (5 篇)
  - [React Server Components 深入解析](wiki/frontend/2026-01/react-server-components-deep-dive.md) · `react` `rsc` · 2026-01-15
  - [Next.js App Router 路由指南](wiki/frontend/2026-01/nextjs-app-router-guide.md) · `nextjs` `app-router` · 2026-01-12
  - ...
- **backend** (4 篇)
- **meeting-notes** (2 篇)
- **uncategorized** (1 篇)

## 💡 概念庫（8 個）
- [[server-component-serialization-boundary]] — Server Component 序列化邊界
- [[effect-shallow-compare]] — Effect / useMemo 依賴淺比較
- ...

## 🏷️ 熱門標籤
- `react` (3 篇)
- `nextjs` (2 篇)
- `database` (2 篇)
- `patterns` (2 篇)
```

---

## 範例 6：PDF 含圖片 + 影片（FR-3 多模組）

### 輸入

```
用戶：把這份 PDF 變 wiki
     （附檔：rsc-multimodal.pdf，內含 5 張圖 + 1 段 3 分鐘 demo 影片）
```

### 對話流程

```
Agent: 開始執行 dav-wiki：將 rsc-multimodal.pdf 轉成 wiki 文件

⏳ [1/7] 來源識別：PDF，偵測到 5 張圖 + 1 影片
⏳ [2/7] 內容處理（多模組）：
   [2a] 圖片提取（pdfimages） → assets/images/{1-5}.png
   [2b] Vision API 描述（GPT-4V）：為每張圖生 1-3 句描述
   [2c] 影片提取（ffmpeg） → assets/videos/demo.mp4
   [2d] Whisper 字幕轉錄 → assets/videos/demo.transcript.md
   [2e] 章節切分（場景偵測 + AI 摘要） → demo.chapters.json
⏳ [3/7] Category 建議（選擇或自訂）：
⏳ [4/7] Tag 自動提取
⏳ [4b/7] Keywords
⏳ [5/7] 交叉引用
⏳ [6/7] 概念提取
⏳ [7/7] 寫入 + 更新索引 + 重建 docs/README.md

✅ 完成！
  - 主文件：docs/wiki/frontend/2026-01/react-multimodal-deep-dive.md
  - 圖片：assets/images/{1-5}.png（含 Vision AI caption）
  - 影片：assets/videos/demo.mp4 + demo.transcript.md + demo.chapters.json
  - 概念：docs/concepts/{3 個概念}.md
```

### 產出檔案結構

```
docs/wiki/frontend/2026-01/
├── react-multimodal-deep-dive.md     # 主文件（含 image captions + 章節摘要）
└── assets/
    ├── images/1.png                   # RSC 架構圖
    ├── images/2.png                   # Streaming 流程圖
    ├── images/3.png                   # Bundle size 比較圖
    ├── images/4.png                   # Hydration 流程
    ├── images/5.png                   # 錯誤處理示意圖
    ├── videos/demo.mp4                # 3 分鐘 demo 影片
    ├── videos/demo.transcript.md      # Whisper 字幕
    └── videos/demo.chapters.json      # 章節切分
```

### 主檔 frontmatter 片段

```yaml
images:
  - path: "assets/images/1.png"
    caption: "RSC 架構圖：展示 Server Component 與 Client Component 的邊界"
    ocr_text: ""
    alt_text: "React Server Components 架構示意圖"
videos:
  - path: "assets/videos/demo.mp4"
    duration: 180
    transcript_path: "assets/videos/demo.transcript.md"
    chapters:
      - title: "開場"
        start: 0
        end: 30
        summary: "介紹 RSC 動機、與傳統 SSR 差異"
      - title: "原理講解"
        start: 30
        end: 120
        summary: "講解序列化邊界、streaming、partial hydration"
      - title: "實戰 demo"
        start: 120
        end: 180
        summary: "在 Next.js 14 App Router 實作 RSC"
    thumbnail: "assets/videos/demo.thumb.jpg"
```

---

## 範例 7：PPTX 內含影片（FR-3.3 + FR-3.7）

### 輸入

```
用戶：把這份 PPT 變 wiki
     （附檔：tech-talk.pptx，內含 10 slides + 2 段嵌入影片）
```

### 對話流程

```
Agent: 開始執行 dav-wiki：將 tech-talk.pptx 轉成 wiki 文件

⏳ [1/7] 來源識別：PPTX，10 slides + 2 影片
⏳ [2/7] 內容處理：
   [2a] 提取 slide 圖片 → assets/images/slide-{1-10}.png
   [2b] 提取嵌入影片 → assets/videos/intro.mp4 + demo.mp4
   [2c] Whisper 轉字幕（每段影片各一個）
   [2d] 提取每個 slide 的文字 + 表格
⏳ [3/7] Category
⏳ [4/7] Tag
⏳ [5/7] 交叉引用
⏳ [6/7] 概念
⏳ [7/7] 寫入

✅ 完成！
```

---

## 參考

- [SKILL.md](SKILL.md) — 主流程
- [frontmatter-schema.md](frontmatter-schema.md) — frontmatter 欄位定義
- [concept-evolution.md](concept-evolution.md) — 演進規則詳解
