# 交付摘要 — dav-planner AC 範本獨立化 + HTML 版本

**日期**：2026-09-26
**Backlog ID**：TMO-006
**SOP 版本**：v1.8
**Reviewer Verdict**：✅ PASS（首次 FAIL 抓到 2 P0 + 4 P1 + 4 P2，修正後 PASS）

---

## 對話摘要（90 秒可讀完）

### 做了什麼

dav-planner skill 從 v1.8 起，每個 User Story 都有獨立的 AC 範本了：

- `docs/ac/<US-ID>.md` — Markdown 版（給開發者，版本控管）
- `docs/ac/<US-ID>.html` — HTML 版（給利害關係人，列印友好）

`docs/backlog.md` 的 AC 欄位從「塞整段 Given-When-Then」精簡為「**AC 摘要 + 連結**」，backlog.md 仍是 single source of truth（看進度用）。

### 為什麼做

用戶痛點：原本 AC 整段塞在 markdown 表格 cell 內（用 `<br>` 分行），**閱讀體驗差、不利校對 / 分享 / 列印**。利害關係人要單獨看 AC 必須打開整份 backlog。

### 對用戶的價值

| 角色 | 改變 |
|------|------|
| **PO / QA** | 可單獨打開 `docs/ac/US-XXX.html`，列印 / Email / 分享給客戶 |
| **開發者** | `docs/ac/US-XXX.md` 可版本控管，git diff 追蹤 AC 變更 |
| **Agent** | 走 SOP §4.6：同 turn 生成 .md + .html + 更新 backlog，3 動作齊全 |

### 變更檔案（9 個）

| 檔案 | 動作 | 內容 |
|------|------|------|
| `docs/backlog.md` | 修改 | + TMO-006（Story Point 8）|
| `docs/sop/handbook/changelog.md` | 修改 | + v1.8 條目（P0/P1/P2 分類）|
| `skills/dav-planner/SKILL.md` | 修改 | + §4.3.2（AC 欄位精簡）+ §4.6（HTML 生成 SOP）|
| `docs/ac/README.md` | 新建 | 目錄說明 + 命名規範 |
| `docs/ac/US-101.md` | 新建 | 範例 AC 範本（信用卡快速結帳）|
| `docs/ac/US-101.html` | 新建 | 範例 AC HTML 版（列印友好 CSS）|
| `docs/prd/01-dav-planner-ac-templates.md` | 新建 | 本次變更 PRD |
| `tests/dav-planner-ac-templates.bats` | 新建 | 10 個探針守護 SOP 章節 |
| `docs/reflection/v1.8-dav-planner-ac-templates-reflection.md` | 新建 | 反省報告（含 Reviewer 結果）|

### Gate 驗證

| Gate | 結果 |
|------|------|
| Gate 1 (TDD) | ✅ 10/10 PASS（先紅後綠）|
| Gate 2 (lint) | ✅ Markdown + 連結完整性 + HTML 結構全通過 |
| Gate 3 (regression) | ✅ 無迴歸（206/218 pass，13 預存在 env fail 屬環境問題）|
| Gate 4 (reviewer) | ✅ PASS（V03 紀律成功抓 2 P0 blocker）|

### 下一步

| 選項 | 動作 |
|------|------|
| A | 用戶驗收本次交付，commit + push |
| B | 觀察實際生成新 US 時的 SOP 流程是否順暢，再 commit |
| C | 順手修 pre-existing bugs（changelog self-link / SKILL.md §5 重複句）|

---

## 變更檔案清單（含 diff 摘要）

### 新建檔案（7 個）

1. `docs/ac/README.md` — 76 行，目錄說明文檔
2. `docs/ac/US-101.md` — 範例 AC 範本（Markdown）
3. `docs/ac/US-101.html` — 範例 AC HTML 版（含列印友好 CSS）
4. `docs/prd/01-dav-planner-ac-templates.md` — 212 行 PRD
5. `tests/dav-planner-ac-templates.bats` — 10 個探針
6. `docs/deliverable/2026-09-26-dav-planner-ac-templates.md` — 本檔
7. `docs/deliverable/2026-09-26-dav-planner-ac-templates.html` — HTML 版
8. `docs/reflection/v1.8-dav-planner-ac-templates-reflection.md` — 反省報告

### 修改檔案（3 個）

| 檔案 | 新增行數 | 內容 |
|------|---------|------|
| `docs/backlog.md` | +74 | TMO-006 新條目 + 詳細段 |
| `docs/sop/handbook/changelog.md` | +33 | v1.8 條目 |
| `skills/dav-planner/SKILL.md` | +106 | §4.3.2 + §4.6（2 個新章節）|

**總計**：211 insertions(+), 2 deletions(-)（不含新建檔）

---

## 對應 AC（TMO-006 完成標準）

| 標準 | 狀態 |
|------|------|
| `docs/ac/` 目錄存在 + 至少 1 個範例檔 | ✅ |
| `dav-planner/SKILL.md` §4.3.2 新增（AC 精簡規則）| ✅ |
| `dav-planner/SKILL.md` §4.6 新增（HTML 生成 SOP）| ✅ |
| `tests/dav-planner-ac-templates.bats` 守護（≥ 3 探針）| ✅ 10 探針 |
| `tests/dav-planner-ac-templates.bats` 守護 docs/ac/ 範本 | ✅ |
| changelog v1.8 條目 | ✅ |
| Reviewer verdict: PASS | ✅ |
| `docs/backlog.md` TMO-006 → done | 🟡 待用戶驗收後 |

---

## 已知問題與限制

| 項目 | 處理 |
|------|------|
| 既有 backlog.md TMO-005 的 7 欄 bug | ✅ 順手修 |
| 既有 changelog self-link bug（2 處）| ⏭️ pre-existing，下次 Sprint 順手修 |
| 既有 SKILL.md §5 句重複 | ⏭️ pre-existing，不在本次 scope |
| 13 個 wiki-extract-media bats fail（環境問題）| ⏭️ pre-existing，與本次變更無關 |

---

## 對未來的建議（Think Big）

1. **下次新 US 生成時** 走 SOP §4.6：同 turn 生成 `docs/ac/<US-ID>.md` + `<US-ID>.html` + 更新 backlog.md
2. **既有 US 遷移**（optional）：用戶可隨時手動把現有 AC 從 backlog.md 抽出到 `docs/ac/`，分階段完成
3. **docs/ac/ index 頁**（下次 Sprint）：加一個 `docs/ac/README.md` 列出所有已生成的 US 範本（依 ID 排序），方便找
4. **HTML 主題切換**（下次 Sprint）：dark mode / 列印樣式優化（目前只有 print + desktop）
5. **AC lint**（下次 Sprint）：自動檢查 AC 是否符合「Given-When-Then 3 條以上 + DoD 4 條以上」

---

## 變更歷史

| 日期 | 版本 | 變更 | 作者 |
|------|------|------|------|
| 2026-09-26 | v1.0 | 初版建立（dav-planner v1.8 交付摘要）| Agent |
