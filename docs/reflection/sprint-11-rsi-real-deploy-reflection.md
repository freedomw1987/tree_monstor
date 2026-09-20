# Sprint 11 反省 — RSI 真實部署 + 規則庫擴充（2026-09-20）

> **Sprint**：Sprint 11
> **主軸**：真實部署 + 規則庫擴充
> **SP**：6/6（100%）
> **bats**：12 新加（5+5+7+7=24）+ 60 全綠

---

## 1. Sprint 目標達成

| 目標 | 結果 |
|---|---|
| TD-033：rsi-metrics 加 30 天 trend | ✅ DONE（5 bats）|
| TD-034：rsi-propose 加 confidence score | ✅ DONE（5 bats）|
| US-019：真實部署小型 web app 14 天 | ✅ DONE（7 bats + 部署指南）|
| US-020：從觀察反推 + 補規則 8→12 | ✅ DONE（7 bats + 規則擴充日誌）|

## 2. 6 維度檢查

### 2.1 UX/UI 一致性 ✅

- 部署指南 10 章節結構清晰
- 4 個 Gate 5 反省文檔格式一致
- 規則擴充日誌與既有 sprint 文檔一致

### 2.2 RWD 響應式設計 N/A

- 純 CLI 工具與 markdown 文檔，無 RWD 需求

### 2.3 技術債 ⚠️ 1 個

| ID | 問題 | 嚴重度 |
|---|---|---|
| TD-035 | `local -a arr=()` 在 macOS bash 3.2 + set -u 報 unbound → 改用 string 累加 | 🟡 中 |
| TD-036 | `set -u` 對 local 變量嚴格，trend_history 需 `set +u` 暫時放寬 | 🟡 中 |

兩個技術債在 Sprint 11 過程中發現並繞過，未根除。

### 2.4 可維護性 ✅

- 4 個工具檔案結構一致（set + LC_ALL + flag parser + usage）
- 12 個規則庫 `lookup_proposal()` case 統一格式
- 8 個本 sprint 新加文件都有 frontmatter / 章節 / AC

### 2.5 測試覆蓋率 ✅

- 12 新加 bats（TD-033×5 + TD-034×5 + US-019×7 + US-020×7）
- 60 個 sprint 10/11 累計全綠
- AC 對齊率 100%（每個 AC 至少 1 個 bats 驗證）

### 2.6 需求對齊 ✅

| FR | 對應 | 狀態 |
|---|---|---|
| FR-4.14 | TD-033 30 天 trend | ✅ |
| FR-4.15 | TD-034 confidence | ✅ |
| FR-4.16 | US-019 真實部署 | ✅ |
| FR-4.17 | US-020 規則庫 8→12 | ✅ |

## 3. 重要發現

### 3.1 TDD 假綠教訓（Sprint 11 學到最重要的）

- **問題**：3 次測試用 grep「事件名」或 grep -c 計數 → 假綠
- **修法**：改驗「修法描述」（「雙向跳脫」「frontmatter」「timeout」「conventional」）
- **教訓**：TDD 測試要驗「行為」不要驗「名字」，且用「雙驗證」（肯定 + 否定）
- **影響**：Sprint 12 起，每個 bats 都要通過「假綠自審」

### 3.2 macOS bash 3.2 set -u 相容性

- `local -a arr=()` 在 set -u 下報 unbound
- 修法：用 `local arr=""` + `arr="$arr val"`
- 教訓：macOS bash 3.2 對 array + set -u 不穩，string 累加更可靠

### 3.3 US-019 cron 自動接手

- 14 天觀察由 cron 自動跑（不必人守）
- 部署指南 §3.4 寫明 cron 設定
- 中間點（第 7 天）跑 1 次 trend，第 14 天寫 review

## 4. Sprint 10 vs Sprint 11 對比

| 指標 | Sprint 10 末 | Sprint 11 末 | 變化 |
|---|---|---|---|
| SP | 5 | 6 | +1 |
| bats 累計 | 215 | 235+ | +20 |
| 工具 subcommand | 8 | 9（＋trend_history） | +1 |
| 規則庫 | 8 | 12 | +4 |
| FR 累計 | 13 | 17 | +4 |
| 真實觀察專案 | 0（mock）| 1（部署指南 + cron） | +1 |
| 觀察天數 | 1（mock）| 14（cron） | +13 |

## 5. Sprint 12 候選 Backlog Item

### 5.1 User Story（功能性）

| ID | 標題 | SP | 推薦 |
|---|---|---|---|
| US-021 | 真實觀察 14 天後回顧 + 從 cron.log 反推新規則 | 3 | ✅ |
| US-022 | rsi-metrics 加回歸警告（觀察數下降 30%+ 觸發告警） | 2 | ✅ |

### 5.2 Technical Debt（技術債）

| ID | 標題 | SP | 推薦 |
|---|---|---|---|
| TD-035 | 修 `local -a arr=()` 在 set -u 下報 unbound | 0.5 | ⏳ |
| TD-036 | trend_history 函式加 `set -u` 隔離層 | 0.5 | ⏳ |
| TD-037 | rsi-propose 加 `--output-format json` 給機器讀 | 1 | 🟡 |

### 5.3 Spike（研究）

| ID | 標題 | SP | 推薦 |
|---|---|---|---|
| SP-005 | 研究「跨專案規則去重」：兩個 mock 專案觀察到同類事件如何合併 | 2 | 🟡 |

## 6. Sprint 12 推薦規劃

### 6.1 主軸（推薦）

#### RSI 真實部署回顧 + 回歸警告

包含：
- US-021（真實觀察 14 天回顧）
- US-022（回歸警告）
- TD-035（修技術債，bundle with US-021）

### 6.2 預估 SP

| ID | SP |
|---|---|
| US-021 | 3 |
| US-022 | 2 |
| TD-035 | 0.5 |
| **小計** | **5.5** |

## 7. Sprint 11 文檔清單

| 檔案 | 用途 | markdownlint |
|---|---|---|
| `docs/plan/2026-09-20-sprint-11-rsi-real-deploy.md` | §2.1 規劃 | ✅ 0 issues |
| `docs/prd/04-self-evolution.md` §11 | §2.2 設計增量 | ✅ 0 issues |
| `docs/system-design.md` ADR-015~017 | §2.2 設計增量 | ✅ 0 issues |
| `docs/sop/rsi-reviewer-verdict-2026-09-20-sprint11.md` | Reviewer 二審 | ✅ |
| `docs/sop/rsi-reflection-2026-09-20-td033.md` | Gate 5 反省 | ✅ 0 issues |
| `docs/sop/rsi-reflection-2026-09-20-td034.md` | Gate 5 反省 | ✅ 0 issues |
| `docs/sop/rsi-reflection-2026-09-20-us019.md` | Gate 5 反省 | ✅ 0 issues |
| `docs/sop/rsi-reflection-2026-09-20-us020.md` | Gate 5 反省 | ✅ 0 issues |
| `docs/sop/rsi-rule-extension-2026-09-20.md` | 規則庫擴充日誌 | ✅ 0 issues |
| `docs/deploy/2026-09-20-real-webapp-deploy-guide.md` | 部署指南 | ✅ |

## 8. Sprint 11 待批准

請用戶批准 §2.4 反省，進 §2.5 提交。
