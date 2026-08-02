# PROJECT-OVERVIEW.md — Template

> **When to use:** Bootstrap 或 greenfield project 的第一份 doc。
> **No-code rule:** 不適用（本檔純 prose 規格）。

## 必填區塊

```markdown
# <Project Name> — Project Overview

## 一句話
[這個 project 做什麼,用一句非技術語言解釋]

## 目標用戶
- 主要: [誰會用]
- 次要: [誰會間接受影響]

## 核心價值主張
- 用戶用呢個 project 解決咩問題?
- 跟現有方案比,我們的差異點是?

## 成功標準
- KPI 1: [具體可量度,例:DAU > 1000]
- KPI 2: ...

## 範圍 (Scope)
- ✅ In scope: [做咩]
- ❌ Out of scope: [不做咩,防止 scope creep]

## 主要 Risk
- Risk 1: [風險] → Mitigation: [應對]
- Risk 2: ...

## 變更歷史
| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-06-06 | 初版 | 從 kanban task t_c658eba4 開始 |
```

## 更新時機
- 每次 scope 變更
- 每季度 review 一次
- 不能在 commit 之前(必須跟首個 code commit 同步入 git)