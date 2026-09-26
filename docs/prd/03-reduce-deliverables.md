# PRD-03: 減法 — 文件產出物精簡

**版本**：v1.0
**日期**：2026-09-26
**Backlog**：TMO-008
**SOP 版本**：v2.0（待 Reviewer 確認）

---

## 背景

v1.8 / v1.9 連續兩個 sprint 的反省報告顯示，**完整 SOP 流程產出物快速膨脹**：

| Sprint | changelog | PRD | reflection | deliverable.md | deliverable.html | tests |
|--------|-----------|-----|------------|----------------|------------------|-------|
| v1.8 | +33 行 | +1 檔（6435 bytes）| +1 檔（3778 bytes）| +1 檔 | +1 檔（11058 bytes）| +10 探針 |
| v1.9 | +12 行 | +1 檔（2898 bytes）| +1 檔（4059 bytes）| +1 檔 | +1 檔（10581 bytes）| +7 探針 |
| **合計** | **+45** | **+2 檔** | **+2 檔** | **+2 檔** | **+2 檔** | **+17 探針** |

每次 sprint 都要寫 6+ 個檔。**用戶決定走減法**：減少未來 sprint 的產出物，保留存量 audit。

## 目標

未來 sprint 從「必寫 6 個檔」精簡為「必寫 2 個檔」，存量完全不動。

## 範圍

### In Scope（要做）

1. **AGENTS.md §2.4 / §2.5 章節**：精簡「§2.4 Reflection Gate 產出物 / §2.5 Submit Gate 產出物」說明
2. **skills/dav-submitter/SKILL.md**：精簡「三層產出物」結構，改為「兩層產出物」
3. **docs/sop/handbook/changelog.md**：新增 v2.0 條目
4. **docs/backlog.md**：新增 TMO-008（Story Point 估算見下）
5. **PRD**：本次變更需要架構決策 → 寫 PRD（本檔）
6. **Tests**（必要守護）：6 個探針守護 v2.0 規則（changelog v2.0、dav-submitter 不再提「三層」、不要求 HTML、§2.5 self-check 無 HTML、§2.4 反思併進規則、TMO-008 backlog）

### Non-goals（不做）

1. **不動存量**：v1.7.1 / v1.8 / v1.9 的 PRD / reflection / deliverable / html 全部保留
2. **不寫 deliverable.html**（本次也遵守新規則）
3. **不寫獨立 reflection.md**（併進本次的「deliverable.md 末段」）
4. **不增加 SOP 章節**：精簡不增章

## 未來 sprint 產出物規則（v2.0 新）

| 產出物 | 未來規則 | 為什麼 |
|--------|---------|-------|
| **changelog** | ✅ 必寫 | audit trail（規則改了就要有記錄）|
| **deliverable.md** | ✅ 必寫（含 reflection 末段）| 用戶驗收的主要交付 + 反省反思 |
| **PRD.md** | 🟡 視情境 | 只有「架構 / 結構變更」才寫；純文字修改 / 簡單 bug fix / 規則調整不寫 |
| **bats 探針** | 🟡 視情境 | 只有「需要守護變動」才加；避免「為證明工作而加」的探針 |
| **deliverable.html** | ❌ 不寫 | md 足夠；html 雙倍維護；協作主要在 git/markdown |
| **獨立 reflection.md** | ❌ 不寫 | 併進 deliverable 末段（不再獨立檔）|

### 新 deliverable.md 結構（兩段）

```markdown
# 交付摘要 — <task-name>

## 對話摘要（90 秒可讀完）
...（既有 §2.5 內容）

## 變更檔案清單 + Gate 驗證 + 下一步
...（既有 §2.5 內容）

---

## 反思（Reflection，併入此處）
...（既有 §2.4 6 維度 + 過程檢討）

## Reviewer 二審結果（V03 紀律）
...（既有 §2.4 reviewer findings 摘要）
```

## 使用流程（未來 sprint）

```
§2.1 Plan → 對話（含 V01/V02）
§2.2 Design → 視情境（架構/結構變更才寫 PRD）
§2.3 Execution → 4 Gate
  - Gate 1 TDD：視情境加探針
  - Gate 2 lint：必跑
  - Gate 3 regression：必跑
  - Gate 4 reviewer：SOP 變更必跑（V03 紀律）
§2.4 Reflection → 併入 §2.5 deliverable.md 末段
§2.5 Submit → 寫 deliverable.md（含反思）
```

## Story Point 估算（5）

| 工作項 | 點數 |
|-------|------|
| AGENTS.md §2.4 / §2.5 精簡 | 1 |
| dav-submitter SKILL.md 三層→兩層 | 1 |
| changelog v2.0 條目 | 1 |
| tests 探針（必要守護）| 1 |
| 測試 + Reviewer + 提交 | 1 |
| **合計** | **5** |

## 風險與緩解

| 風險 | 緩解 |
|------|------|
| 用戶忘記新規則，Agent 又寫出 html | §2.5 SOP 明示「不再生成 html」+ §2.7 (v1.9) 角色題依舊先問 |
| Reflection 併進 deliverable 變長，難讀 | deliverable 結構強制定錨「## 反思」段 |
| 探針減少 → 守護不足 | 加「必要守護判斷準則」（什麼情境要加探針）|

### 「必要守護」判斷準則（v2.0 新）

加 bats 探針的條件（符合任 1 個）：
- SOP 章節 / changelog 版本被修改（防止靜默移除）
- 跨檔一致性（文件 A 提到 B、B 確實存在）
- 已知 bug 修復（防止復發）

不加探針的情境：
- 「為證明工作」而加（沒有實際守護價值）
- 「feature creep 守護」（測試本來就要測的功能）

## DoD

- [ ] AGENTS.md §2.4 / §2.5 精簡說明
- [ ] skills/dav-submitter/SKILL.md 三層→兩層
- [ ] changelog v2.0 條目
- [ ] docs/backlog.md TMO-008 + 詳細段
- [ ] tests/v2-reduce-deliverables.bats 6 個探針守護
- [ ] Reviewer verdict: PASS（V03 紀律）
- [ ] TMO-008 → done
- [ ] 本次也遵守新規則：deliverable.md 含反思、不寫獨立 reflection.html

## 變更歷史

| 日期 | 版本 | 變更 | 作者 |
|------|------|------|------|
| 2026-09-26 | v1.0 | 初版建立（減法 PRD）| Agent |
