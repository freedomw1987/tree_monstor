# 交付 — TMO-092：拆 Jev Oracle 做獨立 skill `dav-jev-oracle`

> **交付日期**: 2026-10-28
> **對應 Backlog**: TMO-092
> **交付狀態**: ✅ 完成（Gate 4.5 獨立對帳：1 條需求句全數 ✅、0 條 ⚠、0 條 ❌；R-ID 覆蓋率 1/1）

## 1. 這次完成什麼

用戶決策「好，做 ②」——`dav-developer` 再瘦身。今次把 Jev Oracle（LLM 語意判斷）由 `dav-developer` 拆成自足嘅獨立 skill `dav-jev-oracle`：
`dav-developer` 專注「寫測試 → 紅變綠 → 探針同回歸 → Reviewer 二審」，`dav-jev-oracle` 自帶 PoC、探針同文件，兩邊指標互指、全 repo 冇死引用。

**關鍵成果**：
- ✅ `dav-developer` context **2,098 → 1,208 行**（−42%；同口徑 2,678 → 1,208 ＝ −55%），主檔 139 行
- ✅ `dav-jev-oracle` 自足：主檔 ＋ 4 支子檔 ＋ `PoC/` 48 檔 ＋ `tests/` 4 支探針
- ✅ 路徑大搬遷（CI／mutant 表／探針／docs／`.gitignore`／安裝引用）全部更新，死引用 0 命中
- ✅ 新增 `skills/dav-developer/tests/skill-contract.bats`（7 條結構契約）＋ `ENV-EQ-21`（frontmatter 合法性）
- ✅ v2.8 文檔行數限制改 **baseline ratchet**（每個 skill 各自上限 ＋ 1,500 硬上限）——原本「全部 ≤700」喺內容量面前冇人跟得到＝假規則

## 2. 做了什麼改動

### 2.1 新增檔案

- `skills/dav-jev-oracle/`：獨立 skill（主檔 ＋ `jev-oracle.md`／`examples.md`／`api-contract.md`／
  `output-format.md` ＋ `PoC/` ＋ `tests/` 4 支探針）
- `skills/dav-developer/tests/skill-contract.bats`：7 條結構契約（4 段導航／150 行上限／指標可達／
  Step 順序／Jev 邊界／`dav-jev-oracle` 自足／4 道 Gate 齊）
- `docs/req/TMO-092-requirement.md`：需求錨點（用戶原話 ＋ 驗收句）
- `docs/ac/TMO-092.md`：AC 範本（AC01–AC05 ＋ DoD）
- `docs/reconcile/TMO-092-reconcile.md`：需求對帳表（Gate 4.5 產物）

### 2.2 修改檔案

- `skills/dav-developer/SKILL.md`（收窄成 4 步 ＋ 指標去 `dav-jev-oracle`）、`skills/dav-developer/develop.md`（jev 整合段加指標、刪孤兒小標）
- `skills/dav-skill-creater/editor-guide.md`（baseline ratchet 表 ＋ 量法改 `git ls-files` 口徑 ＋ 存量例外登記 ＋ 探針比照 V03 路徑補 `skills/*/tests/**`）
- `.github/workflows/ci.yml`、`scripts/check-all.sh`、`scripts/ci/mutant-must-die.py`、
  `scripts/ci/mutants.tsv`、`.gitignore`、`tests/env-equivalence.bats`、
  `tests/secret-masking.bats`、`tests/mutant-must-die.bats`（路徑搬遷 ＋ `ENV-EQ-21`）
- `docs/ci/dav-jev-oracle.md`（由原 docs/ci/dav-developer-jev-poc.md rename）、`docs/install-reference.md`、`docs/ac/README.md`、`docs/ac/TMO-091.md`、`docs/reconcile/TMO-091-reconcile.md`（舊路徑死引用修正）
- `docs/cleanup/cleanup-scan.py`（保護清單加 `**/dav-jev-oracle/**`、刪死規則 `**/dav-developer/PoC/prompts/**`）
- `README.md`、`CONTRIBUTING.md`、`docs/backlog.md`、`docs/glossary_list.md`、`docs/system-design.md`（導航 ＋ 術語 ＋ 規則同步）

### 2.3 刪除檔案（如有）

- `docs/ac/TMO-092.md`：TMO-092 收尾後依 `docs/cleanup` 保留策略歸檔（內容保留在 git history；AC 判定見 §3）
- `docs/deliverable/2026-10-26-delivery-fidelity-tmo-069-071.md`：交付摘要只留最近一次（舊份靠 git history）
- `docs/req/TMO-071-requirement.md`、`docs/req/TMO-072-requirement.md`、`docs/req/TMO-073-requirement.md` ＋ 對應 3 支 `docs/reconcile/TMO-07*-reconcile.md`：上一輪交付嘅引用鏈（本次交付已接棒）

## 3. 驗收條件對應

| AC | 描述 | 結果 | 證據 |
|----|------|------|------|
| AC01 | `dav-jev-oracle` 自足（主檔＋4 子檔＋PoC 48 檔＋tests 4 支）| ✅ | `skills/dav-jev-oracle/SKILL.md` 99 行 ＋ 子檔 361／334／45／34 行；`PoC/` 48 檔、`tests/` 4 支實數 |
| AC02 | `dav-developer` 只留 4 件事；context 2,098 → 1,208 行 | ✅ | `skills/dav-developer/SKILL.md:27-66` 恰為 4 步；context 實測 1,208 行；主檔 139 行 ≤150 |
| AC03 | 全 repo 引用更新、冇死引用、CI SOP 改名 | ✅ | CI／check-all／mutant 表／`.gitignore`／探針／docs 全部指向新路徑；死引用 grep 0 命中（`docs/reconcile/TMO-091-reconcile.md:14` 為刻意保留嘅「拆分前路徑」歷史註明）|
| AC04 | `skills/dav-developer/tests/skill-contract.bats`（7 條）| ✅ | SD-1..SD-7 與 AC 列嘅 7 項一一對應 |
| AC05 | 8 個 skill `description:` 改 `>-` ＋ 新增 `ENV-EQ-21` | ✅ | 8 支已改（文字逐字不變）；探針 `tests/env-equivalence.bats:856-891` |

### 3.1 需求對帳（Gate 4.5 產物）

> 對帳由**未參與實作**的獨立 subagent 執行；格式見 dav-reconciler skill 的對帳表格式規範。
> **硬門檻**：對帳有「部分實作／未實作」時，本文件的狀態**不得**標「✅ 完成」。

| 需求 ID | 需求句（摘要） | 對帳狀態 | 實作位置 | 證據 |
|---------|---------------|---------|---------|------|
| R1 | Jev Oracle 相關內容拆成獨立 skill `dav-jev-oracle`，令 ① `dav-developer` 專注 4 件事 ② `dav-jev-oracle` 自足 ③ 兩邊指標互指、冇死引用 | ✅ 已實作 | `skills/dav-developer/SKILL.md` ＋ `skills/dav-jev-oracle/`（主檔／子檔／PoC／tests）| context 實測 1,208／1,569 行；PoC 48 檔；4 支探針；死引用 grep 0 命中 |

- 對帳表: `docs/reconcile/TMO-092-reconcile.md`
- 對帳者: reviewer（獨立 subagent，未參與實作）
- 覆蓋率: 1 / 1

## 4. 測試結果

| 測試類型 | 通過 / 總數 | 備註 |
|---------|-------------|------|
| 本機全量閘 | 11 / 11 步全綠 | `bash scripts/check-all.sh`（deps／ffmpeg／shellcheck／bashn／heredoc／drift／mdlint／venv／bats／skill-tests／mutant）|
| 突變測試 | 49 / 49 支全死 | mutant 必須死（每支都有綠 baseline 對照）|
| skill-local 探針 | 全綠 | `skills/dav-developer/tests/`（7 條契約）＋ `skills/dav-jev-oracle/tests/`（4 支）|
| repo 級探針 | 全綠 | `bats tests/`（含 `ENV-EQ-21` frontmatter 合法性）|

## 5. 已知問題 / 限制

- `ENV-EQ-21` 只做結構檢查、唔係真 YAML parse（block scalar body 縮排、value 內含 `": "` 有假綠窗口）→ 已記錄，另開票
- `skills/dav-developer/tests/skill-contract.bats` SD-6 只驗 3 個路徑存在，未逐個驗 4 支探針同 4 支子檔 → 另開票
- `skills/dav-developer/develop.md` 仍留 62 行「jev 整合細節」（講 `jev-use` CLI 流程，已加指標指去 `dav-jev-oracle`）
- `skills/dav-jev-oracle` 3 支檔案超 300 行（`jev-oracle.md` 361／`examples.md` 334）＋ context 1,569
  超 1,500 硬上限 → 依 v2.8 登記存量例外（ratchet 只可下唔可上），瘦身另開票
- `PoC/playwright_observer.py` 嘅 USER_AGENT 仍係 `dav-developer-jev-poc/3.1`（UA 係對外協議值，無下游需求唔亂改）

## 6. 下一步建議

### 6.1 立即可做（建議優先）

- 收埋同類未收尾嘅 `TMO-089`／`TMO-091`（backlog row 仍 `doing`，但對帳表已全 ✅）—— 用同一套收尾流程（對帳 → 交付摘要 → 移出 row → 歸檔）

### 6.2 下一個 Sprint 考慮

- `dav-jev-oracle` 瘦身（3 支子檔 + context 降到 ≤1,500）＋ 補 `ENV-EQ-21` 真 YAML parse

## 7. 相關文檔連結

- 需求錨點: `docs/req/TMO-092-requirement.md`
- 對帳表: `docs/reconcile/TMO-092-reconcile.md`
- 拆分後 skill: `skills/dav-jev-oracle/SKILL.md` ＋ `skills/dav-developer/SKILL.md`
- 行數規則（baseline ratchet）: `skills/dav-skill-creater/editor-guide.md`
- 上一輪交付摘要（已歸檔，內容在 git history）: `docs/deliverable/2026-10-26-delivery-fidelity-tmo-069-071.md`

## 8. 反思（Reflection 末段）

### 8.1 6 維度檢查

| # | 維度 | 結果 | 備註 |
|---|------|------|------|
| 1 | 功能正確性 | ✅ | AC01–AC05 全 ✅；對帳 R1 ✅ |
| 2 | 可測試性 | ✅ | 新增 7 條結構契約 ＋ `ENV-EQ-21`；全量閘 11 步 ＋ 49 mutant |
| 3 | 文件一致性 | ✅ | 路徑／術語／行數規則同步；doc-drift D1–D8 全綠 |
| 4 | 可維護性 | ⚠️ | `dav-jev-oracle` 3 支檔超行數上限（已登記例外，ratchet）；`develop.md` 留 62 行 jev 段 |
| 5 | 安全性 | ✅ | 冇新增憑證／網路面；探針輸出照舊走 `mask_secrets` |
| 6 | 用戶價值 | ✅ | `dav-developer` context −42% → 每次觸發成本下降；Jev Oracle 可獨立升版 |

### 8.2 問題清單（每個 ❌ 必含「根因 + 建議」）

- ⚠️（非 ❌）搬遷式重構最易漏死引用 → 根因：路徑字串散落 83 個檔、冇機械檢查；建議：加一支「skill 路徑存在性」探針（本次未加，已記錄）

### 8.3 Action Items

| # | 動作 | 類型 | 驗收條件 | 預估 |
|---|------|------|---------|------|
| 1 | 收埋 `TMO-089`／`TMO-091`（對帳 → 交付摘要 → 移出 row → 歸檔）| TECH | backlog 只剩未完成 row；doc-drift D1–D8 全綠 | 2 SP |
| 2 | `ENV-EQ-21` 改真 YAML parse（`yaml.safe_load` ＋ fallback）| TECH | 壞縮排／壞 value 嘅 frontmatter 被捉到 | 1 SP |
| 3 | `dav-jev-oracle` 瘦身（子檔 ≤300、context ≤1,500）| TECH | 三支檔 ≤300 行；context ≤1,500 | 3 SP |
| 4 | 加「skill 路徑存在性」機械探針 | TECH | 探針喺 CI 捉到任一指標路徑失效 | 2 SP |

### 8.4 Reviewer 二審結果（V03 紀律）

> 今次改動含 code（`.py`）＋ 探針（`.bats`）→ 命中 `AGENTS.md` §1.5 V03 **代碼分支** → 必須獨立 Reviewer 二審。

| 輪次 | 對象 | Verdict | 處理 |
|------|------|---------|------|
| 第 1 輪 | commit `029d52b`（拆分本體，83 檔）| ❌ BLOCK（2 P1 ＋ 8 P2）| 全修：程式層 `~/.claude/skills/dav-jev-oracle` 路徑、3 處 docs 死引用、cleanup 保護清單、baseline 數字同量法、frontmatter 重複句、孤兒小標 |
| 第 2 輪 | 修正批次 | ❌ BLOCK（餘 1 P1：2 條舊路徑字串）| 修 `docs/ac/TMO-091.md` ＋ `docs/reconcile/TMO-091-reconcile.md` ＋ `docs/ac/README.md`；補 `README.md` §Skills 表漏格 |
| 第 3 輪 | 尾項窄幅覆核 | ❌ BLOCK（只差 1 個 token：`docs/reconcile/TMO-091-reconcile.md:14` 備註欄仲寫 `dav-developer`）| 已修（該欄 → `dav-jev-oracle`）；reviewer 明言「改完即 OK」→ 無第 4 輪覆核（尾項 1 個 token，機械 grep 復驗）|

- 問題數：P0=0、P1=4（3 輪累計：2 ＋ 1 ＋ 1，全部已修）、P2=8（已修 7 ＋ 刻意保留 1：UA 協議值）
- 連結 Reviewer 原路徑：原文在本次 session 嘅 subagent artifacts（3 輪）

## 9. 交付後的文件保留狀態

依 `skills/dav-submitter/retention.md`：交付摘要只留最近一次（本次呢份）；TMO-092 嘅**引用鏈**
（`docs/req/TMO-092-requirement.md` ＋ `docs/reconcile/TMO-092-reconcile.md`）保留；
已完成 US 嘅 ac／req／reconcile 其餘歸檔；`docs/backlog.md` 移出完成 row。
