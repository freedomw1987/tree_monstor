# US-009 設計計劃 — `dav-wiki` skill

**對應 Backlog**：[US-009](../backlog.md#us-009建立-dav-wiki-skill--統一文件資料提取與-markdown-化2026-01-15)
**日期**：2026-01-15
**狀態**：✅ 設計完成，待用戶審核
**作者**：Agent（依 SOP §2.2 + `dav-designer`）
**範圍**：M3 — Knowledge Management（新模組）

---

## 1. 目標

建立 `dav-wiki` skill，統一文件資料提取與 Markdown 化流程，
讓所有學習資料、研究筆記、會議記錄可沉澱在結構化知識庫中，
且未來可透過 frontmatter、tag、概念交叉關聯被 AI 高效引用。

### 為什麼這是獨立模組（M3）

| 模組 | 範圍 | 現況 |
|---|---|---|
| **M1** — Installer & Distribution | install.sh / 路徑處理 / 卸載 | ✅ Sprint 01-02 完成 |
| **M2** — SOP Infrastructure | AGENTS.md SOP / Gate 規範 / skill 定義 | ✅ Sprint 02 完成 |
| **M3** — Knowledge Management**（新） | 知識提取 / 概念演進 / 交叉引用 | 🟡 本次新建 |

M3 是 M2 的下游消費者（M2 提供 SOP 規範，M3 依照規範產出 skill），
但 M3 的功能（知識管理）是完全獨立的業務領域，與 install / SOP 無關。

---

## 2. 用戶故事

> **作為** tree_monstor 的使用者，
> **我想要** 一個 `dav-wiki` skill，可以接收各種來源的資料（純文字、Office 文件、網頁、圖片 OCR、影音字幕）並自動轉成 Markdown 知識庫，
> **以便** 我能把所有學習資料、研究筆記、會議記錄統一沉澱在 `docs/wiki/`，且未來 AI 引用時可透過 frontmatter、tag、概念交叉關聯快速取用。

完整 12 條 AC 見 [PRD-03](../prd/03-knowledge-extraction.md) 與 [backlog US-009](../backlog.md#us-009建立-dav-wiki-skill--統一文件資料提取與-markdown-化2026-01-15)。

---

## 3. 系統架構決策

### 3.1 模組劃分

新增 **M3 — Knowledge Management** 模組：

- **職責**：管理知識提取、概念演進、交叉引用
- **介面**：透過 skill SKILL.md frontmatter 自我描述（不 import 其他 skill）
- **產物**：`docs/wiki/`、`docs/concepts/`、`docs/README.md`（git tracked）
- **不變**：M1 / M2 模組

### 3.2 Skill 結構

```
tree_monstor/.agents/skills/dav-wiki/
├── SKILL.md                    # 核心流程（≤150 行）
├── examples.md                 # 5+ 操作範例
├── frontmatter-schema.md       # frontmatter 欄位定義（文件 + 概念兩種）
└── concept-evolution.md        # 概念演進規則（derive/revise/merge/deprecate）
```

### 3.3 產物結構

```
docs/
├── README.md                          # 自動重建的導航頁
├── wiki/
│   ├── _index.json                    # 文件索引
│   ├── _tags.json                     # tag 反向索引
│   └── {category}/{YYYY-MM}/{title}.md
└── concepts/
    ├── _concepts.json                 # 概念索引
    └── {slug}.md
```

### 3.4 技術棧

- **Skill 格式**：Markdown + YAML frontmatter（跟其他 skill 一致）
- **資料格式**：JSON（索引）+ Markdown（內容）+ YAML（frontmatter）
- **雙鏈接語法**：Obsidian `[[xxx]]`
- **核心來源提取工具**：pandoc（PDF/DOCX/PPTX）、fetch_content（網頁）
- **擴充工具**（可選）：tesseract（OCR）、yt-dlp + ffmpeg（字幕）

---

## 4. Skill 流程設計（7 步主流程）

### 4.1 主流程圖

```
[用戶輸入]
    ↓
[1] 來源識別（純文字 / Office / 網頁 / OCR / 字幕）
    ↓
[2] 內容處理（清理 / 結構 / 摘要）
    ↓
[3] Category 互動（AI 給 2-3 建議 → 用戶確認）
    ↓
[4] Tag 提取（AI 自動）
    ↓
[5] 交叉引用（讀 _index.json 比對）
    ↓
[6] 概念提取（1-5 個 concept，建立獨立文件）
    ↓
[7] 寫入 + 更新索引 + 重建 docs/README.md
    ↓
[完成] ✅
```

### 4.2 細節（會寫進 SKILL.md）

| 步驟 | 動作 | 工具 |
| --- | --- | --- |
| 1 | 判斷來源類型，分派提取器 | OS 檔案類型 / URL 格式 |
| 2 | AI 處理文字內容（清理、標題、摘要） | 模型原生 |
| 3 | AI 給 category 候選 → 用戶確認 → 建立目錄 | read + write |
| 4 | AI 自動 tag（3-8 個） | 模型原生 |
| 5 | 讀 `_index.json`，比對找相關文件（2-5 個） | read |
| 6 | AI 提取 1-5 個 concept → 寫 `docs/concepts/{slug}.md` | write |
| 7 | 寫 `{title}.md` + 更新 3 個 JSON + 重建 README | write |

### 4.3 關鍵互動設計（從 DESIGN.md 引用）

- **一次一問**（SOP V01）：Category 確認時一次只問一個問題
- **推薦選項放第一**（SOP V02）：AI 給的 category 建議把最佳放第一
- **可預測**：相同輸入永遠有相同輸出（確定性流程）
- **失敗安全**：寫入失敗 rollback（temp file + rename）
- **軟刪除**：deprecated 標記而非真刪除

---

## 5. Frontmatter Schema（將寫進 `frontmatter-schema.md`）

### 5.1 文件 frontmatter（docs/wiki/{title}.md）

```yaml
---
title: "React Server Components 深入解析"
source:
  type: pdf
  original: "rsc-deep-dive.pdf"
  url: null
extracted_at: 2026-01-15
category: frontend
tags:
  - react
  - server-components
  - rsc
summary: "深入講解 RSC 的運作原理、與 SSR 的差異、效能影響"
related:
  - "[[nextjs-app-router-guide]]"
  - "[[streaming-ssr-patterns]]"
concepts:
  - "[[server-component-serialization-boundary]]"
deprecated: false
superseded_by: null
---
```

### 5.2 概念 frontmatter（docs/concepts/{slug}.md）

```yaml
---
slug: effect-shallow-compare
title: "Effect 依賴淺比較陷阱"
definition: "Effect 依賴淺比較，物件參考變化就重跑"
status: active  # active | deprecated
deprecated: false
superseded_by: null
parents: []
children:
  - "[[effect-shallow-compare-vs-deep]]"
related_docs:
  - "[[react-hooks-cheatsheet]]"
history:
  - date: 2026-01-15
    action: created
    note: "初版"
  - date: 2026-02-03
    action: revised
    note: "加入 useMemo 案例"
---
```

完整 schema（必填、可選、型別、約束）寫進 `frontmatter-schema.md`。

---

## 6. 概念演進規則（將寫進 `concept-evolution.md`）

### 6.1 4 種演進動作

| 動作 | 觸發 | 操作 | 結果 |
| --- | --- | --- | --- |
| **derive** | 新文件發現子概念 | 建立新概念文件，parent 指向原 | 原 + 子兩個概念共存 |
| **revise** | 新文件修正原概念 | 修改 `definition`，加 history 條目 | 概念 ID 不變，內容更新 |
| **merge** | 兩個概念重疊 | 保留一個，另一個加 `superseded_by` | 一個概念、檔案可保留或刪 |
| **deprecate** | 概念被新概念取代 | 加 `deprecated: true` + `superseded_by` | 從 `_concepts.json` 移除、檔案保留 |

### 6.2 判斷流程（AI 決策樹）

```
新文件進來，AI 提取 concept
    │
    ├─ 完全新的 → 建立新概念（無演進）
    │
    ├─ 跟既有概念相關但不重疊
    │   ├─ 是子概念？ → derive
    │   ├─ 是父概念？ → revise（擴充原概念）
    │   └─ 是平行？ → 建立新概念，related_docs 加連結
    │
    ├─ 跟既有概念部分重疊
    │   ├─ 重疊度 > 80% → merge
    │   └─ 重疊度 50-80% → revise（讓原概念涵蓋新案例）
    │
    └─ 跟既有概念完全重疊或被取代 → deprecate
```

完整決策樹與範例寫進 `concept-evolution.md`。

---

## 7. 測試策略

### 7.1 測試層級

| 層級 | 工具 | 範圍 |
| --- | --- | --- |
| 單元 | tdd-test-writer + bats | frontmatter 生成、索引更新、concept 提取 |
| 整合 | dev-checker-loop | 端到端流程（餵 PDF → 產出 wiki + concepts） |
| 回歸 | regression-guard | 跨 skill 一致性（schema、命名） |
| 審查 | reviewer (subagent) | 文件品質、AC 達成度 |

### 7.2 關鍵測試案例

| ID | 輸入 | 預期 |
| --- | --- | --- |
| T1 | 純文字檔 → wiki | 產出 .md + 更新 _index.json + _tags.json |
| T2 | 網頁 → wiki + concepts | 產出 .md + 至少 1 個 concept 獨立檔 |
| T3 | 概念衍生 | 既有 concept + 新文件 → 新建子 concept |
| T4 | 概念合併 | 2 個重疊 concept → 一個標 superseded_by |
| T5 | 軟刪除 | 執行 deprecate → frontmatter 加 deprecated |
| T6 | README 重建 | 任意任務完成 → README.md 自動更新 |
| T7 | /trust 整合 | `/trust <任務>` → 走 dav-trust 流程 |

---

## 8. Sprint 安排

**單一 Sprint 03 跑完**（強相依，不拆）：

| Sprint | 範圍 | Story Point | 累計 |
| --- | --- | --- | --- |
| Sprint 03（建議） | US-009 全部 | 8 | 8 |

### Sprint 03 子任務

| ID | 標題 | 預估 SP | 依賴 |
| --- | --- | --- | --- |
| US-009-T1 | 設計文件（本 PRD + 設計 plan） | 1 | - |
| US-009-T2 | 用 `tdd-test-writer` 寫測試 | 1 | T1 |
| US-009-T3 | 實作 `SKILL.md`（核心流程） | 2 | T2 |
| US-009-T4 | 實作 `frontmatter-schema.md` | 1 | T2 |
| US-009-T5 | 實作 `concept-evolution.md` | 1 | T2 |
| US-009-T6 | 實作 `examples.md` | 1 | T3-T5 |
| US-009-T7 | 用 `dev-checker-loop` 跑質量檢查 | 0.5 | T6 |
| US-009-T8 | 用 `regression-guard` 預留探針 | 0.5 | T6 |
| US-009-T9 | 用 `dav-reflection` 反省 | 0.5 | T7,T8 |
| US-009-T10 | 用 `dav-submitter` 產出交付物 | 0.5 | T9 |

---

## 9. 已知風險與緩解

| 風險 | 機率 | 影響 | 緩解 |
| --- | --- | --- | --- |
| OCR / 字幕需要外部依賴 | 中 | 中 | 列為擴充，預設不安裝 |
| AI 交叉引用品質不穩定 | 中 | 中 | 索引式比對 + 用戶確認 |
| 概念提取主觀性高 | 高 | 低 | 留 `[draft]` 標記供後續調整 |
| 軟刪除累積磁碟 | 中 | 低 | 登記 TD-019 規劃清理 |
| 文件命名衝突 | 低 | 中 | slug 規則 + 自動加 `-2` 後綴 |

---

## 10. 設計決策記錄（ADR）

### ADR-001：用 JSON 而非 YAML 作為索引格式
- **理由**：JSON 在所有 agent runtime 都能解析，YAML 需要依賴
- **影響**：frontmatter 仍用 YAML（人類可讀），機器讀的索引用 JSON

### ADR-002：用 `_index.json` 索引式比對，而非全文搜尋
- **理由**：速度快、token 用量低
- **影響**：交叉引用品質略低於語意搜尋；接受這個 trade-off

### ADR-003：概念文件獨立，不嵌在 wiki 內
- **理由**：概念是「跨文件的知識單元」，獨立存放方便交叉引用
- **影響**：docs/concepts/ 與 docs/wiki/ 是兩個獨立結構

### ADR-004：軟刪除用 frontmatter 標記
- **理由**：保留歷史 + 可追溯 + 可復原
- **影響**：磁碟用量會累積（登記 TD-019）

### ADR-005：OCR / 字幕列為擴充模組
- **理由**：核心流程先做扎實；OCR / 字幕需要外部依賴
- **影響**：MVP 不含這兩個；未來可選安裝

### ADR-006：docs/README.md 自動重建（每次任務完成）
- **理由**：手寫一定過期；自動從索引組裝最可靠
- **影響**：每次 dav-wiki 任務多花一次 IO（成本可忽略）

### ADR-007：C 級加工但不做 QA 問答對
- **理由**：QA 是另一個 use case（訓練資料生成），不在知識管理範圍
- **影響**：未來可派生獨立 skill（如需要）

---

## 11. 設計完成檢核（DESIGN GATE）

依 SOP §2.2，`dav-designer` 必須完成：

- [x] 分析 backlog（US-009 範圍明確）
- [x] 更新 `docs/DESIGN.md`（互動設計已建立）
- [x] 更新 `docs/system-design.md`（技術架構已建立）
- [x] 建立 `docs/prd/03-knowledge-extraction.md`（PRD 已建立）
- [x] 建立 `docs/prd/03-knowledge-extraction.html`（HTML 帶 SVG 已建立）
- [x] 估算 Story Point（8 SP）
- [x] 安排 Sprint（Sprint 03）
- [x] 列風險與緩解
- [x] 寫 ADR

**設計 Gate 通過** → 可以進入執行階段（SOP §2.3）。

---

## 12. 下一步

執行階段（SOP §2.3）會依序跑：

1. **Gate 1（TDD）**：用 `tdd-test-writer` 寫測試（US-009-T2）
2. **Gate 2（lint/syntax）**：Markdown / YAML / JSON 格式驗證
3. **Gate 3（regression）**：用 `regression-guard` 預留探針
4. **Gate 4（reviewer）**：用 `dev-checker-loop` + reviewer 審查

完成後依 SOP §2.4（dav-reflection）做 User Story 級別反省，再依 §2.5（dav-submitter）產出交付物。

---

## 13. 參考資料

- [DESIGN.md](../DESIGN.md) — 互動設計系統
- [system-design.md](../system-design.md) — 技術架構
- [PRD-03](../prd/03-knowledge-extraction.md) — 完整 PRD
- [PRD-03 HTML](../prd/03-knowledge-extraction.html) — 含 SVG 流程圖
- [discussion/2026-01-15-dav-wiki-design.md](../discussion/2026-01-15-dav-wiki-design.md) — 需求討論
- [AGENTS.md §2 SOP](../AGENTS.md) — 5 階段流程
- [US-007 設計計劃](2025-08-21-sop-gates-json.md) — 設計計劃範例
