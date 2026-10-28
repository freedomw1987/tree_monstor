# dav-wiki 樣例檔 — 概念演進範例

> 配合 [`../concept-evolution.md`](../concept-evolution.md) 使用：呢度只放**示範用嘅演進例子**，
> 動作定義（derive / revise / merge / deprecate）同決策準則 → 同套本 skill 子檔（`../concept-evolution.md` §2-§3）。

---

## 1. 四種演進動作的典型例子

```derive
:    [[effect-shallow-compare]] → [[effect-shallow-compare-vs-deep]]（深比較也有陷阱）

revise:    definition "Effect 依賴淺比較" → "Effect / useMemo 依賴淺比較"
merge:     [[react-state-batching]]（主） ← [[react-automatic-batching]]（deprecated + superseded_by）
deprecate: [[react-class-component-lifecycle]] → superseded_by [[react-hooks-lifecycle]]
```

## 2. 完整演進生命週期範例

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
