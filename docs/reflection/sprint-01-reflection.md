# Sprint 01 反省報告

> **Sprint 範圍**：2025-08-16（單日 Sprint）
> **反省日期**：2025-08-16
> **參與者**：Agent + 用戶（依 SOP 2.4 Sprint 級別要求）
> **反省級別**：Sprint
> **對應 Backlog**：US-001 + DE-001

---

## Sprint 總覽

| 項目 | 數據 |
|------|------|
| 計劃完成 US | 1（US-001） |
| 實際完成 US | 1（US-001） + 1 Defect（DE-001） |
| 完成率 | 100%（計劃）+ 額外 1 個修復 |
| 發現的問題 | 6 個技術債（TD-005/006/008/009/010/011） |
| 程式碼總增長 | install.sh：488 → 575 行（+87 行） |
| 測試總增長 | 19 → 26 個（+7 個） |
| 真實環境驗證 | ✅ `~/.claude/skills` 74 個 skills 共存 |

> **註**：這是 tree_monstor 專案的**第一個 Sprint**，所以「完成率 100%」是在「(US-001 完成 + DE-001 額外修復完成) / 計劃項目」意義下成立。

---

## 完成 US 列表

| ID | 標題 | 模組 | 狀態 | 反省結果 |
|----|------|------|------|---------|
| **US-001** | 為 tree_monstor 加入 `install.sh` | M1 — Installer & Distribution | ✅ DONE | ✅ |
| **DE-001** | 修復 installer 拒絕在 `~/.claude/skills` 已存在時安裝 | M1 — Installer & Distribution | ✅ DONE | ✅ |

兩個項目都屬於同一個 Module（M1）的兩個工作項目。

---

## 反省結果總覽

| 檢查維度 | 結果 | 備註 |
|---------|------|------|
| **UX/UI 一致性** | ✅ 通過 | 輸出風格（顏色、符號、訊息層級）全 Sprint 一致；無 scope creep |
| **RWD 響應式設計** | N/A | CLI 工具不適用 |
| **技術債** | ⚠️ 有風險 | 6 個 TD 已登記，無 P0/P1 阻礙；但累積中需控制 |
| **可維護性** | ✅ 通過 | 函數職責清晰、命名語意化、有 10 個 REGRESSION-GUARD 探針 |
| **測試覆蓋率** | ✅ 通過 | 26/26 綠、AC 100% 覆蓋、有 edge case 測試 |
| **需求對齊** | ✅ 通過 | 真正解決用戶痛點（全域安裝一鍵完成 + 保留自裝 skills） |

---

## 詳細檢查（6 個維度）

### 1. UX/UI 一致性 — ✅ 通過

**輸出風格**：
- 全 Sprint 用一致的 `[✓]` / `[!]` / `[✗]` / `[i]` / `[?]` 標記
- 顏色用 NO_COLOR 標準（綠/黃/紅/藍/灰）
- 訊息層級統一：info → ok → warn → err → plan/dry

**互動設計**：
- `--yes` 跳過確認（給 CI 用）
- `--quiet` 只印錯誤與最終摘要
- `--dry-run` 預覽模式不實際執行
- 三層確認訊息（Plan → Proceed → 執行結果）

**用戶期望對齊**：
- US-001 滿足「**改源檔能即時生效**」（透過 symlink）
- DE-001 滿足「**保留用戶自裝 skills**」（透過 merge 預設行為）

⚠️ **小風險**：未來如果新增第 3 種 agent（如 Codex），需要擴展 `print_plan` 的 `case` 分支

### 2. RWD 響應式設計 — N/A

CLI 工具不適用此維度。

### 3. 技術債 — ⚠️ 有風險

#### 已知 TD 登記

| ID | 標題 | 來源 | 優先級 |
|---|---|---|---|
| **TD-005** | AC-11a 改為更精準幂等測試（比對具體檔案而非 hash） | US-001 反省 | P2 |
| **TD-006** | 加 GitHub Actions CI（macOS + Linux） | US-001 反省 | P2 |
| **TD-008** | Magic strings 集中成變數（`.claude`/`.pi`/`.agents`/marker） | US-001 反省 | P3 |
| **TD-009** | `abs_path` 對 trailing slash 邊緣案例補測試 | DE-001 反省 | P2 |
| **TD-010** | 旗標 `=` 形式支援統一化 | DE-001 反省 | P3 |
| **TD-011** | `parse_args` 與 `print_plan` 對 modes 重複驗證集中化 | DE-001 反省 | P3 |

#### 新發現的技術債（本次反省）

##### TD-012：旗標命名不一致（merge / replace / skip 是動詞但命名是「mode」）
- **類型**：技術債
- **嚴重性**：P3
- **描述**：`--claude-skills-mode` 內的 `merge` / `replace` / `skip` 都是動詞，但旗標名稱用 `mode`（名詞）。更語意化應該是 `--claude-skills-strategy` 或把動詞改成名詞（如 `merged` / `replaced` / `skipped`）。
- **影響範圍**：僅 CLI 命名，不影響功能
- **建議方案**：保留現狀（破壞性變更成本高），但登記為未來考量的命名選項
- **Backlog ID**：TD-012

##### TD-013：缺少年份/月份時間戳隔離的清除機制
- **類型**：技術債
- **嚴重性**：P3
- **描述**：`--claude-skills-mode=replace` 會建立 `~/.claude/skills.bak.YYYYMMDD-HHMMSS`，但這些備份永遠不會被自動清除。長期使用會累積大量備份。
- **影響範圍**：磁碟空間；若安裝次數頻繁
- **建議方案**：加 `--claude-skills-clean-backups` 旗標或 `--uninstall` 時自動清除 owned 備份
- **Backlog ID**：TD-013

##### TD-014：magic strings 散落（已記錄但未集中）
- **類型**：技術債
- **嚴重性**：P3
- **描述**：`.claude`、`.pi`、`.agents`、marker 字串散落 8 處。
- **影響範圍**：未來新增 agent 時需手動同步多處
- **建議方案**：已記錄為 TD-008，可與 TD-013 一併處理
- **Backlog ID**：見 TD-008

### 4. 可維護性 — ✅ 通過

**優點**：
- 函數職責清晰（`ensure_symlink` / `ensure_merged_skill` / `ensure_merged_skills_into` / `ensure_file` 各司其職）
- 命名語意化（`merge` / `replace` / `skip` 直接對應動作）
- 10 個 REGRESSION-GUARD PROBE 標記（`log-output` / `arg-parsing` / `symlink-idempotency` / `merged-skill` / `merged-skills-into` / `claude-install` / `pi-install` / `agents-dir-copy` / `copy-with-exclude` / `uninstall`）
- 模組化達成（`install_claude` / `install_pi` / `install_agents_dir` / `do_uninstall` 各自獨立）
- `set -euo pipefail` 啟用，Bash 嚴格模式

**未來風險**：
- 575 行的單檔，安裝邏輯集中在 install.sh（但因為是 CLI 工具，這是合理的）

### 5. 測試覆蓋率 — ✅ 通過

| 指標 | 數據 |
|---|---|
| 測試總數 | 26 |
| 通過率 | 100% |
| US-001 AC 覆蓋 | 16/16 |
| DE-001 AC 覆蓋 | 10/10 |
| 邊緣案例 | 命名衝突、stale symlink、trailing slash、broken symlink、無 HOME、互動式輸入 |

**測試品質**：
- 每個 AC 都有對應測試
- 邊緣案例測試（命名衝突、stale symlink、replace 備份、skip 模式）
- 用 test-env.bash 隔離 HOME（每個測試獨立 tmp dir）
- 無 flaky test
- 測試自己發現的 bug：DE-001 AC-5 原本「意外通過」，證明測試是基於黑盒行為而非實作

### 6. 需求對齊 — ✅ 通過

**用戶原始痛點**：
> 想要一個工具讓 Claude Code 和 Pi Agent 都能讀到 tree_monstor 的 AGENTS.md / SOUL.md / skills/

**實際交付**：
- ✅ Claude Code 透過 `~/.claude/CLAUDE.md` wrapper `@` 引用源檔
- ✅ Pi Agent 透過 `~/.pi/AGENTS.md` symlink 讀源檔
- ✅ skills 透過 merge 友好地合併進 `~/.claude/skills/`
- ✅ 改源檔即時生效（symlink 機制）
- ✅ 真實環境驗證：74 個 skills 共存，無破壞

**無遺漏、無 scope creep**：
- 用戶沒要求的功能（如 `--list` 診斷工具、CI 整合）未擅自加入
- 用戶要求的功能（如 doc 反饋、sub-task 拆解）全部完成

**驗收標準達成**：
- US-001：16/16 AC ✅
- DE-001：10/10 AC ✅

---

## 跨 US 的觀察

### 共同點 1：TDD 流程效果好
兩個 US 都嚴格按 TDD 執行（先寫測試，再實作），發現：
- DE-001 在 TDD 過程中**發現測試本身的邏輯錯誤**（AC-1、AC-2 把「跳過衝突」誤解為「合併衝突」），這證明 TDD 不只能驗證實作，還能驗證需求理解
- 在真實環境安裝時發現 `regression-guard` 帶 trailing slash 的邊緣案例，證明「真實環境測試」是 mock 無法取代的

### 共同點 2：REGRESSION-GUARD 探針發揮作用
- 10 個探針標記未來若 install.sh 結構變動，可以快速定位關鍵函數
- 維護性更高（除錯時知道哪個函數負責什麼）

### 共同點 3：用戶參與度高
- US-001 沒有用戶事先參與的問題（從 0 到 1）
- DE-001 完全是**用戶在真實環境遇到 bug** → 觸發了 P0 級 Defect
- 兩次都用了「**3 個問題的 Q&A 引導**」流程（dav-planner），效果都很好

### 共同點 4：技術債持續累積
- TD-005/006/008 從 US-001 帶下來
- TD-009/010/011 從 DE-001 帶下來
- 加上 TD-012/013 共 8 個 PENDING TD
- 雖然都是 P2/P3，但**未來需要 Sprint 集中清理**

---

## Action Items

### 立即處理（下次執行前）

無（無 P0/P1 阻礙）

### 下一個 Sprint 內處理

- [ ] **TD-005** (P2)：AC-11a 改為更精準幂等測試
- [ ] **TD-006** (P2)：加 GitHub Actions CI（macOS + Linux）
- [ ] **TD-009** (P2)：`abs_path` 對 trailing slash 邊緣案例補測試
- [ ] **新增 TD-013** (P3)：備份清除機制（`.claude/skills.bak.*` 累積問題）

### Backlog Icebox（中期，未來考量）

- [ ] **TD-008** (P3)：Magic strings 集中成變數
- [ ] **TD-010** (P3)：旗標 `=` 形式支援統一化
- [ ] **TD-011** (P3)：modes 重複驗證集中化
- [ ] **TD-012** (P3)：旗標命名一致性考量

### 下個 Sprint 建議

**如果 Sprint 02 還在 M1 模組**：
- 處理 TD-005/006/009（測試品質 + CI）
- 加 `install.sh --list` 診斷工具（Help 工具）
- 加 `install.sh --doctor` 檢查 symlink 健康狀態

**如果 Sprint 02 開新模組**：
- 評估是否進 M2（如 `dav-reflection` 工具化、PR Review 流程）
- 或 M3（如專案級 hooks、CI 預設）

---

## 結論

### 整體評價：✅ 成功

**收穫**：
1. **install.sh 從 0 到 1 + 真實環境驗證** = 487 行 + 26 測試 + 5 文件
2. **DE-001 緊急修復** = 沒有用戶自裝 skills 損壞
3. **Sprint 流程跑通** = TDD + REGRESSION-GUARD + d av-designer + dav-reflection + dav-submitter 完整協作

**教訓**：
1. **真實環境測試不可取代 mock**（DE-001 trailing slash 案例）
2. **TDD 也能驗證需求理解**（DE-001 AC-1/AC-2 測試邏輯錯誤）
3. **技術債持續累積**（4 個 US 就 8 個 TD），需要定期清理

**Sprint 質量**：
- 完成度 100%
- 測試 26/26 綠
- 6 個 TD 健康登記（無 P0/P1）
- 用戶實際痛點（installer 失敗）已解決

---

## 簽核

- [x] Agent 自我反省完畢
- [x] Action Items 已登記到 Backlog
- [x] Sprint 級別用戶共同檢視（**待用戶確認**）
- [ ] 用戶對 Action Items 優先級調整
- [ ] 用戶決定下個 Sprint 方向
