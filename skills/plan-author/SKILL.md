---
name: plan-author
description: 將 Think / Plan 對話共識轉成 modular plan 文檔（PRD master + per-US + DESIGN + components/pages + ADRs + QA-TRACKER baseline + VERIFY）。Use when David / agent 表達新需求 / 新功能 / 「做 X」 / 「plan this」 / 「spec it」/ 開新項目 / 開新大 feature，**且未有 source code 基礎**。已有 source 嘅現有項目請用 `structural-doc-batch`（source-first derive）。
trigger: |
  "新功能" / "做 X" / "plan this" / "spec it" / "開新項目" / "想 build X" / "define plan" / "plan-author" / "我要做 ..." / "有個 idea" / "MVP" / "加 feature"
category: software-development
applicability: operational
---


Last-verified: 2026-08-02
# Plan Author — 從對話到 modular plan 文檔

> **Status:** Operational workflow. Plan phase 的 skill 化入口 — 把 Think/Plan 共識（不是 source code）轉成可執行嘅 modular plan docs。
>
> **配套**：
> - 對話互動規則見 `AGENTS.md` § Think / Plan 互動模式（2-4 選項 + 漏咗什麼自檢 + 推薦熟悉棧）
> - 規範見 `docs/project-documentation-standard.md`（modular 結構 + no-code rule）
> - Per-X templates 見 `docs/project-doc-templates/`（唔好從頭寫）
> - 已有 source code 嘅現有項目用 `structural-doc-batch`（source-first derive）

---

## Core rule

1. **不悶頭做** — 對話互動嚴格遵守 AGENTS.md Think/Plan mode：先問「為什麼需要這個」、提供 2-4 個方向、附「這個清單可能漏了什麼」、推薦熟悉棧要明說理由、至少一個選項跳出慣用棧。
2. **Scope 先於 docs** — 寫任何 doc 之前必須確認：MVP 範圍？核心 3 個 feature 是？Out of scope？這決定 US 數量跟 template 簡繁。
3. **Modular + no-code** — 沿用 `docs/project-documentation-standard.md` 規則：per-US / per-component / per-endpoint / per-coverage 子檔；structural docs 不含 source 語言 snippet；JSON schema / tables / ASCII wireframe OK。
4. **Spec 為 source of truth** — 寫完每個 US / component / endpoint，dev + checker 對齊這份；orchestrator inner loop Work Item 直接 reference per-US 檔，不引用 master 第 N 行（避免 monolithic line-number 引用失效）。
5. **不會自動生** — agent 必須主動 invoke 此 skill；plan 嘅 business decision（user story scope、優先級）係 human-driven。

---

## When to use

- David 表達新需求 / 新項目 / 新大 feature（綠field 或 major extension）
- Plan 階段未開始，需要把對話共識寫成可執行 plan
- 想 kick-off 整個 build 流程（Build 開 dev+checker loop）

## When NOT to use

- 已有 source code 嘅現有項目 → 用 `existing-project-intake` + `structural-doc-batch`
- 只是補 / 改 1 個 US → 直接 inline 改 `docs/US/<id>.md`
- 純研究 / 純閱讀 → 不需要 plan docs
- Build 中要 spec change → 用 `docs-sync`（不重建整份 plan）

---

## Workflow

### Step 0：Scope 確認（必須先做）

問 David：
- 「呢個 feature / 項目嘅一句話係？」
- 「MVP 範圍？什麼是 v1 必須有，什麼是之後？」
- 「如果只能做 3 個功能，是哪 3 個？」
- 「現有 ecosystem（已部署嘅 service / DB / CI）用不用？」

**確認後才進入 Step 1**。如果 David 仲未決定，明確講「需要 David 確認 scope 後先繼續」。

### Step 1：Tech stack options（2-4 個）

候選 stack 必須：
- 每個選項 pros / cons / 成本（開發時間 / 維護成本 / skill 需求）
- 推薦熟悉棧明說理由（已用 skills、學習成本、社群）
- 至少一個選項跳出慣用棧（避免 lock-in）
- 「這個清單可能漏了什麼」段：至少一個沒放上桌的方向 + 排除原因

### Step 2：Architecture decisions（每個重大決策）

候選 ADR 必須：
- 一個 ADR 一個決策（不要一篇寫 5 個決策）
- 用 Michael Nygard 格式（Status / Context / Decision / Consequences / Alternatives）
- 永遠 Accepted 後不改；要改就新 ADR 標 Superseded

### Step 3：US generation（用模板，唔好從頭寫）

每個 US 一個檔 `docs/US/<US-id>-<slug>.md`，用 `docs/project-doc-templates/us-template.md`：
- 描述（As / I want / so that）
- 驗收標準（checkbox list）
- 邊界情況（edge cases）
- Out of scope
- 依賴
- 變更紀錄

US 編號 `US-001`、`US-002` ...；sub-task 用 `US-001.1`。

### Step 4：Modular docs 寫入

| File | 來源 | Template |
|------|------|----------|
| `docs/PRD.md` | Master：Scope + US Index table | `prd-master-template.md` |
| `docs/US/<id>-<slug>.md` | 每 US 一個檔 | `us-template.md` |
| `docs/DESIGN.md` | Master：tokens + component/page index（如有 UI） | `design-master-template.md` |
| `docs/components/<Name>.md` | 每 component 一個檔（contract，**no-code rule**） | `component-contract-template.md` |
| `docs/pages/<page>.md` | 每 page 一個檔（wireframe + interaction） | `page-template.md` |
| `docs/architecture/0001-<title>.md` | 每重大 ADR 一個檔 | `adr-template.md` |
| `docs/QA-TRACKER.md` | US ↔ test mapping | （直接 inline，無 template） |
| `docs/VERIFY.md` | 驗證命令 | `verify-template.md` |
| `docs/API.md` + `docs/endpoints/<resource>.md` | 如有 API | `api-master-template.md` + `endpoint-resource-template.md` |

### Step 5：Pre-Build Documentation Gate（自檢）

Plan 結束、Build 開始前必須通過 `docs/qa-gate.md` §0A：

```bash
python3 scripts/docs_consistency_check.py --project-docs
```

預期 pass。如 fail，回到 Step 3-4 補齊缺失 docs。

### Step 6：Plan summary emit

寫到 `docs/plan-summary.md`（一次性，**不入 git**，作為 David 嘅 session artifact）：
- 一句話目標
- Tech stack 決定（一句）
- US 數量 + P0 數量
- ADR 數量
- Pre-Build Gate 結果
- 下一步：「invoke orchestrator skill 開始 Build」

---

## Files owned / produced

| Action | File |
|--------|------|
| Created | `docs/PRD.md` (master) |
| Created | `docs/US/<id>-<slug>.md` (per US) |
| Created | `docs/DESIGN.md` (master, 如有 UI) |
| Created | `docs/components/<Name>.md` (per component, 如有 UI) |
| Created | `docs/pages/<page>.md` (per page, 如有 UI) |
| Created | `docs/architecture/0001-<title>.md` (per ADR) |
| Created | `docs/API.md` (master, 如有 API) |
| Created | `docs/endpoints/<resource>.md` (per resource, 如有 API) |
| Created | `docs/QA-TRACKER.md` |
| Created | `docs/VERIFY.md` |
| Updated | `docs/00-index.md`（如有需要的話；不更新，state-machine 由 plan-author 寫文件本身即可）|
| **NOT in git** | `docs/plan-summary.md`（session-only artifact） |

---

## Pitfalls

1. **悶頭做 = 違規** — 沒有問 David 直接寫 US。AGENTS.md Think/Plan mode 是硬規定，唔係 optional。
2. **Spec vague** — US acceptance criteria 寫「system 應該 work」太虛。每個 AC 必須是 Given/When/Then 格式（見 us-template.md）。
3. **Out of scope 漏寫** — 每個 US 必填 Out of scope section，否則 scope creep 風險。
4. **Monolithic PRD** — 唔好把所有 US inline 寫喺 PRD.md；只 US Index table + 指向 US/ 子檔（modular 規則）。
5. **Source code snippets in spec** — 唔好喺 component / page spec 寫 `<Button onClick={...}>` 之類 example（no-code rule）。Contract 用 props table + events + a11y 描述。
6. **跳過 ADR** — 每個重大決策（framework、ORM、schema design）都要 ADR；不要一篇寫 5 個決策。
7. **Pre-Build Gate 跳過** — 寫完 doc 必須跑 `docs_consistency_check.py --project-docs`；fail 即補。
8. **Plan summary 寫入 git** — `docs/plan-summary.md` 係一次性 session artifact，唔 commit。git commit 嘅文件先係真相。

---

## 相關 skills / docs

- **AGENTS.md** § Think / Plan 互動模式 — 對話規則（必讀）
- **docs/project-documentation-standard.md** — modular 結構 + no-code rule 規範
- **docs/project-doc-templates/** — 14 個 templates（直接填）
- **docs/qa-gate.md** §0A — Pre-Build Documentation Gate
- **skills/orchestrator/SKILL.md** § Inner loop — Plan 結束後 invoke 開始 Build
- **skills/structural-doc-batch/SKILL.md** — 已有 source 嘅現有項目（不是本 skill 嘅範圍）
- **skills/existing-project-intake/SKILL.md** — 接手現有 project 嘅入口（不是本 skill 嘅範圍）