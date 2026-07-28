---
name: dev-checker-loop
description: |
  Dev-agent / checker-agent collaboration loop driven by downstream project docs/STATE.md.
  Dev agent implements work items and ships a regression test (behind a project-wide
  regression switch with logged output) for every user-visible feature; an independent
  checker agent runs the full regression suite, reads the logs, audits feature coverage,
  and writes findings back; loop continues until all items are VERIFIED, coverage has no
  gaps, or escalation limits are hit.
trigger: |
  "dev checker loop" / "dev-loop" / "STATE.md" / "checker agent" / "雙 agent 開發" / "自動檢查循環" / "開發檢查協作" / "regression 開關"
category: software-development
---


Last-verified: 2026-07-28
# Dev Checker Loop — docs/STATE.md 驅動的開發/檢查協作

> **Status:** Operational workflow. Use when a downstream-project development task needs a built-in quality gate: a dev agent implements, an independent checker agent verifies with real evidence, and both coordinate through the project's `docs/STATE.md` until everything passes or an escalation limit is hit.

---

## Core rule

0. **Loop 是外加層，不是替代流程。** Dev 階段就是原本的完整開發流程，原封不動——鐵律、Think/Plan 互動、plan mode、skill routing（regression-guard、docs-sync、existing-project-intake…）、專案本地規則，在 loop 內全部照常適用。Loop 只外加兩件事：(a) 開發單位記錄為 STATE.md work items；(b) 每輪獨立 checker 實證覆核。任何「因為在跑 loop 所以省略原流程某一步」都是誤用。
1. **Checker 的判斷標準永遠是「實際跑過、觀察到正確行為」**（代碼品質鐵律 3/5）。文檔寫齊、測試檔案存在、dev 聲稱通過，都不構成 VERIFIED。
2. **Checker 必須是 fresh、獨立的 subagent** — 不沿用 dev 的 context，不帶 dev 的偏見。Checker 的職責是找問題，不是幫 dev 通過。
3. **所有協作狀態必須寫進 `docs/STATE.md`** — findings 只留在對話中不算數；dev 的完成聲明沒寫進 STATE.md 就不會被檢查。
4. **Loop 有硬性上限** — 不允許無限打乒乓。達到上限就停下向 David 升級，帶著完整證據。
5. **每個功能都要有可開關、有日誌的 regression test** — dev 交付一個 item 不只交代碼，還要交該功能的 regression test（掛在專案統一的 regression 開關下，執行時輸出結構化日誌）。Checker 每輪開開關實跑全套 regression、讀日誌、並審計前端+後端功能覆蓋——漏測的功能就是 finding。這把 regression 保護從「靠 agent 自覺」變成「留在專案裡的機器可執行物」。

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
| **Dev agent** | 主對話 / 主 agent | **按原有完整開發流程工作**（鐵律、plan mode、skill routing 照常），外加：拆解計畫為 work items；完成 item 時自跑最小驗證並更新 `docs/STATE.md`；**為每個功能型 item 寫 regression test 並掛進專案 regression 開關**；維護 STATE.md 的 Regression Coverage 表；回應 checker findings 並修復 | 不可跳過自我驗證直接標 DEV_DONE；不可為了讓 checker 通過而弱化/刪除測試；不可以「loop 在跑」為由省略原流程步驟；不可交付沒有 regression test 的功能型 item |
| **Checker agent** | 獨立 fresh subagent（每輪新 spawn） | 讀 STATE.md（含 Verification Commands、Resolved Findings、Regression Coverage）；按範圍讀 DEV_DONE items 的 diff；**實際執行**驗證命令；**開 regression 開關實跑全套 regression suite 並逐條讀日誌**；行為可見改動做 runtime 驗證；覆核 FIXED findings；**審計前端+後端功能的 regression 覆蓋**；對照 Goal 做完整性檢查；把 findings + 真實輸出證據寫回 STATE.md | 不可只讀 STATE.md 聲稱就下判斷；不可直接改實作代碼（發現問題交回 dev 修）；不可在沒跑驗證的情況下標 VERIFIED；不可無新證據重提已裁決 finding；不可用純懷疑標 blocker/major；不可只看 runner 的 exit code 不讀日誌內容 |

Checker 唯一允許的寫入是 `docs/STATE.md`（findings、evidence、狀態欄）。

---

## Regression harness contract（專案內的 regression test 基建）

Loop 啟動時，如果專案還沒有以下三件東西，**建立它們就是第一批 work items**（同樣走 dev→checker 流程檢查）：

### 1. Regression 開關

專案統一的開關控制 regression suite 是否執行，形式依專案技術棧（環境變數如 `REGRESSION_MODE=1`、test runner tag/filter 如 `--grep @regression`、或 npm/bun script 如 `test:regression`）。要求：

- **一個開關跑全套** — checker 不需要知道每個測試怎麼跑，開開關執行 runner 就是全部。
- 開關 off 時 regression suite 不干擾正常 dev/test 流程。
- 開關和 runner 命令記錄在 STATE.md 的 `Verification Commands` 表（`regression` 一行）。
- 沿用 [`regression-guard`](../regression-guard/SKILL.md) 的安全邊界：涉及 `/__qa/*` endpoints 或 runtime fixture 時，只在 dev/test/staging 掛載，production 必須 404/403；開關不得繞過 auth / 權限 / audit。

### 2. 結構化日誌輸出

開關 on 執行時，每條 regression test 輸出機器可讀的一行日誌（寫到 stdout 或約定的日誌檔，位置記錄在 Verification Commands 備註），至少含：

```text
[REGRESSION] <RT-ID> | <feature 名稱> | <frontend|backend|e2e> | PASS|FAIL | <耗時> | <失敗時：錯誤摘要>
```

結尾輸出總結行：`[REGRESSION SUMMARY] total=N pass=N fail=N skip=N`。要求日誌**逐功能可對賬**——checker 靠日誌行對照 Coverage 表，而不是只看 exit code。

### 3. STATE.md 的 Regression Coverage 表

專案所有用戶可見功能（前端頁面/交互 + 後端 endpoint/服務行為）的清單，每個功能對應它的 regression test。這是 checker 覆蓋審計的對賬單（格式見 File contract）。

- Loop 第一輪先盤點現有功能建立初版（existing project 可結合 [`existing-project-intake`](../existing-project-intake/SKILL.md)）。
- Dev 每完成一個功能型 item，必須同步在表中登記新功能和對應 `RT-XXX`。
- 純內部重構（無用戶可見行為變化）可標 N/A，但要寫理由。

### Dev 的每 item regression 義務

功能型 item 標 DEV_DONE 的前提，除了原有自驗，還包括：

1. 該功能的 regression test 已寫好、掛進開關、本地開開關跑過一次真實通過。
2. Coverage 表已登記（feature → `RT-XXX` → 類型 frontend/backend/e2e）。
3. 測試斷言的是**用戶可觀察的行為**（頁面渲染結果、API response、狀態變化），不是實作細節——這樣重構不會誤殺，真 regression 逃不掉。

---

## File contract: `docs/STATE.md`

位置：downstream project root 的 `docs/STATE.md`。**Committed**（不是 gitignored runtime state），保留審計線索。

模板：

```markdown
# STATE — <項目名>

> **Status:** Dev/Checker loop coordination state.
> **Goal:** <用戶需求一句話>
> **Round:** 3 / 10 (max)
> **Check depth:** normal | deep
> **Last updated:** YYYY-MM-DD HH:MM by <dev-agent|checker-agent>

## Verification Commands

<第一輪確立本專案的驗證命令，之後每輪 checker 直接使用，不重新摸索>

| 檢查 | 命令 | 備註 |
|------|------|------|
| typecheck | `bun tsc --noEmit` | |
| test | `bun test` | |
| regression | <開關 + runner，如 `REGRESSION_MODE=1 bun test:regression`> | 日誌位置：<stdout / 檔案路徑> |
| runtime smoke | <啟動方式 + 觀察路徑> | 行為可見改動必跑 |

## Regression Coverage

<專案所有用戶可見功能的對賬單。checker 每輪據此審計覆蓋；dev 新增功能必須同步登記>

| Feature | 類型 | RT-ID | 狀態 | 備註 |
|---------|------|-------|------|------|
| 登入流程 | frontend | RT-001 | COVERED | |
| POST /api/orders | backend | RT-002 | COVERED | |
| 訂單列表分頁 | frontend | — | **MISSING** | CK-012 |
| 內部 util 重構 | — | — | N/A | 無用戶可見行為，單元測試覆蓋 |

狀態: COVERED / MISSING / N/A(附理由)

## Work Items

| ID | 描述 | 涉及檔案 / commits | 狀態 | 打回次數 | 最後更新 |
|----|------|-------------------|------|---------|---------|
| WI-001 | ... | `src/a.ts`, `src/b.ts` / abc1234 | VERIFIED | 1 | ... |
| WI-002 | ... | `src/api/x.ts` / def5678..HEAD | CHECK_FAILED | 2 | ... |

狀態: TODO / IN_PROGRESS / DEV_DONE / CHECKING / CHECK_FAILED / VERIFIED / ESCALATED

## Checker Findings (open)

### CK-003 — WI-002: <finding 標題>
- **Severity:** blocker | major | minor | needs-info
- **問題:** <具體問題>
- **證據:** <命令 + 真實輸出摘錄；blocker/major 必須是實際觀察到的失敗>
- **要求:** <dev 需要做什麼>
- **狀態:** OPEN / FIXED / DISPUTED

## Verification Evidence

| WI | 檢查 | 命令 | 結果 | 回合 |
|----|------|------|------|------|
| WI-001 | typecheck | `bun tsc --noEmit` | ✅ 0 errors | 2 |

## Resolved Findings

<CK-XXX 關閉後移到這裡，保留審計線索。含 DISPUTED 後被裁決不成立的 finding 及裁決理由>

## Escalation

<觸發升級時：原因、卡住的 item、已嘗試方案、需要 David 決定什麼>
```

規則：

- Work item ID 格式 `WI-XXX`，checker finding ID 格式 `CK-XXX`，regression test ID 格式 `RT-XXX`，各自遞增。`RT-XXX` 同時出現在測試代碼（測試名或註解）和日誌行，保持可對賬。
- 每次寫入必須更新 header 的 `Round` 和 `Last updated`（含寫入者身份）。
- Dev 標 DEV_DONE 時必須填「涉及檔案 / commits」欄 — checker 據此定位本輪 diff 範圍，不會被跨回合累積的整體 diff 淹沒。
- `Verification Commands` 由第一輪 checker（或 dev 啟動時）確立並持續修正；後續 checker 直接使用，省去每輪重新摸索專案。
- Finding 關閉後從 `Checker Findings (open)` 移到 `Resolved Findings`，不刪除。已裁決不成立的 finding 也要留在 Resolved 並記裁決理由 — 防止後續 fresh checker 重提。
- `Verification Evidence` 只接受真實執行過的命令 + 真實輸出摘錄；沒跑的檢查明確寫「未跑 + 原因」。
- `Check depth` 預設 `normal`；David 要求或 item 涉及 production / 安全敏感 / 高 regression 風險時可設 `deep`（見 Checker standards）。

---

## Loop lifecycle

```text
用戶需求
  → dev: 拆解為 work items，建立 docs/STATE.md
  → ┌─ Round N ─────────────────────────────────────────┐
    │ dev: 取一個 TODO item → IN_PROGRESS               │
    │ dev: 小步實作 + 自跑最小驗證 → DEV_DONE           │
    │ dev: spawn fresh checker subagent                  │
    │ checker: 讀整份 STATE.md（commands/resolved 在內） │
    │ checker: 按範圍讀 DEV_DONE items 的 diff           │
    │ checker: 實際執行驗證命令 + runtime 行為驗證       │
    │ checker: 開 regression 開關跑全套 + 逐條讀日誌     │
    │ checker: 覆蓋審計（Coverage 表 vs 實際功能/日誌）  │
    │ checker: 覆核 FIXED findings（重跑原證據命令）     │
    │ checker: 完整性檢查（items 集合 vs Goal）          │
    │ checker: 寫 evidence + findings 回 STATE.md        │
    │   ├─ 無問題 → VERIFIED                             │
    │   └─ 有問題 → CHECK_FAILED + CK-XXX（打回次數+1）  │
    │ dev: 讀 STATE.md → 修復 open findings → 重新 DEV_DONE│
    └────────────────────────────────────────────────────┘
  → 全部 items VERIFIED、無 open finding、Goal 覆蓋確認 → 向 David 總結報告（引 STATE.md 證據）
  → 或觸發終止條件 → 寫 Escalation section → 停下問 David
```

- 一輪只推進一個（或少量高度相關的）work item — 小步改動，改完即驗證（鐵律 4）。
- 多個 DEV_DONE items 可以在同一次 checker run 一起檢查（省 subagent 開銷），但 findings 必須逐 item 記錄。

---

## Checker standards（檢查清單）

Checker 每輪的固定順序：

**Step 0 — 讀 context（先做，避免重複勞動和重提舊案）**

- 讀整份 `docs/STATE.md`，包括 `Verification Commands`（直接用，不重新摸索專案）和 `Resolved Findings`。
- **不得重提已裁決不成立的 finding**，除非有新證據（新 diff 觸及同一處、新的失敗輸出）；重提時必須引用新證據並註明與舊 finding 的差異。

**Step 1 — 逐 item 檢查（DEV_DONE items）**

1. **Diff 核對（按範圍）** — 依 Work Items 表的「涉及檔案 / commits」欄讀該 item 的 diff（`git diff <range> -- <files>`），核對代碼實際做的事是否符合 item 聲稱的行為，檢查明顯邏輯錯誤、遺漏邊界、hardcode。範圍欄缺失 = 直接 CHECK_FAILED（needs-info），要求 dev 補填。
2. **實證驗證** — 按 `Verification Commands` 實際執行該專案最小相關的 lint / typecheck / test / build，命令和真實輸出摘錄寫進 `Verification Evidence`。跑不了的檢查明確寫明什麼沒跑、為什麼。
3. **Runtime 行為驗證** — item 的改動行為可見時（UI、API endpoint、CLI 輸出、任何用戶可觀察的行為），靜態檢查不夠：實際啟動 app / 呼叫 endpoint / 走一次 happy path 並觀察行為（typecheck 通過不是 runtime 證明）。純內部重構且測試已覆蓋者可豁免，但要在 evidence 註明豁免理由。
4. **FIXED finding 覆核** — 對每個 dev 標了 `FIXED` 的 finding，**重跑該 finding 證據欄的原命令**（或重走原觀察路徑）並貼新輸出，確認該問題本身真的修好（而不是整體測試碰巧通過）。覆核通過才移進 Resolved Findings。
5. **Regression test 交付檢查** — 功能型 item 必須帶 regression test：測試存在且掛在開關下、`RT-XXX` 已登記 Coverage 表、斷言的是用戶可觀察行為而非實作細節。缺任一項 = CHECK_FAILED（major）。
6. **Bug fix 專項** — item 屬於 bug fix 時，依 [`regression-guard`](../regression-guard/SKILL.md) 標準檢查：有無重現證據、有無 red→green 測試、有無 `docs/REGRESSION-GUARD.md` entry 和 `RG-XXX` 代碼標記。
7. **Dev 流程合規** — 順帶檢查：diff 是否小步（一個 item 塞了多個無關邏輯改動 = major）；有無弱化 / 跳過 / 刪除測試的跡象（= blocker，升級）；行為 / API / 測試變更有無按專案規則同步文檔。

**Step 2 — Regression suite 全套執行 + 日誌檢查（每輪必做，不限本輪 items）**

1. 按 `Verification Commands` 的 `regression` 行，**開開關實跑全套 regression suite**——不是只跑本輪 item 的測試。這是抓「本輪改動弄壞舊功能」的主要手段。
2. **逐條讀日誌**（`[REGRESSION]` 行），不是只看 exit code：
   - 任何 `FAIL` → 寫 `CK-XXX` finding（blocker），引用該日誌行 + 錯誤摘要，指向對應 feature 和 `RT-XXX`。
   - 日誌行數 / summary 與 Coverage 表 COVERED 條目對不上（表裡有 RT 但日誌沒出現 = 測試沒跑或被 skip）→ finding（major）。
   - Runner exit 0 但 summary 有 fail、或日誌格式壞掉無法對賬 → finding（major，harness 本身壞了也是問題）。
3. 全套結果（total/pass/fail + 失敗清單）寫進 `Verification Evidence`。

**Step 3 — Regression 覆蓋審計（前端 + 後端功能都要有測試）**

1. 盤點實際功能面：讀路由定義（前端 routes / 後端 endpoints）、對照 STATE.md Goal 和已 VERIFIED items，列出用戶可見功能清單。
2. 對照 `Regression Coverage` 表：
   - 實際存在但表裡沒有的功能 → 補進表標 `MISSING` + 寫 `CK-XXX` finding（major，coverage gap 類），要求 dev 補 regression test。
   - 表標 N/A 的條目抽查理由是否成立（有用戶可見行為卻標 N/A = finding）。
3. 本輪新增 / 修改的功能**必須**當輪覆蓋；存量缺口（loop 開始前就沒測試的舊功能）逐輪補——最後一輪結束時 Coverage 表不得有無 finding 記錄的 MISSING。

**Step 4 — 完整性檢查（對照 Goal，不只對照 items）**

- 對照 STATE.md header 的 **Goal**，判斷現有 work items 集合是否真的覆蓋用戶需求。逐 item 全 VERIFIED ≠ 需求完成。
- 發現缺口（漏掉的功能面、未處理的明顯場景）→ 寫 `SCOPE` 類 finding（`CK-XXX`，severity 按影響定），建議新增 work item。此檢查每輪都做，最後一輪（所有 items 都 VERIFIED 時）**必做**且要在摘要中明確回答「Goal 是否已被覆蓋」。

**證據門檻與 severity：**

| Severity | 含義 | 證據要求 | 對狀態的影響 |
|----------|------|---------|-------------|
| blocker | 功能錯誤、驗證失敗、regression 風險、弱化測試 | **必須附實際觀察到的失敗**（命令輸出 / runtime 行為） | 必須 CHECK_FAILED，計入打回次數 |
| major | 明顯品質問題（遺漏邊界、錯誤處理缺失、非小步 diff） | **必須附實際觀察到的失敗或具體代碼位置** | 必須 CHECK_FAILED，計入打回次數 |
| minor | 風格 / 可讀性 / 非必要優化 | 具體代碼位置即可 | 記錄 finding 但可 VERIFIED，dev 自行決定 |
| needs-info | 無法確認正確性、缺證據、範圍欄缺失 | 說明缺什麼、dev 要補什麼 | CHECK_FAILED，但**不計入打回次數** |

純懷疑（沒有觀察到的失敗）不得標 blocker/major——標 needs-info 要 dev 補證據，或標 minor。這防止猜測性 finding 燒掉打回額度、製造假性乒乓。

**Deep 模式（header `Check depth: deep` 時）：**

- 對高風險 item（production 相關、安全敏感、高 regression 風險），dev 並行 spawn 2–3 個不同視角的 fresh checker：**正確性**（上述清單）、**regression**（會不會弄壞現有行為，跑既有測試全集 + RG guards）、**安全**（輸入驗證、權限、秘密洩漏）。
- 各自寫 findings 進 STATE.md（ID 不衝突：spawn 前 dev 在 prompt 裡分配 ID 區段）；任一 checker 標 blocker/major 即 CHECK_FAILED。
- Token 成本明顯較高，預設 normal；由 David 要求或 dev 判斷 item 風險後升級，並在 header 註明。

---

## Termination and escalation

| 條件 | 動作 |
|------|------|
| 全部 work items VERIFIED、無 open blocker/major finding、最後一輪 regression 全套 PASS、Coverage 表無未處理 MISSING、且 checker 明確確認 Goal 已被覆蓋 | Loop 正常結束，dev 向 David 總結（引用 STATE.md evidence + regression summary） |
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
| `docs/REGRESSION-GUARD.md` | bug fix 防護記錄（`RG-XXX`，bug 觸發） | 不取代，互補：`RG-XXX` 記「修過的 bug 不復發」，本 loop 的 `RT-XXX` 記「每個功能都有可開關重跑的 regression test」。bug fix item 兩者都要：RG entry + 掛進開關的 regression test |
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
7. **逐 item 全 VERIFIED 就宣告完成 = 漏了完整性檢查。** Items 是 dev 自己拆的，拆漏了 checker 逐 item 檢查也看不見；最後一輪必須對照 Goal 確認覆蓋。
8. **靜態檢查通過就放行行為可見的改動 = runtime 盲區。** TypeScript / lint 通過不是 runtime 證明；UI / API / CLI 行為改動必須實際跑起來觀察。
9. **Fresh checker 重提已裁決的舊 finding = 假性乒乓。** Step 0 先讀 Resolved Findings；無新證據不得重提。
10. **只看 regression runner 的 exit code = 白裝了日誌。** Runner 可能吞掉失敗、skip 掉測試而 exit 0；checker 必須逐條對賬日誌行和 Coverage 表。
11. **Regression test 斷言實作細節而非用戶可觀察行為** — 重構時大片誤報，dev 為了過檢查開始刪測試，整個 harness 失去公信力。寫測試時就要斷言行為。
12. **Coverage 表只登記不維護** — 功能改名 / 刪除後表沒更新，checker 對賬全是噪音。dev 改動功能時同步維護表。

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
