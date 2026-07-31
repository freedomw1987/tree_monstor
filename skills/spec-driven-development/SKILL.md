---
name: spec-driven-development
description: |
  Foreground BA gate for every non-trivial new feature or user-story request.
  Produces docs/specs/REQ-XXX/spec.md with atomic Given/When/Then acceptance
  criteria and tests.md with AC-to-RT traceability before implementation starts.
  dev-checker-loop cannot close until every criterion has passing real evidence.
trigger: |
  "new feature" / "user story" / "新功能" / "新增需求" / "加個功能" /
  "spec gate" / "REQ-XXX" / "AC-XXX" / "acceptance criteria" / "驗收標準"
category: software-development
applicability: operational
---

Last-verified: 2026-07-29
# Spec-Driven Development — 前景 BA 需求規格閘門

> **Status:** Operational workflow. Use for every T2/T3 new feature or user-story request. One fresh foreground BA subagent turns the request into an acceptance-and-test contract before implementation; `dev-checker-loop` then implements and independently proves the contract.

---

## Core rules

0. **Spec gate 是外加前置閘門，不是替代流程。** Downstream project 規則、Think/Plan、task tiering、existing-project-intake、PRD / QA-TRACKER、驗證鐵律及其他 matching skills 全部照常適用。
1. **需求未成為可驗收 AC 之前，不開始 implementation。** Plan 可以研究和澄清；Build 必須等 gate 通過。
2. **BA 必須是 fresh foreground subagent。** 主對話等待 BA 完成並覆核產物；不可用 background BA 在 dev 已開工後補文件。
3. **BA 先讀 source，不能猜現有行為。** 不知道的事寫成 blocking `OPEN QUESTION`。任何 blocking question 未清空，gate 未通過。
4. **每個 AC 必須映射到 test contract。** AC 無 RT、RT 無真實 test、test 無實際 PASS evidence，都不算完成。
5. **文檔不能替代驗證。** `spec.md` / `tests.md` 寫齊只代表可以開工；完成仍由真實測試、use case 和 checker evidence 決定。
6. **Per-request spec 是 durable traceability。** `docs/PRD.md` / `docs/QA-TRACKER.md` 仍是 project-wide canonical；spec 不取代它們，也不在交付後自動 archive。

---

## Trigger boundary

### Must use

同時符合以下兩項：

1. 根據 [`docs/task-tiering.md`](../../docs/task-tiering.md) 屬於 **T2 或 T3**；及
2. 是新 feature、user story、scope / business behavior 增量，或改變現有 acceptance contract。

做到一半才發現原任務其實新增行為：**立即停手 → 重新分級 → 跑本 gate → 才繼續 Build**。

### Must not use

| 情況 | 原因 / 正確路徑 |
|------|-----------------|
| T1 typo、文案、單一 trivial change | 按 task-tiering T1 template 申報，直接做最小驗證 |
| 純閱讀、研究、解釋、review | 沒有新行為要驗收 |
| QA-only：只跑或補既有測試 | 走既有 QA / `dev-checker-loop` coverage 流程 |
| Restart、清 cache、重啟服務等 trivial ops | 運維動作，不製造 feature contract |
| Bug fix / 舊 bug 復發 | 走 [`regression-guard`](../regression-guard/SKILL.md)：先重現、root cause、red→green、`RG-XXX`；若 bug 揭示需求本身缺失，再另開 REQ |

跳過時必須申報：

```text
【Spec gate 例外】本次跳過 spec gate，因為 <T1 判準 / bug fix / read-only / QA-only / trivial ops>。
仍然執行：先讀後寫、實證驗證（附命令 + 真實輸出）。
```

---

## Roles and ownership

| 角色 | 擁有 | 禁止事項 |
|------|------|----------|
| **BA subagent** | 需求澄清、source-verified 現狀、scope、AC、AC→RT contract；寫 `spec.md` / `tests.md`，T3 有新 US 時同步 PRD / QA-TRACKER | 寫 implementation code、tests 或 STATE；猜未知行為；自行回答 blocking question；塞入不必要實作方案 |
| **Dev agent** | `dev-checker-loop`、WI 拆解、real RT 實作、STATE runtime ledger、code、tests、真實自驗 | 弱化 / 刪除 AC；把未跑測試標 PASS；以 tests.md 取代 STATE |
| **Checker agent** | fresh independent verification；對賬 AC、RT、WI、test code、structured logs、use cases | 改 AC 或 implementation；只看文檔就標 VERIFIED |
| **David** | 決定 scope / blocking questions / disputed acceptance meaning | — |

BA gate 每個 REQ 預設只跑一次。Checker 發現 implementation gap 交回 dev；只有 genuine scope contradiction 才由 David 決定是否重新跑 BA。不得讓 BA / checker 互相改寫對方標準。

---

## Foreground BA subagent contract

主 agent spawn BA 時，prompt 必須包含：

- 用戶原話（verbatim，不可只給 paraphrase）
- project root 及 project-local rules
- T2 / T3 判定與理由
- 需求「為什麼需要」的答案；若沒有，要求 BA 留 blocking question
- 現有 `docs/PRD.md`、`docs/QA-TRACKER.md`、`docs/STATE.md` 是否存在
- 可用的 REQ / US / RT 最大 ID（由 repo 搜尋所得，不能憑空猜）
- 要讀的 source / routes / APIs / tests 範圍
- 硬規則：atomic AC、Given/When/Then、observable outcome、edge/error/permission states、不得寫 implementation code

BA 只在以下條件全部成立時回報 gate ready：

1. `spec.md` 和 `tests.md` 已寫入正確 REQ folder。
2. Source-verified 現狀有 file:line 或實際命令證據。
3. `OPEN QUESTIONS` 沒有 blocking `OPEN`。
4. 每個 AC 在 tests.md 至少出現一次。
5. 每個 mapping 使用未衝突的 real `RT-XXX`，或在 STATE 尚不存在時明確使用 `RT-TBD-*`。
6. T3 新增 / 修改 US 已同步 PRD 和 QA-TRACKER。

回報格式：

```text
REQ-XXX | AC=<n> | RT mappings=<n> | blocking questions=0 | gate=READY
```

---

## ID contract

| ID | Scope / owner | Rule |
|----|---------------|------|
| `REQ-XXX` | project-wide incoming request | 掃描 `docs/specs/REQ-*` 後取下一個；不可重用 |
| `US-XXX` | PRD / QA-TRACKER product story | 保持既有 sequence；REQ 可 map 一個或多個 US，不可另建 shadow PRD |
| `AC-XXX` | one REQ | 每個 spec 由 001 開始；跨 REQ 時寫全稱 `REQ-014/AC-003` |
| `RT-XXX` | project regression ledger / executable test | 掃描 STATE、test code、regression docs 後保留未用 ID；同時出現在 test 名 / 註解、STATE、structured log |
| `RT-TBD-*` | temporary only | 只容許 STATE / harness 尚未建立；loop 第一批 WI 必須轉 real RT，任何 TBD 殘留都阻止 DEV_DONE / closure |

---

## File contract: `docs/specs/REQ-XXX/spec.md`

```markdown
# REQ-XXX — <一句話標題>

> **Status:** DRAFT | APPROVED | DELIVERED | SUPERSEDED
> **Requested:** YYYY-MM-DD by <requester>
> **Tier:** T2 | T3
> **US mapping:** US-004, US-007 | US-012 (new) | N/A — no PRD baseline（已申報）
> **RT reserved:** RT-041..RT-047 | RT-TBD-1..7
> **Loop state:** docs/STATE.md | not-created
> **Superseded-by:** —

## 原始需求（verbatim）

<用戶原話，不可 paraphrase>

## 背景與目的

<為什麼需要；未知即 blocking OPEN QUESTION>

## Scope

- In scope:
- Out of scope:

## 現狀（source-verified）

| 項目 | 現時行為 | 證據（file:line / 命令 + 輸出） |
|------|----------|---------------------------------|

## Acceptance Criteria

### AC-001 — <一句話>
- **Given** <前置條件>
- **When** <一個動作>
- **Then** <一個可觀察結果>
- **Observable via:** UI | API response | DB state | CLI output | log line
- **Priority:** P0 | P1 | P2

## Non-functional / 邊界

| 類別 | 要求 | AC |
|------|------|----|
| security / permission / error / empty / performance | | AC-00X |

## OPEN QUESTIONS（blocking OPEN 未清空 = gate 未通過）

| ID | 問題 | 為什麼 blocking | 狀態 |
|----|------|-----------------|------|
| Q-001 | | | OPEN | ANSWERED: <David 回覆 + 日期> |

## 依賴與風險

## Changelog

| 日期 | 變更 | 原因 |
|------|------|------|
```

### AC writing standard

- 一個 AC 只描述一個可觀察結果，並且只有一個 `When`。
- 禁用「正確地」「正常」「適當」等不可判定字眼；寫清具體 response、畫面、狀態或輸出。
- 驗收行為，不驗收 private implementation：`POST /api/orders 回 201 且 body 有 id` 可以；`呼叫 createOrder()` 不可以。
- Happy path、error、empty、permission denied、critical boundary 各自獨立 AC。
- 建議一個 REQ 不超過 12 個 AC；再大就拆 REQ，避免一個 gate 吞掉多個獨立 feature。

---

## File contract: `docs/specs/REQ-XXX/tests.md`

```markdown
# REQ-XXX — Test Mapping

> **Spec:** ./spec.md
> **Coverage ledger:** docs/STATE.md § Regression Coverage
> **Status:** DRAFT | APPROVED | DELIVERED
> Runtime status / PASS evidence 只以 STATE.md + 真實 regression log 為準；本檔只擁有 mapping。

## AC → RT mapping（每個 AC 至少一個 RT）

| AC | RT | Test level | 可觀察驗證方式 | 對應 US |
|----|----|------------|----------------|---------|
| AC-001 | RT-041 | e2e | 登入 → 建立訂單 → 頁面顯示訂單號 | US-012 |
| AC-002 | RT-042 | backend | 缺必要欄位時 API 回 400 + stable error code | US-012 |

Test level: `frontend` | `backend` | `e2e` | `doc-check`。

## 必跑 use cases

| ID | Use case | 起點 → 終點 | 期望觀察 | AC | Evidence ref |
|----|----------|-------------|----------|----|--------------|
| UC-001 | | | | AC-001 | pending |

## 已知不測（不可 silent skip）

| 項目 | 理由 | 補償措施 | 批准者 |
|------|------|----------|--------|
```

Rules:

- 每個 spec AC 必須在 mapping table 至少出現一次。
- 一個 RT 可以覆蓋多個 AC，但每行要說明該 RT 如何觀察對應 AC。
- tests.md 不保存 `PLANNED / PASSING` runtime 狀態；否則會和 STATE drift。
- `doc-check` 只適用於 profile / docs / generated artifact 等可由 repeatable command 驗收的工作，不可用來逃避 app runtime 測試。

---

## Handoff to `dev-checker-loop`

Gate ready 後才啟動 [`dev-checker-loop`](../dev-checker-loop/SKILL.md)：

1. STATE header 寫入 spec path。
2. 每個 AC 導入至少一個 WI 的 Acceptance 欄；不可有 orphan AC。
3. 每個 tests.md mapping 導入 Regression Coverage / Spec Traceability。
4. 若有 `RT-TBD-*`，第一批 WI 分配 real RT 並同一改動更新 tests.md + STATE。
5. Dev 寫 test 時，real `RT-XXX` 必須存在於測試名或註解，runner 要輸出：

```text
[REGRESSION] <RT-ID> | <feature> | <frontend|backend|e2e|doc-check> | PASS|FAIL | <duration> | <error>
```

6. Checker 每輪實跑並對賬，不可只看表格或 exit code。
7. tests.md 的每個 use case 必須實際走過，evidence 寫入 STATE；跑不了要明確 blocker / exception，不可默認通過。

### Closure contract

只有以下全部成立，spec-driven work 才可結束：

- 全部 WI VERIFIED、無 open blocker / major finding。
- 全部 qualified AC 在 Spec Traceability = `PASSING`。
- 每個 AC 有 real RT；沒有 `RT-TBD-*`。
- 每個 RT 存在於 executable test、STATE Coverage，以及本輪 `[REGRESSION] ... PASS` log。
- 必跑 use cases 全部有真實 evidence。
- 沒有 blocking open question。
- Project 原有 lint / typecheck / test / build / smoke / docs gates 同樣通過。

任何一環斷裂，checker 建立 finding 並阻止 closure。

---

## Lifecycle and change control

`DRAFT → APPROVED → DELIVERED → SUPERSEDED`

- `APPROVED`：blocking questions = 0，AC 完整，mapping 完整，可以 Build。
- `DELIVERED`：closure contract 全部通過，附 STATE / verify-log evidence。
- Delivered AC 不可靜默改寫。需求改變建立新 REQ，舊 spec 加 `Superseded-by` 和 changelog。
- 如果只是 implementation 修正但 acceptance contract 不變，不新開 REQ；照原 spec 修至 PASS。
- Spec 永不自動 archive；它保留「當時要求、驗收、證據」的 traceability。

---

## Profile-maintenance mode

本 profile 自身新增 workflow / skill 也可 dogfood 本 gate。Spec 放在 profile 的 `docs/specs/REQ-XXX/`；可重跑的 repository checker / catalog assertion 可用 `doc-check` RT，但仍須先看是否有真正 runtime / script behavior 要測，不能用文檔代替可執行驗證。

---

## Relationship to existing mechanisms

| Mechanism | Owner | Relationship |
|-----------|-------|--------------|
| `docs/PRD.md` / `docs/QA-TRACKER.md` | project product / QA baseline | project-wide canonical；REQ 只保存 per-request detail，新 / 改 US 仍同步兩者 |
| `docs/STATE.md` | dev-checker-loop | runtime status、WI、Coverage、evidence 的唯一 ledger |
| `docs/REGRESSION-GUARD.md` | regression-guard | bug path；新 feature gate 不取代 RG root-cause / red→green 規則 |
| `feature-plan-alignment` | direction approval | 若兩者都觸發：方向選擇 → spec gate AC 化 → dev-checker-loop |
| `existing-project-intake` | source/docs baseline | baseline 未知時先 intake，再讓 BA 建立 source-verified spec |
| `docs/task-tiering.md` | tier source of truth | 決定 T1/T2/T3；本 skill 只定義 feature gate |

---

## Pitfalls

0. **Spec theater** — 把 feature title 重寫成 AC，但沒有可觀察結果。
1. **先寫 code 後補 spec** — commit order 已證明 gate 失效。
2. **BA 猜現有行為** — 沒有 source / command evidence 的「現狀」不可信。
3. **一個 AC 包多個行為** — checker 無法指出哪部分 pass / fail。
4. **RT ID 憑空作** — 和既有 test / STATE 撞號，或根本沒有 executable test。
5. **tests.md 成為第二份 status ledger** — 和 STATE drift；mapping 和 runtime status 必須分治。
6. **OPEN QUESTION 自問自答** — scope decision 必須由 David 或有權限的 stakeholder 回答。
7. **Spec 取代 PRD** — project-wide roadmap / US baseline 變 stale。
8. **每個 typo 都開 REQ** — 官僚化會令人繞過真正重要的 gate；嚴格跟 task-tiering。
9. **只證明 test PASS，不證明 AC 行為** — checker 必須實際觀察 use case / runtime outcome。

---

## Claude Code runtime note

Claude Code wrapper 位於 `adapters/claude-code/skills/spec-driven-development/`；canonical 規則永遠是本檔。Runtime skill 必須以 foreground BA gate 運行，不得 background 補 spec。

---

## Related docs

- [Dev Checker Loop](../dev-checker-loop/SKILL.md)
- [Regression Guard](../regression-guard/SKILL.md)
- [Existing Project Intake](../existing-project-intake/SKILL.md)
- [Task Tiering](../../docs/task-tiering.md)
- [QA Gate](../../docs/qa-gate.md)
- [Subagent roles](../../docs/subagents.md)
- [Skills catalog](../README.md)
