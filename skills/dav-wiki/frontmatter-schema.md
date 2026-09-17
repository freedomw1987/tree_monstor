# Frontmatter Schema — dav-wiki

> 本檔定義 dav-wiki 產出檔案的 frontmatter 欄位。
> 分兩種：**文件 frontmatter**（`docs/wiki/`）與 **概念 frontmatter**（`docs/concepts/`）。

---

## 1. 文件 frontmatter（docs/wiki/{title}.md）

### 1.1 完整範例

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
deprecated: false                 # 必填：true | false
superseded_by: null                # 選填：deprecated 時填新檔路徑
---
```

### 1.2 欄位規範

| 欄位 | 型別 | 必填 | 約束 |
| --- | --- | --- | --- |
| `title` | string | ✅ | 50 字內、首字大寫 |
| `source.type` | enum | ✅ | `pdf` `docx` `pptx` `txt` `md` `url` `ocr` `subtitle` |
| `source.original` | string | ✅ | 原始檔名 / URL |
| `source.url` | string \| null | ❌ | URL 來源時填 |
| `extracted_at` | date | ✅ | ISO 8601（YYYY-MM-DD） |
| `category` | string | ✅ | kebab-case 小寫 |
| `tags` | string[] | ✅ | 3-8 個、kebab-case 小寫 |
| `summary` | string | ✅ | 1-3 句 |
| `keywords` | string[] | ✅ | 3-5 個關鍵詞（從 summary 提取、提升交叉引用品質） |
| `related` | string[] | ✅ | `[[xxx]]` 雙鏈接，可空 |
| `concepts` | string[] | ✅ | `[[xxx]]` 雙鏈接，可空 |
| `deprecated` | boolean | ✅ | `true` / `false` |
| `superseded_by` | string \| null | ❌ | deprecated 時填 |

---

## 2. 概念 frontmatter（docs/concepts/{slug}.md）

### 2.1 完整範例

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

### 2.2 欄位規範

| 欄位 | 型別 | 必填 | 約束 |
| --- | --- | --- | --- |
| `slug` | string | ✅ | kebab-case、唯一 |
| `title` | string | ✅ | 30 字內 |
| `definition` | string | ✅ | 1-2 句話定義 |
| `status` | enum | ✅ | `active` `draft` `deprecated` |
| `deprecated` | boolean | ✅ | `true` / `false` |
| `superseded_by` | string \| null | ❌ | slug 或 null |
| `parents` | string[] | ✅ | `[[xxx]]`，可空 |
| `children` | string[] | ✅ | `[[xxx]]`，可空 |
| `related_docs` | string[] | ✅ | `[[xxx]]`，可空 |
| `history` | object[] | ✅ | 可空，見下表 |

### 2.3 history 條目規範

每條 history 是一個物件：

| 欄位 | 型別 | 必填 | 說明 |
| --- | --- | --- | --- |
| `date` | date | ✅ | 發生日期（ISO 8601） |
| `action` | enum | ✅ | `created` `derived` `revised` `merged` `deprecated` |
| `note` | string | ❌ | 一句話說明 |

---

## 3. 驗證規則

### 3.1 寫入前檢查

寫入任何 frontmatter 前，必須確認：

- ✅ 所有必填欄位都有值
- ✅ 日期是有效 ISO 8601
- ✅ category / tag / slug 都符合 kebab-case
- ✅ `[[xxx]]` 內的 slug 在 `_index.json` 或 `_concepts.json` 存在（不存在會 warn，但不擋寫入）

### 3.2 軟刪除檢查

- 標 `deprecated: true` 的檔案 → 從 `_index.json` / `_concepts.json` 移除（檔案保留）
- 標 `superseded_by` 的檔案 → 同上，但保留反向連結以便追溯
- 自動從 `docs/README.md` 隱藏

### 3.3 命名衝突

若 slug 已存在：

- 自動加 `-2`、`-3` 後綴
- 在對話中提示用戶

---

## 4. 範例

### 4.1 一篇完成的 wiki 文件

```markdown
---
title: "Next.js App Router 路由指南"
source:
  type: url
  original: "https://nextjs.org/docs/app/building-your-application/routing"
  url: "https://nextjs.org/docs/app/building-your-application/routing"
extracted_at: 2026-01-15
category: frontend
tags:
  - nextjs
  - app-router
  - routing
summary: "Next.js 13+ App Router 的路由系統，包含 file-based routing、layouts、dynamic routes"
related:
  - "[[react-server-components-deep-dive]]"
concepts:
  - "[[app-router-file-conventions]]"
deprecated: false
superseded_by: null
---

# Next.js App Router 路由指南

## 簡介
...
```

### 4.2 一個演進中的概念

```markdown
---
slug: app-router-file-conventions
title: "App Router 檔案命名慣例"
definition: "App Router 透過檔案命名（page.tsx, layout.tsx, loading.tsx 等）來定義路由行為的慣例"
status: active
deprecated: false
superseded_by: null
parents: []
children:
  - "[[app-router-loading-conventions]]"
  - "[[app-router-error-conventions]]"
related_docs:
  - "[[nextjs-app-router-guide]]"
history:
  - date: 2026-01-15
    action: created
    note: "初版"
  - date: 2026-02-10
    action: revised
    note: "加入 route groups 說明"
---
```

---

## 5. 參考

- [Obsidian Internal Links](https://help.obsidian.md/Linking/Internal+links) — `[[xxx]]` 語法
- [JSON Schema Draft 07](https://json-schema.org/draft-07/json-schema-release-notes.html) — 索引格式
- [SKILL.md](SKILL.md) — 主流程
- [concept-evolution.md](concept-evolution.md) — 演進規則
