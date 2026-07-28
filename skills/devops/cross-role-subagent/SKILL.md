---
name: cross-role-subagent
description: QA Feedback Loop — 持續循環直至 QA 通過，用戶只看到最終好結果。
tags: ["qa", "subagent", "coordination", "collaboration", "feedback-loop"]
related_skills: ["route53-nginx-https"]
---


Last-verified: 2026-07-28
# Cross-Role Subagent 協調協議 + Feedback Loop

## 🔄 Feedback Loop 流程

**持續 loop，直至 QA 完全通過為止。用戶只會收到最終的好結果。**

```
QA 檢測 ──→ 發現問題 ──→ Spawn Subagent
    ↑                            │
    │                       協調修正
    │                            ↓
    └────── QA 重檢 ◄─── 責任角色完成修復
                   │
           ┌───────┴───────┐
           │   QA 通過？    │
           └───────┬───────┘
           ❌不通過 │  ✅通過
                  │    ↓
                  │ ✅ 交付用戶
                  │  （過程保密）
                  └────── ◄────┘
```

### 用戶視角

```
QA 完成 → ✅ 功能正常 → 交付用戶
```

**用戶永遠不知道：**
- 中間經過幾次 feedback loop
- 期間有哪些角色被諮詢過
- 有過什麼爭論或反覆

> 如果用戶主動問起過程，只說：「已經修好了，現在可以正常使用了。」

### Feedback Loop 次數

- **沒有上限** — 只要 QA 未通過，就繼續 loop
- 直到 QA 完全通過，才算完成
- 每次 loop 都要記錄在 `memory/YYYY-MM-DD.md`

### 記録格式

每次 Feedback Loop 迭代，在 memory 中記錄：

```
## Feedback Loop — [功能名稱] — [時間戳]

### Iteration N
- **問題：** [描述]
- **責任角色：** [誰負責]
- **Subagent 回傳：** [結果]
- **QA 重檢：** ✅ 通過 / ❌ 未通過
  - 如果未通過：[下一個問題描述]
```

---

## 核心原則

**千萬不要**嘗試用 `send_message` 讓 Developer 自己發消息去別的 channel。

> 用戶明確否決這個做法：「不，developer profile 中應該有subagent 做這些工作的」

**正確做法：** 永遠用 `delegate_task` spawn subagent，而不是自己跳去發消息。

## 核心原則

**當 QA 發現問題，spawn subagent 去處理，不要自己跳去別的 channel 發消息，也不要透過用戶傳話。**

```
用戶報告問題或 QA 發現問題
        ↓
Developer 分析問題，確定 subagent 類型
        ↓
Spawn subagent，附上完整上下文
        ↓
Subagent 直接與對應角色溝通（讀取該 channel 的回覆、發消息）
        ↓
Subagent 完成協調，回傳結果
        ↓
Developer 整合結果，驗證修復
        ↓
✅ 交付用戶（只告知結果）
```

---

## 問題分類 → Subagent 對照

| 問題類型 | Subagent goal | 需要的 context |
|----------|--------------|----------------|
| 後端邏輯錯誤、API、資料庫 | `backend-fix` | 問題描述 + 預期 vs 實際行為 + 截圖/日誌 |
| UI 顯示問題、UX 不符合預期 | `frontend-fix` | UI 截圖 + 預期行為 + 設計規範 link（如有） |
| 功能需求不清、規格爭議 | `pm-resolve` | 用戶原始需求 + 爭議點 + 選項建議 |
| 流程/進度協調、跨團隊 blocker | `pm-coordinate` | blocker 描述 + 影響範圍 + 已嘗試的解決方案 |
| 業務邏輯、數據指標疑問 | `ba-clarify` | 上下文 + 具體疑問點 + 已知的業務規則 |
| 研究/技術調研問題 | `research` | 研究目標 + 預期產出 + 截止時間 |

---

## Discord 角色對應 Channel

| 角色 | Channel |
|------|---------|
| Backend（後端） | `#developer`（直接在此 channel 協調） |
| Frontend / UI Design | `#product` |
| Product Manager | `#product-manager` |
| Project Manager | `#project-manager` |
| Business Analyst | `#business-analyst` |
| Researcher | `#researcher` |

---

## 標準 Spawn 格式

```python
delegate_task(
    goal="[具體任務描述，清楚說明需要對方做什麼]",
    context="""[完整上下文]
    - 原始需求：[用戶怎麼說的]
    - 問題描述：[觀察到的問題]
    - 預期行為：[應該是什麼]
    - 實際行為：[觀察到什麼]
    - 已有資源：[截圖、日誌、連結等]
    """,
    tasks=[{
        "goal": "[對應上方的 subagent goal]",
        "context": "[同上，但更針對該角色的職責]"
    }]
)
```

---

## 標準溝通格式（Subagent 發給對應角色的消息）

```
🚨 QA Issue — [功能名稱]

**問題描述：** [清楚描述觀察到的問題]
**預期行為：** [應該是什麼]
**實際行為：** [觀察到什麼]
**截圖/日誌：** [附件或描述]
**影響範圍：** [哪些用戶會受影響]

請 [角色] 確認並處理，謝謝。
```

---

## Subagent 任務終結標準

每個 subagent 都應該：
- **知道何時算完成**：獲取到足夠資訊、或問題被確認解決
- **主動終結**：不需要無限期等待，有結論就回報
- **記錄結論**：把最終結論寫入 `memory/YYYY-MM-DD.md`

---

## ⚠️ 嚴禁事項

- **嚴禁** 自己跳去別的 channel 發消息——用 subagent
- **嚴禁** 把其他角色的問題帶回給用戶：「這個要問設計師...」
- **嚴禁** 在沒有完整上下文的情況下 spawn subagent
- **嚴禁** spawn 後不追蹤結果——必須等 subagent 回報並驗證

---

## 例外情況（需要用戶決策）

以下情況才需要把選項帶給用戶：
- 涉及商業決策
- 需求本身有歧義，無法從上下文判斷
- 兩個角色對責任歸屬有爭議
- 涉及外部資源需要用戶授權

---

## 實戰範例

**情境：** QA 測試時發現登入按鈕在某些解析度下位置偏移。

**正確做法：**

```python
# Developer 不要自己跑去問，直接 spawn subagent
delegate_task(
    goal="Frontend issue found during QA: login button misaligned at certain viewport sizes",
    context="""QA 在測試電子商務專案時發現：
    - 功能：登入按鈕
    - 問題：在 viewport < 768px 時，按鈕位置偏移到畫面外
    - 預期：按鈕應該垂直置中於登入表單右方
    - 實際：行動裝置上按鈕跑到畫面外邊
    - 截圖：/tmp/qa-screenshots/login-mobile.png
    - 設計稿：Figma link（如有）
    """,
    tasks=[{
        "goal": "frontend-fix",
        "context": "請確認這個 UI 問題並修復，之後在 #developer 回報結果。"
    }]
)
```

**Subagent 到 `#product` 或相關 channel 發消息協調，完成後回報結果。**
