# US-007 設計計劃 — 把 §2.3 Gate 邏輯抽成 JSON

**對應 Backlog**：[US-007](../backlog.md#us-007把-23-gate-邏輯抽成-docssopgatesjsonsingle-source-of-truth2025-08-21)
**日期**：2025-08-21
**狀態**：待用戶審核
**作者**：Agent（依 SOP §2.2）
**範圍**：M2 — SOP Infrastructure（新模組）

---

## 1. 目標

把 AGENTS.md §2.3 的「4 個 Gate」邏輯抽成 `docs/sop/gates.json`，作為 single source of truth；AGENTS.md §2.3 改為引用 JSON；install.sh 同步把 gates.json 部署到 Pi Agent / Claude Code 的對應位置。

### 為什麼這是獨立模組（M2）

| 模組 | 範圍 | 現況 |
|---|---|---|
| **M1 — Installer & Distribution** | install.sh / 路徑處理 / 卸載 | 已完成 Sprint 01 + 02 計劃中 |
| **M2 — SOP Infrastructure**（新） | AGENTS.md SOP / Gate 規範 / 部署到 Pi/Claude | 本次新建 |

M2 跟 M1 在「部署」維度有關聯（install.sh 要改），但「規範內容」是獨立的 — 規範本身不該被 install 邏輯綁死。

---

## 2. 用戶故事

### US-007：把 §2.3 Gate 邏輯抽成 `docs/sop/gates.json`

> **作為** tree_monstor 的維護者，
> **我想要** 把 AGENTS.md §2.3「4 個 Gate」的定義抽成 `docs/sop/gates.json`，
> **以便** 強制 Agent 在每個 Gate 留下證據（測試 output / lint output / 截圖），防止「跳過 gate」或「假報通過」；且未來改 Gate 只需改 JSON 一處。

### AC（10 條）

**結構驗收（必通過）**：

- [ ] AC-1：`docs/sop/gates.json` 存在，含 4 個 Gate 定義（id / name / trigger_skill / pass_criteria / required_evidence / fail_action）
- [ ] AC-2：`docs/sop/gates.schema.json` 存在，符合 JSON Schema Draft 2020-12
- [ ] AC-3：使用 ajv 對 `gates.json` 跑驗證，結果 **0 錯誤**
- [ ] AC-4：AGENTS.md §2.3 改為引用 `./sop/gates.json`，不再列 Gate 細節表格
- [ ] AC-5：`install.sh` 增加邏輯：複製 `docs/sop/` 到目標位置的 `sop/` 子目錄（`~/.pi/sop/` 與 `~/.claude/sop/`）
- [ ] AC-6：`install.sh --dry-run` 正確顯示 gates.json 會被複製到目標位置
- [ ] AC-7：AGENTS.md 中對 gates.json 的引用路徑在 install 後位置一致（用 `./sop/gates.json` 相對路徑）

**行為驗收（必通過）**：

- [ ] AC-8：跑 1 個真實小型任務（如透過 `dav-skill-creater` 登記一個 1 SP 新 skill），Agent 在執行過程中**明確引用** `gates.json` 內容（例如在對話中貼出 JSON 內的 `required_evidence` 列表）
- [ ] AC-9：4 個 Gate（TDD / lint / regression / reviewer）全部觸發，且每個 Gate 都留有對應 `required_evidence` 指定的證據（測試 output / lint output / baseline diff / reviewer 原文）
- [ ] AC-10：執行日誌 / deliverable 中可看到 Agent 引用 JSON 的軌跡（例如對話中出現「依 gates.json 規範，Gate X 需要...」）

---

## 3. 系統架構決策（system-design）

### 3.1 模組劃分

新增 **M2 — SOP Infrastructure** 模組：
- 職責：管理 SOP 規範檔（AGENTS.md / JSON 規範 / skill 定義）
- 不變：M1 — Installer & Distribution（install.sh 邏輯本體）
- 介面：M1 透過「檔案清單」與 M2 對接（M1 不知道 M2 的內容，只知道要複製哪些檔案）

### 3.2 檔案清單（M2 新增）

```
docs/sop/
├── gates.json          # 4 個 Gate 的定義（規範來源）
└── gates.schema.json   # JSON Schema Draft 2020-12（驗證 gates.json）

AGENTS.md              # §2.3 改為引用 ./sop/gates.json
install.sh             # M1 增加一行：複製 docs/sop/ 到目標位置
```

### 3.3 部署路徑（install 後）

```
~/.pi/
├── AGENTS.md → /path/to/tree_monstor/AGENTS.md
└── sop/
    └── gates.json → /path/to/tree_monstor/docs/sop/gates.json
    └── gates.schema.json → ...

~/.claude/
├── CLAUDE.md (wrapper 引用 AGENTS.md)
└── sop/
    └── gates.json
    └── gates.schema.json
```

### 3.4 為什麼用 symlink 而非 copy

跟 US-001 一致 — 改源檔即時生效，不需重跑 install.sh。

---

## 4. gates.json 結構設計（草案）

```json
{
  "$schema": "./gates.schema.json",
  "version": "1.0.0",
  "gates": [
    {
      "id": "gate-1",
      "name": "TDD gate",
      "trigger_skill": "tdd-test-writer",
      "pass_criteria": [
        "測試可運行",
        "看到「先紅後綠」（失敗→通過）"
      ],
      "required_evidence": [
        "測試執行指令",
        "失敗輸出（修改實作前的測試失敗訊息）",
        "通過輸出（修改實作後的測試通過訊息）"
      ],
      "fail_action": "不可寫實作 code"
    },
    {
      "id": "gate-2",
      "name": "lint / syntax gate",
      "trigger_skill": null,
      "pass_criteria": [
        "對應語言的 linter 0 error / 0 warning"
      ],
      "required_evidence": [
        "linter 完整 output"
      ],
      "fail_action": "不可繼續寫更多 code"
    },
    {
      "id": "gate-3",
      "name": "regression gate",
      "trigger_skill": "regression-guard",
      "pass_criteria": [
        "探針埋好",
        "完整測試套件跑過"
      ],
      "required_evidence": [
        "修改前 baseline（完整測試套件 output）",
        "修改後 output（完整測試套件 output）",
        "Diff 對比（既有測試結果一致 + 新探針如預期觸發）"
      ],
      "fail_action": "不可聲稱『做完了』"
    },
    {
      "id": "gate-4",
      "name": "reviewer gate",
      "trigger_skill": "dev-checker-loop",
      "pass_criteria": [
        "checker subagent 回傳『沒找到更多問題』",
        "playwright-cli E2E 全綠（含截圖證據，UI 任務必跑）"
      ],
      "required_evidence": [
        "checker subagent 原文回傳",
        "playwright test 報告路徑 + 截圖路徑（若有 UI）"
      ],
      "fail_action": "不可進入 §2.4 反省"
    }
  ]
}
```

### 4.1 對應 AGENTS.md §2.3 的新內容（精簡版）

原本 §2.3 是約 80 行的 Gate 說明表，改為：

```markdown
#### 必須按順序通過 4 個 gate（缺一不可）

完整 Gate 定義（含每個 gate 的 `pass_criteria` / `required_evidence` / `fail_action`）見
[`./sop/gates.json`](./sop/gates.json)。

| Gate | 名稱 | 觸發 skill |
| --- | --- | --- |
| Gate 1 | TDD gate | `/skill:tdd-test-writer` |
| Gate 2 | lint / syntax gate | 語言對應工具 |
| Gate 3 | regression gate | `/skill:regression-guard` |
| Gate 4 | reviewer gate | `/skill:dev-checker-loop` + playwright-cli（UI 任務必跑） |

> **fail-fast gate** — 不通過 gate = 不可進入 §2.4 反省、不可宣稱任務完成。
> 修改 Gate 規範請改 `docs/sop/gates.json`（single source of truth）。
```

---

## 5. 執行策略

### 5.1 順序（一次完整跑完）

```
[1] 產出 docs/sop/gates.schema.json    ← 設計 JSON Schema
    ↓
[2] 產出 docs/sop/gates.json           ← 用 schema 規範自己
    ↓
[3] ajv 驗證 gates.json（Gate 2 跑 lint）
    ↓
[4] 修改 AGENTS.md §2.3 為引用版
    ↓
[5] 修改 install.sh 增加 gates.json 複製邏輯
    ↓
[6] install.sh --dry-run 驗證（Gate 3 regression）
    ↓
[7] Subagent reviewer 檢查整體（Gate 4 reviewer）
    ↓
[8] 行為驗收：跑 dav-skill-creater 1 SP 任務
    ↓
[9] 反省 + 交付
```

### 5.2 Story Point 估算（Fibonacci）

| 子任務 | 點數 | 評估依據 |
|---|---|---|
| 設計 gates.schema.json | 2 | 結構化設計，~30 行 schema |
| 產出 gates.json + 自我驗證 | 1 | 對照 AGENTS.md §2.3 寫 4 個 gate |
| ajv 驗證腳本 | 1 | ajv CLI 即可 |
| AGENTS.md §2.3 改寫 | 1 | 改 80 行 → 15 行 |
| install.sh 整合 | 2 | 加 1 個 copy 邏輯 + dry-run 顯示 |
| 結構驗收 | 1 | 跑 ajv + dry-run |
| Subagent reviewer | 2 | dev + checker 兩個 subagent |
| 行為驗收（跑 skill-creater） | 3 | 跨 4 個 Gate + 完整 SOP 流程 |
| 反省 + 交付 | 2 | 標準 SOP §2.4+2.5 |
| **合計** | **13** | |

> ⚠️ 注意 13 是上限 — 如果你覺得太大，可以拆成「結構驗收（5 點）」+「行為驗收（8 點）」兩個 Sprint，但這違背「最小可行」原則。我建議**一次跑完**，因為行為驗收的價值在結構做完之後立刻跑才能驗證真實性。

### 5.3 預估時長

| 階段 | 預估 |
|---|---|
| 結構驗收 7 項（步驟 1-7） | 1.5 小時 |
| 行為驗收（步驟 8） | 1 小時 |
| 反省 + 交付（步驟 9） | 30 分鐘 |
| **合計** | **~3 小時** |

---

## 6. 交付物清單

完成 US-007 後應產出：

- [ ] `docs/sop/gates.json`（新檔案，4 個 Gate）
- [ ] `docs/sop/gates.schema.json`（新檔案，JSON Schema Draft 2020-12）
- [ ] `AGENTS.md`（更新 §2.3，從 ~80 行縮為 ~15 行）
- [ ] `install.sh`（更新，增加 gates.json 部署邏輯）
- [ ] `tests/install.bats`（更新，新增 gates.json 部署的測試案例）
- [ ] `docs/reflection/us-007-reflection.md`（6 維度反省）
- [ ] `docs/deliverable/2025-08-21-sop-gates-json.{md,html}`（交付摘要）

---

## 7. 風險與緩解

| 風險 | 緩解 |
|---|---|
| ajv CLI 環境未安裝 | 文件第一行註明「需 `npm install -g ajv-cli` 或用 `npx ajv`」 |
| install.sh 改動可能破壞既有測試 | 行為驗收前先跑 `bats tests/install.bats` baseline |
| AGENTS.md 改寫可能漏失原意 | 對照原本的 4 個 Gate 表逐項檢查 |
| 行為驗收（跑 skill-creater）可能撞 ID 衝突 | 用新的 skill 名稱（避開既有 8 個 tree_monstor skills） |
| 13 點偏高，可能超 Sprint | 如果超時，行為驗收可降為「內部測試」而非「真實 skill 登記」 |

---

## 8. 待用戶確認

請你看完整份計劃後告訴我：

1. **計劃 OK，可以進入 SOP §2.3 開始執行？**
2. 還是某些部分要改？

確認後我會：
1. 開始 §2.3 執行階段（4 個 Gate 都要跑完）
2. 最後 §2.4 反省 + §2.5 交付

> **備註**：執行前我會先做一步**設定檢查**（確認 git 狀態、ajv 是否可用、install.sh 測試 baseline），確保在乾淨環境開始。