# 框架 Context 瘦身 ＋ 體重守門（第二刀 A+D）

> **交付日期**: 2026-10-26
> **對應 Backlog**: TMO-082
> **Sprint / Module**: 框架自我管理層（meta layer）第二刀
> **交付狀態**: ✅ 完成（AC01..AC07 全部達成；V03 二審結論見 §7）
> **錨點**: `docs/req/TMO-082-requirement.md`

---

## 1. 這次完成什麼

TMO-075（第一刀）砍咗框架嘅 **meta 探針層**；但佢自己嘅 §6.2／§6.3 留低嘅未做方向仲喺度。
今次做**第二刀**，兩件事：

- **A（Context 瘦身刀）**：壓縮 13 個 skill 嘅支援檔（`SKILL.md` 以外嘅 `.md`）——
  呢啲係 **agent 每次觸發 skill 要讀落 context** 嘅量（上界：主檔 + 全部支援檔；agent 實際只讀主檔 + 被指標指向嘅子檔）。
  **context 總量（SKILL.md + 支援 .md，唔含 CHANGELOG）：9,619 → 7,413 行（−2,207，−22.9%）**。
- **D（體重守門）**：新增 `scripts/ci/check-framework-weight.py` ＋ `docs/ci/framework-weight.json`
  ＋ `tests/framework-weight.bats`（16 支），守住「唔准再無聲膨脹」。

### 1.2 為什麼做這個改動

**問題/脈絡**：第一刀之後，框架嘅**高頻成本**仍然未處理。量測顯示：
`skills/` 嘅支援檔共 **7,950 行**（唔含 CHANGELOG），而 agent 每次觸發 skill 都要讀其中被點名嘅部分；
最重嘅 `regression-guard` 一個 skill 就 **2,495 行**（主檔只有 120 行）。
同時 TMO-075 §6.3 提出嘅「膨脹率可見」仲係紙上談兵。

**為什麼選這個解法**：先切**高頻成本**（支援檔），唔係治理文件（`system-design.md` 等一次性讀取）；
而且**每刀都配一把尺**（D），令「減完唔會長回來」有機械證明。

**成功怎麼看**：(a) context 成本真係降咗（量測數字）；(b) 零被探針錨定嘅內容契約損失；
(c) 守門喺**壞情境**下真係會紅（唔係「掃唔到就當綠」）。

---

## 2. 做了什麼改動

### 2.1 新增檔案

| 檔案路徑 | 用途 |
|---------|------|
| `scripts/ci/check-framework-weight.py` | 體重量度 + 守門（context 預算／指標完整性／框架／產品比）＋ 儀表板 |
| `docs/ci/framework-weight.json` | 機器可讀嘅 cap 與 ratchet baseline（`skill_caps` / `total_context_cap` / `ratio`） |
| `tests/framework-weight.bats` | **16 支**守門探針（FW-1..016），每種壞情境都有實測證明 |
| `docs/req/TMO-082-requirement.md` | 需求錨點（用戶原話 + 澄清後驗收句 + 背景實測數據） |
| `docs/ac/TMO-082.md` | AC 範本（AC01..AC07 + DoD + 風險） |
| `docs/reconcile/TMO-082-reconcile.md` | 需求對帳權威表 |
| `docs/deliverable/2026-10-26-context-slim-framework-weight.md` | 本交付摘要 |

### 2.2 修改檔案（支援檔壓縮：量度 13 個 skill，其中 **9 個** skill 嘅 **14 個**支援檔被壓縮）

| 檔案路徑 | 前 → 後 | 手法 |
|---------|---------|------|
| `skills/regression-guard/examples.md` | 861 → 291 | Jev Oracle 章節同 `jev-oracle.md` **重複** → 壓成索引 ＋ 保留被錨定嘅四種輸出同 fix proposal 契約 |
| `skills/regression-guard/testing-methods.md` | 388 → 184 | 9 類測試法各有一段長範例 → 對照表 ＋ 可抄骨架 |
| `skills/dav-wiki/examples.md` | 610 → 248 | 8 個完整對話流程 → 共通 7 步骨架 ＋ 每個範例只留差異 |
| `skills/dav-wiki/frontmatter-schema.md` | 293 → 189 | 兩個幾乎一樣嘅完整 YAML 範例 → 合併成一個超集 ＋ 欄位表 |
| `skills/dav-wiki/concept-evolution.md` | 239 → 116 | 4 種動作各一節 → 一張對照表 ＋ 決策樹 ＋ 重疊度啟發式 |
| `skills/tdd-test-writer/examples.md` | 563 → 251 | 4 種框架長範例 → 1 個完整 ＋ 其餘骨架 ＋ 金字塔改用表格 |
| `skills/dav-trust/examples.md` | 533 → 309 | Trust Log 範本保留（格式契約），戰例壓縮 ＋ 雙寫對照表 |
| `skills/ask-me/examples.md` | 239 → 207 | 消化前後範例合併 ＋ 補「雙寫對應表」 |
| `skills/dav-reflection/checklist.md` | 194 → 141 | 6 維度各一張重複嘅標記標準表 → 一張共用表 ＋ 每節門檻行 |
| `skills/dav-reflection/template.md` | 217 → 200 | 3 個級別模板重覆骨架 → 共用骨架 ＋ 每級差異 |
| `skills/dav-submitter/examples/deliverable-sample.md` | 214 → 202 | 刪重複檔頭 ＋ 表格精簡（保留「點填」教學價值）|
| `skills/dev-checker-loop/workflow.md` | 200 → 116 | 8 張「步驟／操作／目的」表 → 2 張 ＋ 狀態機加文字版 |
| `skills/regression-guard/PoC/README.md` | 274 → 176 | 5 張 milestone 證據表 → 1 張；刪已完成嘅「M2/M3 接續」段 |
| `skills/dav-planner/backlog-rules.md` | 173 → 161 | INVEST／AC 格式／類型合併段 ＋ 刪重複嘅 Module sprint 說明 |

### 2.3 修改檔案（守門接線）

| 檔案路徑 | 改動內容 |
|---------|---------|
| `.github/workflows/ci.yml` | 加 `Verify framework weight (context budget + ratio)` step（**不得** `continue-on-error` / `\|\| true`）|
| `CONTRIBUTING.md` | 加本機指令 ＋ CI 清單第 6 項 ＋ 「框架體重守門」小節 |
| `docs/backlog.md` | 加 TMO-082 一列（狀態 done）|
| `docs/sop/handbook/changelog.md` | 加 v2.18 條目 |

---

## 3. 驗收標準對應

| AC | 描述 | 結果 | 證據 |
|----|------|------|------|
| AC01 | 儀表板：每 skill context 成本、框架／產品比、產物線檔案數 | ✅ | `python3 scripts/ci/check-framework-weight.py` → 三段輸出（本次實跑：合計 7,413 行、ratio 2.9203、產物線 req 7／ac 18／reconcile 7／deliverable 6／prd 3）|
| AC02 | context 總量 ≤ 7,900 行且零內容契約損失 | ✅ | 動工前 9,619 → 動工後 **7,413**（−2,207，−22.9%）；契約清單見 §5.2 |
| AC03 | 全量探針綠 | ✅ | `bats tests/` → 見 §4 |
| AC04 | 超預算／死指標／子檔掏空 → rc≠0 且指名 | ✅ | FW-3 / FW-4 / FW-5（fixture 實測，各自有壞情境）|
| AC05 | ratio 明顯上升 → rc≠0 | ✅ | FW-7 |
| AC06 | 守門自己有探針證明會紅 ＋ CI 接上不得假綠 | ✅ | FW-1..016（16 支全綠）＋ FW-9 鎖 CI 接線與假綠 |
| AC07 | V03 獨立 Reviewer 二審 | ✅ | 見 §7 |

---

## 4. 測試結果

| 測試類型 | 通過 / 總數 | 備註 |
|---------|-------------|------|
| 回歸測試（全量 bats） | **682 / 682** | 666 支原有 ＋ 16 支新增 FW；**0 紅、0 skip** |
| 新增守門探針 | 16 / 16 | `tests/framework-weight.bats`（FW-1..016）|
| skill-local 探針 | 5 / 5 | `SKILLS_DIR_OVERRIDE="$PWD/skills" bats skills/*/tests/*.bats` |
| 突變測試（mutant） | 58 / 58 全死 | `scripts/ci/mutants.tsv` **未動**（本票冇改任何既有探針）|
| 文件漂移（D1..D8） | 全綠 | `bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26` |
| Markdown lint | 0 issues | `markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"` |
| 體重守門 | rc=0 | `python3 scripts/ci/check-framework-weight.py` |

### 4.1 實跑輸出（2026-10-26）

| 檢查 | 指令 | 結果 |
|------|------|------|
| 全量回歸 | `bats tests/` | `1..682`，**682 ok / 0 not ok / 0 skip**（約 3 分半）|
| 新增守門 | `bats tests/framework-weight.bats` | `1..16`，16 ok |
| skill-local | `SKILLS_DIR_OVERRIDE="$PWD/skills" bats skills/*/tests/*.bats` | `1..5`，5 ok |
| 突變測試 | `python3 scripts/ci/mutant-must-die.py` | `OK: 58 支 mutant 全部死亡`（表未動）|
| 主檔行數 | `bash scripts/ci/check-skill-size.sh` | `OK: 13 個 SKILL.md 皆 <= 150 行` |
| 文件漂移 | `bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26` | `OK: 26 項檢查完成，7 項豁免`（動工前 22 項）|
| Markdown lint | `markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"` | `Summary: 0 issues in 0 files`（128 檔）|
| 體重守門 | `python3 scripts/ci/check-framework-weight.py` | `OK: context 預算、指標完整性、框架／產品比全部通過` |

---

## 5. 需求對帳

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 |
|---------|---------------|------|---------|------|
| R1 | 必須先量測現況再減磅；目標係 agent 觸發 skill 嘅 context 成本；不得犧牲任何被探針錨定嘅內容契約 | ✅ 已實作 | `docs/ac/TMO-082.md`（AC02/AC03）、本檔 §2.2／§5.2 | 量測：context 總量（SKILL.md + 支援 .md，唔含 CHANGELOG）**9,619 → 7,413**（−2,207，−22.9%；口徑：13 個 skill、git tracked、量度工具 `scripts/ci/check-framework-weight.py`，前後同一把尺）。契約清單見 §5.2：14 條被錨定嘅字串／段落／檔案存在性全部保留，由對應探針逐條驗證 |
| R2 | 必須同時交付瘦身同防回潮；守門必須自己都有探針證明會紅；不得假綠 | ✅ 已實作 | `scripts/ci/check-framework-weight.py`、`docs/ci/framework-weight.json`、`tests/framework-weight.bats`、`.github/workflows/ci.yml` | 守門三層：①context 預算（per-skill cap ＋ 總量 cap）②指標完整性（明確指標 `./xxx.md` ＋ 庫存檢查：任何 .md 被掏空／被刪除都報）③框架／產品行數比 ratchet（baseline 2.9203 ＋ tolerance 0.05）。**16 支探針**逐個壞情境實測會紅：FW-3 超預算／FW-4 死指標／FW-5 子檔掏空／FW-6 枚舉壞咗／FW-7 ratio 超標／FW-8 冇 `skills/` rc=2／FW-9 CI 接線與假綠／FW-10 自我證明／FW-11 怪路徑唔會量成 0／FW-12 裸名引用嘅子檔掏空／FW-13 子檔被刪除／FW-14 支援檔之間嘅死指標／FW-15 cap=0／FW-16 產品層 0 行。CI step **無** `\|\| true`、**無** `continue-on-error` |

### 5.2 被錨定嘅內容契約（壓縮後一個都唔少）

| # | 契約 | 由邊支探針守住 | 狀態 |
|---|------|----------------|------|
| 1 | `skills/regression-guard/examples.md` 含 `## 🧠 Jev Oracle 範例` ＋ `journey YAML` / `dry-run` / `batch report` / `JSON 報告` | `tests/v2.1-jev-poc.bats` SKILL-c | ✅ 保留 |
| 2 | 同上含 `Fix proposal` / `JEV_FIX_PROPOSAL` | 同上 M6-f | ✅ 保留 |
| 3 | 同上含 `Fix proposal v2` / `JEV_FIX_PROPOSAL_V2` / `skill 本身 LLM` | 同上 M6.1-f | ✅ 保留 |
| 4 | `skills/regression-guard/jev-oracle.md` 含 `ac_aware` / `mock` / `playwright` / `修正循環補充` / `JEV_FIX_PROPOSAL` / `M6.1 修正循環補充` / `LLM Relay` | 同上 SKILL-b / M6-e / M6.1-e | ✅ 保留（該檔未壓縮）|
| 5 | `skills/regression-guard/runner-cheatsheet.md` 含 `## …TTY fail-fast` 段 ＋ `Watch Usage` | `tests/regression-guard-watch-mode.bats` | ✅ 保留（該檔未壓縮）|
| 6 | `skills/dav-wiki/examples.md` 有 ≥5 個 `## 範例 N` | `tests/dav-wiki.bats` AC-7 | ✅ 保留（8 個）|
| 7 | `skills/dav-wiki/frontmatter-schema.md` 含文件 schema 9 個欄位 ＋ 概念 schema 7 個欄位 | 同上 AC-5a / AC-5b | ✅ 保留 |
| 8 | `skills/dav-wiki/concept-evolution.md` 含 derive / revise / merge / deprecate | 同上 AC-6a..6d | ✅ 保留 |
| 9 | `skills/dav-wiki/output-structure.md` 含 `_index.json` / `_tags.json` / `_concepts.json` / `transcript.md`；`soft-delete.md` 含 `deprecated_at` / `--older-than` / `--purge` | 同上 AC-1g | ✅ 保留（兩檔未壓縮）|
| 10 | `skills/dav-trust/{examples,time-anchor,preflight,resume}.md` 不得含「5 階段」等舊語意；`resume.md` 必含 `DEADLINE_TS` / `進度錨點` / `PHASE` / `DONE` / `NEXT` / `UPDATED_AT` 且 ≥40 非空白行；`time-anchor.md` 必含進度錨點四欄位 | `tests/restruct-dav-trust.bats` | ✅ 保留 |
| 11 | `skills/dav-planner/backlog-rules.md` 必定義 R-ID 規則 | `tests/doc-drift.bats` D6 相關 | ✅ 保留 |
| 12 | `skills/dav-submitter/template.md` 嘅 `> **對應 Backlog**` 必須喺第一個 `##` 之前 | `tests/doc-drift.bats` D8 前置規則 | ✅ 保留（該檔未壓縮）|
| 13 | `skills/*/examples/*` 必含「對應 skill 版本基線」標記 | `skills/dav-skill-creater/tests/check-examples-version-baseline.bats` | ✅ 保留（3 個 examples/ 檔未壓縮）|
| 14 | 所有 skill 主檔 ≤ 150 行；支援檔被點名指標必須解析到實體 | `scripts/ci/check-skill-size.sh`、`tests/dav-wiki.bats` AC-1e | ✅ 保留（並新增 FW 指標完整性守門）|

---

## 6. 已知問題 / 限制

| 問題 | 嚴重性 | 說明 |
|------|--------|------|
| **「context」用行數做代理** | P3 | token 數會更準，但行數可審核、可 diff、跨工具穩定。已知邊界，寫在 `docs/ci/framework-weight.json` 嘅 `_已知邊界` |
| **框架／產品比會被「加探針」推高** | P2 | 所以用 baseline + tolerance 嘅 ratchet，而唔係硬上限；改 baseline = 改規範（須走 V03）|
| **cap 同 baseline 本身可以被放寬** | P2 | 改 `docs/ci/framework-weight.json` 就冇人守 → 已加 fail-closed（值設成 0／tolerance 越界會紅，FW-15）＋ FW-1 鎖必要欄位存在；**仍未做**：「只可下不可上」嘅機械鎖（見 §7.4）|
| **只壓縮咗 9 個 skill 嘅 14 個支援檔（量度範圍 13 個 skill），未動 `docs/` 治理層** | P2 | 用戶選咗 A+D（唔包 B）；治理文件（`docs/system-design.md` 743 行等）**低頻讀取**，影響較細 → 留待第三刀 |
| **「衍生膨脹」（每個 story 產生 7-8 份檔案）仍未治理** | P2 | 用戶選咗 A+D（唔包 C）；儀表板已把 `docs/req` / `ac` / `reconcile` / `deliverable` 嘅檔案數印出（本次實跑：req 7／ac 18／reconcile 7／deliverable 6／prd 3），**可見但未設上限** |
| **本次量測過程中發現守門腳本自身一個真 bug 並修正** | P2 | 跳過清單若連 root 路徑都睇 → repo 放喺 `/tmp/xxx` 或 `.../cache/xxx` 之下會令全部檔案被跳過 → 量度變 0 → 守門「因為冇嘢可查」而永遠綠。已修（只睇相對路徑）並加 FW-11 鎖住 |
| **守門本身仲有 3 條未收口嘅假綠路徑**（第二輪二審指出） | P2 | ①**裸名指標指向一個從來冇存在過嘅檔** → 唔會紅（庫存檢查只捉「被掏空／被刪除」；裸名無法判斷係同 dir 子檔定係 docs/ 產出物名，改用「裸名 + 同 dir 同名存在」會大量誤紅，暫不做）②**子目錄指標**（`./a/b.md`）→ regex 唔含 `/`，唔檢查（`skills/` 現時無此寫法）③**「掏空」門檻只係 <8 非空白行** → 一個支援檔可以被削到 8 行仍然綠 |
| **壓縮後嘅支援檔冇再被人 review 過語意完整性** | P2 | 本次只保證「被探針錨定嘅契約」一個唔少；**未錨定嘅教學內容有被刪**（例：`regression-guard/examples.md` 原本 Jev Oracle 四種輸出嘅**樣本正文**已刪，淨返錨定字串；完整用法見同套 `jev-oracle.md`）。刻意保留原樣嘅係 pptx-slim 嘅踩雷表等**表格型知識** |

---

## 7. V03 二審結論

> 見 `docs/reconcile/TMO-082-reconcile.md`（對帳者：獨立 Reviewer subagent，未參與實作）。
> **本節係第一輪二審嘅真實結果**（唔係預先宣告）：兩位獨立 Reviewer subagent 並行審，
> 一位做 V03 二審（diff ＋ 風險分級 ＋ 跨 SOP 一致性），一位做 Gate 4.5 需求對帳。

### 7.1 第一輪二審結果（2 位獨立 Reviewer）

| # | 發現 | 分級 | 處置 |
|---|------|------|------|
| 1 | **守門嘅 ratio baseline 喺「新檔未入 git index」嘅視角量出 → 交付後守門會紅、CI 會擋住所有 PR** | **P0** | ✅ 已修：`git add -A` 後重量 → baseline 由「未落檔視角」嘅 2.8127 改成**落檔後**嘅實測值 2.9203；並喺設定檔寫明「量基線必須先 stage/commit，否則量到嘅係舊視角」|
| 2 | **headline 數字用咗兩套口徑**（前含 CHANGELOG、後唔含）→ 9,847→7,413 推導唔出 | P1 | ✅ 已修：統一為 context 總量（唔含 CHANGELOG）**9,619 → 7,413（−2,207，−22.9%）**；支援檔 7,950 → 5,743（−27.8%）；全部同步到 AC／交付摘要／對帳表／backlog／handbook v2.18 |
| 3 | **「指標完整性」只捉 `./xxx.md`，但 repo 主流寫法係裸名 → 掏空／刪除守門近乎失效**（且 docstring 講咗一條實作冇做嘅規則） | P1 | ✅ 已修：改成「明確指標（`./`）+ **庫存檢查**（skill 目錄內任何 .md 被掏空／被刪除都報）」；docstring 同實作對齊；新增 FW-12（裸名引用嘅子檔被掏空）／FW-13（子檔被刪除）|
| 4 | **我自己引入咗一個死指標**（`tdd-test-writer/examples.md` 指向唔存在嘅 `testing-methods.md`）| P1 | ✅ 已修：改抽象寫法；並將守門嘅指標檢查**擴到支援檔**（新增 FW-14）；順手修走 2 個存量死指標（`dav-submitter` 嘅 `checklist.md`、`regression-guard/PoC/README.md` 嘅兩個）|
| 5 | **交付摘要 §6 對「未錨定內容保留原樣」嘅描述同實情唔符**（Jev Oracle 四種輸出嘅樣本正文其實刪咗）| P1 | ✅ 已修：改成實話（刪咗乜、保留咗乜、完整用法喺邊）|
| 6 | **cap／baseline 被設成 0 → 守門靜靜哋唔檢查**（假綠方向）| P2 | ✅ 已修：設定值 fail-closed（cap/baseline 必須 > 0、tolerance ∈ (0, 0.5]）；新增 FW-15 |
| 7 | **`product_lines == 0` → ratio 守門恒真**（冇分母）| P2 | ✅ 已修：fail-closed；新增 FW-16 |
| 8 | **FW-9 嘅假綠檢查**：`\|\| true` 變體捉唔到、訊息語意誤導 | P2 | ✅ 已修：regex 改 `\|\|\s*(true\|:)`；訊息改成 repo 政策表述 |
| 9 | **「壓縮 13 個 skill」講法唔準**（實際 9 個 skill 嘅 14 個支援檔；13 係量度範圍）| P2 | ✅ 已修：全部改成「量度 13 個；其中 9 個 skill 嘅 14 個支援檔被壓縮」|
| 10 | **9 個受影響 skill 嘅 CHANGELOG／主檔變動歷史冇記錄今次重構** | P2 | ✅ 已修：9 個 skill 嘅 CHANGELOG 加條目 ＋ 主檔變動歷史同步（版本號照現況順序遞增；主檔保持 ≤3 列、≤150 行）|
| 11 | **`dav-reflection/checklist.md` 共用標記標準表同各維度門檻語意唔一致** | P2 | ✅ 已修：共用表只保留符號方向語意，明寫「數量門檻逐維度見各節」|
| 12 | **`dav-wiki/examples.md` 刪走咗 FR-3 多模組（圖片/影片/字幕）唯一工作流程例** | P2 | ✅ 已修：補回一個 24 行嘅「多模組子步驟（2a..2e）」小節 |
| 13 | **交付摘要 §7 預先寫咗「二審結論」（自我核准）** | P2 | ✅ 已修：本節改為第一輪二審嘅**真實**結果 |
| 14 | **backlog 現況摘要行數加總唔啱**（79+3+1=83 但得 82 列）| P2 | ✅ 已修：改成 78+3+1 = 82 列 |
| 15 | **CI step／CONTRIBUTING 寫「FW-1..010」但實際已到 011**（而家 016）| P2 | ✅ 已修：兩處改成 FW-1..016 |

### 7.2 第二輪二審結果（覆核第一輪 ＋ 捉新問題）

> 第二輪由**另外兩位**獨立 Reviewer subagent 做（一個 V03 覆核、一個 Gate 4.5 覆核），同第一輪唔重疊。

| # | 第二輪發現 | 分級 | 處置 |
|---|----------|------|------|
| 1 | **本票自己引入多處文件數字漂移**（backlog 寫 7,388、changelog 寫 7,388 同「11 支」同 FW-1..011、AC 寫 ratio 2.9023、交付摘要內部自相矛盾「11 支」vs「16 支」）—— 而 `tests/doc-facts.bats` **明文唔掃** `docs/deliverable/`、`changelog.md`、`docs/backlog.md` → repo 現有守門捉唔到 | P1 | ✅ 已修：全部統一成現值（context **7,413**、探針 **16 支**、FW-1..**016**、全量 **682** 支、baseline **2.9203**、dav-wiki **765**）；並喺 §7.1 第 2 行修正「已全部同步」嘅聲稱（當時 backlog／handbook 其實未同步）|
| 2 | **P0 修正本身無法由檔案證明**（baseline 量度之後又新增數百行框架層內容）| P1 | ✅ 已修：全部改動完成後**重新量度並重設 baseline**，再實跑守門（rc=0）|
| 3 | **新守門仍有 3 條未記錄嘅假綠路徑**（裸名指標指向從來冇存在過嘅檔／子目錄指標 `./a/b.md` 唔檢查／「掏空」門檻只係 <8 非空白行）| P2 | ✅ 已記錄：寫入本檔 §6 ＋ `docs/ci/framework-weight.json` 嘅 `_已知邊界`（唔隱瞞、唔當做已修）|
| 4 | **FW-9 訊息聲稱「repo 政策」但只掃 ci.yml**（另一個 workflow 有 `continue-on-error`）；且只查同一行 → 多行 `run: \|` 區塊寫法捉唔到 | P2 | ✅ 已修：訊息改成「ci.yml 內」；FW-9 改成抽**整個 step 區塊**逐行查 `\|\| true` / `\|\| :`，並要求該 step 真係執行個腳本。已用 mutation 驗證（加 `\|\| true` → 轉紅）|
| 5 | **FW-3 嘅訊息斷言係空轉**（grep "context" 必然命中儀表板標題）| P2 | ✅ 已修：改抓違規特徵字串「上限」|
| 6 | **dav-wiki 主檔變動歷史 4 列但自述「最近 3 條 + v2.0 首版錨點」**（我插入新列時誤刪咗 v2.0 錨點）| P2 | ✅ 已修：回復 v2.2.4／v2.2.3／v2.2.2 ＋ v2.0 錨點（v2.2.1 條目在 CHANGELOG）|
| 7 | **交付摘要兩處措辭自相矛盾**（「0 issues in 0 files（128 檔）」、「≤12 行」但實際 24 行、「2.9203 → 修正後 2.9203」自我矛盾）| P2 | ✅ 已修：改成準確表述 |

**第二輪嘅正面結論**：

- 16 支 FW 探針逐支核過 fixture 構造，**冇「建構失敗就當綠」**；
- 13 個 per-skill cap 全部高過實測值（餘裕 12-17%）→ 守門本身唔會因為 cap 誤紅；
- **冇新死指標**；主檔全部 ≤148 行；
- 既有門檻（mutant 58 支、`SKILL.md ≤150`、`.bats` 地板、markdownlint 規則同 glob）**一個都冇放寬**。

### 7.3 二審重點（風險分級 ＋ 跨 SOP 一致性 ＋ 門檻）

| 面向 | 結論 |
|------|------|
| 風險分級 | **中**（改 `skills/` 支援檔 = 影響 agent 行為；新增 CI 守門 = 影響每個 PR）|
| 跨 SOP 一致性 | AGENTS.md §1.5 V03（改規範走二審）✅；dav-skill-creater editor-guide（主檔 ≤150 行、變動歷史外移、純文字引用零容忍）✅（順手修走 3 個存量死指標）；PNA-1（探針名全 ASCII）✅；PNA-4（fail-fast 慣例）✅；markdownlint MD013 ✅；`docs/sop/gates.json` 唔需改（本次冇改 Gate 定義）|
| 門檻有無放寬 | **無**。mutant 表未動（58 支全死）、`SKILL.md ≤150` 未動、`.bats` 檔數地板未動；本次**只新增**上限（per-skill cap／總量 cap／ratio baseline）。⚠️ 但 **baseline 本身更新過一次**（P0-1 修正：改為「落檔後」嘅實測值）—— 出處已寫在設定檔 `_baseline_說明`|
| 有冇假綠風險 | 已逐條封：指標完整性（FW-4/5/12/13/14）、空過防護（FW-6/11）、假綠防線（FW-9）、設定值自我失效（FW-15）、ratio 冇分母（FW-16）、自身 bug（FW-11）|

### 7.4 下一步建議

1. **「cap 只可下不可上」嘅機械鎖**：目前改 `docs/ci/framework-weight.json` 就等於放寬門檻（屬規範改動、應走 V03，但無機械證明）；本次已加 fail-closed（值設成 0 會紅），但**仍然可以改成一個更大嘅合法值**。
2. **第三刀候選**（按用戶先前嘅排序）：治理文件收斂（B）→ 衍生膨脹上限（C）→ 風險分級 Gate。
3. **context 預算延伸到 token**：用 token 取代行數做代理（更準，但要處理不同模型 tokenizer 嘅漂移）。

---

**產生者**: Agent（透過 dav-submitter skill）
**產生時間**: 2026-10-26
