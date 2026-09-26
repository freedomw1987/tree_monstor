---
name: dav-skill-creater
description: 從用戶對話或操作中提煉可重複應用的概念，產出新 skill（含 frontmatter + 「任務導航」5 段結構 + 純文字引用），存進 `skills/<name>/SKILL.md`。
---

# Dav Skill Creator

## TL;DR

1. **做什麼**：從用戶對話或操作中提煉可重複應用的概念 → 生成新 skill（含 frontmatter + 「任務導航」5 段結構）→ 存進 `skills/<name>/SKILL.md`。
2. **何時觸發**：用戶主動說「這是一個 skill」、「把它變成 skill」、「做 skill」；Agent 偵測到對話內容具備重複應用潛力。
3. **預設 SOP 路徑**：§2.6 一般任務（不需完整 SOP，因 skill 是輔助元工具）。
4. **關鍵紀律**：
   - **概念提煉 ≠ 操作記錄**：只總結「步驟描述 + 每步目的 + 想要效果」，不含具體代碼指令
   - **150 行上限**：SKILL.md 過長必拆到子檔（如 `examples.md`、`workflow.md`）
   - **「任務導航」5 段**（v2.1）：TL;DR / 觸發時機 / 流程 / 規則 / 變動歷史（推薦結構）
   - **純文字引用**（v2.1）：不放 `../`、`docs/` 跨檔連結或 `[[...]]` Obsidian cross-dir 連結；改用純文字「見 <path>」
   - **frontmatter 必填**：`name` + `description` 一句話 + 何時用 + 何時不用
5. **必產出物**：`skills/<name>/SKILL.md`（必含 frontmatter + 5 段結構）

## 觸發時機

| 情境 | 觸發 |
|------|------|
| 用戶說「這是一個 skill」「把它變成 skill」| ✅ 必須 |
| Agent 偵測對話有可重複應用潛力 | ✅ 主動詢問用戶 |
| 對話中出現「下次也這樣做」「之後再遇到」| ✅ 詢問是否變 skill |
| 純提問 / 不需重複應用 | ❌ 不觸發 |
| 用戶明確說「這不用記」 | ❌ 不觸發 |

## 流程（5 步）

### Step 1：提煉概念

- **動作**：從對話 / 操作中提煉可重複應用的概念（工作描述 + 步驟 + 每步目的 + 想要效果）
- **為什麼**：skill 是「可重用的概念」，不是「操作記錄」
- **產出**：概念草稿（含描述使用場景）
- **證據**：能用 2-3 句話說明「下次遇到 X，會這樣做」

### Step 2：與用戶確認

- **動作**：詢問用戶 1）技能名稱（必英文字符或 kebab-case）2）使用場景描述 3）必含規則
- **為什麼**：避免 AI 自行命名、避免場景不清
- **產出**：對話確認三項
- **證據**：對話有「名稱 = X / 場景 = Y / 規則 = Z」

### Step 3：設計「任務導航」結構（v2.1）

- **動作**：依推薦結構組織 SKILL.md — TL;DR / 觸發時機 / 流程 / 規則 / 變動歷史
- **為什麼**：LLM 注意力優化 — 5 段結構讓 LLM 快速定位、降低認知負擔
- **產出**：SKILL.md 草稿
- **證據**：5 段齊全（每段有獨立 `## <name>` 標題）

### Step 4：寫入 SKILL.md（純文字引用）

- **動作**：寫入 `skills/<name>/SKILL.md`，含 frontmatter；過 150 行拆子檔（如 `examples.md`）
- **為什麼**：可讀性 + skill 獨立搬動（純文字引用允許 skill 移到任何位置仍可用）
- **產出**：`skills/<name>/SKILL.md` + 必要子檔
- **證據**：SKILL.md < 150 行（或有合理解釋）+ 純文字引用

### Step 5：自驗收

- **動作**：自己讀一次 SKILL.md、確認 1）frontmatter 齊全 2）5 段結構 3）150 行內 4）純文字引用 5）有一句話 description
- **為什麼**：skill 是「給 LLM 讀的」，可讀性差直接影響效果
- **產出**：自驗收通過
- **證據**：5 項檢查全綠

## 規則 / 例外 / 限制

| 規則 | 例外 | 限制 |
|------|------|------|
| SKILL.md < 150 行 | 大型 skill（如 dav-planner）可例外 | 過長必拆 `examples.md` / `workflow.md` |
| frontmatter 必含 `name` + `description` | N/A | 不接受空 frontmatter |
| 概念提煉 ≠ 操作記錄 | N/A | 代碼示例放 `examples.md` |
| 5 段任務導航結構（v2.1）| 極簡 skill 可只有 TL;DR + 流程 | 推薦但不強制 |
| 純文字引用（v2.1）| skill 子檔可用 markdown | 不寫 `../`、`docs/`、`[[...]]` 跨 dir 連結 |
| 名稱必 kebab-case | N/A | 不接受空格、中文 |
| description 一句話 | N/A | 含「做什麼 + 何時用 + 何時不用」|
| 跨 skill 溝通純文字 | N/A | 用「見 <path>」 |

## SKILL.md 編寫準則（LLM 注意力優化）

### 5 段推薦結構（任務導航）

| 段落 | 目的 | 寫法 |
|------|------|------|
| **TL;DR** | 第一眼看到 | 5 個重點條列：做什麼 / 何時觸發 / SOP 路徑 / 關鍵紀律 / 必產出物 |
| **觸發時機** | 何時該用 / 不該用 | 表格：情境 + ✅/❌ |
| **流程** | 怎麼做 | N 步，每步 動作/為什麼/產出/證據 |
| **規則** | 邊界 / 例外 / 限制 | 表格：規則 / 例外 / 限制 |
| **變動歷史** | 版本演進 | 表格：版本 / 日期 / 變動 / 為什麼 |

### 可讀性原則

- **TL;DR 必須第一**：讓 LLM 第一秒就抓到核心
- **emoji 限縮**：只在「觸發時機」表用 ✅🟡❌，不在流程 / 規則濫用
- **表格只放結論**：長說明放流程步驟內、不放表格
- **流程明步**：每步必含 動作 / 為什麼 / 產出 / 證據 四元素
- **規則表格**：規則 / 例外 / 限制 三欄

### 反模式（避免）

| ❌ 反模式 | ✅ 改為 |
|----------|--------|
| ASCII box-drawing 流程圖 | 文字描述 + 表格 |
| 一大段散文 | 5 條列 |
| 不明步驟（只有標題） | 每步 4 元素（動作 / 為什麼 / 產出 / 證據）|
| 沒 frontmatter | 必含 `name` + `description` |
| `description` 太長（> 200 字）| 一句話聚焦 + 何時用 + 何時不用 |
| 跨 dir 連結（相對路徑指 docs/ 或 Obsidian wiki link 指其他 dir）| 純文字「見 docs/prd/03-knowledge-extraction.md」|

### 純文字引用規範（v2.1）

- **不放 markdown 跨 dir 連結**：禁止任何用相對路徑指向 SKILL.md 所在 dir 之外的 markdown 連結
- **不放 Obsidian 跨 dir 連結**：禁止用 Obsidian wiki link 指向其他 dir 的檔案
- **skill 子檔可用 markdown**：因為子檔和 SKILL.md 在同 dir，可正常使用相對連結
- **替代寫法**：純文字「見 `docs/prd/03-knowledge-extraction.md`」或「詳見 `skills/dav-wiki/SKILL.md`」

**例外**（仍可用 markdown 連結）：
- skill 自己的 `CHANGELOG.md` 內的版本歷史連結
- `AGENTS.md`（全域索引、非 skill）內的 handbook / gates.json 連結

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v2.1 | 2026-09-26 | 加「任務導航」5 段 + LLM 注意力準則 + 純文字引用 | TMO-009 階段 10：新 skill 編寫準則統一 |
| v2.0 | 2026-09-26 | 文件產出物精簡規則適用 | TMO-008 減法 |
| v1.x | — | （舊版 150 行 + Wiki link 規則）| 詳見 `docs/sop/handbook/changelog.md` |

---

**交叉引用（純文字）**：
- 規劃技巧（V01/V02 提問紀律）→ 見 `skills/dav-planner/SKILL.md`
- SOP 完整流程（§2.1-§2.5）→ 見 `docs/sop/handbook/`
- 全域 SOP 變動歷史 → 見 `docs/sop/handbook/changelog.md`
- TMO-009 設計依據（5 段結構理由）→ 見 `docs/prd/04-restructure-skills-llm-friendly.md`
