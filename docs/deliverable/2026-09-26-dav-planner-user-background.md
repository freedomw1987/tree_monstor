# 交付摘要 — dav-planner 用戶背景收集機制

**日期**：2026-09-26
**Backlog ID**：TMO-007
**SOP 版本**：v1.9
**Reviewer Verdict**：✅ PASS（首次 OK with P1，2 P1 修正後 PASS）

---

## 對話摘要（90 秒可讀完）

### 做了什麼

dav-planner skill 從 v1.9 起，**每次對話開始**會先問你 1 題「你在這個項目的角色是？」：

- **PM/PO** → 下一題問目標用戶/規模
- **開發者** → 下一題問熟悉的技術棧/團隊規模
- **設計師** → 下一題問品牌規範/視覺風格
- **業務/客戶** → 下一題問目標市場/付款物流
- **其他** → 自由描述

### 為什麼做

原本 dav-planner 對 PM 和開發者問同一句「你想要什麼效果？」— **深度無差別**。有了角色背景，Agent 可動態調整後續 §3 維度的深度與語言（PM 不問技術棧、開發者不問品牌規範）。

### 對用戶的價值

| 角色 | 體驗 |
|------|------|
| **首次用戶** | 友善破冰問題，不直接進抽象需求探討 |
| **PM** | 跳過「技術棧」這類對 PM 沒意義的維度 |
| **開發者** | 跳過「品牌規範」這類對工程師沒意義的維度 |
| **重複對話** | §2.7.1 提供跳過規則（同 US 第 3+ 輪可直接問需求）|

### 變更檔案（5 個）

| 檔案 | 動作 | 內容 |
|------|------|------|
| `skills/dav-planner/SKILL.md` | 修改 | + §2.7（3 個子章節）+ line 69 P1-1 修正 |
| `docs/sop/handbook/changelog.md` | 修改 | + v1.9 條目 |
| `docs/backlog.md` | 修改 | + TMO-007 + 詳細段（P1-2）|
| `docs/prd/02-dav-planner-user-background.md` | 新建 | 本次變更 PRD |
| `tests/dav-planner-user-background.bats` | 新建 | 7 個探針守護 |

### Gate 驗證

| Gate | 結果 |
|------|------|
| Gate 1 (TDD) | ✅ 7/7 PASS（先紅後綠）|
| Gate 2 (lint) | ✅ Markdown + 連結完整性 OK |
| Gate 3 (regression) | ✅ 213/226 pass（13 預存在 env fail 與本次無關）|
| Gate 4 (reviewer) | ✅ PASS（V03 紀律成功捕獲 P1-1 跨檔 §2.7 語意衝突）|

### 下一步

| 選項 | 動作 |
|------|------|
| A | 用戶驗收本次交付，commit + push |
| B | 觀察下次 dav-planner 啟動時 §2.7 實際表現，再 commit |
| C | 順手修本次發現的 P2 nice-to-have（bats 探針粒度 + 標題風格）|

---

## 變更檔案清單（含 diff 摘要）

### 新建檔案（2 個）

1. `docs/prd/02-dav-planner-user-background.md` — 124 行 PRD
2. `tests/dav-planner-user-background.bats` — 7 個探針

### 修改檔案（3 個）

| 檔案 | 新增行數 | 內容 |
|------|---------|------|
| `skills/dav-planner/SKILL.md` | +60 行 | §2.7（用戶背景收集）+ §2.7.1（跳過規則）+ §2.7.2（Persona 對照表）+ line 69 P1-1 修正 |
| `docs/sop/handbook/changelog.md` | +12 行 | v1.9 條目 |
| `docs/backlog.md` | +60 行 | TMO-007 row + 詳細段 |

**總計**：+132 行 / -0 行（不含新建檔）

---

## 對應 AC（TMO-007 完成標準）

| 標準 | 狀態 |
|------|------|
| SKILL.md §2.7 + §2.7.1 + §2.7.2 | ✅ |
| 5 個角色（PM/Dev/Designer/業務/其他）| ✅ |
| changelog v1.9 | ✅ |
| TMO-007 詳細段 | ✅ |
| PRD-02 | ✅ |
| bats 7 探針 | ✅ |
| Reviewer verdict: PASS | ✅ |
| TMO-007 → done | 🟡 待用戶驗收 |

---

## 已知問題與限制

| 項目 | 處理 |
|------|------|
| bats 探針 2 用 substring grep 易誤判 | 記錄（P2-1，下次 Sprint 加「bats probe 寫作指南」處理）|
| §2.7 標題尾點風格不一致 | 記錄（P2-2，純風格）|
| V02 範例未示範 | 記錄（P2-3，下次加新規則段時示範）|
| 跳過條件「明顯」稍主觀 | 記錄（P2-4）|
| 未明示「中途換角色」情境 | 記錄（P2-5）|

---

## 對未來的建議（Think Big）

1. **下次 dav-planner 啟動**：用戶會看到新的 §2.7 背景題 — 確認體驗
2. **bats probe 寫作指南**（下次 Sprint）：明文規範 substring grep 必須加範圍限縮（避免這次 P2-1）
3. **backlog hygiene 自動化**（下次 Sprint）：加探針驗證「每個 TMO-XXX row 都有對應詳細段」
4. **§ 引用前綴規範**（下次 Sprint）：明文規範跨檔引用要加來源前綴（避免 P1-1 跨檔語意衝突）
5. **Audit 探針**（下次 Sprint）：統計 §2.7.1 跳過率，避免 Agent 為效率過度跳過

---

## 變更歷史

| 日期 | 版本 | 變更 | 作者 |
|------|------|------|------|
| 2026-09-26 | v1.0 | 初版建立（dav-planner v1.9 交付摘要）| Agent |
