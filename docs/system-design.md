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
├── M3 — Knowledge Management        [✅ Sprint 03]
└── M4 — Self-Evolution (RSI)        [🟢 Ready for Sprint — US-011~017]
```

### 2.2 模組職責矩陣

| Module | 職責 | 邊界 | 變更影響 |
| --- | --- | --- | --- |
| **M1** Installer | 安裝 / 卸載 / 路徑處理 | 不管 SOP 內容 | 全域 / 專案安裝 |
| **M2** SOP Infra | SOP 規範 / Gate 規則 | 不管業務邏輯 | AGENTS.md / gates.json / skill 定義 |
| **M3** Knowledge | 知識提取 / 概念演進 / 交叉引用 | 不管 agent runtime | docs/wiki / docs/concepts |
| **M4** Self-Evolution | RSI 觀察 / 聚合 / 提案 / 審批 / 合併 / 同步 | 不改業務邏輯，只改 SOP | AGENTS.md / gates.json / skills/ / docs/ |

### 2.3 模組介面契約

**M1 ↔ M2**：install.sh 部署 SOP 檔（複製 / symlink），不解析 SOP 內容
**M2 ↔ M3**：skill 透過 `name` / `description` frontmatter 自我描述，不互相 import
**M3 → M1**：M3 產物（docs/wiki, docs/concepts）由 M1 deploy 到全域（未來擴充）
**M1 ↔ M4**：install.sh 部署 `sop-evolver` skill（symlink）+ 初始化 `~/.tree-monstor/observations/`；卸載時對應清理
**M2 ↔ M4**：M2 的 gates.json 加 Gate 5 (RSI gate)；M2 的 AGENTS.md 加 §2.8 handbook + V03 紀律
**M4 ↔ M1↔M2**：M4 走 `rsi-sync.sh` 把新版 SOP 同步到所有已裝專案的 `~/.pi/sop/`（**不覆蓋本地 override**，保留用戶自訂）
**M4 ↔ 跨專案**：M4 觀察模式只在已裝 tree_monstor 的專案觸發，**只寫 observation JSON，不動 SOP 檔**

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

## 4. M4 — Self-Evolution (RSI) 詳細設計（US-011~017）

### 4.1 設計目標

讓 tree_monstor 具備「跨專案學習、單一源進化」能力：裝在專案裡的 tree_monstor **只觀察不動 SOP**；裝回源 repo 才聚合 + 提案 + 改 SOP；改完一次同步給所有已裝專案。

### 4.2 系統組成部件

```
M4 — Self-Evolution
├── skills/sop-evolver/                # 核心入口 skill
│   ├── SKILL.md                       # ≤150 行
│   ├── observation.md                 # 觀察模式規範 + JSON schema
│   ├── aggregator.md                  # 聚合模式規範
│   ├── proposer.md                    # 提案 prompt 模板
│   └── safety.md                      # 4 條不可違反規則
│
├── tools/                             # RSI 工具腳本
│   ├── rsi-aggregate.sh               # 收集觀察 + 聚合
│   ├── rsi-propose.sh                 # 產出 diff 提案
│   ├── rsi-metrics.sh                 # 量化指標（6 個）
│   ├── rsi-rollback.sh                # 一鍵回滾 + git tag
│   └── rsi-sync.sh                    # 同步 SOP 到已裝專案
│
├── docs/sop/                          # M2 產出被 M4 修改
│   ├── gates.json                     # + Gate 5 (RSI gate)
│   ├── handbook/2.8-rsi-evolution.md  # RSI 完整 SOP
│   └── rsi-log.md                     # 自我改進日誌
│
└── docs/prd/04-self-evolution.md      # 本模組 PRD
```

### 4.3 完整 RSI 流程圖

```
┌───────────────────────────┐    ┌───────────────────────────┐
│ 專案 A（裝了 tree_monstor）│    │  專案 B（裝了 tree_monstor） │
│  skills/sop-evolver      │    │  skills/sop-evolver      │
└─────────────┬─────────────┘    └─────────────┬─────────────┘
              │                                │
        任務完成                               │
              ▼                                ▼
        [觀察模式]                          [觀察模式]
              │                                │
              ▼                                ▼
┌───────────────────────────────────────────────────────────────────┐
│  ~/.tree-monstor/observations/                                  │
│   ├── project-A/2025-09-21.json                                │
│   ├── project-A/2025-09-22.json                                │
│   ├── project-B/2025-09-21.json                                │
│   └── ...                                                    │
└───────────────────────────────────────────────────────────────────┘
                                │
                                │ 用戶：cd 回源 repo + 打 /reflect
                                ▼
┌───────────────────────────────────────────────────────────────────┐
│  tree_monstor 源 repo  （Sprint 09+ 執行）                            │
│                                                                   │
│  [1] 聚合  rsi-aggregate.sh                                       │
│       │                          │
│       ├─ 去重 + 統計 + 排序                              │
│       └─ 產出 docs/rsi-aggregated-report.md                       │
│                │                                                  │
│                ▼                                                  │
│  [2] 提案  sop-evolver proposer.md                               │
│       │                          │
│       ├─ 讀聚合報告                              │
│       ├─ 映射成具體 PR diff                             │
│       └─ 每個 diff 附「證據」+「影響專案數」+「rollback 指令」              │
│                │                                                  │
│                ▼                                                  │
│  [3] Reviewer 二審  dev-checker-loop  ← V03 紀律要求                 │
│       │                          │
│       ├─ 風險分級 🟢/🟡/🔴                                    │
│       ├─ 跨 SOP 一致性檢查                                       │
│       └─ 產出 reviewer-verdict.md                                │
│                │                                                  │
│                ▼                                                  │
│  [4] 用戶批准  ← 必經人手                                          │
│       │                          │
│       ├─ 批准 / 退回 / 跳過 Reviewer 直接批                            │
│       └─ git commit + tag rsi-vYYYYMMDD-NN                       │
│                │                                                  │
│                ▼                                                  │
│  [5] 合併  rsi-rollback.sh 寫 rsi-log.md                            │
│                │                                                  │
│                ▼                                                  │
│  [6] 同步  rsi-sync.sh （install.sh 跑完後自動觸發）                        │
│       │                          │
│       └─ 把新版 ~/.pi/sop/ 同步到所有已裝專案                          │
│             （不覆蓋本地 override）                                      │
└───────────────────────────────────────────────────────────────────┘
```

### 4.4 觀察記錄 Schema（白名單 + 黑名單雙重保護）

觀察記錄只允許白名單欄位，多餘欄位自動 reject（嚴格驗證）；
黑名單欄位也自動 reject（防漏網）。裝在以下位置：

```json
{
  "task_id": "uuid-v4",
  "project_id": "a3f7b2c1",          // SHA256(安装路徑)[:8]，不存明文路徑
  "timestamp": "2025-09-21T14:30:00Z",
  "gate_results": {
    "gate-1-tdd": "pass",
    "gate-2-lint": "pass",
    "gate-3-regression": "fail",
    "gate-4-reviewer": "pass"
  },
  "skills_used": ["dav-planner", "tdd-test-writer"],
  "failure_signals": [
    {"gate": "gate-3-regression", "type": "test_timeout", "count": 2}
  ],
  "duration_seconds": 145
}
```

黑名單（被拒絕的欄位）：`raw_conversation` / `code_snippets` / `file_paths` / `env_values` / `git_messages`。

### 4.5 安全規則（不可違反，4 條）

1. **觀察/改動分離**：裝在專案裡的 tree_monstor **只能觀察**，不能改 SOP。驗證：專案裡打 `/evolve` 應被拒絕。
2. **匿名化**：observation 只記結構化信號，不收 raw 對話、code、路徑。
3. **Reviewer 二審必經**：所有 SOP 改動提案都走 dev-checker-loop 二審，用戶收到「diff + verdict」兩者並呈（V03 紀律）。
4. **一鍵回滾**：每次合併自動寫 git tag (`rsi-vYYYYMMDD-NN`)，`rsi-rollback.sh` 從 rsi-log.md 找 diff 還原。

### 4.6 量化指標（6 個）

`tools/rsi-metrics.sh` 統計：
1. **任務完成率**（過 4 Gates / 啟動任務）
2. **規範違規次數**（未引用 mandatory_phrase）
3. **TD 閉環率**（產出 TD / 解決 TD）
4. **跨專案觀察分佈**（哪些專案最容易出問題）
5. **AGENTS.md 字數變化**（SOP 熵增追蹤）
6. **skill 使用頻率**（哪些 skill 被低度使用）

---

## 5. 技術決策記錄（Architecture Decision Records）

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

### ADR-008：RSI 探用「主動跨專案升級」策略
- **理由**：跨專案學習 + 單一源進化，平衡「學習價值」與「避免版本碎片化」；只允許源 repo 改 SOP，避免多個 SOP 版本不一致
- **影響**：裝在專案裡的 tree_monstor **只能觀察不動 SOP**；源 repo 才能聚合 + 提案 + 改

### ADR-009：觀察記錄探 JSON Schema 白名單 + 黑名單
- **理由**：跨專案觀察最怕意外洩漏敏感資料；白名單強制結構化、黑名單明文拒絕
- **影響**：多餘欄位自動 reject；`project_id` 用 SHA256 雜湊不存明文路徑

### ADR-010：所有 SOP 改動必走 Reviewer subagent 二審（V03）
- **理由**：agent 自己提案自己改易形成自我強化偏見；Reviewer subagent 提供跨 SOP 一致性檢查與風險分級
- **影響**：用戶收到「diff + reviewer verdict」兩者並呈；可明確說「跳過 Reviewer」直接批

### ADR-011：rsi-sync 不覆蓋本地 override
- **理由**：用戶可能在已裝專案上調 SOP；如果 sync 強制覆蓋會造成無謂損失
- **影響**：sync 規則為「來源比目標新時才更新；只比來源檔，不動本地手動改動」；使用者可以手動 merge

### ADR-012：rsi-rollback.sh 合併自動寫 git tag `rsi-vYYYYMMDD-NN`（Sprint 10, TD-031）
- **理由**：手動 git tag 易遺漏；每次合併自動寫便於一鍵回滾
- **影響**：`rsi-rollback.sh tag --message "<msg>"` 子命令 → 計算當天最大序號 + 1；`list` 命令能列出所有 `rsi-v*` tag
- **實作**：grep `rsi-v$(date +%Y-%m-%d)-*` 找現有最大序號

### ADR-013：rsi-sync.sh --dry-run 列出將同步檔案清單（Sprint 10, TD-032）
- **理由**：使用者要在 sync 前看到會改哪些檔案（path + 動作 + hash 對比），不只是「N 個」
- **影響**：`rsi-sync.sh --dry-run --output <md-file>` 產出 markdown table；預設不破壞（dry-run 模式）
- **實作**：md5 hash 對比 + 表格式輸出

### ADR-014：rsi-propose.sh 規則庫 ≥ 8 個內建規則（Sprint 10, TD-030）
- **理由**：Sprint 09 只有 3 個內建規則，新觀察類型都 fallback 到「待人工分析」；累積後要擴充
- **影響**：`lookup_proposal()` 加 5 個新 case：`markdownlint_error` / `bash_error` / `test_fail` / `bats_unknown` / `v02_violated`
- **實作**：每個規則對應 1 個修改提案 + ≥ 1 個 bats 測試

---

## 6. 部署架構（Deployment Architecture）

### 6.1 本地開發

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

## 7. 測試策略

### 7.1 測試層級

| 層級 | 工具 | 範圍 |
| --- | --- | --- |
| **單元** | tdd-test-writer + bats | frontmatter 生成、索引更新、concept extraction |
| **整合** | dev-checker-loop | 端到端流程（餵 PDF → 產出 wiki + concepts） |
| **回歸** | regression-guard | 跨 skill 一致性（frontmatter schema、命名規範） |
| **審查** | reviewer (subagent) | 文件品質、AC 達成度 |

### 7.2 關鍵測試案例（US-009-T2）

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

## 8. 已知技術債（登記到 backlog TD）

| ID | 描述 | 來源 |
| --- | --- | --- |
| TD-019（建議） | 軟刪除的檔案沒有自動清理機制 | US-009 ADR-004 |
| TD-020（建議） | 交叉引用品質受限於 `_index.json` 比對 | US-009 ADR-002 |

（這兩個會在 US-009 開始執行時正式登記到 backlog）

---

## 9. 參考資料

- [AGENTS.md §2 SOP](../AGENTS.md) — 5 階段流程
- [Google Stitch DESIGN.md](https://stitch.withgoogle.com/docs/design-md/specification/) — frontmatter 格式
- [Obsidian Wiki Links](https://help.obsidian.md/Linking/Internal+links) — `[[xxx]]` 語法
- [JSON Schema Draft 07](https://json-schema.org/draft-07/json-schema-release-notes.html) — Schema 規範

---

## ADR-015：rsi-metrics.sh 加 30 天滑動 trend（Sprint 11）

- **狀態**：Accepted（2026-09-20）
- **背景**：當前 metrics 只能看「當下快照」，沒有歷史趨勢
- **決定**：
  - 加 `trend_history` 子命令
  - 從 `~/.tree-monstor/observations/` 抓最近 30 天 daily metrics
  - 用 sparkline（`▁▂▃▄▅▆▇█` 8 級字符）顯示趨勢
- **影響**：
  - 用戶能看 30 天變化趨勢而非單點
  - 對 Sprint 11 US-019 的 14 天觀察是必要工具
  - 5 個新 bats 測試

## ADR-016：rsi-propose.sh 加 confidence score（Sprint 11）

- **狀態**：Accepted（2026-09-20）
- **背景**：當前 propose 沒有「信心分數」，容易把噪音當提案
- **決定**：
  - 計算每個提案的 confidence（0~1）
  - 公式：`min(1.0, freq × 0.3 + projects × 0.2 + 1)`
  - ≥ 0.7 列為主要提案
  - < 0.7 列為「需人工確認」
- **影響**：
  - 過濾低信心提案
  - 對 Sprint 11 US-020 的「從觀察反推規則」是必要工具
  - 5 個新 bats 測試

## ADR-017：Sprint 11 真實部署策略（Sprint 11）

- **狀態**：Accepted（2026-09-20）
- **背景**：Sprint 09/10 都用 mock，沒有真實跨專案訊號
- **決定**：
  - 選 1 個輕量小型 web app（Express.js / Flask / Sinatra）
  - 用 `install.sh --enable-rsi` 裝觀察模式
  - 每日 cron 跑 `rsi-metrics.sh`
  - 觀察 14 天
  - 結束後跑 `trend_history` 看趨勢
  - 觀察/改動分離守住
- **影響**：
  - 第一次真實跨專案訊號
  - 為 Sprint 11 US-020 提供觀察資料
  - 8 個新 bats 測試
