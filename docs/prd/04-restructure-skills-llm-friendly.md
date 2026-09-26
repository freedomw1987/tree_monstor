# PRD-04: 重結構 — 5 個 skill + AGENTS.md 改為「任務導航」風格

**版本**：v1.0
**日期**：2026-09-26
**Backlog**：TMO-009
**SOP 版本**：v2.0（保持）
**階段數**：5 階段分階段提交

---

## 背景

v1.8 / v1.9 / v2.0 連續 3 個 sprint 的反省都顯示同個問題：

| 問題 | 證據 |
|------|------|
| 章節編號冗餘（§2.7 / §2.7.1 / §2.7.2）| v1.9 P1-1 + Reviewer 抓跨檔語意衝突 |
| 大量 emoji 裝飾干擾 LLM 注意力 | v2.0 表格用 🚦✅⚠️❌📋 裝飾 |
| 表格密度太高 | v2.0 6 探針 + 6 維度反思表 |
| 「重要事項藏在大量文字中」 | Reviewer P2-3「存量特例」位置 |
| 術語不一致 | 「反思 / 反省 / reflection」混用 |

**根本問題**：當前 SKILL.md 結構是「人類好讀」風格，但**這個項目中 LLM 是主要讀者**（Agent skill 觸發、Reviewer 讀檔、bats 探針 grep）。人類可讀性 vs LLM 注意力友好之間存在張力，本 PRD 選擇「以 LLM 注意力為主、人類可讀為輔」。

## 目標

5 個 skill + AGENTS.md 重構為「任務導航」風格，LLM 第一眼能抓到：
1. 這個 skill **做什麼**
2. **何時該用 / 何時不該用**
3. **關鍵紀律**（V01/V02/V03 等）
4. **怎麼走 SOP**

## 範圍

### In Scope（11 階段分階段提交）

| 階段 | 內容 | Story Point |
|------|------|------------|
| 階段 1（PoC）| 只重構 `skills/dav-reflection/SKILL.md`（最簡單的）| 2 |
| 階段 2 | 套用同結構到 `skills/dav-submitter/SKILL.md` | 2 |
| 階段 3 | 套用同結構到 `skills/dav-planner/SKILL.md`（v1.9 改最多的）| 3 |
| 階段 4 | 套用同結構到 `skills/dav-trust/SKILL.md` | 2 |
| 階段 5 | 重構 `AGENTS.md` | 2 |
| 階段 6 | 重構 `skills/dav-wiki/SKILL.md` + 純文字引用 | 2 |
| 階段 7 | 重構 `skills/regression-guard/SKILL.md` + 純文字引用 | 3 |
| 階段 8 | 重構 `skills/tdd-test-writer/SKILL.md` + 純文字引用 | 2 |
| 階段 9 | 重構 `skills/dev-checker-loop/SKILL.md` + 純文字引用 | 2 |
| 階段 10 | 強化 `skills/dav-skill-creator/SKILL.md`（加可讀性 + LLM 注意力編寫準則）| 2 |
| 階段 11 | 回頭修既有 4 skill + AGENTS.md：跨檔引用改純文字 | 3 |
| **合計** | | **25** |

**註**：dav-designer（30 行）已很精簡，跳過重結構（避免「為改而改」）。

### 「skill 獨立搬動」原則（v2.1 新）

> **目的**：skill 可隨時搬到任何目錄，不會壊連結 / 壊引用。

**規則**：
1. **skill 內不寫任何 markdown 連結**（不論 `.md` / `.html` / 跨 skill），改用純文字說明
2. **引用跨檔時用「見 <路徑>」純文字**（不寫 `[name](path)`）
3. **skill 唯一可引用的 markdown 連結**：自己的子檔（如 `dav-submitter/SKILL.md` 引用 `template.md`）

**例外**：
- skill 內 `## 變動歷史` 表中的 changelog 連結（指向 `docs/sop/handbook/changelog.md`）— 可保留
- AGENTS.md 對 handbook / gates.json 的引用 — 可保留（AGENTS.md 是「主索引」，不是 skill）

**探針守護**：
- 每個 skill 不含 `[text](../*.md)` 或 `[text](../../*.md)` 形式
- 跨 skill 引用必為「見 skills/<name>/SKILL.md」純文字

### Non-goals

1. **不動 handbook 內文**（2.1~2.7）：只動 SKILL.md 的內部結構
2. **不動 bats 探針邏輯**：探針驗證的內容仍是 SOUL.md 的「真實規則」，只是結構變；探針若失效需更新，但屬於「調整探針」非「重探針邏輯」
3. **不動 PRD / changelog / deliverable 結構**：v2.0 規則適用
4. **不刪除任何現有功能**：所有章節內容都會在新結構中找到對應位置
5. **不動存量檔案**：v1.7.1 / v1.8 / v1.9 / v2.0 反思 / 交付檔全保留

## 新 SKILL.md 結構（「任務導航」5 段）

每個 SKILL.md 統一以下結構：

```markdown
---
name: <skill>
description: <一句話 + 何時用 + 何時不用>
---

# <Skill Name>

## TL;DR

1. **這個 skill 做什麼**：<一句話定義>
2. **何時觸發**：<一句話條件>
3. **預設 SOP 路徑**：§2.1 → §2.2 → §2.3 → §2.4 → §2.5
4. **關鍵紀律**：<V01 / V02 / V03 / ...>
5. **必產出物**：<檔案清單>

## 觸發時機

| 情境 | 觸發 |
|------|------|
| 觸發條件 A | ✅ 必須 |
| 觸發條件 B | 🟡 視情境 |
| 不該觸發 | ❌ 不觸發 |

## 流程（N 步）

### Step 1：<動詞 + 物件>

- **動作**：<一句話>
- **為什麼**：<一句話>
- **產出**：<檔案 / 對話輸出>
- **證據**：<怎麼確認完成>

### Step 2：...

## 規則 / 例外 / 限制

| 規則 | 例外 | 限制 |
|------|------|------|
| 一行規則 | 何時可豁免 | 何時強制 |

## 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v1.9 | 2026-09-26 | +§2.7 用戶背景收集 | 用戶決策 TMO-007 |
```

### 設計原則

| 原則 | 說明 |
|------|------|
| **TL;DR 第一** | LLM 第一眼就抓到「是什麼、紀律是什麼」 |
| **決策上移** | 重要事項（如跳過規則、存量特例）放在「流程」或「規則」開頭，不藏在最後 |
| **表格只放結論** | 表格 cell 不超過 1 行；細節放段落 |
| **emoji 限縮** | 只在「觸發時機」表用 ✅🟡❌，其他段不用裝飾 emoji |
| **流程明步** | 每步驟固定格式（動作 / 為什麼 / 產出 / 證據）|
| **變動歷史必含** | 每個 SKILL.md 自帶 CHANGELOG，與 docs/sop/handbook/changelog.md 交叉引用 |

## 階段交付策略（風險控制）

### 階段 1（PoC）：dav-reflection

- 為什麼先動這個：最簡單（123 行 → 重構後預估 80 行）、最不影響下游
- 完成標準：bats 探針仍綠、dav-submitter skill 仍可調用 dav-reflection、3 個用過 dav-reflection 的 sprint 仍可重跑
- 失敗標準：bats 探針破壞 > 5 個

### 階段 2-5

- 每階段結束都跑 v2-reduce / v1.8 / v1.9 全套探針
- 失敗 → 退回上一階段、修正

## Story Point 估算（總 12）

| 階段 | 工作項 | 點數 |
|------|-------|------|
| 1 | dav-reflection 重結構 + 探針驗證 + Reviewer | 2 |
| 2 | dav-submitter 重結構 + 探針驗證 + Reviewer | 2 |
| 3 | dav-planner 重結構 + 探針驗證 + Reviewer | 3 |
| 4 | dav-trust 重結構 + 探針驗證 + Reviewer | 2 |
| 5 | AGENTS.md 重結構 + 探針驗證 + Reviewer | 2 |
| **合計** | | **11** |

## 風險與緩解

| 風險 | 緩解 |
|------|------|
| v1.8 / v1.9 / v2.0 探針因結構改而失效 | 分階段提交：每階段結束跑全套 regression |
| 跨 skill 一致性（5 個 skill 結構統一）| 階段 1 確立「範本」，階段 2-5 套用 |
| bats 探針 grep 字串失效 | 探針結構同步更新（屬於「調整探針」非「重探針邏輯」）|
| 用戶中途改主意 | 分階段提交可隨時停 |

## DoD

### 階段 1（PoC）
- [ ] `skills/dav-reflection/SKILL.md` 重結構為「任務導航」5 段
- [ ] 探針全綠（dav-reflection 行為不變）
- [ ] Reviewer verdict: PASS

### 階段 2-5（套用）
- [ ] 每個 SKILL.md 結構符合「任務導航」5 段
- [ ] 每階段結束跑全套 regression 219/232 仍綠
- [ ] 每階段 Reviewer verdict: PASS

### 整體完成
- [ ] 5 個 SKILL.md + AGENTS.md 全重結構
- [ ] 全部 bats 探針仍綠（或更新後綠）
- [ ] TMO-009 → done
- [ ] 每次階段都遵循 v2.0「兩層交付物」規則（changelog + deliverable.md 含反思）

## 變更歷史

| 日期 | 版本 | 變更 | 作者 |
|------|------|------|------|
| 2026-09-26 | v1.0 | 初版建立（重結構 PRD）| Agent |
