# DE-001 交付：installer 自動合併 `~/.claude/skills`

**對應 Backlog**：DE-001
**日期**：2025-08-16
**狀態**：✅ DONE
**作者**：Agent（依 SOP 2.5）
**討論來源**：[`docs/discussion/2025-08-16-install-sh-merge.md`](../discussion/2025-08-16-install-sh-merge.md)
**設計計劃**：[`docs/plan/2025-08-16-install-sh-merge.md`](../plan/2025-08-16-install-sh-merge.md)
**反省報告**：[`docs/reflection/de-001-reflection.md`](../reflection/de-001-reflection.md)

---

## 1. 對話摘要

`./install.sh` 之前會在 `~/.claude/skills` 已存在的環境直接報錯拒絕安裝。今天修了：

- **新增 merge 預設行為**：自動逐個 skill symlink 進去，使用者 69 個自裝 skills 全部保留
- **新增 `--claude-skills-mode` 旗標**：可選 `merge`（預設）/ `replace`（備份後覆蓋）/ `skip`（略過）
- **CLAUDE.md 自動重寫**：stale symlink 自動解除並重寫成新 wrapper
- **真實環境安裝成功**：74 個 skills（你原本 69 + tree_monstor 8）共存
- **測試 26/26 通過**（舊 19 + 新 7）

---

## 2. 變更檔案

| 檔案 | 變更類型 | 行數變化 | 說明 |
|---|---|---|---|
| `install.sh` | 🔧 改 | +87 行 | 加 `CLAUDE_SKILLS_MODE` 變數、`--claude-skills-mode` 旗標（含 `=` 形式）、2 個新 helper `ensure_merged_skill` / `ensure_merged_skills_into`、重構 `install_claude` 處理 3 種模式、更新 `print_plan` + `print_help` |
| `tests/install.bats` | ➕ 加 | +95 行 | 7 個 DE-001 測試案例 |
| `tests/helpers/test-env.bash` | ➕ 加 | +45 行 | 2 個 helper：`create_existing_claude_skills_dir`、`create_existing_claude_wrapper_symlink` |
| `tests/fixtures/mock-tree-monstor/skills/conflict-skill/SKILL.md` | ➕ 加 | +13 行 | 命名衝突 fixture |
| `docs/discussion/2025-08-16-install-sh-merge.md` | ➕ 加 | 對話記錄 | 3 個決策 Q&A |
| `docs/plan/2025-08-16-install-sh-merge.md` | ➕ 加 | 設計計劃 | 旗標、函數、流程、測試 |
| `docs/reflection/de-001-reflection.md` | ➕ 加 | 反省報告 | 6 維度檢查 |
| `docs/backlog.md` | 🔧 改 | 狀態更新 | DE-001 → DONE、登記 TD-009/010/011 |

---

## 3. 驗收對應

### 3.1 AC 對應

| AC | 驗收結果 | 對應測試 |
|---|---|---|
| AC-1：merge 預設行為 | ✅ | DE-001 AC-1, AC-2 |
| AC-2：per-skill symlink | ✅ | DE-001 AC-1, AC-2 |
| AC-3：命名衝突跳過 | ✅ | DE-001 AC-3 |
| AC-4：`--claude-skills-mode` 旗標 | ✅ | DE-001 AC-4 (replace), AC-4b (skip) |
| AC-5：CLAUDE.md 自動重寫 | ✅ | DE-001 AC-5 |
| AC-6：`~/.pi/` 維持原計劃 | ✅ | AC-1, AC-3（19 個舊測試仍綠） |
| AC-7：`.agents/tree_monstor/` copy | ✅ | AC-4（19 個舊測試仍綠） |
| AC-8：7 個新測試 | ✅ | DE-001 AC-1 ~ AC-5 + AC-3b + AC-4b |
| AC-9：26/26 測試全綠 | ✅ | 全部 |
| AC-10：dry-run 顯示 merge 行為 | ✅ | DE-001 AC-5（涵蓋）、原 AC-9 仍綠 |

### 3.2 真實環境驗證

```
✓ 7 個 tree_monstor skills 合併進 ~/.claude/skills/
✓ 1 個 existing symlink (regression-guard) 帶 trailing slash 自動修復
✓ 69 個使用者自裝 skills 全部保留（autoplan/benchmark/...）
✓ ~/.claude/CLAUDE.md 從 stale symlink 變成新 wrapper
✓ ~/.pi/AGENTS.md, SOUL.md, skills 三個 symlink 建立
✓ ~/.agents/tree_monstor/ copy 完成
```

---

## 4. 已知問題

無。本次 DE-001 修復無已知未解決問題。

技術債（從反省產生）：
- **TD-009**（P2）：`abs_path` 對 trailing slash 邊緣案例補測試
- **TD-010**（P3）：旗標 `=` 形式支援統一化
- **TD-011**（P3）：`parse_args` 與 `print_plan` 對 modes 重複驗證集中化

---

## 5. 下一步建議

### 立即（給你決定）
1. **確認安裝結果**：`~/.claude/skills/` 內 merge 結果是否如預期
2. **測試新旗標**：可手動試
   - `cd tree_monstor && NO_COLOR=1 ./install.sh --dry-run --claude-skills-mode=replace` 看備份模式
   - `./install.sh --uninstall --global` 然後 `./install.sh` 重新安裝驗證冪等

### 之後（自然衍生）
3. **處理 TD-009**：加 `abs_path` 對 trailing slash 的專屬測試（避免未來改動時迴歸）
4. **更新 README**：把 `--claude-skills-mode` 新旗標加到 Usage 章節
5. **Sprint 級別反省**：US-001 + DE-001 完成後，可做一次 Sprint 級反省（按 `dav-reflection` 觸發規則）

### 戰略（Think Big）
6. **輔助工具**：考慮開發 `install.sh --list` 顯示目前安裝狀態（診斷用）
7. **CI 整合**：把 `bats tests/` 加到 `.github/workflows/test.yml`（TD-006）

---

## 6. 對應 Backlog 狀態

```diff
- PENDING: 1
+ PENDING: 1
- IN_PROGRESS: 0
+ IN_PROGRESS: 0
- DONE: 1
+ DONE: 2
```

DE-001 從 PENDING → DONE。

新登記 3 個技術債 TD-009/010/011（合計 6 個 PENDING TD：TD-005/006/008/009/010/011）。
