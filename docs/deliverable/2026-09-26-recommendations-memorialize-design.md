# 設計：把 2 條建議入庫 — 多檔合併變更（dav-planner v2.6 後續維護提醒 + SOP §2.1.5 行數預檢 + editor-guide v2.5）

| 項目 | 值 |
|------|-----|
| 日期 | 2026-09-26 |
| 對應 Backlog | TD-020 後續（dav-planner v2.6 反思建議入庫）|
| 變動範圍 | 3 個檔（dav-planner/SKILL.md + AGENTS.md + dav-skill-creater/editor-guide.md）|
| V03 觸發 | ✅ 是（合併多檔 SOP 修改）|

---

## 1. 為什麼做這個改動

dav-planner v2.6 引入 dav-wiki 後產生 2 條「給未來的建議」（見 deliverable §5.4）：

1. **dav-wiki 引用同步檢查**（R1 殘留風險緩解）
2. **V03 主檔行數預檢**（R4 殘留風險緩解）

這 2 條不寫進檔就會**隨時間遺忘**。本次把它們正式入庫。

---

## 2. 改了什麼

### 2.1 變更總覽

| 檔 | 變動 | 行數預估 |
|----|------|----------|
| `skills/dav-planner/SKILL.md` | v2.6「為什麼」欄位分兩段（決策依據 + 後續維護提醒） | +1 行 |
| `AGENTS.md` | §1.5 表格加 1 行「V03.5 主檔行數預檢」 | +1 行 |
| `dav-skill-creater/editor-guide.md` | +新章節「主檔行數預檢規範」 | +10 行 |
| `skills/dav-skill-creater/SKILL.md` | 變動歷史加 v2.6 條目；v2.3 條目外移至 CHANGELOG | +1 行 |
| `skills/dav-skill-creater/CHANGELOG.md` | +v2.6 條目 | +1 行 |
| `docs/deliverable/2026-09-26-recommendations-memorialize.md` | 交付摘要 | 新檔 |

### 2.2 A. dav-planner 主檔 v2.6「為什麼」欄位追加

**原內容**：

```
dav-wiki 已是 monorepo skill、軟引用而非強制耦合；V03 Reviewer 二審通過（verdict-3）；依賴 dav-wiki skill 需同套安裝
```

**修正**：分兩段（決策依據 + 後續維護提醒），避免混雜語意

**修正後（兩段）**：

```
dav-wiki 已是 monorepo skill、軟引用而非強制耦合；V03 Reviewer 二審通過（verdict-3）；依賴 dav-wiki skill 需同套安裝

**後續維護提醒**：dav-wiki 大改後需跑「dav-planner 引用同步檢查」（防止 Step 1.5 引用過時）
```

### 2.3 B-1. AGENTS.md §1.5.1 主檔行數預檢（V03 紀律延伸）

**位置**：在 AGENTS.md `## §1.5 提問與建議紀律（fail-fast）` 段落內加 1 行（與 V01 / V02 / V03 並列）

**修正原因**：AGENTS.md 無 §2.1 母節（已抽去 handbook）、§2.1.5 編號會破壞 §2.x 索引一致性；§1.5.1 是「紀律延伸」、語意最貼切（預檢是 fail-fast 紀律的一部分）

**內容**（在 §1.5 表格加 1 行）：

```
| **V03.5** — V03 SOP 修改前必跑主檔行數預檢（見 `dav-skill-creater/editor-guide.md`「主檔行數預檢規範」） | 避免主檔逼近 150 上限 | 純文字修正不需預檢 |
```

### 2.4 B-2. editor-guide.md 新章節 + dav-skill-creater 主檔 v2.6 條目

**editor-guide.md 加新章節**（用 `##` 級別、與既有 5 個主題段並列）：

```markdown
## 主檔行數預檢規範（V03 SOP 修改前必跑）

**同源**：見 AGENTS.md §1.5.1（V03.5 紀律）

觸發條件：SOP / skill 結構修改 → 走 V03 Reviewer 二審之前

動作：
1. 目標 skill 主檔 `wc -l SKILL.md`
2. 若 ≥ 150 → 必先瘦身（主檔 ≤ 130 行再進 §2.2）
3. 若 130-149 → 在設計草案加「行數預警」、避免觸發 150 上限
4. 若 < 130 → 不預警

為什麼：
- 主檔 ≥ 150 行 → 違反 editor-guide.md 行數上限
- 主檔 130-149 → 餘裕不足、未來小變更也可能觸發

例外：純文字修正（typo / link / 註解）不需預檢
```

**dav-skill-creater 主檔 SKILL.md 變動歷史加 v2.6 條目**（不是 editor-guide.md；因 editor-guide.md 無變動歷史表）：

```markdown
| v2.6 | 2026-09-26 | +editor-guide.md 「主檔行數預檢規範」新章節；V03 SOP 修改前必跑 `wc -l` 預檢 | dav-planner v2.6 反思 R4：主檔 138/150 餘裕 12 行，下次再加需外移；建立預檢機制以免屆時被動瘦身 |
```

**dav-skill-creater 主檔加 v2.6 後觸發 v2.4 外移**：當前 3 條（v2.5/v2.4/v2.3）+ v2.6 = 4 條 → **v2.3 外移到 CHANGELOG.md**，主檔只留 v2.6 /
v2.5 / v2.4 共 3 條

**dav-skill-creater/CHANGELOG.md 加 v2.6 條目**（完整紀錄）：

```markdown
| v2.6 | 2026-09-26 | +editor-guide.md 「主檔行數預檢規範」新章節（V03 SOP 修改前必跑 `wc -l`）；主檔變動歷史 v2.3 外移 | dav-planner v2.6 反思 R4：主檔 138/150 餘裕 12 行；建立預檢機制以免主檔逼近 150 才被動瘦身 |
```

---

## 3. 驗證

| 探針 | 預期結果 |
|------|---------|
| restruct-no-cross-dir-path.bats | 2/2 ok |
| check-examples-version-baseline.bats | 1/1 ok |
| 5 項自驗收（dav-planner / dav-skill-creater）| 全綠 |

**特別驗證**：本次變動 0 新增 path、0 新增跨檔連結。

---

## 4. 殘留風險

| # | 風險 | 評估 | 緩解 |
|---|------|------|------|
| R1 | AGENTS.md §2.1.5 可能與現有 SOP 編號衝突 | 低 | §2.1 是「規劃」主段落，加 §2.1.5 為「規劃內子節」，不影響 §2.2 / §2.3 |
| R2 | editor-guide.md 若無 §2.4.5 結構性位置 | 低 | 已在草稿明示「若無結構性段落則加在 v2.4 規範後」|

---

## 5. Reviewer 二審 6 點

1. **合規性**：A 追加文字 30 字內、B-1/B-2 規範條目是否符合 editor-guide.md 既有慣例？
2. **結構性**：AGENTS.md SOP 編號 §2.1.5 是否與現有編號衝突？
3. **行數影響**：AGENTS.md 加 +10 行、editor-guide.md 加 +5 行、dav-planner 加 +0 行 — 是否觸發各自上限？
4. **v2.5 變動歷史**：editor-guide.md 加 v2.5 條目後是否觸發瘦身規則？
5. **雙向引用**：AGENTS.md §2.1.5 ↔ editor-guide.md §2.4.5 同源設計是否清晰？
6. **backlog / 探針**：本次變動不動 backlog、不動探針 — 確認？
