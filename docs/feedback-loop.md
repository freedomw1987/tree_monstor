# Feedback Loop

> **Status:** Canonical. Source of truth for review/test failure loops and iteration rules.

## 核心概念

> **Feedback Loop 是持續的循環過程，直至最終結果完美符合用戶需求為止。用戶只會收到最終的好結果。**

---

## Loop 流程

```
┌─────────────────────────────────────────────────┐
│                   FEEDBACK LOOP                  │
│                                                  │
│  發現問題 ──→ 派發修正 Subagent                 │
│      ↑                │                         │
│      │         重新審查/測試                     │
│      └────────────────┘                         │
│                                                  │
│  全部通過 ──→ QA Gate ──→ 交付用戶              │
└─────────────────────────────────────────────────┘
```

---

## Loop 規則

### 循環繼續條件
- BA 分析發現需求不明確 → 向用戶確認 → 重新 BA
- UI/UX 設計發現需求問題 → 回到 BA 重新確認
- SA Code Review 發現 CRITICAL/IMPORTANT 問題 → 修正 → 回到 SA Review
- QA 測試發現任何問題 → 修正 → 回到 SA Review
- User Simulation 發現任何問題 → 修正 → 回到 SA Review

### 循環終止條件
- BA 分析: 完成（需求明確）
- UI/UX 設計: 完成（設計 token 確定）
- SA Code Review: APPROVED
- UI/UX Design Review: APPROVED
- QA 測試: 100% 通過
- User Simulation: 100% 通過

---

## 獎勵

| 情況 | 獎勵 |
|------|------|
| 交付後連續 7 天無用戶 bug 報告 | ✅ 記 1 功 |
| 主動發現並修復潛在隱患（非用戶報告） | ✅ 記 1 功 |
| 顯著提升系統穩定性或效能 | ✅ 特別表揚 |

---

## 罰則

| 等級 | 情況 | 罰則 |
|------|------|------|
| **P0 — 嚴重** | 核心功能完全不能用、用戶數據丟失或泄露 | ❌ 記 3 過 |
| **P1 — 高** | 主要流程不通（登入、支付等）、功能直接報錯 | ❌ 記 2 過 |
| **P2 — 中** | 非核心功能 bug、邊界情況處理不當 | ❌ 記 1 過 |
| **P3 — 低** | UI 文案錯誤、非關鍵顯示問題 | ⚠️ 口頭警告 |

---

## 記錄方式

每次迭代記錄在 `memory/YYYY-MM-DD.md`（active project 的記憶文件）。

---

## Related docs

- [Documentation index](00-index.md)
- [Phase workflow](phases.md)
- [Failure policy](failure-policy.md)
- [QA Gate](qa-gate.md)
