---
name: dev-checker-loop
description: |
  Dev-agent / checker-agent collaboration loop driven by downstream project docs/STATE.md.
  Dev agent implements and records work items; an independent checker agent verifies each
  item with real lint/typecheck/test/build evidence and writes findings back; loop continues
  until all items are VERIFIED or escalation limits are hit.
trigger: |
  "dev checker loop" / "dev-loop" / "STATE.md" / "checker agent" / "雙 agent 開發" / "自動檢查循環" / "開發檢查協作"
version: 1
category: software-development
---

# Dev Checker Loop — docs/STATE.md 驅動的開發/檢查協作

> **Status:** Operational workflow. Use when a downstream-project development task needs a built-in quality gate: a dev agent implements, an independent checker agent verifies with real evidence, and both coordinate through the project's `docs/STATE.md` until everything passes or an escalation limit is hit.

---

## Core rule

0. **Loop 是外加層，不是替代流程。** Dev 階段就是原本的完整開發流程，原封不動——鐵律、Think/Plan 互動、plan mode、skill routing（regression-guard、docs-sync、existing-project-intake…）、專案本地規則，在 loop 內全部照常適用。Loop 只外加兩件事：(a) 開發單位記錄為 STATE.md work items；(b) 每輪獨立 checker 實證覆核。任何「因為在跑 loop 所以省略原流程某一步」都是誤用。
1. **Checker 的判斷標準永遠是「實際跑過、觀察到正確行為」**（代碼品質鐵律 3/5）。文檔寫齊、測試檔案存在、dev 聲稱通過，都不構成 VERIFIED。
2. **Checker 必須是 fresh、獨立的 subagent** — 不沿用 dev 的 context，不帶 dev 的偏見。Checker 的職責是找問題，不是幫 dev 通過。
3. **所有協作狀態必須寫進 `docs/STATE.md`** — findings 只留在對話中不算數；dev 的完成聲明沒寫進 STATE.md 就不會被檢查。
4. **Loop 有硬性上限** — 不允許無限打乒乓。達到上限就停下向 David 升級，帶著完整證據。

---

## When to use

- 多 work item 的功能開發或重構，需要每步都有品質 gate。
- David 明確要求「dev-loop」、「checker agent」或「開發完自動檢查」。
- 長任務（>1 小時 / 多 subagent），且失敗成本高（regression 風險、production 相關）。

## When not to use

- 單一 trivial 改動（typo、一行 fix）— 直接做 + 自己跑最小驗證即可，loop 開銷不值得。
- 純研究 / 純閱讀任務 — 沒有代碼改動就沒有東西可 check。
- 該專案連最小驗證命令都跑不起來（無法安裝依賴等）— 先修好環境，否則 checker 無法實證。

---

## Agent roles

| 角色 | 執行者 | 職責 | 禁止事項 |
|------|--------|------|---------|
| **Dev agent** | 主對話 / 主 agent | **按原有完整開發流程工作**（鐵律、plan mode、skill routing 照常），外加：拆解計畫為 work items；完成 item 時自跑最小驗證並更新 `docs/STATE.md`；回應 checker findings 並修復 | 不可跳過自我驗證直接標 DEV_DONE；不可為了讓 checker 通過而弱化/刪除測試；不可以「loop 在跑」為由省略原流程步驟 |
| **Checker agent** | 獨立 fresh subagent（每輪新 spawn） | 讀 STATE.md 中 DEV_DONE items；讀相關 diff；**實際執行**該專案最小相關 lint / typecheck / test / build；把 findings + 真實輸出證據寫回 STATE.md | 不可只讀 STATE.md 聲稱就下判斷；不可直接改實作代碼（發現問題交回 dev 修）；不可在沒跑驗證的情況下標 VERIFIED |

Checker 唯一允許的寫入是 `docs/STATE.md`（findings、evidence、狀態欄）。

---

## File contract: `docs/STATE.md`

位置：downstream project root 的 `docs/STATE.md`。**Committed**（不是 gitignored runtime state），保留審計線索。

模板：

```markdown
# STATE — <項目名>

> **Status:** Dev/Checker loop coordination state.
> **Goal:** <用戶需求一句話>
> **Round:** 3 / 10 (max)
> **Last updated:** YYYY-MM-DD HH:MM by <dev-agent|checker-agent>

## Work Items

| ID | 描述 | 狀態 | 打回次數 | 最後更新 |
|----|------|------|---------|---------|
| WI-001 | ... | VERIFIED | 1 | ... |
| WI-002 | ... | CHECK_FAILED | 2 | ... |

狀態: TODO / IN_PROGRESS / DEV_DONE / CHECKING / CHECK_FAILED / VERIFIED / ESCALATED

## Checker Findings (open)

### CK-003 — WI-002: <finding 標題>
- **Severity:** blocker | major | minor
- **問題:** <具體問題>
- **證據:** <命令 + 真實輸出摘錄>
- **要求:** <dev 需要做什麼>
- **狀態:** OPEN / FIXED / DISPUTED

## Verification Evidence

| WI | 檢查 | 命令 | 結果 | 回合 |
|----|------|------|------|------|
| WI-001 | typecheck | `bun tsc --noEmit` | ✅ 0 errors | 2 |

## Resolved Findings

<CK-XXX 關閉後移到這裡，保留審計線索>

## Escalation

<觸發升級時：原因、卡住的 item、已嘗試方案、需要 David 決定什麼>
```

規則：

- Work item ID 格式 `WI-XXX`，checker finding ID 格式 `CK-XXX`，各自遞增。
- 每次寫入必須更新 header 的 `Round` 和 `Last updated`（含寫入者身份）。
- Finding 關閉後從 `Checker Findings (open)` 移到 `Resolved Findings`，不刪除。
- `Verification Evidence` 只接受真實執行過的命令 + 真實輸出摘錄；沒跑的檢查明確寫「未跑 + 原因」。

---

## Loop lifecycle

```text
用戶需求
  → dev: 拆解為 work items，建立 docs/STATE.md
  → ┌─ Round N ─────────────────────────────────────────┐
    │ dev: 取一個 TODO item → IN_PROGRESS               │
    │ dev: 小步實作 + 自跑最小驗證 → DEV_DONE           │
    │ dev: spawn fresh checker subagent                  │
    │ checker: 讀 STATE.md DEV_DONE items + git diff     │
    │ checker: 實際執行 lint/typecheck/test/build        │
    │ checker: 寫 evidence + findings 回 STATE.md        │
    │   ├─ 無問題 → VERIFIED                             │
    │   └─ 有問題 → CHECK_FAILED + CK-XXX（打回次數+1）  │
    │ dev: 讀 STATE.md → 修復 open findings → 重新 DEV_DONE│
    └────────────────────────────────────────────────────┘
  → 全部 items VERIFIED 且無 open finding → 向 David 總結報告（引 STATE.md 證據）
  → 或觸發終止條件 → 寫 Escalation section → 停下問 David
```

- 一輪只推進一個（或少量高度相關的）work item — 小步改動，改完即驗證（鐵律 4）。
- 多個 DEV_DONE items 可以在同一次 checker run 一起檢查（省 subagent 開銷），但 findings 必須逐 item 記錄。

---

## Checker standards（檢查清單）

Checker 每輪至少做齊：

1. **實證驗證** — 實際執行該專案最小相關的 lint / typecheck / test / build，把命令和真實輸出摘錄寫進 `Verification Evidence`。跑不了的檢查明確寫明什麼沒跑、為什麼。
2. **Diff 核對** — 讀該 item 相關的 `git diff`，核對代碼實際做的事是否符合 item 描述聲稱的行為，檢查明顯邏輯錯誤、遺漏邊界、hardcode。
3. **Bug fix 專項** — item 屬於 bug fix 時，依 [`regression-guard`](../regression-guard/SKILL.md) 標準檢查：有無重現證據、有無 red→green 測試、有無 `docs/REGRESSION-GUARD.md` entry 和 `RG-XXX` 代碼標記。
4. **文檔≠驗證** — 「測試檔案存在」「文檔已更新」不等於通過；判斷只基於實際執行結果。
5. **不確定就打回** — 無法確認正確性時標 CHECK_FAILED 並說明缺什麼證據，而不是放行。

Severity 定義：

| Severity | 含義 | 對狀態的影響 |
|----------|------|-------------|
| blocker | 功能錯誤、驗證失敗、regression 風險 | 必須 CHECK_FAILED |
| major | 明顯品質問題（遺漏邊界、錯誤處理缺失） | 必須 CHECK_FAILED |
| minor | 風格 / 可讀性 / 非必要優化 | 記錄 finding 但可 VERIFIED，dev 自行決定是否處理 |

---

## Termination and escalation

| 條件 | 動作 |
|------|------|
| 全部 work items VERIFIED 且無 open blocker/major finding | Loop 正常結束，dev 向 David 總結（引用 STATE.md evidence） |
| 同一 work item 打回次數達 **3** | 該 item 標 ESCALATED，停 loop，寫 Escalation section，問 David |
| 總回合數達上限（預設 **10**，可在 STATE.md header 調整） | 停 loop，寫 Escalation section（含剩餘 items 狀態），問 David |
| dev 與 checker 對同一 finding 標 DISPUTED 往返達 **2** 次 | 停 loop，把雙方理據寫進 Escalation section，交 David 裁決 |
| checker 無法執行任何驗證命令（環境壞） | 停 loop，先向 David 報告環境問題 |

Escalation section 必須包含：卡住的 item、finding 全文、dev 已嘗試的方案、雙方證據、需要 David 決定的具體問題。**不允許靜默放棄或靜默降級標準。**

---

## 與現有 Tree Monstor 機制的關係

| 檔案 | 定位 | 與本 skill 的關係 |
|------|------|------------------|
| `docs/STATE.md`（downstream project） | 本 loop 專用的 committed 協作檔 | 本 skill 擁有；task 級粒度 |
| `docs/task-board.md` | 整體專案 task board（orchestrator 擁有） | 不取代。大型多階段專案中，STATE.md 對應 task board 上一個任務的內部 loop |
| `docs/_meta/dev-task-state.md` | gitignored runtime resume state（dev-task-memory 擁有） | 不取代。中斷恢復仍走該機制 |
| `docs/REGRESSION-GUARD.md` | bug fix 防護記錄 | 不取代。bug fix item 通過 loop 後仍要有 RG entry，checker 負責檢查 |
| `docs/QA-TRACKER.md` / `docs/TEST-COVERAGE.md` | QA / 測試基線 | 不取代。需求級測試追蹤仍走原文檔 |

---

## Pitfalls

0. **把 loop 的精簡步驟當成完整開發流程 = 最常見誤用。** Loop lifecycle 描述的是協作節奏，不是開發方法；dev 階段的開發方法永遠是原有流程（鐵律 + Think/Plan + skill routing）。實測發現 dev agent 跑 loop 時會退化成只照 loop 步驟走、丟失原流程——所以本檔和操作版都明文：loop 從不豁免任何原有步驟。
1. **Checker 只看 STATE.md 聲稱不看代碼 / 不跑命令 = 失職。** VERIFIED 沒有 evidence 行支撐就是無效判定。
2. **Dev 為了讓 checker 通過而弱化、跳過或刪除測試 = 紅線。** 發現此行為時 checker 必須標 blocker 並升級。
3. **Findings 只留在 subagent 回覆、沒寫進 STATE.md = 不算數。** 下一輪 checker 是 fresh 的，STATE.md 是唯一協作媒介。
4. **同一個 checker context 重用多輪** — 會累積對 dev 實作的熟悉和偏見，失去獨立性。每輪必須 fresh spawn。
5. **沒設回合上限就開 loop** — 收斂不了的問題會無限燒 token。開 loop 前 header 必須有 max round。
6. **把 STATE.md 當 dev 的個人筆記** — 它是兩個 agent 的協作契約，格式亂了 checker 會漏檢。遵守模板欄位。

---

## Claude Code runtime note

在 Claude Code 中，dev agent 是主對話本身，checker 用 Agent tool spawn general-purpose subagent。操作版 skill 位於 `~/.claude/skills/dev-loop/`（可用 `/dev-loop` 啟動）；本檔為 canonical 標準，兩者不一致時以本檔為準。

---

## Related docs

- [Orchestrator](../orchestrator/SKILL.md) — 多 subagent 協調與 task board
- [Regression Guard](../regression-guard/SKILL.md) — bug fix 驗證標準
- [Docs Sync](../docs-sync/SKILL.md) — findings 影響需求/設計/測試時同步文檔
- [Dev Task Memory](../dev-task-memory/SKILL.md) — runtime resume state
- [Feedback loop](../../docs/feedback-loop.md) — Review/Test 失敗迭代原則
- [QA Gate](../../docs/qa-gate.md) — 出貨品質關卡
- [Skills catalog](../README.md)
