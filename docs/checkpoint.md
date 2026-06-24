# Checkpoint 機制

> **Status:** Canonical. Source of truth for checkpoint and long-task recovery behavior.

## 目的
長期任務中斷後能從斷點恢復，不需要從頭開始。

---

## Checkpoint 格式

```markdown
## Checkpoint — [任務名稱] — [時間戳]

### 已完成
- 完成了什麼

### 進行中
- 目前做到哪個步驟

### 下一步
- 接下來要做的 3-5 件事

### 關鍵狀態
- 任何需要記住的變量、配置、狀態

### 教訓
- 過程中發現的重要事項（如果有）
```

---

## 保存頻率

- 每完成一個 milestone（每 10-20 個 tool calls 左右）
- 開始新的大模塊前
- 任何有價值的發現或決定

---

## 保存位置

`memory/YYYY-MM-DD.md` 或在 `/home/ubuntu/developer/checkpoints/` 建立以任務為名的目錄

---

## 中斷後恢復流程

1. 用戶說「繼續之前的任務」或「keep working」
2. 先讀取最新的 checkpoint 文件
3. 根據「下一步」列表恢復工作
4. 確認之前的狀態（環境、變量、檔案狀態）再繼續

---

## 重要原則

> **沒有 checkpoint 就等於沒有記憶。長期任務必須主動記錄。**

---

## Feedback Loop 追蹤記錄

每次迭代必須記錄：

```markdown
## Feedback Loop — [功能名稱] — [迭代次數]

### 迭代 N
- **Phase 0 BA 商業分析**: ✅ 完成 / ❌ 發現問題
- **Phase 0.5 UI/UX 設計**: ✅ 完成 / ❌ 發現問題
- **Phase 3 SA Code Review**: ✅ 通過 / ❌ 發現 [N] 個問題
- **Phase 4 QA 測試**: ✅ 通過 / ❌ 發現 [N] 個問題
- **Phase 4 User Simulation**: ✅ 通過 / ❌ 發現 [N] 個問題
- **修正後狀態**: ✅ 已修正並重新審查 / ❌ 仍在修正中
```

---

## 🧭 Goal 回顧紀律（每個 Phase 必做）

長期任務中，每進入一個新 phase 或每 20 個 tool calls，主動問自己：

```
╔══════════════════════════════════════════╗
║  🧭 GOAL SANITY CHECK                   ║
╠══════════════════════════════════════════╣
║  原始目標: [寫在這裡]                    ║
║  我正在做: [寫在這裡]                     ║
║  這件事真的服務原始目標嗎？               ║
║                                          ║
║  ✅ 是 → 繼續                            ║
║  ❌ 否 → 停止，重新對齊 goal              ║
╚══════════════════════════════════════════╝
```

**沒有這個紀律，開發會像迷路的螞蟻 — 很忙，但不知道去哪裡。**

---

## Related docs

- [Documentation index](00-index.md)
- [Session and workspace rules](../AGENTS.md)
- [Failure policy](failure-policy.md)
- [Feedback loop](feedback-loop.md)
