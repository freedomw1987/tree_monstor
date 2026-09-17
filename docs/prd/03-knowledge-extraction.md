# PRD-03 — Knowledge Extraction（dav-wiki skill）

> **對應 Backlog**：[US-009](../../backlog.md#us-009建立-dav-wiki-skill--統一文件資料提取與-markdown-化2026-01-15)
> **模組**：M3 — Knowledge Management
> **Story Point**：8（中等偏重：含核心流程 + schema + 演進規則 + examples + 測試）
> **建立日期**：2026-01-15

---

## 1. 模組目標（Module Goal）

建立 `dav-wiki` skill，統一文件資料提取與 Markdown 化流程，
讓用戶能把所有學習資料、研究筆記、會議記錄沉澱在結構化知識庫中，
且未來可透過 frontmatter、tag、概念交叉關聯被 AI 高效引用。

---

## 2. 功能清單（Functional Requirements）

### FR-1：多來源輸入

| ID | 功能 | 層級 | 說明 |
| --- | --- | --- | --- |
| FR-1.1 | 純文字檔（.txt, .md） | 核心 | 直接讀取 |
| FR-1.2 | PDF 文件 | 核心 | 用 pdf2text / pandoc 提取文字 |
| FR-1.3 | Word 文件（.docx） | 核心 | 用 pandoc 提取 |
| FR-1.4 | PowerPoint（.pptx） | 核心 | 用 pandoc 提取 |
| FR-1.5 | 網頁 URL | 核心 | 用 fetch_content 抓取並轉 markdown |
| FR-1.6 | 圖片 OCR | 擴充 | 用 tesseract（可選安裝） |
| FR-1.7 | YouTube 字幕 | 擴充 | 用 yt-dlp 提取字幕 |
| FR-1.8 | 影片本地檔 | 擴充 | 用 ffmpeg + 字幕提取 |

### FR-2：內容處理（AI 加工）

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-2.1 | 格式清理 | 移除頁碼、雜訊、廣告、重複內容 |
| FR-2.2 | 標題層級 | 自動加 # / ## / ### 結構 |
| FR-2.3 | 重點摘要 | 提取 1-3 句核心摘要（放 frontmatter） |
| FR-2.4 | 圖表標記 | 標記重要圖表（不放實際圖，僅標 `<!-- 圖：描述 -->`） |
| FR-2.5 | Tag 自動生成 | 3-8 個 tag / 篇（基於內容） |
| FR-2.6 | 交叉引用 | 讀 `_index.json`，比對找 2-5 篇相關 |

### FR-3：Category 互動

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-3.1 | AI 建議 | 給 2-3 個 category 候選 |
| FR-3.2 | 用戶確認 | 用戶可接受 / 拒絕 / 自訂 |
| FR-3.3 | 新 category | 自訂時自動建立目錄 |

### FR-4：概念系統

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-4.1 | 概念提取 | 每篇 1-5 個 concept（語意命題，不是 tag） |
| FR-4.2 | 概念獨立文件 | `docs/concepts/{slug}.md` |
| FR-4.3 | 衍生（derive） | 新概念建立為子概念 |
| FR-4.4 | 修正（revise） | 修改既有 concept + 加 history |
| FR-4.5 | 合併（merge） | 兩個概念合成一個 |
| FR-4.6 | 棄用（deprecate） | 標 `deprecated: true` + `superseded_by` |

### FR-5：索引與導航

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-5.1 | `_index.json` | 文件索引（title / category / tags / summary） |
| FR-5.2 | `_tags.json` | tag 反向索引 |
| FR-5.3 | `_concepts.json` | 概念索引（含演進 history） |
| FR-5.4 | `docs/README.md` | 自動重建的導航頁 |
| FR-5.5 | Obsidian 雙向連結 | `[[xxx]]` 語法 |

### FR-6：Trust 整合

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-6.1 | `/trust` 前綴 | 走 dav-trust 自主模式 |
| FR-6.2 | 正常模式 | 對話中逐步確認 |

### FR-7：軟刪除

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-7.1 | 軟刪除文件 | frontmatter 加 `deprecated` / `superseded_by` |
| FR-7.2 | 軟刪除概念 | 同上 + 從 `_concepts.json` 移除 |
| FR-7.3 | 從 README 隱藏 | 不影響檔案，只是不列入導航 |

### FR-8：錯誤處理

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-8.1 | 寫入失敗 rollback | temp file + rename 模式 |
| FR-8.2 | 索引更新重試 | 失敗重試 3 次 |
| FR-8.3 | 概念提取失敗標記 | 留 `[draft]` 後綴 |
| FR-8.4 | 網路斷線快取 | 部分結果快取，續傳 |

---

## 3. 非功能需求（NFR）

| ID | 需求 | 指標 |
| --- | --- | --- |
| NFR-1 | skill 大小 | SKILL.md ≤ 150 行 |
| NFR-2 | 處理速度 | 純文字 < 5 秒；PDF < 30 秒；網頁 < 20 秒 |
| NFR-3 | Token 用量 | 索引比對用 < 2k tokens |
| NFR-4 | 相容性 | Pi Agent + Claude Code 雙兼容 |
| NFR-5 | 可測試性 | 核心路徑 100% 有單元測試 |
| NFR-6 | 可追溯 | 所有操作有 log，可重建流程 |

---

## 4. 用戶故事與驗收

對應 backlog US-009 的 12 條 AC（見 [backlog.md](../../backlog.md#us-009建立-dav-wiki-skill--統一文件資料提取與-markdown-化2026-01-15)）。

---

## 5. Sprint 拆解（建議）

### 5.1 整體估算

| Sprint | 範圍 | Story Point | 累計 |
| --- | --- | --- | --- |
| Sprint 03（建議） | US-009 全部 | 8 | 8 |

由於本 US 強相依（schema → 演進規則 → examples → 測試 → 整合），不建議拆成多個 Sprint 跑。

### 5.2 Sprint 03 子任務

| ID | 標題 | 預估 SP | 依賴 |
| --- | --- | --- | --- |
| US-009-T1 | 設計文件（本 PRD + 設計 plan） | 1 | - |
| US-009-T2 | 用 `tdd-test-writer` 寫測試 | 1 | T1 |
| US-009-T3 | 實作 SKILL.md（核心流程） | 2 | T2 |
| US-009-T4 | 實作 frontmatter-schema.md | 1 | T2 |
| US-009-T5 | 實作 concept-evolution.md | 1 | T2 |
| US-009-T6 | 實作 examples.md | 1 | T3-T5 |
| US-009-T7 | dev-checker-loop 質量檢查 | 0.5 | T6 |
| US-009-T8 | regression-guard 探針 | 0.5 | T6 |
| US-009-T9 | dav-reflection 反省 | 0.5 | T7,T8 |
| US-009-T10 | dav-submitter 交付 | 0.5 | T9 |

合計：8 SP

---

## 6. 風險與緩解

| 風險 | 機率 | 影響 | 緩解 |
| --- | --- | --- | --- |
| OCR / 字幕擴充模組需要外部依賴 | 中 | 中 | 列為擴充，預設不安裝；提供安裝指南 |
| AI 交叉引用品質不穩定 | 中 | 中 | 索引式比對 + 用戶確認機制 |
| 概念提取主觀性高 | 高 | 低 | 留 `[draft]` 標記讓用戶後續調整 |
| 軟刪除累積磁碟 | 中 | 低 | 登記 TD-019 規劃定期清理 |
| 文件命名衝突 | 低 | 中 | title 走 slug 規則 + 衝突自動加 `-2` 後綴 |

---

## 7. 參考資料

- [docs/DESIGN.md](../../DESIGN.md) — 互動設計系統
- [docs/system-design.md](../../system-design.md) — 技術架構
- [docs/discussion/2026-01-15-dav-wiki-design.md](../../discussion/2026-01-15-dav-wiki-design.md) — 需求討論
- [dav-skill-creater](../../.agents/skills/dav-skill-creater/SKILL.md) — skill 創建規範
- [dav-trust](../../.agents/skills/dav-trust/SKILL.md) — trust 整合
- [dav-planner](../../.agents/skills/dav-planner/SKILL.md) — 規劃規範
