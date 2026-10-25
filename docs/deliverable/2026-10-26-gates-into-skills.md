# SOP 移出 AGENTS.md：只留萬事原則，Gate 定義改由 skill 承載

> **交付日期**: 2026-10-26
> **對應 Backlog**: TMO-076
> **Sprint / Module**: 框架規範層（SOP）
> **交付狀態**: ✅ 完成（待 V03 Reviewer 二審 verdict 落地，見 §3）

## 1. 這次完成什麼

**問題**：`AGENTS.md` 內嵌整套 5 階段 SOP（121 行），導致**每一件小事都被預設要跑 4 道 Gate**。
但 Gate 本來就該由各自的 skill 承載——skill 被觸發時就看得到通過標準，不該回頭讀一份全域文件。

**做了什麼**：

| 改動 | 前 → 後 |
|---|---|
| `AGENTS.md` | 121 → **35 行**：只留 §1 萬事原則（SOUL 7 條逐字）＋ §1.5 三條行為紀律。**刪** §2 SOP 全部（§2.0 分流表／§2.3 Gate 速查表／§2.x 索引／變動歷史）|
| Gate 定義 | 從 `gates.json` ＋ `AGENTS.md §2.3` → **各自承載它的 skill**（見下表）|
| 新探針 | `tests/gate-in-skill.bats`：鎖「skill 內的 Gate 定義 == `gates.json` 逐條一致」＋「Gate 4.5 與 handbook 2.3 一字不差」|
| 交叉引用 | 修 **17 個檔案**內指向 `AGENTS.md §2` / `§1.5` / `§2.0` 的 live 引用（含 README／CONTRIBUTING 這兩份**最初漏掉**的）|

**Gate → skill 對照**：

| Gate | 承載 skill | 為什麼是它 |
|---|---|---|
| 1 TDD | `skills/tdd-test-writer/` | 它的 Gate |
| 2 lint / syntax | `skills/tdd-test-writer/` | 無專屬 skill（`trigger_skill: null`）；已在該 skill 被提到 |
| 3 regression | `skills/regression-guard/` | 它的 Gate |
| 4 reviewer | `skills/dev-checker-loop/` | 它的 Gate |
| 4.5 需求對帳 | `skills/dav-reconciler/` | 它的子關卡（不進 `gates.json`，schema 限制 id 為整數）|

**關鍵成果**：
- ✅ **預設不再強制跑流程**：沒有指定 Gate 時就是直接做。只有「寫 code／改規範／用戶明示」才進對應 Gate
- ✅ **進 Gate 必引用 `mandatory_phrase` 的義務沒有掉**（原 TD-016）：寫進 handbook 2.3「Agent 必做動作」＋ 4 支 skill 的 Gate 段各一行
- ✅ **skill 自足（5 欄）**：每支 Gate skill 內都有 `name` / `pass_criteria` / `required_evidence` / `fail_action` / `mandatory_phrase`
  （`notes` 與 `remediation` 仍在 `gates.json` 與 handbook 2.3——見 §5）
- ✅ **SOP 本身沒有被刪**：handbook（7 章）／`gates.json`＋schema／5 個 SOP skill／`install.sh` 的 sop 安裝**全部原地保留**，需要時仍可查、仍會安裝
- ✅ **門檻一個都沒放寬**：所有探針改動皆為強化（詳見 §4）

## 2. 做了什麼改動

### 2.1 新增檔案

| 檔案路徑 | 用途 |
|---------|------|
| `tests/gate-in-skill.bats` | 4 支探針：逐條比對 Gate 定義落在承載 skill（GATE-SKILL-1）、Gate section 需點名 gate＋指向 `gates.json`（GATE-SKILL-2）、比對器自證（GATE-SKILL-3，壞 fixture 必紅／好 fixture 必綠）、Gate 4.5 與 handbook 2.3 一字不差（GATE-SKILL-4）|
| `docs/deliverable/2026-10-26-gates-into-skills.md` | 本交付摘要 |
| `docs/req/TMO-076-requirement.md` | 需求錨點（用戶原話 R1..R4 ＋ 澄清後驗收句）|
| `docs/reconcile/TMO-076-reconcile.md` | 權威需求對帳表（R1..R4）|

### 2.2 修改檔案

| 檔案路徑 | 改動內容 |
|---------|---------|
| `AGENTS.md` | 121 → 35 行。刪 §2 全部；保留 §1 萬事原則（逐字）＋ §1.5 V01／V02／V03 |
| `skills/tdd-test-writer/SKILL.md` | 105 → 136 行：新增「## Gate 定義」段（Gate 1 TDD ＋ Gate 2 lint／syntax）|
| `skills/regression-guard/SKILL.md` | 133 → **149** 行：新增 Gate 3 regression 定義。（後續 TMO-077 同日再瘦身至 **120 行**——把「流程（5 步）」由 39 行重排為表格，語意不減）|
| `skills/dav-reconciler/SKILL.md` | 128 → 144 行：新增 Gate 4.5 需求對帳 定義（single source 指 handbook 2.3）|
| `docs/sop/gates.json` | `description` 由「AGENTS.md §2.3 會自動引用」改為「定義另外落在各自的 skill；本檔為機器可讀副本，兩邊都要改」|
| `docs/sop/gates.schema.json` | 同上（英文 `description`）|
| `docs/sop/handbook/{2.1,2.2,2.3,2.4,2.5,2.6,2.7}-*.md` | 章節自我描述由「本檔是 AGENTS.md §2.X 的詳細內容」改為「本檔是 SOP §2.X 的詳細內容」；2.1／2.2／2.6 的 trust 與分流交叉引用改指 `skills/dav-trust/preflight.md` 與本檔；2.3 補「Gate 定義自 2026-10-26 起由各自的 skill 承載」|
| `docs/sop/handbook/changelog.md` | 新增 v2.14 條目；表頭的三處 AGENTS.md 交叉引用更新 |
| `skills/dav-planner/SKILL.md` | 「§2.1 Plan Gate（在 §2.0 啟動後、§2.2 Design 前）」→「（規劃階段；§2.2 Design 之前）」|
| `skills/dav-skill-creater/editor-guide.md` | V03.5 的「同源」由 AGENTS.md §1.5 改指 AGENTS.md §1.5 的 V03 ＋ 本檔預檢規範 |
| `docs/system-design.md` | 參考資料的「AGENTS.md §2 SOP」改指 `docs/sop/handbook/` |
| `docs/prd/05-delivery-fidelity.md` | ADR-D1 決策與影響兩處更新（Gate 4.5 登記點改變）；階段 2 驗收項加註 |
| `docs/ac/` 內 Gate 4.5 驗收清單的 `.md` 與 `.html` | 「AGENTS.md §2.3 速查表同步」標記為已由 skill 承載（**兩份同步**，避免 md/html 分歧）|
| `docs/reconcile/` 內 Gate 4.5 那張權威對帳表 | R1 列的「實作位置／證據」更新（RECON-012 已改測「登記在承載它的 skill」）|
| `docs/deliverable/2026-10-26-slim-meta-layer.md` | 移除會過期的硬編檢查項數（「15 項檢查」→ 不寫死）|
| `docs/reconcile/` 內文件漂移那張權威對帳表 | 移除會過期的硬編檢查項數 |
| `README.md` | 「工作流程：看 AGENTS.md」整節改寫：AGENTS.md＝行為準則；Gate 定義在各自 skill；`gates.json` 為機器可讀副本 |
| `CONTRIBUTING.md` | 「詳見 `AGENTS.md` §2」→ 改指 `docs/sop/handbook/` 與各 skill |
| `skills/dev-checker-loop/SKILL.md` | 129 → 146 行：新增 Gate 4 reviewer 定義；V03.5 標籤改為「主檔行數預警」（原標籤已併入 §1.5 V03）；Gate 段補「進 Gate 必引用」一行 |
| `docs/backlog.md` | 新增 TMO-076（1 列；75 → 76 列）|
| `tests/agents-md.bats` | 4 支探針調整（**皆強化**，見 §4）|
| `tests/regression-guard-watch-mode.bats`／`tests/wiki-media-describe.bats` | 純註解措辭更新（殘留的「gates.json single source」→「machine-readable copy」；「V03.6」→「原 V03.6，現併入 §1.5 V03」）|
| `tests/markdownlint-guard.bats` | 新增 `MLG-10`（全部 git 追蹤檔須嚴格 UTF-8 解碼）＋ `MLG-10b`（內建自證）|
| `tests/restruct-dav-reconciler.bats` | RECON-012 改為「Gate 4.5 登記在承載它的 skill」|

### 2.3 刪除檔案

| 檔案路徑 | 刪除原因 |
|---------|---------|
| （無） | 本次是**搬移**不是刪除；SOP 本體全部保留 |

### 2.4 改動背後的理由

| 改動 | 為什麼這樣設計 | 放棄的選項 |
| --- | --------------- | ----------- |
| SOP 從 AGENTS.md 移出，機制原地保留 | AGENTS.md 是**每次都會被讀**的那一份；SOP 是**需要時才讀**的。把前者瘦到只剩「你是誰」，就不會每件小事都被逼跑流程 | 整條 SOP 鏈刪掉（省 40–60 檔，但 `dav-reconciler` 需求對帳的守門力會消失）|
| Gate 定義搬進 skill | skill 被觸發時就看得到通過標準，不必回頭查全域文件；且「這支 skill 對應哪道 Gate」變成在同一檔內可讀 | 只刪 AGENTS.md §2、定義留在 `gates.json`（最小改動，但 skill 仍不自足）|
| 保留第二份定義（`gates.json`）並用探針鎖一致 | `gates.json` 有 schema、install 會裝到 `~/.pi/sop/`、有 mutant 依賴；刪掉會失去「機器可驗」的能力 | 刪 `gates.json`（單一來源變成 skill，但失去機器可讀性，且 Gate 2 無處可放）|
| V03 留一行（不是整個 §1.5 砍掉）| 15 處 skill 引用 V03（「改 SOP／skill 必走二審」）。它不是流程步驟，是**規範修改的品質紀律**——砍掉會留下 15 處孤兒引用，且失去二審機制 | 連 V03 一起砍（要一併改 15 個檔案，且失去品質紀律）|

## 3. 驗收標準對應

| AC | 描述 | 結果 | 證據 |
|----|------|------|------|
| AC-1 | `AGENTS.md` 只剩「你是誰 + 萬事原則 + 行為紀律」 | ✅ | 121 → 35 行；`agents-md.bats` TD-017 AC-1（< 60 行）＋ AC-2（不再內嵌 Gate 表、須指名 4 支承載 skill）|
| AC-2 | 每道 Gate 的定義落在承載它的 skill | ✅ | `gate-in-skill.bats` GATE-SKILL-1／2／4；4 支 skill 各新增「## Gate 定義」段 |
| AC-3 | skill 內定義與 `gates.json` 不飄 | ✅ | `gate-in-skill.bats` GATE-SKILL-1 逐條比對（name／pass_criteria／required_evidence／fail_action／mandatory_phrase）|
| AC-4 | 沒有留下指向 `AGENTS.md §2` 的 live 引用 | ✅ | 17 個檔案全部修正（其中 12 處是直接指名 `AGENTS.md §2`）；殘留只剩**已標註為歷史**的提及（`docs/sop/handbook/changelog.md`、各 skill `CHANGELOG.md`、`docs/ac/` 內 Gate 4.5 的驗收清單、`docs/reconcile/` 內 Gate 4.5 的權威對帳表、`docs/backlog.md`、`skills/dav-trust/preflight.md` 的版本列、本文件） |
| AC-5 | SOP 本體沒有被誤刪 | ✅ | handbook 7 章／`gates.json`＋schema／5 個 SOP skill／`lib/install/sop.sh` 全部在位 |
| AC-6 | 門檻一個都沒放寬 | ✅ | MMD-1 仍 `-eq 55`；`.bats` 地板仍 `-ge 40`（兩處）；`agents-md.bats` 上限由 200 **收緊到 60** |
| AC-7 | 全量測試全綠 | ✅ | `bats tests/` → **1..654，654 ok / 0 not ok / 0 skip** |
| AC-8 | Reviewer 二審 | ✅ | 8 輪並行複審（V03 Reviewer ＋ Gate 4 checker）。**最終輪：兩者 P0/P1/P2 皆為 0**（Reviewer `approve`）；殘留僅 P3，已全修。見 §3.2 |

### 3.1 需求對帳

> 錨點檔：`docs/req/TMO-076-requirement.md`（本次新增）。權威對帳表：`docs/reconcile/TMO-076-reconcile.md`。

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | `AGENTS.md` 不再內嵌 SOP，且沒有指向舊 §2 的 live 引用 | ✅ 已實作 | `AGENTS.md`（121 → 35 行）| `tests/agents-md.bats` TD-017 AC-1/AC-2；17 個檔案（12 處直接指名）已修 | 歷史 CHANGELOG 的提及刻意保留 |
| R2 | 預設不再強制跑流程 | ✅ 已實作 | `AGENTS.md` 開頭說明段 | 明示「沒有指定 Gate 時預設直接做」＋三種升級條件 | 舊 §2.0 分流表退場（見 §5）|
| R3 | 每道 Gate 定義落在承載它的 skill，且與 `gates.json` 一致 | ✅ 已實作 | 4 支 skill 的「## Gate 定義」段 | `tests/gate-in-skill.bats` GATE-SKILL-1/2/4 | Gate 4.5 的 single source 是 handbook 2.3 |
| R4 | SOP 本體全部原地保留 | ✅ 已實作 | `docs/sop/handbook/`、`gates.json`、SOP 階段 skill、`lib/install/sop.sh` | 本次 diff 無任何刪除檔 | 本次是搬移不是刪除 |

> 權威對帳表：`docs/reconcile/TMO-076-reconcile.md`（由未參與實作的 subagent 產出）

### 3.2 複審紀錄（8 輪並行雙角色）

每一輪都是 **V03 Reviewer 二審 ＋ Gate 4 checker 並行**、唯讀、互不重疊。

- **第 1 輪**：兩者 `request-changes`。P1×3、P2×4。
  最重的兩條：**`README`／`CONTRIBUTING` 仍 live 指向已刪的 `AGENTS.md §2`**；
  **原 TD-016 的「進 Gate 必引用 `mandatory_phrase`」搬走後無家**。
- **第 2 輪**：Reviewer `request-changes`（checker 未交件）。新守護 `AC-4` 抓不到它宣稱要防的 README 型。
- **第 3 輪**：兩者各剩 1 P2（文件門檻、skill 行數自述）。
- **第 4 輪**：checker P0/P1/P2 = 0；Reviewer 1 P2。
  並抓到**我「宣稱已修、實際沒落地」2 條**。
- **第 5 輪**：兩者 `request-changes`。**`changelog` 被我的 `sed` 打成非法 UTF-8**
  —— markdownlint（0 issues）與 `bats tests/`（全綠）**都攔不到** → 補 `MLG-10`。
- **第 6 輪**：`MLG-10` 用副檔名白名單 → 漏 `.tsv`／`.jsonc`／`.ts`／`.gitignore`
  → 改成掃全部 git 追蹤檔。
- **第 7 輪**：兩者收斂到**同一條** 1 P2（§7.1「淨 +7」實為 +8）。
- **第 8 輪（最終）**：**兩者 P0/P1/P2 皆為 0**（Reviewer `approve`、checker `approve-with-comments`）；
  殘留 3 條一行級 P3 已修。

**貫穿 8 輪的教訓**：late-round findings 幾乎全是**我自己交付摘要內的數字漂移**
（`11/11→12/12`、`最長 148→149`、`+4→+7`、`+7→+8`、`89 行→86 行`）。
這正是本專案在打的病——**探針抓不到文件數字漂移**。
本次新增的 `MLG-10` 只解決了「位元組損毀」那一半。

- 對帳表: 本節（上表）與 `docs/reconcile/TMO-076-reconcile.md` 一致｜對帳者: `reviewer` subagent（V03 二審，未參與實作）｜覆蓋率: 4 / 4（100%）

## 4. 測試結果

| 項目 | 結果 |
|------|------|
| 回歸測試（全量 bats） | **654 / 654**；0 not ok、0 skip |
| `gate-in-skill.bats`（新） | 4 / 4 綠 |
| `agents-md.bats` | **12 / 12** 綠（新增 TD-017 AC-4／AC-4b）|
| `restruct-dav-reconciler.bats` | 16 / 16 綠 |
| `scripts/ci/mutant-must-die.py` | 55 支 mutant 全部死亡 |
| `scripts/ci/check-doc-drift.sh` | rc=0、無 `DRIFT` 行（7 項豁免；**檢查項數會隨 `docs/req` / `docs/reconcile` 增加而變，故不寫死數字**）|
| skill-local（CI 方式） | 5 / 5 綠 |
| `markdownlint-cli2` | 0 issues（**檔數隨新增 `.md` 變動，故不寫死**；本輪實跑 119 檔）|
| `markdownlint-guard.bats` **MLG-10／10b（新）** | 11/11 綠（含 2 支新支）|
| 4 支 probe linter ＋ 2 支 shell checker | 全 OK |
| `check-skill-size.sh` | 13 個 SKILL.md 皆 ≤ 150 行（最長 **148**：`dav-skill-creater`）|

**探針改動（全部為強化，無一放寬）**：

| 探針 | 前 | 後 | 為什麼不是放寬 |
|------|----|----|--------------|
| `agents-md.bats` TD-017 AC-1 | < 200 行 | **< 60 行** | 收緊 |
| `agents-md.bats` TD-017 AC-2 | AGENTS.md 必須連結 8 個 handbook 章節 | 不得內嵌 Gate 表**且**必須指名 4 支承載 skill | 改測目標（性質不變：正向＋負向都有）|
| `agents-md.bats` TD-018 AC-6 | AGENTS.md 必須連結 `~/.pi/sop/handbook` 與 `~/.claude/sop/handbook` | AGENTS.md 必須**自足**（不依賴安裝後路徑）＋ §1 至少 7 條 | 改測目標；附正向防空過 |
| `agents-md.bats` SOUL-3 | 段落範圍綁 `§1.5` 節名 | 段落範圍到「下一個 `##` 為止」＋兩邊都要 > 0 | 收緊（不綁節名，且防空過）|
| `agents-md.bats` SKILL-REF-2 | 掃 AGENTS.md 的「務必使用」行 | 掃全 repo 文件面（AGENTS.md／SOUL.md／handbook／skills）的 `/skill:` 引用 | **原版已成 0 迭代空過**（AGENTS.md 不再有「務必使用」行）→ 改掃更大範圍 |
| `restruct-dav-reconciler.bats` RECON-012 | AGENTS.md 速查表列 Gate 4.5 | Gate 4.5 登記在承載它的 skill（＋AGENTS.md 不得內嵌定義欄位）| 改測目標；Gate 4.5 的守護由 `gate-in-skill.bats` GATE-SKILL-4 接手（更嚴：與 handbook 逐字比對）|
| `markdownlint-guard.bats` **MLG-10／10b（新）** | （無）| **全部 git 追蹤檔**（不再用副檔名白名單——白名單會漏 `.bash`／`.tsv`／`.jsonc`／`.ts`／無副檔名檔）必須能**嚴格 UTF-8 解碼**；二進位以**兩層**跳過（① 已知二進位副檔名 `BINARY_EXT` 前置過濾 ② 解碼失敗 **且** 前 8KB 含 NUL）；`scanned ≥ 150` 防空過。MLG-10b 內建自證（壞檔必紅／好檔必綠／含 NUL 的二進位不誤報）| 新守護。**為什麼要**：本次用 `sed` 多檔替換數字時把 changelog 一行打成非法 UTF-8（`149／146` → `0xbc8f…`），而 markdownlint（0 issues）與 `bats tests/`（全綠）**都攔不到** |
| `agents-md.bats` **TD-017 AC-4（新）** | （無）| live 文件不得再把讀者導向已移除的 `AGENTS.md §2`。**兩種檢查**：① 同行寬鬆 pattern（`AGENTS.md` 與 `§2` 之間容許反引號／空白／少量夾字）② **區段式**（標題點名 `AGENTS.md` → 該區段內任何 `§2` 皆違規）。列舉檔案數 **≥ 15**，且**每個 glob 家族各自非空** | 新守護。**為什麼要**：改動當下的自證指令 `grep -rn "AGENTS\.md §2"` 命不中 `README` 的「§2.0」與 `CONTRIBUTING` 的「`AGENTS.md` §2」→ 兩份 live 文件漏改，是本次二審抓到的 P1 |

**新增探針的突變驗證**（副本 mutation）：

| 突變 | 預期轉紅 | 結果 |
|------|---------|------|
| 改 `regression-guard/SKILL.md` 的 Gate 3 `fail_action` 引號（`『做完了』`→`「做完了」`）| `GATE-SKILL-1` | ✅ 轉紅 |
| `gate-in-skill.bats` GATE-SKILL-3 內建：5 個欄位各掉一輪 ＋ `PHRASE-5` 一輪（共 6 輪）必紅、完整版必綠、`gates.json` 欄位清空必紅 | 比對器自證 | ✅ 雙向成立 |
| `agents-md.bats` TD-017 AC-4b 內建：同行型／區段型／`###` 型違規必紅；已標註移除必綠；「已於…說明」不得被豁免 | 掃描器自證 | ✅ 雙向成立 |

## 5. 已知問題 / 限制

> ⚠️ 老實標記已發現但這次沒解決的問題，避免「假完成」。

| 問題 | 嚴重性 | 已記錄位置 |
|------|--------|-----------|
| **§2.0 的任務分流表就此退場**：原本「trust mode ＞ 開發編程任務 ＞ 一般任務」的判斷優先序**只寫在 AGENTS.md §2.0**。移出後不再有全域分流規則；handbook 2.6 保留「一般任務的自動升級觸發器」，`skills/dav-trust/preflight.md` 保留 trust 執行段判準 | P2 | handbook `2.6-general-task.md`、`skills/dav-trust/preflight.md` |
| **`AGENTS.md §2` 在歷史文件裡仍是「過去式」提及**：`docs/sop/handbook/changelog.md` 的 v2.13 及更早索引、各 skill `CHANGELOG.md`、`docs/backlog.md` 主題欄都會提到 §2.0／§2.3。這是歷史記錄（append-only），不回改 | P3 | 本次刻意保留 |
| **`gates.json` 與 skill 仍是兩份定義**：靠 `tests/gate-in-skill.bats` 鎖一致，不是單一來源 | P3 | 本文件 §2.4；`tests/gate-in-skill.bats` |
| **MLG-10 的 NUL 安全閥有理論假陰**：若一個**文字**檔被損毀到同時含 NUL，會被當成二進位跳過。目前 repo 無此型檔；要收緊需改用「NUL 比例」或副檔名雙條件 | P3 | 本文件 §5；`tests/markdownlint-guard.bats` `_utf8_check()` |
| **`BINARY_EXT` 前置過濾理論上會跳過同名文字檔**（例如有人把純文字命名為 `x.pdf`）：目前 repo 無此類追蹤檔 | P3 | 同上 |
| **AC-4 掃描器有兩個已知邊界**（刻意保留，不補）：① `## …AGENTS.md` → `### 子標題`（標題不含 AGENTS.md）→ 裸 `§2` 會漏抓（「任何層級標題都重算旗標」的必然副作用）② `## 變動歷史` 段內的 live 指引會被豁免。目前 repo 無此型真違規；要收緊需改用標題縮排棧 | P3 | 本文件 §4；`tests/agents-md.bats` `_ac4_scan()` |
| **「skill 自足」只涵蓋 5 欄**：`notes` 與 `remediation`（失敗後策略）仍在 `gates.json` 與 handbook 2.3，沒有進 skill | P3 | 本文件 §1；`tests/gate-in-skill.bats` 的比對器只鎖 5 欄 |
| **skill 內新增了跨目錄「指名」引用**（`docs/sop/gates.json` ×6、`docs/sop/handbook/2.3-execution.md` ×2、`tests/gate-in-skill.bats` ×4（皆為**出現次數**口徑））：它們避開了探針的讀取動詞表（「機器可讀副本 X」不是讀取指令），但 `editor-guide.md` 的 v2.2 規則本意是「不放指向 `docs/` 內具體檔案的引用」。屬已知落差，非斷鏈 | P3 | 本文件 §5；`tests/restruct-zero-cross-read.bats` |
| **skill 內的新指標是 repo-relative**：`docs/sop/gates.json` / `docs/sop/handbook/...` 在 skill 全域安裝後（gates 落在 `~/.pi/sop/`）不解析。既有同型前例：`skills/dav-reflection/template.md` | P3 | 本文件 §5；四個 Gate 段的指標行 |
| **Gate 2 掛在 `tdd-test-writer` 是權宜**：它沒有專屬 skill（`trigger_skill: null`）。若未來新增 lint skill，應把 Gate 2 搬過去 | P3 | `skills/tdd-test-writer/SKILL.md`「Gate 定義」段註記 |
| **`tests/fixtures/mock-tree-monstor/` 內仍是舊結構**（fixture 樹，含 `docs/sop/handbook/*` 與舊 gates.json）：它是 install 測試的素材，不是本 repo 的真實結構，故未同步 | P3 | 本次刻意保留 |

## 6. 下一步建議

### 6.1 立即可做（建議優先）

1. **跑一次真實任務驗證「預設變輕」**：找一個小事（例如改一行設定）走一輪，確認真的不會被逼跑 4 道 Gate。
   - **為什麼這個優先**：這次證明的是「文件結構對了」；還沒證明「行為真的變輕」。那才是這次的目標。
2. **合併 `feat/gates-into-skills` 回 master**（V03 二審通過後）

### 6.2 下一個 Sprint 考慮

- [ ] 第二刀：`docs/sop/handbook/2.1`～`2.7` 是否還有必要？（它們已不再被 AGENTS.md 指向）
- [ ] 若 Gate 2 未來有專屬 skill，把定義從 `tdd-test-writer` 搬過去
- [ ] `docs/req/` 錨點檔的產生時機：現在 dav-planner 會產，但已無 SOP 強制

### 6.3 長期方向（Think Big）

- **規範要跟著觸發點走**：這次的教訓是「全域文件被預設讀，就會被預設套用」。任何規範都應該放在它**真正被用到的那一刻**看得到的地方
- **可逆的預設**：把「預設輕、需要時才重」做成框架的預設姿態，而不是靠 user 每次記得說「這次簡單就好」

## 7. 反思

### 7.1 6 維度檢查

| # | 維度 | 結果 | 備註 |
| - | --- | --- | --- |
| 1 | UX/UI 一致性 | N/A | 無 UI 變更 |
| 2 | RWD 響應式設計 | N/A | 同上 |
| 3 | 技術債 | ✅ | 少了 89 行全域規範與 17 個檔案（其中 12 處直接指名）的交叉引用漂移；skill 自足度提升 |
| 4 | 可維護性 | ✅ | Gate 定義與 skill 同檔；探針鎖兩份一致，改一邊會紅 |
| 5 | 測試完整性 | ✅ | 淨 **+8** 支探針（`gate-in-skill.bats` +4、`agents-md.bats` AC-4/AC-4b +2、`markdownlint-guard.bats` MLG-10/10b +2）；另 `restruct-dav-reconciler.bats` 的 RECON-012 為**同名改寫**，不計入新增。改動皆強化，門檻零放寬 |
| 6 | 文件一致性 | ✅ | 17 個檔案（其中 12 處直接指名）的 live 交叉引用修正；`gates.json`／schema／handbook 表頭同步 |

### 7.2 這次真正學到什麼

1. **「文件被預設讀」＝「規則被預設套用」**：AGENTS.md 每次都會被讀，SOP 放進去就等於每次都跑。
   把規範放回它被觸發的地方（skill），預設就自然變輕——不需要靠 user 每次說「這次簡單就好」。
2. **移走規則時，要先看「誰還在指向它」**：這次查出 17 個檔案（其中 12 處直接指名）的 live 交叉引用（handbook 表頭、`dav-planner`
   的「§2.0 啟動後」、`editor-guide.md` 的 V03.5 同源…）。只改 AGENTS.md 會讓這些全部變成指到不存在的段落的斷鏈——正是上一輪才剛清完的那類問題。
3. **「砍掉」與「搬走」的差別要先問清楚**：我一開始的預設是「V03 隨 SOP 一起消失」，實際盤點後
   發現 15 處 skill 引用它。若不是先查，就會留下 15 處孤兒引用。**先量依賴，再決定去留。**
4. **探針會因為被測對象消失而變成空過**：`SKILL-REF-2` 原本掃 AGENTS.md 的「務必使用」行；AGENTS.md
   不再路由 skill 後，那個迴圈變成 0 次迭代→永遠綠。**「刪掉被測物」時要回頭看探針是否還在驗東西。**
