# 任務分級（Task Tiering）— 小型任務判準與 gate 適用範圍
> **When to read:** Plan

> **Status:** Canonical. Source of truth for task tiers, the small-task (T1) downgrade checklist, mid-task re-tiering, and the declaration template.

> **背景**：SOUL.md 文檔紀律紅線寫明「小型任務 / 未採用基線嘅 project，文檔要求降為建議」，但「小型任務」過往冇客觀判準，靠 agent 臨場判斷，係不一致嘅來源。本文檔將判準寫死：**分級靠 checklist，唔靠感覺。**

---

## 三個 tier

| Tier | 名稱 | 進入條件 | 適用 gate |
|------|------|----------|-----------|
| **T1** | 小型任務 | 下方判準 1-6 **全部**滿足，並已按本文檔格式申報 | 驗證驅動紅線 54-56 + 基礎紅線（永不降級）；文檔紅線 10-12 及 doc-sync gate 降為建議 |
| **T2** | 標準任務 | 預設 tier：唔係 T1，且 project 未採用文檔基線 | T1 所有 gate + 工程紀律紅線 13-18 嘅實質要求（root cause、測試、CVE=0）；涉及嘅 doc artifact 按 `skills/regression-guard/` 等 skill 建立，唔可以因為未有文檔基線而跳過 bug-fix 紀律；新 feature / user-story 另走 spec gate |
| **T3** | 完整基線任務 | project 已存在 `docs/PRD.md` + `docs/QA-TRACKER.md`，**或** David 明確要求 full documentation baseline | 全部紅線 + `docs/qa-gate.md` 全部 gate；新 feature / user-story 另走 spec gate |

**永不降級（任何 tier）**：

- 驗證驅動紅線 54-56（先重現、實證驗證、先讀後寫 — 全文見 [`SOUL.md`](../SOUL.md)）
- 基礎紅線（唔寫安全漏洞代碼、唔 commit 明文 secrets）
- 例外申報本身（冇申報嘅降級 = 違規，唔係例外）

---

## T1 小型任務判準（全部滿足先算）

逐項核對；**任何一項唔滿足或唔確定 → 唔係 T1**：

1. **單一邏輯改動** — 一個 commit message 講得完嘅一件事；預計 diff ≤ 50 行（唔計 lock file / generated code / 純 test / 純 docs），觸及 ≤ 3 個 source file
2. **唔改契約** — 唔改 DB schema、API contract / endpoint、auth / permission 邏輯、部署 / infra 配置
3. **唔改依賴** — 唔新增 / 升級 / 移除任何 dependency
4. **唔觸及高風險區** — 唔改 P0/P1 user story 嘅行為；唔觸碰帶 `RG-` 標記嘅 code
5. **唔係 bug fix** — bug fix 一律走 `skills/regression-guard/`（紅線 13-14 唔可以降級），唔可以用 T1 繞過
6. **唔加開關** — 唔新增 feature flag、env var、endpoint、config key

**邊界規則**：

- 判準 1 嘅數字係 hard ceiling，唔係目標：50 行內但踩中判準 2-6 任何一項，照樣唔係 T1
- 唔確定滿唔滿足某一項 → 當唔滿足（升 tier），或直接問 David
- T3 project 內嘅個別改動仍可按本 checklist 申報 T1（例如改 typo、調 log 字眼），但涉及 PRD / QA-TRACKER scope 嘅改動一律唔得

---

## 分級決策順序

1. project 有 `docs/PRD.md` + `docs/QA-TRACKER.md`，或 David 明確要求 full baseline？→ **T3**
2. 唔係 T3 → 逐項核對 T1 判準，全部滿足並申報 → **T1**
3. 其餘一律 → **T2**

---

## 中途升級規則

T1 / T2 做到一半發現超出判準（例如原本改 UI 文案，做落發現要動 schema）：

1. **即刻停手**，唔好「順手做埋」
2. 重新分級（通常升 T2 / T3），並重新申報
3. 補齊新 tier 要求嘅 gate / docs，先至繼續改 code

---

## 申報格式（T1 必用；copy-paste template）

```
【任務分級申報】本任務按 T1 小型任務處理（docs/task-tiering.md 判準 1-6 已逐項核對，全部滿足）。
跳過：<列出跳過嘅 gate / 文檔，例如 doc-sync、QA-TRACKER row>。
仍然執行：先讀後寫、實證驗證（附命令 + 真實輸出）。
```

T2 喺缺 project doc artifact 時，同樣要申報「缺 <文檔>，等效資訊記錄喺 <位置>」。冇申報而降級 = 違規（見 SOUL.md 例外申報規則）。

---

## Spec gate 適用範圍

Tier 只決定工作規模與文檔基線；新 feature / user-story 的前置驗收契約由 [`spec-driven-development`](../skills/spec-driven-development/SKILL.md) 定義：

- T2 / T3 新 feature、scope 增量或 acceptance contract 改動：Build 前必須通過 foreground BA spec gate。
- T1、bug fix、read-only、QA-only、trivial ops 的 routing 與例外申報：以該 skill 的 trigger boundary 為準；T1 判定仍只以本檔判準 1-6 為準。
- 中途發現新 feature scope：套用本檔「中途升級規則」，停手、重新分級並補 spec gate。

---

## Related docs

- [Documentation index](00-index.md)
- [QA Gate](qa-gate.md)
- [Core identity](../SOUL.md)
- [Session and workspace rules](../AGENTS.md)
- [Project documentation standard](project-documentation-standard.md)
