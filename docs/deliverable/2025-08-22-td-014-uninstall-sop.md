# TD-014 交付摘要 — `do_uninstall` 加 sop/ 清理

**日期**：2025-08-22
**Backlog ID**：TD-014（P3，2 SP）
**作者**：Agent
**狀態**：✅ 完成

---

## 摘要

新增 `remove_merged_sop` 函式（與 `remove_merged_skills` 對稱），讓 `--uninstall` 能正確清理 `~/.pi/sop/*.json` 與 `~/.claude/sop/*.json` 內指向 `docs/sop/` 的 symlinks，**保留用戶自加的 .json 檔案**。

---

## 變更清單

| 檔案 | 改動 |
| --- | --- |
| `install.sh` | 新增 `remove_merged_sop()` 函式（51 行） + `uninstall_claude()` 與 `uninstall_pi()` 各加 sop/ 清理（~12 行）|
| `tests/install.bats` | 新增 4 個 TD-014 測試（AC-1/2/3/4）|

---

## 驗收證據

- **Gate 1（TDD）** ✅：4 個 TD-014 測試紅→綠
- **Gate 2（lint）** ✅：
  - `bash -n install.sh`：0 error
  - ajv 仍 valid
- **Gate 3（regression）** ✅：bats **41/41** 全綠（baseline 37 + 新增 4，0 破壞）
- **Gate 4（reviewer）** ✅：5 項手工檢查全綠

---

## 已知問題

無

---

## 下一步建議（V20）

- **驗收方式**：`bash install.sh --uninstall --global --yes` 看 `~/.pi/sop/` 與 `~/.claude/sop/` 是否清乾淨
- **預估時間**：< 5 分鐘
- **風險提示**：⚠️ 真實環境可能已有用戶加的 .json — 但 `remove_merged_sop` 只刪指向 `$SOURCE_DIR/docs/sop/` 的 symlink，用戶檔案不會被誤刪