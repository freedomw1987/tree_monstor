# Concept Evolution — dav-wiki

> 本檔定義 dav-wiki 中**概念演進**的 4 種動作：derive / revise / merge / deprecate。
> 配合同套本 skill 子檔（`./frontmatter-schema.md`）使用；演進範例 → 同套本 skill 樣例檔（`./examples/concept-evolution-examples.md`）。

---

## 1. 為什麼需要概念演進？

概念（concept）不是 tag —— 它是**語意命題**，會隨新文件、新發現而**演化**：新文件可能發現子概念（derive）、
修正既有理解（revise）、揭示兩者其實是同一件事（merge），或被新概念取代（deprecate）。
沒有演進機制，概念庫會變成「一堆過時命題的墳場」。

---

## 2. 4 種演進動作

- **derive**（衍生）
  - 觸發：新文件發現既有概念的子領域
  - 關鍵操作：新建概念檔；原概念 `parents` + 新概念 `children` 互指；雙方 history 各記一筆
  - 結果：原概念 + 子概念**共存**
- **revise**（修正）
  - 觸發：新文件修正既有理解（定義不準、缺案例）
  - 關鍵操作：改 `definition`；history 加 `{date, action: revised, note}`；**slug 不變**、parents/children 不變
  - 結果：同一概念 ID、內容更新、歷史可追溯
- **merge**（合併）
  - 觸發：兩概念重疊度 > 80%
  - 關鍵操作：保留較早較完整者為主；另一個加 `deprecated: true` + `superseded_by`；主概念 definition 合併精華、`related_docs` 合併；被合併者移出 `_concepts.json`
  - 結果：一個概念；被合併檔案保留（可追溯）但索引消失
- **deprecate**（棄用）
  - 觸發：概念被新概念取代（技術演進，非合併）
  - 關鍵操作：加 `deprecated: true` + `superseded_by` + `status: deprecated`；移出 `_concepts.json`；history 加最後一筆 `action: deprecated`
  - 結果：新舊檔案都保留；舊的從索引與 README 移除

**操作順序（derive / merge / deprecate 共通）**：先改檔案 frontmatter → 再更新索引 → 最後重建 `docs/README.md`。

**典型例子**（derive / revise / merge / deprecate 各一）→ 同套本 skill 樣例檔（`./examples/concept-evolution-examples.md`）§1。

---

## 3. AI 決策樹

```
新概念 candidate 進來
    │
    ├─ 跟既有概念無 tag / 定義重疊 → 建立新概念（無演進）
    │
    ├─ 跟既有概念 A 部分重疊（50-80%）
    │   ├─ 是 A 的子領域？      → derive（A 為 parent）
    │   ├─ 是 A 的延伸案例？    → revise（更新 A 的 definition）
    │   └─ 是平行的不同主題？  → 建立新概念 + related_docs 加 [[A]]
    │
    ├─ 跟既有概念 A 高度重疊（> 80%） → merge（保留較完整的，A 為主）
    │
    └─ 完全重疊 或 A 被新發現否定 → deprecate（A），建立或指向新概念
```

**重疊度啟發式**：

- **Tag 完全相同 + definition 幾乎一樣** → 重疊度 > 90% → 動作：merge
- **Tag 重疊 50%+ + definition 互補** → 重疊度 60-80% → 動作：revise
- **Tag 不重疊但 definition 主旨相同** → 重疊度 70% → 動作：merge
- **Tag 不重疊 + definition 是上位 / 下位關係** → 重疊度 80% → 動作：derive
- **Tag 不重疊 + definition 無關** → 重疊度 < 30% → 動作：建立新概念

---

## 4. 對索引與 README 的影響

- **derive** — `_concepts.json`：兩者都加入；`docs/README.md`：兩個都列（用 `↳` 表示子概念）；檔案：都保留
- **revise** — `_concepts.json`：原概念更新（slug 不變）；`docs/README.md`：同一行，顯示最後更新日期；檔案：保留
- **merge** — `_concepts.json`：主要概念更新、被合併的**移除**；`docs/README.md`：只列主要概念、被合併的隱藏；檔案：保留（軟刪除）
- **deprecate** — `_concepts.json`：被棄用的**移除**；`docs/README.md`：隱藏（除非用戶開啟「顯示已棄用」）；檔案：保留

---

## 5. 用戶介入時機

AI 在以下情況應該停下來問用戶（不自動決定）：

- **merge 兩個概念** — 為何要問：用戶可能知道哪個語意更重要
- **deprecate 一個概念** — 為何要問：影響範圍大
- **revise 修改既有 definition** — 為何要問：用戶可能有特定措辭偏好

derive 同「建立全新概念」可由 AI 直接決定，事後告訴用戶結果。

---

## 6. 完整演進生命週期範例

- 演進生命週期範例（created → revised → derived → deprecated）→ 同套本 skill 樣例檔（`./examples/concept-evolution-examples.md`）§2

---

## 7. 參考

- 主流程 → 同套本 skill 主檔（`./SKILL.md`）
- history 條目規範 → 同套本 skill 子檔（`./frontmatter-schema.md`）
- 演進操作的對話範例 → 同套本 skill 樣例檔（`./examples/concept-evolution-examples.md`）
