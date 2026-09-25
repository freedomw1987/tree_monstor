---
name: tree-monstor-design-system
description: |
  Design tokens and interaction design rationale for tree_monstor.
  tree_monstor is a CLI / agent-skill framework (no GUI), so this file
  documents the *interaction design system* — command patterns, output
  formats, confirmation flows — rather than visual UI tokens.
generated_by: dav-designer
generated_for: US-009 (dav-wiki skill)
---

# 🎨 tree_monstor Design System

> 本檔定義 tree_monstor 專案的**互動設計系統**。
> 由於 tree_monstor 是 CLI / AI agent skill 框架（無 GUI），
> DESIGN.md 在此專案內定義「命令列互動、輸出格式、確認流程」等設計 token，
> 而非傳統的顏色、字體、UI 組件。

---

## 1. 設計哲學（Design Philosophy）

### 1.1 核心原則

| 原則 | 說明 | 範例 |
| --- | --- | --- |
| **可預測（Predictable）** | 相同語境下，相同命令永遠有相同行為 | `/trust` 前綴永遠走 trust 模式 |
| **可中斷（Interruptible）** | 用戶可以隨時 Esc / Ctrl+C 中斷 | skill 輸出中途停下不影響系統狀態 |
| **可回放（Replayable）** | 所有輸出都可被複製、重跑、版本控制 | frontmatter 是 YAML，方便 grep / diff |
| **失敗安全（Fail-safe）** | 失敗時保持原狀，不留半成品 | 寫檔前先 dry-run，確認才落盤 |
| **漸進披露（Progressive Disclosure）** | 預設簡潔，進階功能按需展開 | AI 先給 2-3 個 category 建議，用戶可要求更多 |

### 1.2 設計張力（Trade-offs）

| 張力 | 預設取捨 | 例外情境 |
| --- | --- | --- |
| **自動 vs 手動** | AI 自動 + 用戶確認（AI 給建議，人做最後決定） | `/trust` 模式下 AI 全自動 |
| **簡潔 vs 完整** | 預設簡潔（-v 加詳細輸出） | 概念提取永遠顯示完整輸出 |
| **嚴謹 vs 靈活** | schema 嚴謹（frontmatter 必填欄位固定） | tag 名稱自由，不強制 |

---

## 2. 命令列設計（CLI Design Tokens）

### 2.1 命令前綴語法

```yaml
command_prefix:
  skill_invocation: "/<skill-name>"           # 觸發 skill
  trust_mode: "/trust "                       # 前綴 → 走 dav-trust
  args: "<space-separated key=value>"         # 命令列引數
  example: "/trust 把這份 PDF 變 wiki"
```

| Token | 規則 | 範例 |
| --- | --- | --- |
| Skill 名稱 | kebab-case（小寫 + 連字號） | `dav-wiki`、`dav-submitter` |
| Trust 前綴 | `/trust` 後接任意任務 | `/trust 批次處理這 5 份 PDF` |
| 旗標 | `--kebab-case` | `--auto-confirm` |
| 簡寫 | `-X`（單字符） | `-y` (yes), `-v` (verbose) |

### 2.2 輸出格式規範

```yaml
output_format:
  success: "✅ {一句話總結}"                  # 1 行，成功
  warning: "⚠️ {風險說明}"                    # 1 行，警告
  error: "❌ {錯誤原因} → {建議動作}"          # 1 行，錯誤含建議
  info: "ℹ️ {補充資訊}"                        # 1 行，補充
  progress: "⏳ [{n}/{total}] {步驟描述}"      # 進度條
```

| Token | 顏色建議 | 使用場景 |
| --- | --- | --- |
| ✅ success | 綠 | 任務完成 |
| ⚠️ warning | 黃 | 軟刪除、跳過、預設值覆寫 |
| ❌ error | 紅 | 中斷任務，建議下一步 |
| ℹ️ info | 藍 | 額外說明、依賴提示 |
| ⏳ progress | 灰 | 長時間任務的進度 |

### 2.3 確認流程（Confirmation Flow）

```yaml
confirmation:
  destructive_action: required                # 刪除、覆蓋必須確認
  read_only_action: skipped                  # 讀取、查詢跳過確認
  reversible_action: skipped                 # 可逆動作（如軟刪除）跳過確認
  batch_action: required_for_n_gt_5          # 批次超過 5 個要確認
```

**確認 prompt 格式**：

```
{emoji} {動作描述}
  → {將影響的範圍}
  → {預期結果}
{y/N}: 
```

**範例**：

```
⚠️ 將覆蓋 docs/wiki/frontend/2026-01/react-server-components.md
  → 原檔案 142 行、extracted_at: 2026-01-10
  → 新版本 187 行（+45 行）、新增 2 個 concept
y/N: 
```

---

## 3. AI 對話設計（Agent Interaction Tokens）

### 3.1 提問節奏

```yaml
one_question_at_a_time: true                 # SOP V01 — 一次只問一題
options_with_recommendation: true            # SOP V02 — 多選必標推薦
recommendation_position: first               # 推薦選項永遠放第一
fallback_input: "或輸入你自己的答案"          # 開放選項
```

### 3.2 確認 / 完成訊息模板

| 階段 | 訊息模板 |
| --- | --- |
| 開始任務 | `開始執行 {skill-name}：{一句話任務描述}` |
| 中間進度 | `⏳ [{step}/{total}] {步驟描述}...` |
| 需要確認 | `{問題}？\n{A. 推薦}\n{B. 替代}\n{C. 其他}` |
| 任務完成 | `✅ 完成！{N} 個檔案已產出，{M} 個概念已建立。` |
| 任務失敗 | `❌ 失敗：{原因}\n建議：{下一步}` |

### 3.3 長輸出處理

| 情境 | 處理方式 |
| --- | --- |
| 超過 20 行的 list | 摘要前 10 條 + `(共 {N} 條，輸入 'all' 看完整)` |
| 概念數量 > 5 | 用表格而非 bullet list |
| 交叉引用 > 10 | 分群（按 category）顯示 |

---

## 4. 檔案結構設計（File System Tokens）

### 4.1 dav-wiki 產出結構（FR-3 多模組擴充版）

```
docs/
├── README.md                          # 自動生成的導航頁
├── wiki/
│   ├── _index.json                    # 文件索引
│   ├── _tags.json                     # tag 反向索引
│   └── {category}/
│       └── {YYYY-MM}/
│           ├── {title}.md             # 帶 frontmatter 的內容檔
│           └── assets/                # FR-3 多模組資產（2026 Sprint 08+）
│               ├── images/{n}.png
│               ├── videos/{n}.mp4
│               ├── videos/{n}.transcript.md
│               └── audio/{n}.mp3
└── concepts/
    ├── _concepts.json                 # 概念索引
    └── {slug}.md                      # 概念文件
```

| Token | 規則 | 範例 |
| --- | --- | --- |
| `{category}` | kebab-case，小寫 | `frontend`、`meeting-notes` |
| `{YYYY-MM}` | ISO 8601 月份 | `2026-01` |
| `{title}` | kebab-case，50 字內 | `react-server-components-deep-dive` |
| `{slug}` (concept) | 同 title，但更精煉 | `effect-shallow-compare` |

### 4.2 frontmatter 設計

參見 [`frontmatter-schema.md`](skills/dav-wiki/frontmatter-schema.md)（US-009 產出）

### 4.3 命名規範

| 對象 | 規範 | 範例 |
| --- | --- | --- |
| 檔名 | `[a-z0-9-]+.md` | `react-server-components.md` |
| Tag | `[a-z0-9-]+`（小寫） | `react`、`server-components` |
| Category | `[a-z0-9-]+`（小寫） | `frontend`、`meeting-notes` |
| Concept slug | `[a-z0-9-]+`（小寫） | `effect-shallow-compare` |

---

## 5. 錯誤處理設計（Error Handling Tokens）

### 5.1 錯誤分類

| 等級 | 前綴 | 處理 |
| --- | --- | --- |
| **Critical** | ❌ | 中止任務，提示用戶 |
| **Recoverable** | ⚠️ | 跳過該項，繼續其他 |
| **Info** | ℹ️ | 提示用戶，但不阻塞 |

### 5.2 錯誤訊息模板

```yaml
error_template:
  critical:
    format: "❌ {動作} 失敗：{root_cause}\n   → 建議：{建議動作}"
    example: "❌ 提取 PDF 失敗：檔案損壞（無法讀取 page 3）\n   → 建議：請確認 PDF 是否完整，或改用其他來源"
  
  recoverable:
    format: "⚠️ {動作} 略過：{原因}\n   → 影響：{影響範圍}"
    example: "⚠️ OCR 略過：圖片品質過低\n   → 影響：本文件無文字內容，將以「[需要人工 OCR]」標記"
```

### 5.3 失敗復原

| 情境 | 復原策略 |
| --- | --- |
| 寫到一半中斷 | 自動 rollback（temp file + rename 模式） |
| 索引更新失敗 | 重試 3 次後提示用戶手動修 |
| 概念提取失敗 | 該概念留 `[draft]` 標記，事後補 |
| 網路斷線（網頁來源） | 快取部分結果，下次重連續傳 |

---

## 6. 跨 skill 設計一致性（Cross-Skill Consistency）

| Token | 規範 | 採用 skill |
| --- | --- | --- |
| `/trust` 前綴 | 永遠觸發 dav-trust 自主模式 | 所有 skill |
| ✅❌⚠️ℹ️⏳ | 統一 emoji 語意 | 所有 skill |
| YAML frontmatter | 統一格式（title / status / date） | 所有 skill |
| `docs/backlog.md` | 統一任務登記處 | 所有 skill |
| Wiki link `[[xxx]]` | 統一雙向連結語法 | dav-wiki、dav-reflection |

---

## 7. 設計決策記錄（Design Decisions）

| 決策 | 取捨 | 影響範圍 |
| --- | --- | --- |
| `dav-wiki` 走 CLI 而非 Web UI | 簡化部署，但失去 GUI 操作 | 用戶必須熟悉命令列 |
| 用 Obsidian `[[xxx]]` 連結 | 與 Obsidian 兼容，但其他工具不識別 | 主要用戶需使用 Obsidian 或自製渲染 |
| `_index.json` 而非全文搜尋 | 速度快，但失去語意精準度 | 交叉引用品質略低於全文比對 |
| 軟刪除而非真刪除 | 歷史可追溯，但磁碟用量增加 | 長期需清理機制（TD-019 待辦） |
| C 級深度加工但不做 QA | 內容品質高，但無訓練資料產出 | 不適合用 dav-wiki 做 AI 微調 |

---

## 8. 參考資料

- [Google Stitch DESIGN.md spec](https://stitch.withgoogle.com/docs/design-md/specification/)
- [tree_monstor SOP §1.5](../sop/handbook/changelog.md) — V01 / V02 提問與建議紀律
- [dav-skill-creater](../skills/dav-skill-creater/SKILL.md) — skill 命名與結構規範
