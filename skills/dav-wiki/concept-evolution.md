# Concept Evolution — dav-wiki

> 本檔定義 dav-wiki 中**概念演進**的 4 種動作：derive / revise / merge / deprecate。
> 配合 [frontmatter-schema](frontmatter-schema.md) 使用。

---

## 1. 為什麼需要概念演進？

概念（concept）不是 tag —— 它是**語意命題**，會隨新文件、新發現而**演化**：

- 新文件可能發現**子概念**（derive）
- 新文件可能**修正**既有概念的理解（revise）
- 兩個概念被發現**其實是同一件事**（merge）
- 概念被**新概念取代**（deprecate）

沒有演進機制，概念庫會變成「一堆過時命題的墳場」。

---

## 2. 4 種演進動作

### 2.1 derive（衍生）

**觸發**：新文件發現既有概念的子領域。

**操作**：
1. 建立新概念檔 `docs/concepts/{new-slug}.md`
2. 在 `parents` 加上 `[[original-concept]]`
3. 在原概念的 `children` 加上 `[[new-concept]]`
4. 雙方的 `history` 都記一筆

**範例**：

```
# 原本
[[effect-shallow-compare]]: Effect 依賴淺比較陷阱

# 新文件發現「深比較也有陷阱」
→ derive 出 [[effect-shallow-compare-vs-deep]]
```

**結果**：原概念 + 子概念**共存**，透過 parents / children 連結。

---

### 2.2 revise（修正）

**觸發**：新文件修正既有概念的理解（定義不準確、缺漏案例）。

**操作**：
1. 修改原概念檔的 `definition`
2. 在 `history` 加一筆 `{date, action: "revised", note: "..."}`
3. **不改 slug**（保留 ID 穩定性）
4. **不改 parents / children**（不是衍生關係）

**範例**：

```
# v1（2026-01-15）
[[effect-shallow-compare]]:
  definition: "Effect 依賴淺比較"

# v2（2026-02-03）新文件指出 useMemo 也類似
→ revise definition: "Effect / useMemo 依賴淺比較"
→ history += {date: 2026-02-03, action: revised, note: "加入 useMemo"}
```

**結果**：同一個概念 ID，內容更新，歷史可追溯。

---

### 2.3 merge（合併）

**觸發**：兩個概念被發現是**同一件事**（重疊度 > 80%）。

**操作**：
1. 選一個**主要概念**（較完整、較早建立的）保留
2. 另一個概念：
   - frontmatter 加 `deprecated: true`
   - 加 `superseded_by: "{primary-slug}"`
3. 主要概念的 `definition` 合併兩者精華
4. 兩者的 `related_docs` 合併到主要概念
5. 從 `_concepts.json` 移除被合併的那個
6. 兩者的 `history` 都記一筆

**範例**：

```
# 兩個相似概念
[[react-state-batching]]: React 狀態批次更新
[[react-automatic-batching]]: React 自動批次（18+ 新特性）

# 發現其實是同一件事的不同階段
→ merge：保留 [[react-state-batching]] 為主
→ [[react-automatic-batching]] 標 deprecated + superseded_by: "[[react-state-batching]]"
```

**結果**：一個概念；被合併的檔案保留（可追溯）但從索引消失。

---

### 2.4 deprecate（棄用）

**觸發**：概念被**新概念取代**（不是合併，是技術演進）。

**操作**：
1. 在被取代的概念：
   - 加 `deprecated: true`
   - 加 `superseded_by: "{new-concept-slug}"`
   - `status: deprecated`
2. 從 `_concepts.json` 移除
3. 在 `history` 加最後一筆 `action: deprecated`

**範例**：

```
# 舊概念
[[react-class-component-lifecycle]]: React class 元件生命週期

# 改用 Hooks 後棄用
→ 新概念 [[react-hooks-lifecycle]]: Hooks 生命週期（用 useEffect 模擬）
→ [[react-class-component-lifecycle]] 標 deprecated + superseded_by: "[[react-hooks-lifecycle]]"
```

**結果**：新舊概念檔案都保留；從 `_concepts.json` 與 `docs/README.md` 移除舊的。

---

## 3. AI 決策流程

新文件進來、提取 concept 時，AI 用以下決策樹：

```
新概念 candidate 進來
    │
    ├─ 跟既有概念無任何 tag / 定義重疊
    │   → 建立新概念（無演進）
    │
    ├─ 跟既有概念 A 部分重疊（重疊度 50-80%）
    │   ├─ 是 A 的子領域？
    │   │   → derive（A 為 parent）
    │   ├─ 是 A 的延伸案例？
    │   │   → revise（更新 A 的 definition）
    │   └─ 是平行的不同主題？
    │       → 建立新概念 + related_docs 加 [[A]]
    │
    ├─ 跟既有概念 A 高度重疊（重疊度 > 80%）
    │   → merge（保留較完整的，A 為主）
    │
    └─ 跟既有概念 A 完全重疊 或 A 被新發現否定
        → deprecate（A），建立或指向新概念
```

---

## 4. 判斷「重疊度」的啟發式

| 訊號 | 重疊度評估 |
| --- | --- |
| Tag 完全相同 + definition 幾乎一樣 | > 90% → merge |
| Tag 重疊 50%+ + definition 互補 | 60-80% → revise |
| Tag 不重疊但 definition 主旨相同 | 70% → merge |
| Tag 不重疊 + definition 是上位 / 下位關係 | 80% → derive |
| Tag 不重疊 + definition 無關 | < 30% → 建立新概念 |

---

## 5. 對 `_concepts.json` 的影響

| 動作 | 對 `_concepts.json` 的影響 |
| --- | --- |
| **derive** | 兩者都加入 |
| **revise** | 原概念更新內容（slug 不變） |
| **merge** | 主要概念更新；被合併的**移除** |
| **deprecate** | 被棄用的**移除** |

**但檔案都保留**在 `docs/concepts/` 目錄（軟刪除）。

---

## 6. 對 `docs/README.md` 的影響

| 動作 | README 變化 |
| --- | --- |
| **derive** | 兩個概念都列（用 `↳` 表示子概念） |
| **revise** | 同一行，但顯示最後更新日期 |
| **merge** | 只列主要概念；被合併的隱藏 |
| **deprecate** | 隱藏（除非用戶開啟「顯示已棄用」選項） |

---

## 7. 用戶介入時機

AI 在以下情況應該停下來問用戶（不自動決定）：

| 情境 | 為何要問 |
| --- | --- |
| merge 兩個概念 | 用戶可能知道哪個語意更重要 |
| deprecate 一個概念 | 影響範圍大 |
| revise 修改既有 definition | 用戶可能有特定措辭偏好 |

derive 和「建立全新概念」可由 AI 直接決定，事後告訴用戶結果。

---

## 8. 範例：完整演進生命週期

```
時間軸：

2026-01-15  created
  [[react-state-batching]] — React 狀態批次更新
  定義："在同一個事件處理中多次 setState 會被合併"

2026-02-10  revised
  [[react-state-batching]] — 加入 React 18 自動批次新行為
  定義："React 18+ 在 Promise、setTimeout 等非同步中也會自動批次"
  history += {revised, "加入 React 18 自動批次"}

2026-03-05  derived
  [[react-state-batching-in-react-18]] — 專門討論 React 18 自動批次
  parent: [[react-state-batching]]

2026-05-12  deprecated
  發現新概念 [[react-concurrent-rendering]] 涵蓋了批次行為的上位概念
  [[react-state-batching]] 標 deprecated
  superseded_by: "[[react-concurrent-rendering]]"
```

這個範例展示一個概念從「建立 → 修正 → 衍生 → 棄用」完整生命週期。

---

## 9. 參考

- [SKILL.md](SKILL.md) — 主流程
- [frontmatter-schema.md](frontmatter-schema.md) — history 條目規範
- [examples.md](examples.md) — 演進操作的對話範例
