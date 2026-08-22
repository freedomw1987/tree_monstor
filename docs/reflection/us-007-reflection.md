# US-007 反省報告

**日期**：2025-08-22
**Backlog**：US-007（Extract §2.3 4 Gate logic to gates.json）
**層級**：User Story（獨立 Sprint — SOP Infra Sprint 01）

---

## 6 維度檢查

| # | 維度       | 結果 | 備註 |
| - | -------- | :-: | -- |
| 1 | UX/UI 一致性 | ✅ | 本任務為 SOP 規範文件，無 UI |
| 2 | RWD 響應式設計 | ✅ | 不適用（文件 + JSON） |
| 3 | 技術債      | ⚠️ | TD-014（uninstall sop/）+ TD-015（Draft 07 vs 2020-12）已登記 |
| 4 | 可維護性     | ✅ | 結構化 JSON + Schema，未來擴充只需改 gates.json |
| 5 | 測試覆蓋率   | ✅ | 5 個新 bats 測試覆蓋 AC-5/5b/5c/6/7；37/37 全綠 |
| 6 | 需求對齊     | ✅ | 結構 7/7 + 行為 3/3 接力 US-008 |

---

## 問題清單（V15 — 每個 ❌ 必含「根因 + 建議」）

### ❌ [P3] TD-014：uninstall 不清理 `~/.pi/sop/` 與 `~/.claude/sop/`

- **根因**：US-007 只實作 install 邏輯（`install_sop`），沒對應的 `do_uninstall_sop`。
- **影響**：源檔被刪時 symlink 失效；uninstall 後殘留 dead symlinks。
- **建議**：在 `do_uninstall` 加清理 `~/.pi/sop/*.json` 與 `~/.claude/sop/*.json`，用 `remove_managed_path` 模式（跟 AGENTS.md/skills 一致）。
- **優先級**：P3（不擋當前 sprint，但下一個 sprint 應處理）。

### ⚠️ [P3] TD-015：gates.schema.json 用 Draft-07 而非原計劃 2020-12

- **根因**：ajv-cli 只支援 draft-07 與 2019-09，不支援 2020-12。
- **影響**：與計劃文件 §4「JSON Schema Draft 2020-12」有出入。
- **建議**：當前用 Draft-07 是務實決定（驗證工具支援度）。未來若改用 ajv API（直接 Node.js import）可升級到 2020-12。
- **優先級**：P3（功能不受影響，純粹是「用了什麼標準」的文件差異）。

---

## ⚠️ 觀察（非問題，僅記錄）

| # | 觀察 | 影響 |
| - | -- | -- |
| O1 | AGENTS.md §2.3 表格原本有「通過條件」「不通過後果」2 欄，現縮成「名稱」「觸發 skill」2 欄 | 詳細條件全部在 gates.json，但快速閱讀時看不到 fail_action 摘要。可考慮在 AGENTS.md 加 1 欄「失敗時禁止什麼」 |
| O2 | install.sh 用 symlink 部署（跟 AGENTS.md 一致），但意味著源檔是 single point of truth | 改 gates.json 後不需要重跑 install ✅，但源檔被 git reset 會導致 deployed gates.json 跟著變 |
| O3 | Gate 4 reviewer 因環境無 subagent 改手工模式 | reviewer 視角一致，但缺獨立 agent 的盲點掃描。建議下個 sprint 環境支援後補一次 subagent reviewer |

---

## Action Items（V15 — 必含 4 欄位）

| # | 動作 | 類型（TECH/DE/US/Spike） | 驗收標準 | 預估 |
| - | -- | ----------------- | ---- | -- |
| 1 | 執行 US-008：用 `dav-skill-creater` 產 1 SP 任務，驗證 Agent 真的引用 gates.json | US-008 | AC-1~AC-4 全綠 | 1 SP |
| 2 | `do_uninstall` 加 `~/.pi/sop/` + `~/.claude/sop/` 清理（用 `remove_managed_path` 模式） | TD-014 | uninstall 後無 dead symlinks | 2 SP |
| 3 | 文件加註明 gates.schema.json 使用 Draft-07（非 2020-12）原因 | TD-015 | gates.schema.json 加 `$comment` 或 README 註記 | 1 SP |
| 4 | AGENTS.md §2.3 表格加「失敗時禁止什麼」欄（從 gates.json `fail_action` 提取） | 觀察 O1 | 表格 3 欄完整 | 1 SP |

---

## 交付物

- `docs/sop/gates.json`（1907 bytes — 4 個 Gate + schema reference）
- `docs/sop/gates.schema.json`（3380 bytes — JSON Schema Draft 07 完整定義）
- `AGENTS.md` §2.3（從 583 → 522 行，-61 行）
- `install.sh`（3 處改動：print_plan / install_sop / main loop）
- `tests/install.bats`（新增 5 個 US-007 測試）
- `docs/review/2025-08-22-us-007-reviewer-check.md`（10 項 reviewer 檢查全綠）

---

## SOP §2.7 自檢 — 違規記錄

本任務執行過程中：
- ✅ 嚴格遵守 4 Gate 依序（Gate 1 TDD 紅→綠 → Gate 2 lint → Gate 3 regression → Gate 4 reviewer）
- ✅ TDD 過程中誠實修正測試期望（AC-6 從「gates.json」改「/.pi/sop/」），原因真實（plan 用 `*.json` 通配符）
- ✅ 環境限制誠實標記（Gate 4 手工 reviewer）
- ✅ Draft-07 vs 2020-12 偏離原計劃時誠實記錄（TD-015）
- ⚠️ 一個輕微違規風險：Gate 4 改手工模式時**沒有事先問用戶**就動手 — 但用戶事後確認選項 A（已追認合規）

**無重大違規** ✅