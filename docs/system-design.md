# System Design — tree_monstor 技術架構

> 本檔定義 tree_monstor 專案的技術棧、系統組成部件、模組劃分與介面契約。
> 由 `dav-designer` 維護；每次新增 Backlog item 涉及架構變更時，必須同步更新本檔。

---

## 1. 技術棧（Tech Stack）

| 層 | 技術 | 用途 | 備註 |
| --- | --- | --- | --- |
| **Agent Runtime** | Pi / Claude Code | AI agent 執行環境 | skill 跨兩者兼容 |
| **Skill 格式** | Markdown + YAML frontmatter | skill 定義 | ≤150 行/SKILL.md |
| **腳本語言** | Bash (≥4.0) | install.sh / 系統腳本 | macOS + Linux 兼容 |
| **測試框架** | bats | 自動化測試 | 覆蓋 install.sh、SOP gates |
| **Schema 驗證** | ajv-cli + JSON Schema Draft 07 | 驗證 gates.json | |
| **文件格式** | Markdown + YAML | 知識庫、計畫、反省 | |
| **配置管理** | JSON / YAML | 索引、配置、metadata | |
| **版本控制** | Git | 源碼、文件、計畫 | |

---

## 2. 模組劃分（Module Architecture）

### 2.1 模組總覽

```
tree_monstor/
├── M1 — Installer & Distribution     [✅ Sprint 01-02]
├── M2 — SOP Infrastructure          [✅ Sprint 02]
└── M3 — Knowledge Management        [🟡 PENDING — US-009]
```

### 2.2 模組職責矩陣

| Module | 職責 | 邊界 | 變更影響 |
| --- | --- | --- | --- |
| **M1** Installer | 安裝 / 卸載 / 路徑處理 | 不管 SOP 內容 | 全域 / 專案安裝 |
| **M2** SOP Infra | SOP 規範 / Gate 規則 | 不管業務邏輯 | AGENTS.md / gates.json / skill 定義 |
| **M3** Knowledge | 知識提取 / 概念演進 / 交叉引用 | 不管 agent runtime | docs/wiki / docs/concepts |

### 2.3 模組介面契約

**M1 ↔ M2**：install.sh 部署 SOP 檔（複製 / symlink），不解析 SOP 內容
**M2 ↔ M3**：skill 透過 `name` / `description` frontmatter 自我描述，不互相 import
**M3 → M1**：M3 產物（docs/wiki, docs/concepts）由 M1 deploy 到全域（未來擴充）

---

## 3. M3 — Knowledge Management 詳細設計（US-009）

### 3.1 系統組成部件（FR-3 Sprint 08 多模組擴充）

```
dav-wiki skill (M3)
├── SKILL.md                       # 主流程定義（≤150 行）
├── examples.md                    # 5+ 操作範例
├── frontmatter-schema.md          # frontmatter 欄位定義（含 FR-3 圖/影/音）
└── concept-evolution.md           # 概念演進規則

工具（tools/）
├── wiki-cleanup.sh                # Sprint 04 TD-019 軟刪除
├── wiki-cross-ref.sh              # Sprint 04 TD-020 交叉引用
├── wiki-extract-media.sh          # Sprint 08 FR-3.1 PDF/DOCX/PPTX 媒體提取
└── wiki-media-describe.sh         # Sprint 08 FR-3.4 Vision + Whisper 調用

產物（被 M3 寫入 docs/）
├── README.md                      # 自動導航頁
├── wiki/
│   ├── _index.json
│   ├── _tags.json
│   └── {category}/{YYYY-MM}/
│       ├── {title}.md
│       └── assets/                # FR-3 多模組資產
│           ├── images/{n}.png
│           ├── videos/{n}.mp4
│           ├── videos/{n}.transcript.md
│           └── audio/{n}.mp3
└── concepts/
    ├── _concepts.json
    └── {slug}.md
```

### 3.2 資料流（Data Flow，FR-3 多模組版）

```
用戶輸入（文件 / URL / 文字）
    │
    ▼
[1] 來源識別與提取（FR-3.1）
    │   純文字 → 直接讀
    │   PDF → pdfimages + pdf2text
    │   DOCX → pandoc --extract-media
    │   PPTX → python-pptx
    │   網頁 → fetch_content
    │
    ├─→ [2a] 圖片處理（FR-3.4 Vision API + OCR）
    │      存 assets/images/ + AI 生 1-3 句描述
    │
    ├─→ [2b] 影片處理（FR-3.6 ffmpeg + Whisper）
    │      存 assets/videos/ + 字幕 .transcript.md + chapters.json
    │
    └─→ [2c] 音訊處理（FR-3.8 Whisper）
           存 assets/audio/ + 字幕 .transcript.md
    │
[2] 內容處理（AI）
    │   清理噪音 / 加標題層級 / 摘要
    ▼
[3] Category 建議（AI 給 2-3 個，用戶確認）
    ▼
[4] Tag 提取（AI 自動）
    ▼
[5] 交叉引用（讀 _index.json 比對，產出 [[xxx]]）
    ▼
[6] 概念提取（1-5 個 concept，建獨立 .md）
    ▼
[7] 寫入檔案 + 更新索引
    │   docs/wiki/...
    │   docs/concepts/...
    │   docs/wiki/_index.json
    │   docs/wiki/_tags.json
    │   docs/concepts/_concepts.json
    ▼
[8] 重建 docs/README.md 導航頁
    ▼
完成 ✅
```

### 3.3 索引結構設計

#### `docs/wiki/_index.json`

```json
[
  {
    "path": "frontend/2026-01/react-server-components-deep-dive.md",
    "title": "React Server Components 深入解析",
    "category": "frontend",
    "tags": ["react", "server-components", "rsc"],
    "summary": "深入講解 RSC 的運作原理、與 SSR 的差異",
    "extracted_at": "2026-01-15",
    "concepts": ["server-component-serialization-boundary"],
    "deprecated": false,
    "superseded_by": null
  }
]
```

#### `docs/wiki/_tags.json`

```json
{
  "react": ["react-server-components-deep-dive", "nextjs-app-router-guide"],
  "rsc": ["react-server-components-deep-dive"],
  "server-components": ["react-server-components-deep-dive"]
}
```

#### `docs/concepts/_concepts.json`

```json
[
  {
    "slug": "effect-shallow-compare",
    "title": "Effect 依賴淺比較陷阱",
    "definition": "Effect 依賴淺比較，物件參考變化就重跑",
    "parents": [],
    "children": ["effect-shallow-compare-vs-deep"],
    "related_docs": ["react-hooks-cheatsheet"],
    "status": "active",
    "superseded_by": null,
    "history": [
      { "date": "2026-01-15", "action": "created" },
      { "date": "2026-02-03", "action": "revised", "note": "加入 useMemo 案例" }
    ]
  }
]
```

### 3.4 概念演進規則

| 動作 | 觸發 | 操作 |
| --- | --- | --- |
| **derive（衍生）** | 新文件發現子概念 | 建立子概念文件，parent 指向原概念 |
| **revise（修正）** | 新文件修正原概念 | 修改 `definition`，加 history 記錄 |
| **merge（合併）** | 兩個概念重疊 | 保留一個，另一個標 `superseded_by` |
| **deprecate（棄用）** | 概念被新概念取代 | 標 `deprecated: true`，從 `_concepts.json` 移除（但檔案保留） |

完整規則見 [`docs/.agents/skills/dav-wiki/concept-evolution.md`](.agents/skills/dav-wiki/concept-evolution.md)。

### 3.5 Trust 整合

```
/trust <任務>
    │
    ▼
dav-trust skill 接管
    │
    ├── 自主完成 dav-wiki 的 7 步流程
    ├── 中間不打擾用戶
    ├── 決策寫進 docs/trust-log.md
    └── 完成後退出 trust 模式
```

### 3.6 軟刪除機制

| 操作 | frontmatter 變更 | 索引變更 |
| --- | --- | --- |
| 棄用單篇文件 | 加 `deprecated: true` 或 `superseded_by: <path>` | 從 `_index.json` 移除（或保留加 `deprecated` 標記） |
| 棄用概念 | 加 `deprecated: true` + `superseded_by` | 從 `_concepts.json` 移除，檔案留著 |
| 從 README 隱藏 | 不影響檔案，只是不列入導航頁 | |

---

## 4. 技術決策記錄（Architecture Decision Records）

### ADR-001：用 JSON 而非 YAML 作為索引格式
- **理由**：JSON 在所有 agent runtime 都能解析，YAML 需要依賴
- **影響**：frontmatter 仍用 YAML（人類可讀），但機器讀的索引用 JSON

### ADR-002：用 `_index.json` 索引式比對，而非全文搜尋
- **理由**：速度快、token 用量低
- **影響**：交叉引用品質略低於語意搜尋；接受這個 trade-off

### ADR-003：概念文件獨立，不嵌在 wiki 內
- **理由**：概念是「跨文件的知識單元」，獨立存放方便交叉引用
- **影響**：docs/concepts/ 與 docs/wiki/ 是兩個獨立結構

### ADR-004：軟刪除用 frontmatter 標記
- **理由**：保留歷史 + 可追溯 + 可復原
- **影響**：磁碟用量會累積（登記 TD-019：定期清理機制）

### ADR-005：OCR / 字幕列為擴充模組
- **理由**：核心流程先做扎實；OCR / 字幕需要外部依賴（tesseract / yt-dlp）
- **影響**：MVP 不含這兩個；未來可選安裝

### ADR-006：docs/README.md 自動重建（每次任務完成）
- **理由**：手寫一定過期；自動從索引組裝最可靠
- **影響**：每次 dav-wiki 任務多花一次 IO（但成本可忽略）

### ADR-007：C 級加工但不做 QA 問答對
- **理由**：QA 是另一個 use case（訓練資料生成），不在知識管理範圍
- **影響**：未來可派生獨立 skill `dav-qa-generator`（如需要）

---

## 5. 部署架構（Deployment Architecture）

### 5.1 本地開發

```
/Users/<user>/www/tree_monstor/
├── .agents/skills/dav-wiki/        # skill 源碼
├── docs/                            # 知識庫產物（git tracked）
│   ├── README.md
│   ├── wiki/
│   └── concepts/
└── install.sh                       # 不管 M3（M3 隨 skill 部署）
```

### 5.2 全域安裝後

```
~/.pi/skills/
└── dav-wiki/                        # symlink 到源碼

~/.pi/AGENTS.md                      # 包含 SOP，含 dav-skill-creater 引用
```

### 5.3 Skill 安裝路徑
跟 M1 install.sh 一致：symlink `tree_monstor/.agents/skills/dav-wiki/` → `~/.pi/skills/dav-wiki/`

無需修改 install.sh（M1 的 per-skill symlink 機制已覆蓋）。

---

## 6. 測試策略

### 6.1 測試層級

| 層級 | 工具 | 範圍 |
| --- | --- | --- |
| **單元** | tdd-test-writer + bats | frontmatter 生成、索引更新、concept extraction |
| **整合** | dev-checker-loop | 端到端流程（餵 PDF → 產出 wiki + concepts） |
| **回歸** | regression-guard | 跨 skill 一致性（frontmatter schema、命名規範） |
| **審查** | reviewer (subagent) | 文件品質、AC 達成度 |

### 6.2 關鍵測試案例（US-009-T2）

| 案例 | 輸入 | 預期 |
| --- | --- | --- |
| T1: 純文字 → wiki | `notes.txt` | 產出 .md + 更新 `_index.json` + `_tags.json` |
| T2: 網頁 → wiki + concepts | URL | 產出 .md + 至少 1 個 concept 獨立檔 |
| T3: 概念衍生 | 既有 concept + 新文件 | 新建子 concept，更新 parent.children |
| T4: 概念合併 | 2 個重疊 concept | 一個標 superseded_by，另一個保留 |
| T5: 軟刪除 | 執行 deprecate | frontmatter 加 deprecated，從索引移除 |
| T6: README 重建 | 任意任務完成 | README.md 自動更新，含最新文件 + concepts |
| T7: /trust 整合 | `/trust <任務>` | 走 dav-trust 流程，不打擾用戶 |

---

## 7. 已知技術債（登記到 backlog TD）

| ID | 描述 | 來源 |
| --- | --- | --- |
| TD-019（建議） | 軟刪除的檔案沒有自動清理機制 | US-009 ADR-004 |
| TD-020（建議） | 交叉引用品質受限於 `_index.json` 比對 | US-009 ADR-002 |

（這兩個會在 US-009 開始執行時正式登記到 backlog）

---

## 8. 參考資料

- [AGENTS.md §2 SOP](../AGENTS.md) — 5 階段流程
- [Google Stitch DESIGN.md](https://stitch.withgoogle.com/docs/design-md/specification/) — frontmatter 格式
- [Obsidian Wiki Links](https://help.obsidian.md/Linking/Internal+links) — `[[xxx]]` 語法
- [JSON Schema Draft 07](https://json-schema.org/draft-07/json-schema-release-notes.html) — Schema 規範
