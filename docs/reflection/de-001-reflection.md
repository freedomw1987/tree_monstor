# DE-001 反省報告

**對應 Backlog**：DE-001 — installer 拒絕在 `~/.claude/skills` 已存在的環境中安裝
**日期**：2025-08-16
**級別**：User Story（Defect 等同小 US）
**作者**：Agent（依 SOP 2.4）
**討論來源**：[`docs/discussion/2025-08-16-install-sh-merge.md`](../discussion/2025-08-16-install-sh-merge.md)
**設計計劃**：[`docs/plan/2025-08-16-install-sh-merge.md`](../plan/2025-08-16-install-sh-merge.md)

---

## 1. 確認反省範圍

**交付物**：
- `install.sh`（488 → 575 行，+87 行）
- `tests/install.bats`（19 → 26 個測試，+7）
- `tests/helpers/test-env.bash`（+45 行，2 個 helper）
- `tests/fixtures/mock-tree-monstor/skills/conflict-skill/SKILL.md`（新 fixture）
- `docs/discussion/2025-08-16-install-sh-merge.md`（討論記錄）
- `docs/plan/2025-08-16-install-sh-merge.md`（計劃）

**驗收結果**：26/26 測試 ✅ · 安裝成功於真實 `~/` 環境 ✅

---

## 2. 六維度檢查

### 2.1 UX/UI 一致性 — ✅ 通過

- 新的 `merge` 預設行為完全符合用戶確認的 A → A2 → C 策略
- 輸出風格與既有 `log_ok` / `log_warn` / `log_err` 保持一致（用 `[✓]` / `[!]` / `[✗]` 標記）
- 對衝突情況用 `[!]` 警告是符合既有風格的（與既有 symlink 修復警告一致）
- `print_help` 旗標說明順序、命名風格與既有 CLI 對齊

### 2.2 RWD 響應式設計 — N/A

（這是 CLI 工具，不適用）

### 2.3 技術債 — ⚠️ 有風險

1. **旗標值重複驗證**：在 `parse_args` 內對 `--claude-skills-mode` 做了 `merge|replace|skip` 驗證，但 `print_plan` 內又 case 了一次。**風險**：未來新增 mode 時容易忘記更新其中一處。
   - **緩解**：可考慮集中成 `VALID_CLAUDE_SKILLS_MODES` 變數 + 抽出 `print_claude_skills_plan()` 函數（降為 P3 延後處理）

2. **`abs_path` 對 trailing slash 處理**：現實安裝時發現 `regression-guard` 舊 symlink 帶有 trailing slash（`tree_monstor/skills/regression-guard/`），目前 `abs_path` 對目錄會 strip slash，但對 symlink 到目錄 + trailing slash 的組合仍會出現「current vs target_abs」不相等的修復？
   - **事實**：實際安裝時已自動修復 ✅
   - **真正風險**：測試中沒有覆蓋這個邊緣案例（`abs_path` 對 trailing slash 的處理），只是在真實環境「剛好」修復。
   - **Action**：登記為 **`TD-009`**（P2，下次處理）

3. **旗標支援 `--mode=val` 形式**：本次新增了 `--claude-skills-mode=val` 支援，但既有 `--target` / `--agent` / `--source` 都不支援 `=` 形式。**不一致**。
   - **Action**：登記為 **`TD-010`**（P3，未來可統一所有旗標支援 `=` 形式）

### 2.4 可維護性 — ✅ 通過

- 新函數 `ensure_merged_skill` / `ensure_merged_skills_into` 職責清晰，命名易讀
- 既有 `ensure_symlink` 完全沒動，避免不必要的修改
- `install_claude` 改用 `case` 處理 3 種模式，邏輯分支清楚
- 每個新函數都有單獨的 `REGRESSION-GUARD PROBE:` 標記（10 個探針）

### 2.5 測試覆蓋率 — ✅ 通過

- 7 個新測試案例，每個 AC 都有對應
- 包含邊緣案例：命名衝突、錯向 symlink 修復、replace 備份、skip 模式、stale symlink 覆寫
- `assert_path_is_file` 確保用戶原檔未被覆蓋
- `assert_path_is_symlink` 確保新合併的 symlink 目標正確
- 缺：未來可加 — 大量 skills 的效能測試（目前 8 個 skill 是手動測的 P1）

### 2.6 需求對齊 — ✅ 通過

- 完全達成原始 3 個決策（A → A2 → C）
- 解決用戶痛點：installer 不再因 `~/.claude/skills` 已存在而失敗
- 69 個用戶自裝 skills 全部保留（實測 `autoplan` 等完好）
- 額外提供 `--claude-skills-mode=replace` / `skip` 兩個進階選項（用戶未明確要求，但增加彈性）

---

## 3. 問題清單

| # | 問題 | 類型 | 優先級 |
|---|------|------|--------|
| 1 | `abs_path` 對 trailing slash 邊緣案例 | 技術債 | P2 |
| 2 | 旗標 `=` 形式支援不一致 | 技術債 | P3 |
| 3 | `parse_args` 與 `print_plan` 對 modes 重複驗證 | 技術債 | P3 |

> 註：本次無新 Bug、無缺失功能（merge 模式已涵蓋三種需求）。

---

## 4. Action Items

### 立即處理（本 PR 內）
- 無

### 延後到下個 Sprint / Module
- **TD-009**：`abs_path` 對 trailing slash 邊緣案例（P2）
- **TD-010**：旗標 `=` 形式支援統一化（P3）

---

## 5. 反思

**這次做對的事**：
- TDD 先行：先寫 7 個**全紅**測試再實作，驗證測試本身的品質（2 個測試的邏輯被我修過）
- 邊緣案例：**實際安裝時**才發現 `regression-guard` 舊 symlink 帶 trailing slash，印證「真實環境測試」比 mock 更重要
- 26 個測試全綠 + 真實環境（用戶真實 `~/.claude/skills`）安裝成功，雙重驗證

**下次可改進**：
- 在 fixtures 加上邊緣案例（trailing slash, broken symlink）
- 對 `print_help` 加 `bats` 測試斷言「所有旗標都有說明」

---

## 6. 簽核

- [x] Agent 自我反省完畢
- [x] 已登記 Action Items 到 Backlog
- [x] 測試 26/26 通過
- [x] 真實環境安裝成功
- [ ] **待用戶確認**（這是 US 級別，用戶可選擇略過）
