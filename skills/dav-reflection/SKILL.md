---
name: dav-reflection
description: 在自我反省階段使用，分層級（User Story / Sprint / Module）對執行階段的交付物作宏觀反思和檢討，包含 6 項檢查維度，產出反省報告和更新 docs/backlog.md。
---

# Dav Reflection Skill

## 使用場景

在 SOP 的「自我反省」階段使用，無論是 User Story、Sprint 或 Module 結束後，都可觸發本 skill 進行宏觀反思。適用於：

- 找出 UX/UI、RWD、技術債、可維護性、測試覆蓋率、需求對齊的問題
- 將發現的問題轉化為可執行的 Backlog item
- 為日後追溯決策保留歷史記錄

## 觸發時機（三層級）

| 級別 | 觸發條件 | 執行者 | 反省範圍 |
|------|---------|--------|---------|
| **User Story** | 每個 US 完成驗收後 | Agent 自動 | 該 US 的 AC、UX/UI、測試覆蓋率 |
| **Sprint** | 每個 Sprint 結束後 | Agent + 用戶 | 整個 Sprint 內所有 US 的 UX/UI 一致性、RWD、技術債、可維護性 |
| **Module** | 每個 Module 交付後 | Agent + 用戶 | 模組間協作、整體架構、需求對齊 |

## 工作流程

```
┌──────────────────────────────────────────────────────┐
│                   1. 確認反省範圍                       │
│   - User Story / Sprint / Module                     │
│   - 收集交付物（代碼、文檔、設計稿）                      │
├──────────────────────────────────────────────────────┤
│                   2. 檢查 6 個維度                      │
│   參考 [[checklist]] 的詳細檢查清單                     │
│   每個維度標記：✅ 通過 / ⚠️ 有風險 / ❌ 不通過           │
├──────────────────────────────────────────────────────┤
│                   3. 產出反省報告                       │
│   輸出到 docs/reflection/<name>-reflection.md          │
│   報告模板請參考 [[template]]                          │
├──────────────────────────────────────────────────────┤
│                   4. 轉化為 Backlog item               │
│   - 技術債問題 → Technical Debt 類型                   │
│   - Bug → Defects 類型                                │
│   - 缺失功能 → User Story 類型                        │
│   - 需研究 → Spike 類型                               │
│   更新到 docs/backlog.md                              │
├──────────────────────────────────────────────────────┤
│                   5. 跟用戶確認 Action Items            │
│   - 哪些 item 要立即處理（P0/P1）                      │
│   - 哪些可以放入下個 Sprint                            │
└──────────────────────────────────────────────────────┘
```

## 6 項檢查維度

反省的核心是回答「交付物是否真的好」，6 個必檢維度：

1. **UX/UI 一致性** — 是否符合用戶需求原意、符合 docs/DESIGN.md
2. **RWD 響應式設計** — 桌面、平板、手機尺寸是否都正確呈現
3. **技術債** — 硬編碼、缺少抽象、文件缺失、過時依賴、重複代碼
4. **可維護性** — 代碼結構、命名、模組化、職責分離
5. **測試覆蓋率** — 每個 AC 是否都有對應測試、回歸測試是否齊全
6. **需求對齊** — 實際交付是否真的解決用戶的痛點和目的

每個維度的詳細檢查問題請參考 [[checklist]]。

## 反省報告產出位置

| 級別 | 反省報告路徑 |
|------|-------------|
| User Story | `docs/reflection/us-<us-id>-reflection.md` |
| Sprint | `docs/reflection/sprint-<number>-reflection.md` |
| Module | `docs/reflection/module-<module-name>-reflection.md` |

## Backlog 更新規則

每個發現的問題都要在 `docs/backlog.md` 新增對應類型的 item：

| 問題類型 | Backlog 類型 | 優先級判斷 |
|---------|-------------|-----------|
| 技術債、硬編碼、過時依賴 | Technical Debt | 阻礙開發 = P0，影響效能 = P1，其餘 = P2 |
| Bug、缺陷、錯誤 | Defects | 影響核心功能 = P0，次要功能 = P1 |
| 缺失功能、未實現需求 | User Story | 影響核心流程 = P0 |
| 需研究、不確定方案 | Spike | 阻礙後續開發 = P0 |

## 與其他 Skill 協作

```
dav-planner     →  確認原始 User Story 和痛點（用於「需求對齊」維度）
dav-designer    →  取得 docs/DESIGN.md 和 docs/system-design.md（用於 UX/UI 和架構檢查）
dev-checker-loop →  取得當前 Sprint 進度（用於判斷哪些 US 屬於本 Sprint）
```

## 關鍵原則

- **看整體**：不要只看單一檔案，要從模組、Sprint 級別看全局
- **誠實面對問題**：找到問題不要迴避，要明確標記 ❌ 不通過
- **轉化為行動**：反省的目的不是抱怨，而是產出可執行的 Action Items
- **用戶參與**：Sprint 和 Module 級別的反省必須有用戶參與確認
- **歷史可追溯**：反省報告要保留，方便日後追溯為何做某個決定
- **避免過度反省**：User Story 級別的反省要輕量，不要影響開發節奏

---

**詳細內容**：
- 6 項檢查維度的詳細問題 → [[checklist]]
- 反省報告模板 → [[template]]