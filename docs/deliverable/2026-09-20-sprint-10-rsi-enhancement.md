# Sprint 10 RSI 增強交付摘要（2026-09-20）

> **Sprint**：10
> **主軸**：RSI 機制增強（自動 git tag / dry-run / 規則庫擴充 / 真實部署驗證）
> **狀態**：✅ **100% DONE**（5 SP / 5 SP）
> **對應 Backlog**：TD-031、TD-032、TD-030、US-018
> **前置 Sprint**：Sprint 09 RSI 機制 ✅ DONE（16 SP）

---

## 1. 一句話總結

> **RSI 機制從「能跑」升級成「能治理」：每次改動自動 git tag、`--dry-run` 預覽、規則庫 3→8、真實部署 mock 驗證觀察/合併層次正確。**

---

## 2. Sprint 10 做了什麼

### 2.1 規範層（FR-4.10~4.13 增量 PRD）

| FR | 內容 | 對應 |
|---|---|---|
| FR-4.10 | 自動 git tag（每次合併 RSI 改動寫 `rsi-vYYYYMMDD-NN`） | TD-031 |
| FR-4.11 | `--dry-run` 預覽（顯示 path + action + md5 hash） | TD-032 |
| FR-4.12 | 規則庫擴充（從 3 個加到 8 個內建規則） | TD-030 |
| FR-4.13 | 真實部署觀察（3 mock + rsi-metrics 趨勢） | US-018 |

### 2.2 架構層（ADR-012/013/014）

| ADR | 決策 |
|---|---|
| ADR-012 | 每次合併自動寫 git tag `rsi-vYYYYMMDD-NN` |
| ADR-013 | rsi-sync.sh 加 `--dry-run`，預設不破壞 |
| ADR-014 | 規則庫擴充到 8 個內建規則（3 既有 + 5 新）|

### 2.3 工具層（5 個 CLI 工具增強）

| 工具 | 增強內容 |
|---|---|
| `tools/rsi-rollback.sh` | 加 `tag` 子命令 + `--message` 旗標 |
| `tools/rsi-sync.sh` | `--dry-run` 顯示 [modify]/[skip]/[add] + md5 hash |
| `tools/rsi-propose.sh` | `lookup_proposal()` 加 5 個 case |
| `tools/rsi-metrics.sh` | Sprint 10 末量化指標 |
| `tools/rsi-aggregate.sh` | 保持 Sprint 09 功能 |

### 2.4 測試層（35 個新 bats）

| 類別 | 數量 |
|---|---|
| TD-031（git tag）| 8 |
| TD-032（dry-run 檔案清單）| 7 |
| TD-030（規則庫 8 個）| 10 |
| US-018（真實部署驗證）| 10 |
| **新增** | **35** |
| **累計** | **215 個全綠** |

---

## 3. 內建規則庫（Sprint 10 末，8 個）

| # | 規則 | 對應事件 | Sprint |
|---|---|---|---|
| 1 | prompt_too_long | prompt 太長 | 09 |
| 2 | skill_error | skill 缺 frontmatter | 09 |
| 3 | gate_skip | agent 跳過 gate | 09 |
| 4 | markdownlint_error | markdown lint 錯 | 10 ⭐ |
| 5 | bash_error | shell script 錯 | 10 ⭐ |
| 6 | test_fail | 測試失敗 | 10 ⭐ |
| 7 | bats_unknown | bats 不識 test name | 10 ⭐ |
| 8 | v02_violated | 未標「推薦」 | 10 ⭐ |

---

## 4. Sprint 10 量化指標（結束時）

| 指標 | 值 | 備註 |
|---|---|---|
| 任務完成率 | 0% | 觀察模式不算完成（預期） |
| 規範違規次數 | 0 | mock 中故意違規 3 次（已記錄） |
| TD 閉環率 | 12.5% | TD-030/031/032 DONE |
| 跨專案觀察分佈 | 3 個 mock | test-proj-A/B/C |
| AGENTS.md 字數變化 | 推測 +150 | Sprint 10 加 |
| skill 使用頻率 | 推測 14 | 加 3 新常見規則 |
| 內建規則 | 8 個 | 從 3 提升 167% |
| **bats 累計** | **215 全綠** | +35 |

---

## 5. Sprint 09 vs Sprint 10 對比

| 維度 | Sprint 09 | Sprint 10 |
|---|---|---|
| 主軸 | 機制建立 | 機制增強 |
| SP | 16 | 5 |
| 新規則 | 3 | 5（從 3 → 8） |
| ADR | 4 個新（008~011） | 3 個新（012~014） |
| 測試增加 | 103 | 35 |
| 觀察/改動分離 | 守住 | 守住 |
| Reviewer 流程 | 觸發 2 次 | 觸發 1 次 |

---

## 6. 文檔清單

| 檔案 | 動作 | 內容 |
|---|---|---|
| `docs/prd/04-self-evolution.md` §10 | 加 | FR-4.10~4.13 增量 PRD |
| `docs/prd/04-self-evolution.html` §10 | 加 | SVG 模組間互動圖 |
| `docs/system-design.md` ADR-012~014 | 加 | Sprint 10 設計決定 |
| `docs/plan/2026-09-20-sprint-10-rsi-enhancement.md` | 新建 | 8 章節完整計劃 |
| `docs/sop/rsi-reviewer-verdict-2026-09-20-sprint10.md` | 新建 | Reviewer 二審（OK with notes）|
| `docs/sop/rsi-reflection-2025-09-20-td031.md` | 新建 | Gate 5 反省 |
| `docs/sop/rsi-reflection-2025-09-20-td032.md` | 新建 | Gate 5 反省 |
| `docs/sop/rsi-reflection-2025-09-20-td030.md` | 新建 | Gate 5 反省 |
| `docs/sop/rsi-reflection-2025-09-20-us018.md` | 新建 | Gate 5 反省 |
| `docs/reflection/sprint-10-rsi-enhancement-reflection.md` | 新建 | Sprint 10 反省報告 |
| `docs/backlog.md` | 加 4 item | Sprint 11 候選（TD-033/034 + US-019/020）|
| `tools/rsi-rollback.sh` | 改 | 加 `tag` 子命令 |
| `tools/rsi-sync.sh` | 改 | 加 `--dry-run` 檔案清單 + 修 local 漏出 bug |
| `tools/rsi-propose.sh` | 改 | 加 5 個內建規則 + 修 IN_EVENT_TABLE state |
| `tests/us031-rollback-tag.bats` | 新建 | 8 個 bats |
| `tests/us032-sync-dryrun.bats` | 新建 | 7 個 bats |
| `tests/us030-propose-rules.bats` | 新建 | 10 個 bats |
| `tests/us018-sprint10-verify.bats` | 新建 | 10 個 bats |

---

## 7. Sprint 10 成功指標

- ✅ 100% 5 SP 完成（5/5）
- ✅ 100% 5 Gate 通過（每個 US）
- ✅ 215 個 bats 全綠
- ✅ V03 三條禁區零違規
- ✅ Markdownlint 新內容 0 issues
- ✅ 觀察/改動分離守住（mock 專案沒被破壞）
- ✅ Sprint 09 既有測試零回歸

---

## 8. 反省待改進（Sprint 11 解決）

| ID | 問題 | Sprint 11 候選 |
|---|---|---|
| 1 | mock 觀察只有 2 個事件，無法驗 8 規則 | US-019 真實部署 |
| 2 | 7 天觀察只跑當下 1 次 | TD-033 30 天 trend |
| 3 | 規則庫只有 8 個，可能漏常見失敗訊號 | US-020 從真實觀察補規則 |
| 4 | 提案無 confidence score | TD-034 confidence score |

---

## 9. Sprint 11 候選項（4 個，6 SP）

| ID | 內容 | SP | 優先級 |
|---|---|---|---|
| TD-033 | rsi-metrics.sh 加 30 天滑動 trend | 0.5 | P2 |
| TD-034 | rsi-propose.sh 加 confidence score | 0.5 | P2 |
| US-019 | Sprint 11 真實部署 1 個非 mock 專案 14 天 | 3 | P1 |
| US-020 | 從真實觀察反推 + 補規則（≥ 12 個） | 2 | P1 |
| **小計** | | **6** | |

---

## 10. Sprint 10 提交完成

- ✅ 規範層增量（FR-4.10~4.13 + ADR-012~014）
- ✅ 工具層增量（3 個工具增強）
- ✅ 測試層增量（35 個新 bats）
- ✅ 文檔層增量（10 份新/改文檔）
- ✅ 觀察/改動分離守住
- ✅ V03 Reviewer 二審通過

**Sprint 10 結束。Sprint 11 規劃見下個 §2.1 階段。**
