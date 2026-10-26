# Concept Evolution — dav-wiki

> 本檔定義 dav-wiki 中**概念演進**的 4 種動作：derive / revise / merge / deprecate。
> 配合 [frontmatter-schema](frontmatter-schema.md) 使用。

---

## 1. 為什麼需要概念演進？

概念（concept）不是 tag —— 它是**語意命題**，會隨新文件、新發現而**演化**：新文件可能發現子概念（derive）、
修正既有理解（revise）、揭示兩者其實是同一件事（merge），或被新概念取代（deprecate）。
沒有演進機制，概念庫會變成「一堆過時命題的墳場」。

---

## 2. 4 種演進動作

| 動作 | 觸發 | 關鍵操作 | 結果 |
|------|------|---------|------|
| **derive**（衍生） | 新文件發現既有概念的子領域 | 新建概念檔；原概念 `parents` + 新概念 `children` 互指；雙方 history 各記一筆 | 原概念 + 子概念**共存** |
| **revise**（修正） | 新文件修正既有理解（定義不準、缺案例） | 改 `definition`；history 加 `{date, action: revised, note}`；**slug 不變**、parents/children 不變 | 同一概念 ID、內容更新、歷史可追溯 |
| **merge**（合併） | 兩概念重疊度 > 80% | 保留較早較完整者為主；另一個加 `deprecated: true` + `superseded_by`；主概念 definition 合併精華、`related_docs` 合併；被合併者移出 `_concepts.json` | 一個概念；被合併檔案保留（可追溯）但索引消失 |
| **deprecate**（棄用） | 概念被新概念取代（技術演進，非合併） | 加 `deprecated: true` + `superseded_by` + `status: deprecated`；移出 `_concepts.json`；history 加最後一筆 `action: deprecated` | 新舊檔案都保留；舊的從索引與 README 移除 |

**操作順序（derive / merge / deprecate 共通）**：先改檔案 frontmatter → 再更新索引 → 最後重建 `docs/README.md`。

**典型例子**：

```
derive:    [[effect-shallow-compare]] → [[effect-shallow-compare-vs-deep]]（深比較也有陷阱）
revise:    definition "Effect 依賴淺比較" → "Effect / useMemo 依賴淺比較"
merge:     [[react-state-batching]]（主） ← [[react-automatic-batching]]（deprecated + superseded_by）
deprecate: [[react-class-component-lifecycle]] → superseded_by [[react-hooks-lifecycle]]
```

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

| 訊號 | 重疊度評估 | 動作 |
| --- | --- | --- |
| Tag 完全相同 + definition 幾乎一樣 | > 90% | merge |
| Tag 重疊 50%+ + definition 互補 | 60-80% | revise |
| Tag 不重疊但 definition 主旨相同 | 70% | merge |
| Tag 不重疊 + definition 是上位 / 下位關係 | 80% | derive |
| Tag 不重疊 + definition 無關 | < 30% | 建立新概念 |

---

## 4. 對索引與 README 的影響

| 動作 | `_concepts.json` | `docs/README.md` | 檔案 |
|------|-----------------|-----------------|------|
| **derive** | 兩者都加入 | 兩個都列（用 `↳` 表示子概念） | 都保留 |
| **revise** | 原概念更新（slug 不變） | 同一行，顯示最後更新日期 | 保留 |
| **merge** | 主要概念更新；被合併的**移除** | 只列主要概念；被合併的隱藏 | 保留（軟刪除） |
| **deprecate** | 被棄用的**移除** | 隱藏（除非用戶開啟「顯示已棄用」） | 保留 |

---

## 5. 用戶介入時機

AI 在以下情況應該停下來問用戶（不自動決定）：

| 情境 | 為何要問 |
| --- | --- |
| merge 兩個概念 | 用戶可能知道哪個語意更重要 |
| deprecate 一個概念 | 影響範圍大 |
| revise 修改既有 definition | 用戶可能有特定措辭偏好 |

derive 同「建立全新概念」可由 AI 直接決定，事後告訴用戶結果。

---

## 6. 完整演進生命週期範例

```
2026-01-15  created
  [[react-state-batching]] — 定義："在同一個事件處理中多次 setState 會被合併"

2026-02-10  revised
  [[react-state-batching]] — 定義改為："React 18+ 在 Promise、setTimeout 等非同步中也會自動批次"
  history += {revised, "加入 React 18 自動批次"}

2026-03-05  derived
  [[react-state-batching-in-react-18]] — parent: [[react-state-batching]]

2026-05-12  deprecated
  [[react-concurrent-rendering]] 涵蓋了批次行為的上位概念
  [[react-state-batching]] superseded_by: "[[react-concurrent-rendering]]"
```

---

## 7. 參考

- [SKILL.md](SKILL.md) — 主流程
- [frontmatter-schema.md](frontmatter-schema.md) — history 條目規範
- [examples.md](examples.md) — 演進操作的對話範例
