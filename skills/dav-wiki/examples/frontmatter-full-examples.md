# dav-wiki 樣例檔 — frontmatter 完整範例

> 配合 [`../frontmatter-schema.md`](../frontmatter-schema.md) 使用：呢度只放**可直接複製嘅完整範例**，
> 欄位規範（型別 / 必填 / 約束）→ 同套本 skill 子檔（`../frontmatter-schema.md` §1.2-§1.5、§2.2-§2.3）。

---

## 1. 文件 frontmatter 完整範例（含選填的多模組欄位）

```yaml
---

title: "React Server Components 深入解析"
source:
  type: pdf                       # 必填：pdf | docx | pptx | txt | md | url | ocr | subtitle
  original: "rsc-deep-dive.pdf"   # 必填：原始檔名 或 URL
  url: null                       # 選填：網頁來源時填
extracted_at: 2026-01-15          # 必填：ISO 8601 日期
category: frontend                # 必填：用戶確認的 category（kebab-case）
tags:                             # 必填：3-8 個 tag（kebab-case，小寫）
  - react
  - server-components
  - rsc
  - rendering
summary: "深入講解 RSC 的運作原理、與 SSR 的差異、效能影響"  # 必填：1-3 句
keywords:                         # 必填：3-5 個關鍵詞（從 summary 提取、提升交叉引用品質）
  - serialization
  - hydration
  - bundle-size
  - streaming
related:                          # 必填（可空陣列）：交叉引用
  - "[[nextjs-app-router-guide]]"
  - "[[streaming-ssr-patterns]]"
concepts:                         # 必填（可空陣列）：本文件提煉的概念
  - "[[server-component-serialization-boundary]]"
images:                           # 選填（FR-2.2）：文件內含的圖片清單
  - path: "assets/images/1.png"
    caption: "RSC 架構圖"
    ocr_text: ""
    alt_text: "React Server Components 架構示意圖"
videos:                           # 選填（FR-2.3）：文件內含的影片清單
  - path: "assets/videos/demo.mp4"
    duration: 180
    transcript_path: "assets/videos/demo.transcript.md"
    thumbnail: "assets/videos/demo.jpg"
    chapters:
      - title: "開場"
        start: 0
        end: 30
        summary: "介紹 RSC 動機與優勢"
audio:                            # 選填（FR-2.4）：文件內含的音訊清單
  - path: "assets/audio/podcast.mp3"
    duration: 1800
    transcript_path: "assets/audio/podcast.transcript.md"
deprecated: false                 # 必填：true | false
superseded_by: null                # 選填：deprecated 時填新檔路徑
---
```

> 純文字 / URL 來源**唔使**填 `images` / `videos` / `audio`；刪走嗰三段即可（其餘欄位不變）。

## 2. 概念 frontmatter 完整範例

```yaml
---

slug: effect-shallow-compare                # 必填：唯一識別（kebab-case）
title: "Effect 依賴淺比較陷阱"               # 必填：人類可讀名稱
definition: "Effect 依賴淺比較，物件參考變化就重跑"  # 必填：一句話定義
status: active                              # 必填：active | draft | deprecated
deprecated: false                           # 必填
superseded_by: null                         # 選填：deprecated 時填新 concept slug
parents: []                                 # 必填（可空）：父概念 [[xxx]]
children:                                   # 必填（可空）：子概念 [[xxx]]
  - "[[effect-shallow-compare-vs-deep]]"
related_docs:                               # 必填（可空）：引用此概念的文件
  - "[[react-hooks-cheatsheet]]"
history:                                    # 必填（可空）：演進歷史
  - date: 2026-01-15
    action: created
    note: "初版建立"
  - date: 2026-02-03
    action: revised
    note: "加入 useMemo 案例"
---
```
