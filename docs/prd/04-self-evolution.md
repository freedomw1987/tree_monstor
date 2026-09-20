# PRD-04 — Self-Evolution（RSI 機制）

> **對應 Backlog**：[US-011~017 + TD-022](../../backlog.md)
> **模組**：M4 — Self-Evolution (RSI)
> **Story Point**：21 SP（分 2 個 Sprint 跑：Sprint 09 16 SP + Sprint 10 5 SP）
> **建立日期**：2025-09-20

---

## 1. 模組目標（Module Goal）

讓 tree_monstor 具備「**跨專案學習、單一源進化**」能力：

- 裝在專案裡的 tree_monstor **只觀察不動 SOP**
- 裝回源 repo 才聚合 + 提案 + 改 SOP
- 改完一次同步給所有已裝專案（rsi-sync.sh）

**核心精神**：平衡「學習價值」與「避免版本碎片化」。一處改進、全域受益。

---

## 2. 功能清單（Functional Requirements）

### FR-4.1：觀察模式（裝在專案裡）

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-4.1.1 | 觸發點 | 任務完成時自動觸發（Gate 5 RSI gate） |
| FR-4.1.2 | 寫入位置 | `~/.tree-monstor/observations/{project-id}/{YYYY-MM-DD}.json` |
| FR-4.1.3 | 記錄內容 | gate_results / skills_used / failure_signals / duration |
| FR-4.1.4 | **絕不** | 動 SOP / 寫 raw 對話 / 寫 code 片段 / 寫明文路徑 |
| FR-4.1.5 | Schema 強制 | JSON Schema Draft 07 白名單 + 黑名單驗證 |
| FR-4.1.6 | 匿名化 | `project_id` = SHA256(path).substring(0,8) |

### FR-4.2：聚合模式（裝回源 repo）

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-4.2.1 | 觸發點 | 用戶打 `/reflect` |
| FR-4.2.2 | 收集 | 掃 `~/.tree-monstor/observations/`，跨專案所有觀察 |
| FR-4.2.3 | 去重 | 相同 gate 失敗類型聚合 |
| FR-4.2.4 | 統計 | 每個信號的頻率、影響專案數 |
| FR-4.2.5 | 排序 | 按影響專案數 + 出現頻率 |
| FR-4.2.6 | 產出 | `docs/sop/rsi-aggregated-{YYYY-MM-DD}.md` |

### FR-4.3：提案模式（裝回源 repo）

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-4.3.1 | 觸發點 | 聚合完成後自動 / 用戶 `/propose` |
| FR-4.3.2 | 映射 | 把聚合結論映射成「具體 PR diff」 |
| FR-4.3.3 | 必附證據 | 每個 diff 附觀察 JSON 編號 + 觸發情境 |
| FR-4.3.4 | 必附影響 | 每個 diff 附「影響專案數」 |
| FR-4.3.5 | 必附 rollback | 每個 diff 附一鍵回滾指令 |
| FR-4.3.6 | 產出 | `docs/sop/rsi-proposals-{YYYY-MM-DD}.md`（diff 清單） |

### FR-4.4：Reviewer 二審（V03 紀律強制）

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-4.4.1 | 觸發點 | 提案完成後自動 |
| FR-4.4.2 | 工具 | `dev-checker-loop` skill（Reviewer subagent） |
| FR-4.4.3 | 風險分級 | 🟢 低（可自動）/ 🟡 中（快速 review）/ 🔴 高（深度討論） |
| FR-4.4.4 | 一致性檢查 | AGENTS.md / gates.json / handbook 跨 SOP 一致性 |
| FR-4.4.5 | 禁止範圍 | Reviewer **不可**提對 AGENTS.md §1 萬事原則 / §1.5 提問紀律 / §2.3 Gate 規範的修改建議 |
| FR-4.4.6 | 產出 | `docs/sop/rsi-reviewer-verdict-{YYYY-MM-DD}.md` |

### FR-4.5：用戶批准（必經人手）

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-4.5.1 | 並呈 | 用戶收到「diff + reviewer verdict」兩者並呈 |
| FR-4.5.2 | 批准權 | 用戶有權批准 / 退回 / 修改後再批 |
| FR-4.5.3 | 跳過 Reviewer | 用戶可明確說「跳過 Reviewer」直接批准 |
| FR-4.5.4 | git tag | 批准後自動寫 `rsi-vYYYYMMDD-NN` tag |
| FR-4.5.5 | 記錄 | 寫進 `docs/sop/rsi-log.md` |

### FR-4.6：合併 + 一鍵回滾

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-4.6.1 | 合併 | git commit + tag |
| FR-4.6.2 | 列出可回滾 | `rsi-rollback.sh --list` |
| FR-4.6.3 | 回滾到指定 | `rsi-rollback.sh --to rsi-v20250921-01` |
| FR-4.6.4 | 從 log 找 | 從 `docs/sop/rsi-log.md` 找對應 diff |

### FR-4.7：同步到所有已裝專案

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-4.7.1 | 觸發點 | install.sh --enable-rsi 跑完後自動 |
| FR-4.7.2 | 範圍 | 把新版 `~/.pi/sop/` 同步到所有已裝專案位置 |
| FR-4.7.3 | 不覆蓋 | 本地用戶 override 不被覆蓋 |
| FR-4.7.4 | 工具 | `tools/rsi-sync.sh` |

### FR-4.8：量化指標

| ID | 指標 | 計算來源 |
| --- | --- | --- |
| FR-4.8.1 | 任務完成率 | gates.json + 對話日誌 |
| FR-4.8.2 | 規範違規次數 | regex 對對話日誌 |
| FR-4.8.3 | TD 閉環率 | backlog.md |
| FR-4.8.4 | 跨專案觀察分佈 | `~/.tree-monstor/observations/` |
| FR-4.8.5 | AGENTS.md 字數變化 | git log |
| FR-4.8.6 | skill 使用頻率 | 對話日誌 |

### FR-4.9：install.sh 整合

| ID | 功能 | 說明 |
| --- | --- | --- |
| FR-4.9.1 | 新旗標 | `--enable-rsi`（預設）/ `--disable-rsi` |
| FR-4.9.2 | 部署 skill | 對應部署 `skills/sop-evolver/` |
| FR-4.9.3 | 初始化目錄 | 自動建 `~/.tree-monstor/observations/` |
| FR-4.9.4 | 卸載 | `--uninstall` 對應清理 + 詢問是否刪 `~/.tree-monstor/` |

---

## 3. SOP Gate 5（RSI Gate）

在 gates.json 加 Gate 5：

```json
{
  "id": "gate-5",
  "name": "RSI gate",
  "trigger_skill": "sop-evolver",
  "pass_criteria": [
    "觀察記錄已寫入（如果是專案任務）",
    "Reviewer subagent verdict 已產生",
    "用戶已批准或明確說「跳過 Reviewer」"
  ],
  "required_evidence": [
    "反省報告路徑",
    "改進提案 diff",
    "Reviewer verdict 路徑",
    "用戶批准訊息截錄"
  ],
  "fail_action": "不可合併 diff；用戶明確說『跳過 Reviewer』才可",
  "mandatory_phrase": "依 gates.json 規範，Gate 5 (RSI) 需要：反省報告 + 改進提案 diff + Reviewer 二審 verdict + 用戶批准截錄",
  "notes": "RSI 是高風險決策，不可自動修錯（如拒絕需求）；用戶明確說「跳過 Reviewer」是可接受的明示豁免。",
  "remediation": {
    "strategy": "ask_user",
    "description": "RSI 涉及 SOP 改動，誤修成本高（破壞多專案）；agent 停下來問用戶，不自動合併或修改 diff。"
  }
}
```

---

## 4. 安全規則（不可違反，4 條）

1. **觀察/改動分離**：裝在專案裡的 tree_monstor **只能觀察**，不能改 SOP
2. **匿名化**：observation 只記結構化信號，不收 raw 對話 / code / 路徑
3. **Reviewer 二審必經**（V03）：所有 SOP 改動提案都走 dev-checker-loop 二審
4. **一鍵回滾**：每次合併自動寫 git tag，`rsi-rollback.sh` 從 rsi-log.md 找 diff 還原

---

## 5. 觀察記錄 Schema（白名單，強制）

```json
{
  "task_id": "uuid-v4",
  "project_id": "a3f7b2c1",
  "timestamp": "2025-09-21T14:30:00Z",
  "gate_results": {
    "gate-1-tdd": "pass",
    "gate-2-lint": "pass",
    "gate-3-regression": "fail",
    "gate-4-reviewer": "pass"
  },
  "skills_used": ["dav-planner", "tdd-test-writer"],
  "failure_signals": [
    {"gate": "gate-3-regression", "type": "test_timeout", "count": 2}
  ],
  "duration_seconds": 145
}
```

**黑名單（被拒絕）**：`raw_conversation` / `code_snippets` / `file_paths` / `env_values` / `git_messages`

---

## 6. Story Point 拆分

| ID | 子任務 | SP | Sprint |
| --- | --- | --- | --- |
| US-011 | 建立 sop-evolver skill（5 個檔案） | 5 | Sprint 09 |
| US-012 | 加 Gate 5 到 gates.json + Schema | 1 | Sprint 09 |
| US-013 | 寫 §2.8 handbook + AGENTS.md 引用 | 1.5 | Sprint 09 |
| US-014 | 寫 rsi-metrics.sh + rsi-rollback.sh | 2 | Sprint 09 |
| US-015 | 寫 rsi-aggregate.sh + rsi-propose.sh + rsi-sync.sh | 2 | Sprint 09 |
| US-016 | install.sh 加 --enable-rsi 旗標 | 1 | Sprint 09 |
| US-017 | Sprint 09 真實驗證 | 3 | Sprint 09 |
| TD-022 | 觀察記錄格式設計（安全） | 0.5 | Sprint 09 |
| TD-031 | rsi-rollback.sh 自動寫 git tag | 0.5 | Sprint 10 |
| TD-032 | rsi-sync.sh --dry-run 列出檔案清單 | 0.5 | Sprint 10 |
| TD-030 | 擴充 rsi-propose.sh 規則庫（加 5 個新規則） | 1 | Sprint 10 |
| US-018 | Sprint 10 真實部署驗證（7 天觀察） | 3 | Sprint 10 |
| **總計** | — | **21** | — |

---

## 7. 驗收標準（高層次）

- [ ] AC-1：`sop-evolver` skill 5 個檔案齊全，SKILL.md ≤ 150 行
- [ ] AC-2：裝在專案裡只能觀察、不能改 SOP（驗證：專案裡 `/evolve` 被拒絕）
- [ ] AC-3：裝回源 repo 跑 `/reflect`，自動收集 `~/.tree-monstor/observations/`
- [ ] AC-4：聚合分析後產出「跨專案改進提案」，每個附「影響專案數」
- [ ] AC-5：所有 SOP 改動以 diff 形式呈現，**未經批准絕不合併**
- [ ] AC-6：`rsi-rollback.sh` 一鍵回滾到任一歷史版本
- [ ] AC-7：`rsi-metrics.sh` 6 個量化指標
- [ ] AC-8：install.sh 加 `--enable-rsi` / `--disable-rsi` 旗標
- [ ] AC-9：所有 AC 有對應 bats 測試（≥ 15 個，含安全測試）
- [ ] AC-10：通過 5 個 Gate（含 Gate 5）

---

## 8. 風險與緩解

| 風險 | 機率 | 影響 | 緩解 |
| --- | --- | --- | --- |
| 觀察意外洩漏敏感資料 | 中 | 高 | observation 結構強制 + 黑名單驗證 |
| 一處改 SOP破壞多專案 | 中 | 高 | rsi-sync 不覆蓋本地 + git tag + 一鍵回滾 |
| 提案 hallucinate 出虛假問題 | 高 | 中 | 提案必須附「證據」（觀察 JSON 編號） |
| RSI 過度觸發 | 低 | 低 | 觀察自動累積，聚合隨時可跑 |
| 用戶忘了裝回源 repo 聚合 | 中 | 中 | rsi-metrics 每週提醒「N 個觀察待聚合」 |

---

## 9. 相關文件

- 設計計劃：[`docs/plan/2025-09-20-rsi-mechanism.md`](../plan/2025-09-20-rsi-mechanism.md)
- 系統設計：[`docs/system-design.md` §4](../system-design.md)
- 對應 Backlog：[`docs/backlog.md` US-011~017 + TD-022](../../backlog.md)

---

## 10. Sprint 10 增量 PRD（2026-09-20）

> **Sprint**：10
> **主軸**：RSI 機制增強
> **預估總 SP**：5 SP

### 10.1 FR-4.10 自動 git tag（TD-031，0.5 SP，P1）

- **描述**：合併 RSI 改動時，自動寫 git tag `rsi-vYYYYMMDD-NN`
- **使用場景**：
  - 開發者合併 RSI PR 時，`rsi-rollback.sh tag --message "fix: ..."` 自動寫 tag
  - `rsi-rollback.sh list` 顯示所有 `rsi-v*` tag
  - `rsi-rollback.sh --target <tag>` 一鍵回滾
- **驗收**：
  - tag 格式 `rsi-vYYYYMMDD-NN`，`NN` 為當天序號 01, 02, ...
  - 自動計算當天最大序號 + 1
  - 與 git 工作樹狀態無關（只依賴既有 tag）

### 10.2 FR-4.11 dry-run 預覽（TD-032，0.5 SP，P2）

- **描述**：`rsi-sync.sh --dry-run` 列出將同步的檔案清單（path + 動作 + hash 對比）
- **使用場景**：
  - 使用者 sync 前先 `--dry-run --output report.md`，看到會改哪些檔案
  - 確認無誤後 `--apply` 真正執行
- **驗收**：
  - 對每個將同步檔案顯示：path / 動作（add/modify/delete/skip）/ 源頭 md5 / 本地 md5
  - 預設不破壞（dry-run 模式必須明示 `--apply` 才寫）
  - markdown table 結構化輸出

### 10.3 FR-4.12 規則庫擴充（TD-030，1 SP，P2）

- **描述**：`rsi-propose.sh` 內建規則從 3 個擴充到 ≥ 8 個
- **新增規則**：
  - `markdownlint_error`（AGENTS.md / handbook markdownlint 違規）
  - `bash_error`（shellcheck 報錯或 set -e 觸發）
  - `test_fail`（bats 測試失敗）
  - `bats_unknown`（test name 編碼錯誤 unknown）
  - `v02_violated`（一次問多個問題，違反 V02）
- **每個規則**：
  - 對應 1 個修改提案（檔案路徑 + 改動內容）
  - ≥ 1 個 bats 測試
  - ≥ 1 個 mock observation 觸發

### 10.4 FR-4.13 真實部署觀察（US-018，3 SP，P1）

- **描述**：部署觀察模式到 3 個 mock 專案，跑 7 天後看量化指標
- **使用場景**：
  - `tests/rsi-deployment-mock.sh` 建 3 個 mock 專案 + 模擬 7 天使用
  - 每天自動寫 1 個 observation JSON（含真實的 gate_results）
  - 7 天後跑 rsi-aggregate.sh / rsi-propose.sh / rsi-metrics.sh
- **驗收**：
  - 部署 RSI 觀察模式到 3 個 mock
  - 跑 7 天，每天自動寫 observation JSON
  - 7 天後 rsi-aggregate.sh / rsi-propose.sh / rsi-metrics.sh 全跑通
  - 寫 1 份 7 天觀察報告
  - 建議 Sprint 11 是否加規則

### 10.5 Sprint 10 模組間互動（FR-4.10/4.11/4.12/4.13）

```
M4 ──→ TD-031/032/030 ──→ FR-4.10/4.11/4.12/4.13 ──→ M4 工具層（rsi-*）
                                              ↓
                                         FR-4.10 真實部署
                                              ↓
                                    M1↔M2↔M4 觀察/同步流程
```

### 10.6 Sprint 10 風險

| 風險 | 機率 | 影響 | 緩解 |
|---|---|---|---|
| TD-031 git tag 序號衝突 | 低 | 中 | grep 找當天最大序號 + 1 |
| TD-032 hash 計算影響效能 | 中 | 中 | 用 md5（足夠）而非 sha256 |
| TD-030 規則庫擴充打破既有 | 中 | 高 | 既有 3 規則測試必過 + 加 5 個新測試 |
| US-018 7 天太長 | 高 | 中 | Sprint 10 結束時可選縮成 3 天 |

---

## 11. Sprint 11 增量 PRD（2026-09-20）

### 11.1 背景

Sprint 09/10 都用 mock 專案驗證，沒有真實跨專案訊號，且 8 個內建規則可能漏常見失敗類型。Sprint 11 推進到真實部署 + 規則庫擴充。

### 11.2 用戶故事（4 個，6 SP）

#### FR-4.14：rsi-metrics.sh 加 30 天滑動 trend

- 對應：TD-033
- AC：
  - `rsi-metrics.sh trend_history` 子命令
  - 顯示 30 天滑動視窗
  - ≥ 4 個指標有 trend（completion_rate / td_close_rate / violation_count / skill_usage）
  - 趨勢用 sparkline（`▁▂▃▄▅▆▇█` 8 級字符）
  - ≥ 5 個 bats 測試

#### FR-4.15：rsi-propose.sh 加 confidence score

- 對應：TD-034
- AC：
  - 計算每個提案的 confidence（0~1）
  - ≥ 0.7 列為主要提案
  - < 0.7 列為「需人工確認」
  - confidence = `min(1.0, freq × 0.3 + projects × 0.2 + 1)`
  - ≥ 5 個 bats 測試

#### FR-4.16：真實部署 1 個輕量小型 web app 14 天

- 對應：US-019
- AC：
  - 選 1 個輕量小型 web app（如 Express.js / Flask / Sinatra）
  - `install.sh --enable-rsi` 裝 RSI 觀察模式
  - 每日 cron 跑 `rsi-metrics.sh`
  - 觀察 14 天
  - 結束後跑 `trend_history` 看 14 天趨勢
  - 觀察/改動分離守住
  - ≥ 8 個 bats 測試

#### FR-4.17：從 US-019 真實觀察反推 + 補規則（8→12+）

- 對應：US-020
- AC：
  - 分析 US-019 14 天 observation
  - 找出 ≥ 4 個新常見事件
  - 加 4 個新規則到 `lookup_proposal()`
  - ≥ 8 個 bats 測試

##### Sprint 11 US-020 新增規則（8→12）

| # | 規則 | 說明 | 修法 |
| --- | --- | --- | --- |
| 9 | circular_ref | 文檔循環跳脫跳針 | 修 AGENTS.md <-> handbook 雙向跳脫 |
| 10 | skill_timeout | skill 讀取逾時 | 減少 frontmatter 字段、簡化 instructions |
| 11 | agent_hang | agent 卡住無進度 | 加 timeout 機制 |
| 12 | commit_no_msg | commit 不符合 conventional | commit 自動補訊息 |

**累計規則庫**（Sprint 09 + 10 + 11）：12 個規則

### 11.3 順序

```
TD-033 ──┐
         ├──► US-019 ──► US-020
TD-034 ──┘
```

### 11.4 §6 SP 拆分表（更新 Sprint 11）

| Sprint | US/TD | SP |
|---|---|---|
| Sprint 09 | US-011~017 + TD-022 | 16 |
| Sprint 10 | TD-031/032/030 + US-018 | 5 |
| **Sprint 11** | **TD-033/034 + US-019/020** | **6** |
| **總計** | — | **27** |

### 11.5 Sprint 12 增量 PRD（2026-09-20）

#### 11.5.1 背景

Sprint 11 部署指南完成（小型 web app + cron 自動 14 天），但有兩個缺口：

1. **14 天觀察跑完後沒人回顧** — cron.log 累積但沒分析機制
2. **RSI 是「被動觀察」不是「主動監控」** — 觀察數下降 30% 不會告警

Sprint 12 把 RSI 從「被動觀察」進化到「主動監控」。

#### 11.5.2 用戶故事（3 個，5.5 SP）

| ID | 標題 | 優先級 | SP | 對應 FR |
|---|---|---|---|---|
| US-021 | 真實觀察 14 天後回顧 + 從 cron.log 反推新規則 | P1 | 3 | FR-4.18 |
| US-022 | rsi-metrics 加回歸警告（觀察數下降 30%+ 觸發告警） | P2 | 2 | FR-4.19 |
| TD-035 | 修 `local -a arr=()` 在 `set -u` 下報 unbound | P2 | 0.5 | FR-4.20 |
| **小計** | | | **5.5** | |

#### 11.5.3 詳細 AC

**US-021（3 SP）**：

- [ ] 跑 `rsi-aggregate.sh` 聚合 14 天 cron.log 觀察
- [ ] 分析 `trend_history --days 14` 趨勢
- [ ] 識別是否有第 13、14 個規則候選
- [ ] 寫 `docs/review/2026-10-04-rsi-real-deploy-result.md`
- [ ] ≥ 6 個 bats 測試
- [ ] markdownlint 0 issues

**US-022（2 SP）**：

- [ ] 加 `tools/rsi-alert.sh` 工具
- [ ] 觀察數下降 30%+ 觸發告警
- [ ] 設基線（≥ 0.7 confidence 的歷史平均值）
- [ ] 告警輸出到 stderr + log file
- [ ] ≥ 5 個 bats 測試
- [ ] markdownlint 0 issues

**TD-035（0.5 SP）**：

- [ ] 全 sprint 10/11 工具改用 string 累加
- [ ] ≥ 4 個 bats 驗證
- [ ] markdownlint 0 issues

#### 11.5.4 Sprint 12 FR 拆分表（更新）

| Sprint | US/TD | SP |
|---|---|---|
| Sprint 09 | US-011~017 + TD-022 | 16 |
| Sprint 10 | TD-031/032/030 + US-018 | 5 |
| Sprint 11 | TD-033/034 + US-019/020 | 6 |
| **Sprint 12** | **US-021/022 + TD-035** | **5.5** |
| **總計** | — | **32.5** |

#### 11.5.5 §11 Sprint 12 設計原則

1. **主動監控原則**（新增）：RSI 不只看歷史，還要看當下，觀察數下降代表部署失效
2. **14 天回顧原則**（新增）：cron.log 跑滿 14 天必有人類回顧，產出反思
3. **基線設定原則**（新增）：告警閾值用歷史 ≥ 0.7 confidence 平均值，避免靜默設定
4. **技術債必清原則**（強化）：Sprint 11 留下的 TD-035 必在 Sprint 12 開頭清掉，避免後續 sprint 受影響

### 11.6 Sprint 13 增量 PRD（2026-09-20）

#### 11.6.1 背景

Sprint 09-12 讓 RSI 達到「觀察 → 聚合 → 趨勢 → 回顧 → 警告 → 反推 → 改動」完整閉環。但有兩個實作缺口：

1. **rsi-propose 只能輸出 text** — Agent 無法解析、cron 無法套用
2. **部署是手動** — 手動部署 30 分鐘、容易跳步

Sprint 13 補上「JSON 化」+「1 鍵部署」+「dry-run 預覽」三個能力。

#### 11.6.2 用戶故事（3 個 + 1 spike，6 SP）

| ID | 類型 | 標題 | 優先級 | SP | 對應 FR |
|---|---|---|---|---|---|
| TD-037 | TD | rsi-propose 加 `--output-format json` | P3 | 1 | FR-4.21 |
| US-023 | US | rsi-deploy.sh 自動部署小型工具 | P3 | 2 | FR-4.22 |
| US-024 | US | rsi-rollback 加 dry-run | P3 | 1 | FR-4.23 |
| SP-005 | SP | 跨專案規則去重研究 | P3 | 2 | FR-4.24 |
| **小計** | | | | **6** | |

#### 11.6.3 詳細 AC

**TD-037（1 SP）**：

- [ ] 加 `--output-format json` 旗標
- [ ] 輸出結構化 JSON（含 rules + confidence + evidence）
- [ ] 既有 `text` 格式保留
- [ ] ≥ 3 個 bats 驗證
- [ ] markdownlint 0 issues

**US-023（2 SP）**：

- [ ] 建新工具 `tools/rsi-deploy.sh`
- [ ] 1 鍵部署小型 web app（含 Node.js / Python 任一）
- [ ] 自動加 cron（每日 metrics + alert）
- [ ] 自動跑 `rsi-aggregate.sh` 驗證部署
- [ ] ≥ 4 個 bats
- [ ] markdownlint 0 issues

**US-024（1 SP）**：

- [ ] 加 `--dry-run` 旗標到 rsi-rollback.sh
- [ ] 列出將被回滾的變更（檔案清單 + commit hash）
- [ ] 不實際執行 git reset / tag delete
- [ ] ≥ 3 個 bats
- [ ] markdownlint 0 issues

**SP-005（2 SP）**：

- [ ] 寫 `docs/research/2026-09-20-cross-project-rule-dedup.md`
- [ ] 3 個 mock 測試（同類事件在 2 個專案都出現）
- [ ] 結論：是否要合併、如何合併、合併後的規則庫結構
- [ ] ≥ 3 個 bats

#### 11.6.4 Sprint 13 FR 拆分表

| Sprint | US/TD | SP |
|---|---|---|
| Sprint 09 | US-011~017 + TD-022 | 16 |
| Sprint 10 | TD-031/032/030 + US-018 | 5 |
| Sprint 11 | TD-033/034 + US-019/020 | 6 |
| Sprint 12 | US-021/022 + TD-035 | 5.5 |
| **Sprint 13** | **TD-037 + US-023/024 + SP-005** | **6** |
| **總計** | — | **38.5** |

#### 11.6.5 Sprint 13 設計原則

1. **JSON 標準化原則**（新增）：所有產出類工具應有 text + json 兩種輸出格式，讓 Agent / cron 可解析
2. **1 鍵部署原則**（新增）：重複性高、易出錯的手動步驟必有 1 鍵部署工具
3. **dry-run 預覽原則**（新增）：所有破壞性操作必有 dry-run，先看再動
4. **跨專案去重原則**（新增）：同類事件在多個專案出現時，必須評估是否合併（規則庫不爆）
