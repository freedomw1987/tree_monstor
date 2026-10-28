# TMO-092 需求對帳表

> 對帳者: reviewer（獨立 subagent，未參與實作） | 對帳時間: 2026-10-28 | 錨點: docs/req/TMO-092-requirement.md
> 覆蓋率: 1/1

## 對帳表

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | 「Jev Oracle 相關內容（`jev-oracle.md`、`examples.md`、`api-contract.md`、`output-format.md`、`PoC/`、4 支探針）要拆成獨立 skill `dav-jev-oracle`，令：① `dav-developer` 專注『寫測試 → 紅變綠 → 探針同回歸 → Reviewer 二審』；② `dav-jev-oracle` 自足（PoC ＋ 探針 ＋ 文件）；③ 兩邊指標互指、冇死引用。」 | ✅ 已實作 | ①`skills/dav-developer/SKILL.md:29,38,46,58`（4 步）、`:56,134,138`（指標去 dav-jev-oracle）；②`skills/dav-jev-oracle/SKILL.md:29-99`（流程 5 步 :29-68、規則 :70、Gate 註記 :88-91、交叉引用 :93-99）＋ `skills/dav-jev-oracle/{jev-oracle.md,examples.md,api-contract.md,output-format.md}` ＋ `skills/dav-jev-oracle/PoC/` ＋ `skills/dav-jev-oracle/tests/`；③`skills/dav-jev-oracle/SKILL.md:13,27,86,90,95`（指標去 dav-developer） | ①context 實測 **1,208** 行（10 支 .md：139+158+57+33+35+103+60+296+88+239）＝ AC02 聲稱值；主檔 139 行 ≤150。②`PoC/` 實數 48 檔、`tests/` 4 支探針齊；context 實測 **1,569** 行＝ `skills/dav-skill-creater/editor-guide.md:147` baseline；主檔 6 個指標所指檔全部存在。③grep `dav-developer/PoC`、`dav-developer/skills`、`claude/skills/dav-developer` 全 repo → 唯一命中 `docs/reconcile/TMO-091-reconcile.md:14`（刻意保留嘅「拆分前路徑」歷史註明，非死引用）；`skills/dav-developer/PoC` 舊路徑 **0 命中**；程式層 `skills/dav-jev-oracle/PoC/jev_oracle.py:96,103,305` 與 `PoC/.env.example:12` 已指 `~/.claude/skills/dav-jev-oracle/PoC/.env` | 5 項非阻擋備註：①`skills/dav-developer/develop.md:97-158` 仍留「jev 整合細節（v2.4 新增）」62 行（講 `jev-use` CLI 流程，唔係 PoC 個 Jev Oracle；已註明 Jev Oracle 已拆去同套 skill，孤兒「Step 0／Step 3」小標已刪）；②根 `README.md` §Skills 表未加入新 skill `dav-jev-oracle` → **已於對帳後同日補上**（見下面「對帳後續處理」）；③舊名殘留字串（非路徑）：`skills/dav-jev-oracle/PoC/playwright_observer.py:38` USER_AGENT `dav-developer-jev-poc/3.1`（**刻意保留**：UA 係對外協議值，改動會改 UA 行為）、`PoC/README.md:1` 標題、`PoC/gh_pr_comment.py:106`（**已於對帳後同日修正**）；④`ENV-EQ-21` 係結構檢查、唔係真 YAML parse（已知待辦，見下）；⑤`skill-contract.bats` SD-6 只驗 `PoC/`、`tests/`、`PoC/run_ci.sh` 三個路徑存在（已知待辦，見下）|

## 結論

- 全部已實作（1/1；0 項部分實作、0 項未實作、0 項已作廢）
- 對帳者備註: R1 三個條件逐條以工作樹實況核對通過（1,208／1,569 行數、48 檔 PoC、4 支探針、死引用掃描均有本人覆核）；但 AC DoD「閘 11 步全綠」在工作樹內無可查證據（對帳者無 shell 權限、未實跑），且二審末輪 verdict 係 BLOCK、其唯一 P1 係修好之後、無第三輪覆核記錄 —— 交付摘要若標「✅ 完成」宜附此兩點。

## R1 三個條件逐條判定

| 條件 | 錨點驗收句分拆 | 判定 | 證據（行號） |
|---|---|---|---|
| ① | `dav-developer` 專注「寫測試 → 紅變綠 → 探針同回歸 → Reviewer 二審」 | ✅ 已實作 | `skills/dav-developer/SKILL.md:27`（流程（4 步））、`:29` Step 1 寫測試（TDD，先紅）、`:38` Step 2 開發令紅變綠、`:46` Step 3 埋探針＋回歸、`:58` Step 4 Reviewer 二審（Gate 4）；Jev Oracle 內容全部搬走（diff：`skills/dav-developer/{jev-oracle.md,examples.md,api-contract.md,output-format.md}` → `skills/dav-jev-oracle/…`）；context 實測 1,208 行（逐檔 tail 讀行數加總 139+158+57+33+35+103+60+296+88+239）＝ AC02 聲稱值 |
| ② | `dav-jev-oracle` 自足（PoC ＋ 探針 ＋ 文件） | ✅ 已實作 | `skills/dav-jev-oracle/SKILL.md:29`（流程（5 步））、`:31,38,46,54,62`（Step 1-5）、`:70`（規則／例外／限制）、`:88-91`（Gate 定義＋「本 skill 唔新增 Gate」）、`:93-99`（交叉引用 6 項）；子檔 `jev-oracle.md` 361／`examples.md` 334／`api-contract.md` 45／`output-format.md` 34 行；`PoC/` 48 檔（`find` 實數）；`tests/` 4 支（`poc-bootstrap`／`poc-clean-clone`／`poc-venv-guard`／`v2.1-jev-poc`）；context 實測 1,569 行＝ `editor-guide.md:147` baseline 表 |
| ③ | 兩邊指標互指、冇死引用 | ✅ 已實作 | 互指：`skills/dav-developer/SKILL.md:4`（description）、`:56`、`:134`、`:138` → dav-jev-oracle；`skills/dav-jev-oracle/SKILL.md:3`、`:13`、`:27`、`:86`、`:90`、`:95` → dav-developer。死引用掃描：`dav-developer/PoC`、`dav-developer/skills`、`claude/skills/dav-developer` 三組 pattern 全 repo 只命中 `docs/reconcile/TMO-091-reconcile.md:14`（刻意歷史註明）；`skills/dav-developer/PoC`、`dav-developer/api-contract` 等舊路徑 0 命中；`skills/dav-jev-oracle/PoC/jev_oracle.py:96` 已由 `dav-developer` 改為 `dav-jev-oracle`（一輪二審 P1-1 已修，與 `tests/secret-masking.bats:83,85,90,92` 對得上） |

## AC01–AC05 逐條判定

| AC | 判定 | 證據（行號） |
|---|---|---|
| AC01 `dav-jev-oracle` 自足（主檔＋4 子檔＋PoC 48 檔＋tests 4 支） | ✅ 已實作 | `skills/dav-jev-oracle/SKILL.md:8,22,29,31,38,46,54,62,70,88,93`（4 段結構＋5 步＋規則＋Gate 註記）；子檔 `skills/dav-jev-oracle/jev-oracle.md`(361)、`examples.md`(334)、`api-contract.md`(45)、`output-format.md`(34)；`PoC/` 48 檔（實數）；`tests/` 4 支探針（`ls` 實數）。備註：前兩支子檔 >300 硬上限，已在 `skills/dav-skill-creater/editor-guide.md` 登記存量例外（ratchet 只可下不可上；錨點已註明行數限制屬執行約束、唔屬驗收句） |
| AC02 `dav-developer` 只留 4 件事；context 2,098 → 1,208 行 | ✅ 已實作 | `skills/dav-developer/SKILL.md:27-66`（恰為 4 步）、`:134,138`（Jev Oracle 變指標去同套 skill）；context 實測 **1,208** 行＝ AC 聲稱值（10 支 .md 加總，見上）；主檔 139 行 ≤150。備註：`skills/dav-developer/develop.md:97-158` 仍留 jev 整合段（`jev-use` CLI 流程，非 PoC Jev Oracle）→ P2 |
| AC03 全 repo 引用更新、冇死引用、CI SOP 改名 | ✅ 已實作 | `.github/workflows/ci.yml:77`；`scripts/check-all.sh:126,131`；`scripts/ci/mutant-must-die.py:235`；`scripts/ci/mutants.tsv:82,93,98`；`.gitignore:21`；`tests/secret-masking.bats:77,85,87,90,92`；`tests/mutant-must-die.bats:137`；`tests/env-equivalence.bats:268`；`docs/install-reference.md:292,295,298,310,315,361`；`docs/ci/dav-developer-jev-poc.md` → `docs/ci/dav-jev-oracle.md`（rename 87%）；`docs/ac/README.md:24,66`；`docs/ac/TMO-091.md:29`；`docs/reconcile/TMO-091-reconcile.md:14`；`docs/ci/drift-whitelist.txt`；`docs/cleanup/cleanup-scan.py:67`（新增 `**/dav-jev-oracle/**`、刪死規則 `**/dav-developer/PoC/prompts/**`）。備註：根 `README.md` §Skills 表未列新 skill（**已於對帳後同日補上**，見「對帳後續處理」） |
| AC04 新增 `skills/dav-developer/tests/skill-contract.bats`（7 條） | ✅ 已實作 | `skills/dav-developer/tests/skill-contract.bats:20`（SD-1 4 段導航）、`:30`（SD-2 150 行上限）、`:39`（SD-3 指標可達）、`:52`（SD-4 Step 順序）、`:59`（SD-5 Jev 邊界）、`:72`（SD-6 dav-jev-oracle 自足）、`:90`（SD-7 四道 Gate 齊）＝ 7 條，與 AC 列嘅 7 項一一對應；skill-local 探針由 `scripts/check-all.sh` 嘅 `skill-tests` 步驟執行。備註：SD-6 只驗 3 個路徑存在，唔逐個驗 4 支探針同 4 支子檔（P2） |
| AC05 8 個 skill `description:` 改 `>-` ＋ 新增 `ENV-EQ-21` | ✅ 已實作 | 8 支已改：`skills/ask-me/SKILL.md:3`、`dav-designer/SKILL.md:3`、`dav-developer/SKILL.md:3`、`dav-reconciler/SKILL.md:3`、`dav-skill-creater/SKILL.md:3`、`dav-trust/SKILL.md:3`、`dav-wiki/SKILL.md:3`、`pptx-slim/SKILL.md:3`（diff 顯示只把原本 2 行折行改為 `>-` ＋ 單行縮排，文字逐字不變）；`dav-jev-oracle`／`dav-planner`／`dav-submitter` 維持合法單行 plain scalar；探針 `tests/env-equivalence.bats:856-891`（repo 級、CI 會跑），守「description 單行 或 block scalar、唔准跨行」。備註：該探針 block scalar 分支不驗 body 縮排、plain scalar 用 regex 猜 key → 有假綠窗口（一輪二審 P2-6） |

## DoD 逐條判定（`docs/ac/TMO-092.md`）

| DoD 項 | 判定 | 證據 / 缺口 |
|---|---|---|
| `skills/dav-jev-oracle/` 建成（自足）＋ `dav-developer` 收窄 | ✅ 已實作 | 同 R1 條件 ①②（實測見上） |
| 全 repo 引用更新（CI／mutant 表／探針／docs／.gitignore） | ✅ 已實作 | 同 AC03（逐檔行號見上） |
| `skill-contract.bats`（7 條）＋ `ENV-EQ-21` | ✅ 已實作 | 同 AC04／AC05 |
| v2.8 規則改 ratchet baseline（每 skill 上限 ＋ 1,500 硬上限） | ✅ 已實作 | `skills/dav-skill-creater/editor-guide.md` baseline 表 ＋ 1,500 硬上限 ＋ 量法 `git ls-files skills/<name> \| grep '\.md$' \| xargs -r cat \| wc -l`；親測 `dav-developer` 1,208、`dav-jev-oracle` 1,569（>1,500 已登記例外，只可下不可上）與表內數字一致 |
| 閘 11 步全綠 | ✅ 已實作（對帳後補證據） | supervisor 實跑 `bash scripts/check-all.sh`：11 步全綠（deps／ffmpeg／shellcheck／bashn／heredoc／drift／mdlint／venv／bats／skill-tests／mutant），49 支 mutant 全死 |
| V03 獨立 Reviewer 二審 | ✅ 已實作（對帳後補覆核） | 第 1 輪 BLOCK（2 P1 ＋ 8 P2）→ 全修；第 2 輪 BLOCK（餘 1 P1：2 條舊路徑死引用）→ 修；第 3 輪 BLOCK（餘 1 token：`docs/reconcile/TMO-091-reconcile.md:14` 備註欄）→ 已修（reviewer 明言「改完即 OK」，無第 4 輪覆核）。3 輪原文見交付摘要 §8.4 |
| 對帳表 `docs/reconcile/TMO-092-reconcile.md` | ✅ 已實作 | 本檔（本次 Gate 4.5 產出）；R-ID 覆蓋率 1/1，狀態值全部取自 4 種合法值 |

## 對帳後續處理（supervisor，2026-10-28；對帳結論本身未改）

- **README §Skills 表漏格**（對帳備註②）→ 已補：`README.md` 加 `dav-jev-oracle` 一行 ＋ 標題句「13 個 skill」→「11 個 skill」（`skills/` 實際 11 個目錄）。
- **二審末輪 P1**（`docs/ac/TMO-091.md:29`、`docs/reconcile/TMO-091-reconcile.md:14`、`docs/ac/README.md:25` 三處舊路徑）→ 已修（改指 `skills/dav-jev-oracle/PoC/fixtures/ac/`，並保留「拆分前路徑」歷史註明）＋ 第三輪窄幅覆核。
- **刻意保留不修**：`skills/dav-jev-oracle/PoC/playwright_observer.py:38` 嘅 USER_AGENT `dav-developer-jev-poc/3.1`（UA 係對外協議值，改動會改 UA 行為，無下游需求唔亂改）；`X-Title: dav-developer-jev-*` 三個協議標頭值同樣唔改。
- **已知待辦（唔阻本次交付，另開票跟）**：
  - `ENV-EQ-21` 只做結構檢查、唔係真 YAML parse（block scalar body 縮排／value 內含 `": "` 有假綠窗口）
  - `skills/dav-developer/tests/skill-contract.bats` SD-6 只驗 3 個路徑存在，未逐個驗 4 支探針同 4 支子檔
  - `skills/dav-developer/develop.md` 仍留 62 行「jev 整合細節」（講 `jev-use` CLI 流程，已加指標指去 `dav-jev-oracle`）
  - `docs/cleanup/cleanup-scan.py` 嘅 `**/dav-jev-oracle/**` 只覆蓋一層（Python ≤3.12 `PurePath.match` 唔支援 recursive `**`；本機 3.14 正常）
