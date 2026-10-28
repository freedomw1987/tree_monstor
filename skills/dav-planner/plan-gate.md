# Dav Planner — Plan Gate（規劃階段）

> 本檔係規劃階段嘅規則本體（2026-10-28 起由 `docs/sop/handbook/` 搬入本 skill）。
> ⚠️ **只適用於非 trust 嘅開發編程任務路徑** —— trust 進行中唔跑規劃階段：規劃係 trust 嘅啟動前置條件（要用戶互動），
> 必須喺 trust 啟動前完成；trust 內只跑執行 → 反省 → 提交（見同套 `dav-trust` skill）。

## 溝通 & 思考

- 要與用戶溝通討論出一個完整完善的方案；
- **務必使用本 skill（`/skill:dav-planner`）**；

## fail-fast Plan Gate — 規劃 gate（必須通過才能進入設計階段）

- **觸發**：本 skill 走完 Step 1-4（＋ Step 1.5，如適用）
- **通過條件**：
  1. 透過本 skill 與用戶溝通需求（一次一個問題，遵守萬事原則耐心條款）
  2. 產出 `docs/backlog.md`，包含 US（User Story）／DE（Defects）／TECH（Technical Debt）／Spike（需研究）四個分類
  3. **專案有 ≥3 條專屬術語 → 已產出 `docs/glossary_list.md`（A-Z 術語表）**；之後**已接線嘅階段**
     （設計／派工與 Reviewer／交付）一律用入面嘅術語，唔好各自發明叫法
  4. **用戶明確確認**「OK 可以進入設計階段」才可進入下一階段
- **不通過 = 不可進入設計階段**
- **「假裝通過」視為失敗**（見同套 `dav-router` skill 嘅違規回報規則）：
  - ❌ 沒產出 `docs/backlog.md` 就聲稱「規劃完成」
  - ❌ 用戶沒明確確認就跳到設計階段

## Plan Gate 通過聲明格式（Agent 完成時必貼）

```
✅ Plan Gate 通過

- [x] dav-planner 與用戶完成需求訪談（一次一個問題 — V01）
- [x] 術語表已產出（[依同套 `backlog-rules.md` §4.9，如無則填 N/A] — 有 ≥3 條專屬術語就要有 `docs/glossary_list.md`）
- [x] docs/backlog.md 已產出/更新（含 US / DE / TECH / Spike）
- [x] 關鍵決策點 SWOT 已展開（[依同套 `reference.md` §2.6，如無則填 N/A] — 只有不可逆變更/高成本/糾結/戰略影響 才展開）
- [x] 最終選項 SWOT 已寫進對應 backlog AC 欄（[依同套 `backlog-rules.md` §4.3.1，如無則填 N/A] — 只記最終選項、純文字前綴、不用 `>` blockquote）
- [x] 用戶明確確認：「<用戶原話>」
→ 進入設計階段
```
