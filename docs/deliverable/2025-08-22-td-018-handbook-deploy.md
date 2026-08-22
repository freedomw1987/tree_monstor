# TD-018 交付摘要 — handbook/*.md 部署到 agent 安裝位置

**日期**：2025-08-22
**Backlog ID**：TD-018（P1，3 SP）
**作者**：Agent
**狀態**：✅ 完成

---

## 摘要

AGENTS.md 內引用 handbook 用相對路徑，但安裝後 handbook 跑到 `~/.pi/sop/handbook/` 和
`~/.claude/sop/handbook/`，與「AGENTS.md symlink 指向原檔 → 相對路徑從原檔位置算起」
的策略有落差。本任務：

1. **AGENTS.md 加裝「安裝後路徑表」**：明確標示兩個 agent 安裝後 handbook 的位置
2. **`install_sop()` 擴充**：也處理 `docs/sop/handbook/*.md`
3. **`remove_merged_sop()` 擴充**：用遞迴清理子目錄 symlink
4. **Fixture 加 `docs/sop/` + `handbook/`**：讓 install.bats 測試能跑到 sop 部署

---

## 變更清單

| 檔案 | 改動 |
| --- | --- |
| `AGENTS.md` | 加「安裝後路徑表」+ 章節索引加註解（68 → 78 行）|
| `install.sh` | `install_sop()` 加 handbook/*.md 處理；`remove_merged_sop()` 改用遞迴清理子目錄 |
| `tests/fixtures/mock-tree-monstor/docs/sop/` | 新增（gates.json + gates.schema.json + handbook/）|
| `tests/install.bats` | 加 5 個 TD-018 AC 測試（AC-1/2/3/4/5）|
| `tests/agents-md.bats` | 加 TD-018 AC-6 測試（AGENTS.md 引用路徑）|
| `docs/backlog.md` | TD-018 條目登記 |

---

## 驗收證據

### Gate 1 (TDD) — 紅→綠

| 階段 | 結果 |
|---|---|
| 紅（測試先寫）| 4 個 TD-018 AC fail（AC-1/2/3/4 — 因 install_sop 還沒處理 handbook）|
| 綠（實作後）| 全部 AC-1/2/3/4/5/6 通過 |

### 依 gates.json 規範，Gate 2 (lint) 需要：對應語言 linter 0 error

| 工具 | 結果 |
|---|---|
| `bash -n install.sh` | 0 error ✅ |
| `ajv validate` | gates.json valid ✅ |
| `python3 -m json.tool` | 0 error ✅ |

### 依 gates.json 規範，Gate 3 (regression) 需要：探針埋好 + 完整測試套件跑過

| 階段 | 通過 / 失敗 |
|---|---|
| Baseline（TD-018 實作前）| 45 / 0 |
| After（TD-018 實作後） | 51 / 0 |
| Diff | +6 新探針（AC-1/2/3/4/5/6），0 破壞 |

### 依 gates.json 規範，Gate 4 (reviewer) 需要：5 項手工檢查全綠

| 檢查項 | 結果 |
|---|---|
| install.sh 改動正確（install_sop + remove_merged_sop 處理 handbook）| ✅ |
| AGENTS.md 78 行 + 含兩個 agent 安裝路徑 | ✅ |
| Fixture 含 docs/sop/ + handbook/（9 個檔）| ✅ |
| bats 51/51 | ✅ |
| 真實部署驗證（`./install.sh --source . --global --agent pi --yes`）| ✅「sop handbook installed」log 顯示 |

---

## 已知問題

| ID | 問題 | 處理 |
|---|---|---|
| O1 | AGENTS.md 內**本地開發時的相對路徑**（如 `[§2.1](docs/sop/handbook/2.1-planning.md)`）在「安裝後視角」會指向 `~/.pi/agent/docs/sop/handbook/...`，這不存在 | 已加註解說明「AGENTS.md symlink 指向原檔，相對路徑從原檔位置算起」 |
| O2 | 兩個 agent 安裝後 handbook 各自一份（無 deduplication）| 不處理 — handbook 內容由 source 控制，symlink 自然同步 |

---

## 下一步建議（V20）

- **驗收方式**：
  1. 跑 `./install.sh --source . --global --agent pi --yes`，看 `sop handbook installed` log
  2. 跑 `ls -la ~/.pi/sop/handbook/`，看到 9 個 symlink
  3. 跑 `bats tests/install.bats tests/agents-md.bats`，看 51/51
- **預估時間**：< 10 分鐘
- **風險提示**：
  - ⚠️ **R1**：未來若 `docs/sop/handbook/` 子目錄再增加（例如 `handbook/examples/`），`install_sop` 的 `*.md` glob 不會匹配更深的子目錄 — 若需更深層結構要改 glob
  - ⚠️ **R2**：`remove_merged_sop` 遞迴是 breadth-first，先處理 parent dir 才進 child — 若中途失敗會留 partial state，但 uninstall 通常不在意這點

---

## 觀察

| # | 觀察 | 影響 |
| - | -- | -- |
| O3 | 用戶反饋**再次救了系統** — 沒有這個問題，AGENTS.md 內的相對路徑會在所有安裝用戶的環境中完全失效 | 提醒：用戶測試視角 = 系統的真實使用場景 |
| O4 | TD-017 → TD-018 是一個**完整鏈**：精簡 → 引用 → 部署 → 測試鏈未在精簡時一併驗證 | 提醒：跨檔改動要做「全鏈路」思考 |