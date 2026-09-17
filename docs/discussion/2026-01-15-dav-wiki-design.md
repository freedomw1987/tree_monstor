# Discussion — `dav-wiki` skill 設計討論（2026-01-15）

> 本檔記錄 `dav-wiki` skill 從需求發想到定案的完整對話歷程。
> 詳細設計、Story Point、Sprint 安排請見 [`docs/plan/2026-01-15-dav-wiki-design.md`](../plan/2026-01-15-dav-wiki-design.md)（待 `dav-designer` 完成）。

---

## 📅 對話日期
2026-01-15

## 🎯 原始需求
> 用戶：我想做一個 skill，叫 `dav-wiki`，主要要用戶給予文件或資料，技能可以提取文件資料、變成 markdown file。

## 🧭 決策歷程（11 題問答）

### Q1 — 目的（Why）
**用戶選 A**：個人 / 團隊知識管理（把所有來源統一轉成 Markdown，存進 `docs/wiki/` 知識庫，方便檢索 / 複用 / AI 引用）

### Q2 — 輸入來源範圍
**用戶選 F**：全支援（純文字 + Office + 網頁 + 圖片 OCR + 影音字幕）
- 決策：OCR 和影音字幕列為「擴充模組」，核心流程先做扎實

### Q3 — 輸出結構
**用戶選 A**：
```
docs/wiki/{category}/{YYYY-MM}/{title}.md
```
每個檔案帶 YAML frontmatter（來源、提取日期、tags、摘要、related、concepts）

### Q4 — Category 分類方式
**用戶選 C**：AI 建議 2-3 個 category，用戶確認或自訂

### Q5 — 內容處理程度
**用戶選 C**（但去掉 QA 問答對）：
- ✅ 結構化整理（標題層級、重點摘要、圖表標記）
- ✅ AI 加 tag、交叉引用相關文件
- ❌ QA 問答對

### Q6 — 交叉引用運作
**用戶選 B**：索引式引用（維護 `docs/wiki/_index.json`，新文件跟索引比對）

### Q7 — Trust 整合
**用戶選 C**：可選 `/trust` 前綴走 `dav-trust` 自主模式

### Q8 — 驗收標準（AC）
**4 條基本 AC** 用戶確認通過：
1. 檔案產出在正確路徑
2. YAML frontmatter 完整
3. `_index.json` 已更新
4. 用戶確認 category 後才落檔

### Q9 — 概念檔案結構
**用戶選 A**：獨立 wiki（`docs/concepts/{slug}.md`，含 parents / children / related_docs / history）

**用戶附加需求**：skill 要能做「概念提取」+「概念演進（修改 / 延新）」

### Q10 — docs/README.md 導航頁
**用戶確認需要**，並選 A：**每次任務完成自動重建**
- 由 `_index.json` + `_concepts.json` + `_tags.json` 自動組裝

### Q11 — 文件 / 概念刪除
**用戶選 A**：軟刪除（frontmatter 標記 `superseded_by` / `deprecated`，檔案保留）

### Q12 — skill 大小拆分
**用戶選 A**：
```
dav-wiki/
├── SKILL.md                    ← 核心流程 ≤ 150 行
├── examples.md                 ← 操作範例
├── frontmatter-schema.md       ← frontmatter 欄位定義
└── concept-evolution.md        ← 概念演進規則
```

---

## ✅ 最終定案

### Skill 基本資訊
- **名稱**：`dav-wiki`
- **類型**：個人 / 團隊知識管理
- **存放路徑**：`tree_monstor/.agents/skills/dav-wiki/`

### 核心特性
1. **5 種來源**：純文字 / Office / 網頁（核心）+ OCR / 影音字幕（擴充）
2. **輸出結構**：`docs/README.md` + `docs/wiki/{category}/{YYYY-MM}/{title}.md` + `docs/concepts/{slug}.md`
3. **索引系統**：`docs/wiki/_index.json` + `docs/wiki/_tags.json` + `docs/concepts/_concepts.json`
4. **內容處理**：C 級深度加工（不含 QA 問答對）
5. **概念系統**：提取 + 演進（derive / revise / merge / deprecate）
6. **交叉引用**：`_index.json` 索引式比對 + Obsidian `[[xxx]]`
7. **Trust 整合**：可選 `/trust` 前綴
8. **軟刪除**：frontmatter 標記
9. **自動導航**：`docs/README.md` 每次任務完成自動重建

---

## 📝 後續動作
1. ✅ 登記到 `docs/backlog.md`（US-009）
2. ⏳ 用 `dav-designer` 產出設計計劃 → `docs/plan/2026-01-15-dav-wiki-design.md`
3. ⏳ 進入 SOP §2.3 執行階段（Gate 1-4）
