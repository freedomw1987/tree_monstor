# Sprint 02 設計計劃

**對應 Backlog**：Sprint 02（4 個 US：TD-005/006/009 + `--list` + `--doctor`）
**日期**：2025-08-16
**狀態**：待用戶審核
**作者**：Agent（依 SOP 2.2）
**範圍**：M1 — Installer & Distribution 模組（繼續 Sprint 01 的工作）

---

## 1. 目標

延續 Sprint 01 的 M1 模組建設，目標：
1. **清理 3 個 P2 技術債**（TD-005/006/009）
2. **新增 2 個診斷工具**（`--list` / `--doctor`）
3. **更新 README** 把新旗標寫進去
4. **commit** 這次的修改

---

## 2. Sprint 02 用戶故事清單

### US-002：更精準的幂等測試（清理 TD-005）

> **作為** tree_monstor 維護者，
> **我想要** AC-11a 改為比對具體檔案而非 hash 比較，
> **以便** 測試更精準，不會因為 ordering 變動而誤報失敗。

#### 驗收標準
- [ ] AC-1：原 AC-11a 改為枚舉每個預期檔案/symlink 並驗證存在
- [ ] AC-2：測試不再依賴 `xargs | shasum` 的命令鏈
- [ ] AC-3：新增 symlink 指向目標驗證（每個 symlink 都檢查 readlink 結果）
- [ ] AC-4：新增 wrapper 內容驗證（檢查關鍵 marker）
- [ ] AC-5：測試仍通過（19 舊 + 新增的精準版都通過）

### US-003：加 GitHub Actions CI（清理 TD-006）

> **作為** tree_monstor 維護者，
> **我想要** GitHub Actions 在 macOS + Linux 自動跑測試，
> **以便** PR 提交時自動驗證，避免迴歸。

#### 驗收標準
- [ ] AC-1：建立 `.github/workflows/test.yml`
- [ ] AC-2：macOS-latest + ubuntu-latest 兩個 runner
- [ ] AC-3：自動安裝 bats（`brew install bats-core` / `apt-get install bats`）
- [ ] AC-4：執行 `bats tests/install.bats`
- [ ] AC-5：測試失敗時 CI 紅燈（用 bats exit code）

### US-004：補 `abs_path` trailing slash 邊緣案例測試（清理 TD-009）

> **作為** tree_monstor 維護者，
> **我想要** 補 `abs_path` 對 trailing slash 處理的專屬測試，
> **以便** 未來改動 `abs_path` 時不會迴歸。

#### 驗收標準
- [ ] AC-1：新增測試案例 `test_abs_path_handles_trailing_slash`
- [ ] AC-2：測試覆蓋：symlink 到目錄 + trailing slash、普通目錄 + trailing slash、不存在路徑 + trailing slash
- [ ] AC-3：測試通過

### US-005：`install.sh --list` 診斷工具

> **作為** tree_monstor 使用者，
> **我想要** 一個旗標顯示目前安裝狀態，
> **以便** 我能診斷 installation 問題而不用 ls 整個 `~/.claude/`。

#### 驗收標準
- [ ] AC-1：新增 `--list` 旗標
- [ ] AC-2：列出所有已安裝項目：Claude wrapper / `~/.claude/skills` 狀態 / `~/.pi/` 三個 symlink / `.agents/tree_monstor/` copy
- [ ] AC-3：對每個項目顯示狀態：✅ 正常 / `[!]` 異常（stale symlink / 內容錯誤 / 路徑損壞）
- [ ] AC-4：對發現的 `.agents/tree_monstor` 提供 `git status` 風格摘要（檔案數、symlink 數、過期標記）
- [ ] AC-5：對 backups 目錄（`.claude/skills.bak.*`）也列出
- [ ] AC-6：dry-run 規則不適用（`--list` 是觀察的，不改變系統）
- [ ] AC-7：對應 5+ 個 bats 測試

### US-006：`install.sh --doctor` 自動診斷 + 互動修復

> **作為** tree_monstor 使用者，
> **我想要** 一個旗標自動掃描並修復問題，
> **以便** 我能一鍵修復 stale symlink / 損壞 wrapper。

#### 驗收標準
- [ ] AC-1：新增 `--doctor` 旗標
- [ ] AC-2：自動掃描 `--list` 顯示的所有問題
- [ ] AC-3：對每個問題顯示「建議修復」+ `[Y/n]` 互動確認
- [ ] AC-4：使用者答 Y 才執行修復
- [ ] AC-5：答 n 跳過該項繼續下一個
- [ ] AC-6：能用 `--yes` 跳過確認（給 CI/批次用）
- [ ] AC-7：對應 3+ 個 bats 測試（含互動測試）

---

## 3. 執行策略

### 3.1 順序（策略 1：每個 US 完整 SOP 循環）

```
Sprint 02 啟動
  ↓
[立即] 更新 README + commit      ← 第 1 階段
  ↓
US-002 (TD-005)                  ← 第 2 階段
  ├─ 討論 + 計劃
  ├─ TDD 測試
  ├─ 實作
  ├─ 反省
  └─ 交付
  ↓
US-003 (TD-006)
  ├─ ... 同上
  ↓
US-004 (TD-009)
  ├─ ... 同上
  ↓
US-005 (--list)
  ├─ ... 同上
  ↓
US-006 (--doctor)
  ├─ ... 同上
  ↓
Sprint 02 反省                   ← 第 3 階段
```

### 3.2 預估時長

| 階段 | 項目 | 預估工作量 |
|---|---|---|
| 第 1 階段 | README + commit | 30 min |
| 第 2 階段 | US-002 (TD-005) | 30 min |
| 第 2 階段 | US-003 (TD-006) | 30 min |
| 第 2 階段 | US-004 (TD-009) | 20 min |
| 第 2 階段 | US-005 (--list) | 60 min |
| 第 2 階段 | US-006 (--doctor) | 60 min |
| 第 3 階段 | Sprint 02 反省 | 30 min |
| 合計 | | ~4-5 小時 |

每個 US 預估 1-3 個 Story Point（沿用 Sprint 01 的評估標準）。

### 3.3 風險與緩解

| 風險 | 緩解 |
|---|---|
| `--doctor` 互動測試複雜 | 用 `<<<` 餵 stdin 模擬用戶輸入 |
| GitHub Actions 需要 self-hosted runner | 用官方 macOS-latest / ubuntu-latest |
| `abs_path` 邊緣案例可能不只 1 個 | 測試時多嘗試幾個 case |
| 5 個 US 連續執行可能中間遺忘進度 | 每個 US 結束都更新 backlog |

---

## 4. 用戶故事分組（Backlog 登記）

我會立即把 5 個新項目（US-002/003/004/005/006）登記到 `docs/backlog.md`：

| ID | 標題 | 來源 | Module | 優先級 | 估算 |
|---|---|---|---|---|---|
| **US-002** | AC-11a 改為更精準幂等測試 | TD-005 | M1 | P2 | 1 |
| **US-003** | 加 GitHub Actions CI | TD-006 | M1 | P2 | 2 |
| **US-004** | 補 abs_path trailing slash 測試 | TD-009 | M1 | P2 | 1 |
| **US-005** | install.sh --list 診斷工具 | NEW | M1 | P1 | 3 |
| **US-006** | install.sh --doctor 自動修復 | NEW | M1 | P1 | 3 |

> 註：US-005/006 雖然是「戰略導向」，但因為你選 A1（完整專注），把它們優先級從 P3 升為 P1（在 Sprint 02 內必做）。

總計：1+2+1+3+3 = **10 個 Story Point**

---

## 5. 交付物清單

完成 Sprint 02 後應產出：

- [ ] `install.sh`（預估 +150 行）
- [ ] `tests/install.bats`（預估 +10 個測試，總計 36 個）
- [ ] `.github/workflows/test.yml`（新檔案）
- [ ] `README.md`（更新）
- [ ] 5 個 US 的 reflection（反思報告）
- [ ] 5 個 US 的 deliverable（詳錄 + HTML）
- [ ] Sprint 02 反省報告
- [ ] 更新 `docs/backlog.md`

---

## 6. 待用戶確認

請你看完整份計劃後告訴我：

1. **計劃 OK，可以進入 SOP 2.3 開始執行？**
2. 還是某些部分要改？

確認後我會：
1. 立即更新 README + commit（**第 1 階段**）
2. 然後用 Strategy 1 跑 5 個 US（每個完整 SOP 循環）
3. 最後 Sprint 02 級反省

> **備註**：Sprint 02 啟動前我會先做一步**設定檢查**（確認 git 狀態、測試 baseline），確保在乾淨環境開始。
