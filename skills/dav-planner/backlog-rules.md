---
name: dav-planner-backlog-rules
description: dav-planner 的「Backlog 編寫規則」附件（v2.2 拆分自主檔）。含 INVEST / AC / 表格欄位 / 類型 / 更新規則 / AC 範本生成 SOP。
---

# Dav Planner — Backlog 規則（§4 完整版）

> 本檔為 dav-planner 的 Backlog 編寫規則附件，於產出 Backlog 前查閱。主檔在 `SKILL.md`。

## §4.1 INVEST 原則

- **I**ndependent — 獨立
- **N**egotiable — 可協商
- **V**aluable — 有價值
- **E**stimable — 可估算
- **S**mall — 小
- **T**estable — 可測試

## §4.2 AC 範本（Given-When-Then / DoD）

- **Given-When-Then**：3 條以上 BDD 格式
- **DoD**：技術視角（4-6 項 checklist）

## §4.3 Backlog 編寫方式

- 表格欄位：US ID / 類型 / 標題 / **Module（v2.3 新增）** / AC / 優先級 / Story Point / 狀態 / 依賴
- 詳細段：放在表格下方（## TMO-XXX 詳細）
- 既有 US 不主動遷移；新 US 走新格式

### §4.3.1 Module 欄位範本（v2.3 新增）

> v2.3 起：Backlog 表格加 `Module` 欄位，讓 dav-designer 的 Module 定義能直接被 dev-checker-loop 派工用、regression-guard 探針也能綁 Module。

**Backlog 表格範本（含 Module 欄位）**：

```markdown
## Backlog

| US ID | 類型 | Module | 標題 | AC | 優先級 | Story Point | 狀態 | 依賴 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| M01-US-101 | US | M01 | 用戶登入 | 3 條 BDD | P0 | 3 | PENDING | — |
| M01-US-102 | US | M01 | 忘記密碼 | 3 條 BDD | P0 | 5 | PENDING | M01-US-101 |
| M02-US-201 | US | M02 | 付款閘道 | 4 條 BDD | P0 | 8 | PENDING | — |
| M02-US-202 | US | M02 | 退款流程 | 3 條 BDD | P1 | 5 | PENDING | M02-US-201 |
| INT-M01-M02-01 | US | INT | 登入後付款 | 2 條 BDD | P0 | 5 | PENDING | M01-US-101, M02-US-201 |
| DE-301 | DE | M01 | 修正登入 token 過期 | — | P1 | 2 | PENDING | — |
| TECH-401 | TECH | M02 | 付款 API 重構為 async | — | P2 | 8 | PENDING | — |
```

**Module 代碼規則**（v2.3 沿用 dav-designer / dev-checker-loop 共識）：

| 代碼格式 | 語義 | 範例 |
| --- | --- | --- |
| `M<NN>` | 單一 Module | `M01`、`M02`、`M10` |
| `M<NN>-M<NN>` | 多 Module 關聯（跨 Module 邊界）| `INT-M01-M02` |
| `INT-<Mxx>-<Myy>` | Integration test Module（跨 Module）| `INT-M01-M02-01` |
| 未定義 | Module 未切割 fallback = `M00`（整個 repo）| `M00-US-XXX` |

**US ID 規則**（與 Module 欄位一致）：

- `M01-US-101`：Module M01 的 US 編號 101
- `INT-M01-M02-01`：跨 M01 / M02 的 Integration US 編號 01
- `DE-301` / `TECH-401`：跨 Module 的 Bug / 技術債（不綁 Module）
- 不寫 Module 欄位 = `M00` fallback

**AC 段範本**（v2.3 沿用 INVEST + Given-When-Then）：

```markdown
## M01-US-101 詳細

- **對應 Module**: M01（user-auth）
- **負責 dev**: （派工後填入）
- **預估時間**: 3 SP
- **AC**:
  - **AC-1** (Given-When-Then): Given 用戶輸入正確密碼 When 點登入 Then 進入首頁
  - **AC-2** (Given-When-Then): Given 用戶輸入錯誤密碼 3 次 When 第 3 次登入 Then 鎖定 5 分鐘
  - **AC-3** (DoD): 探針 `M01-user-login-returns-correct-data` 必通過
- **依賴**: —
- **驗收方式**: 跑 `REGRESSION_MODULE=M01 ./run_pipeline.sh M01-US-101`
- **為什麼這個優先**（v2.3 新增）：P0 是因為這是其他 Module（M02 / M03）的入口
```

### §4.3.2 Module 級 sprint 規劃（v2.3 新增）

> dav-designer v2.3 規範 + dev-checker-loop v2.2 + regression-guard v2.10 共同鋪路下，backlog 規劃可以 Module 級而非純 US 級。

**Module 級 sprint 範本**：

```markdown
## Sprint 1（Module M01 整體交付）

| US ID | 類型 | Module | 標題 | 優先級 | SP | 狀態 |
| --- | --- | --- | --- | --- | --- | --- |
| M01-US-101 | US | M01 | 用戶登入 | P0 | 3 | PENDING |
| M01-US-102 | US | M01 | 忘記密碼 | P0 | 5 | PENDING |
| M01-US-103 | US | M01 | 修改密碼 | P1 | 3 | PENDING |
| M01-DE-301 | DE | M01 | 修正登入 token 過期 | P1 | 2 | PENDING |

**Module 級 sprint 交付**：1 個 sprint 交付 1 個 Module（M01）；dav-submitter v2.2 Module 級交付語法記錄；dev-checker-loop v2.2 用 Module 級派工；regression-guard v2.10 用 `REGRESSION_MODULE=M01` 跑全 Module 探針。

**為什麼 Module 級 sprint**：
- 平行化加速：Sprint 1 派 M01，Sprint 2 派 M02，兩個 dev 同時做
- 錯誤範圍隔離：M01 壞了不連累 M02
- 探針邊界清楚：`REGRESSION_MODULE` 限定、不混跑

## §4.4 類型混合管理

- User Story（新功能）/ Defects（Bug）/ Technical Debt（技術債）/ Spike（研究）
- 頂部精細、底部粗略（Granularity）

## §4.5 Backlog 更新規則

- 每一個項目目錄只有並唯一有一份 `docs/backlog.md`
- 每次新 Backlog item 填到表格最下方，不估算 / Sprint / Module，預設 PENDING

## §4.6 AC 範本生成 SOP（v1.8 新增，含 HTML）

- **生成時機**：用戶確認新 US 後、寫進 backlog.md 之前
- **生成順序（同 turn）**：先 .md → 再 .html → 最後更新 backlog.md
- **為什麼同 turn**：避免 .md 與 .html 不同步
- **過渡期規則**：既有 US（§4.3.2 之前）不主動生成 AC 範本
- **自我檢查清單**：5 項（檔案存在 / 連結路徑 / CSS 媒體查詢）
