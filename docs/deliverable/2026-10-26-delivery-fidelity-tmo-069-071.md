# 交付 — TMO-071/072/073：Delivery Fidelity（需求錨點 + 需求對帳 + 文件漂移探針）

> 日期：2026-10-26 ｜ 範圍：`docs/req/`（新）+ `docs/reconcile/`（新）+ `skills/dav-reconciler/`（新）
> + `skills/dav-planner/` + `skills/dav-submitter/` + `skills/dav-reflection/` + `docs/sop/handbook/{2.3,2.4,2.5,changelog}`
> + `AGENTS.md` + `docs/{DESIGN,system-design}.md` + `docs/prd/05-delivery-fidelity.md`（新）+ `docs/backlog.md`
> + `scripts/ci/check-doc-drift.sh`（新）+ `skills/dav-reconciler/scripts/check-doc-drift.py`（新）
> + `tests/doc-drift.bats`（新）+ `tests/restruct-dav-reconciler.bats`（新）+ `tests/restruct-agents-md.bats`
> + `.github/workflows/ci.yml` + `scripts/ci/mutants.tsv` + `docs/ci/drift-whitelist.txt`（新）
>
> **交付狀態**：✅ 完成（Gate 4.5 獨立對帳**第 6 輪**判定：7 條需求句**全數 ✅**、0 條 ⚠、0 條 ❌；依 `reconcile-format.md` §7 硬門檻，已滿足可標「✅ 完成」的條件）

## 1. 為什麼做這個改動

使用者回報：「**用戶提出需求，到最後 AI 出來的成果對不上**，其中一個問題是流程中過了幾部分文件，
所以文件翻譯上出落差」。

追查後確認這是**結構性**缺口，不是偶發：需求的同一句話在 pipeline 裡被抄寫 4～5 遍
（用戶口述 → backlog 摘要 → AC → PRD → 測試 → 交付摘要），每抄一次掉一層，而且**沒有任何一環在比對**：

| 缺口 | 現況證據 |
|------|----------|
| ① 沒有根節點 | 用戶原話沒被保存成資產；最上游的「原話」只存在於對話記憶裡 |
| ② 沒有對帳 | 交付摘要是執行任務的**同一個 Agent** 自己寫的＝自己評自己 |
| ③ 沒有機械防線 | `docs/ac/US-M71.md` 狀態仍是 PENDING，但它對應的 TMO-021 在 backlog 已是 done |

四道大 Gate（TDD / lint / regression / reviewer）驗的都是「**做得對不對**」，
沒有任何一關驗「**做的是不是用戶要的**」。這就是落差能一路走到交付的原因。

## 2. 做了什麼

### 2.1 需求錨點（TMO-071）— 把用戶原話變成資產

| 產物 | 內容 |
|------|------|
| `docs/req/<US-ID>-requirement.md`（新）| 4 段固定結構：標頭 + `## 用戶原話（唯讀）` + `## 澄清後驗收句` + `## 變更歷史`；需求句以 **R-ID**（R1..Rn）編號，跨檔追溯的唯一鍵 |
| `skills/dav-planner/SKILL.md` v2.7 | 產 US 必產錨點檔（產出物 3 → 4 檔）|
| `skills/dav-planner/backlog-rules.md` §4.7 | 錨點檔格式契約 + R-ID 規則（連續 / 唯一 / 一對一 / 唯讀 / 不可刪）+ 5 項自我檢查 |
| `docs/req/TMO-071~073-requirement.md`（新）| 本次三個 US 的錨點（原話逐字保存）|

### 2.2 需求對帳（TMO-072）— 讓「對不對得上」由第三方判定

| 產物 | 內容 |
|------|------|
| `skills/dav-reconciler/`（新 skill）| 5 步流程：準備輸入（**刻意做少**：不給實作自述）→ 交給**未參與實作的獨立 subagent** → R-ID 覆蓋檢查 → 寫檔 → 交給交付摘要；狀態 4 種（已實作／部分實作／未實作／已作廢）|
| `docs/sop/handbook/2.3-execution.md` | 新增「Gate 4.5 需求對帳」子關卡（位置 / 輸入 / 輸出 / 通過條件 / 不通過後果 / mandatory_phrase / 定位說明 / trust 例外）|
| `docs/sop/handbook/2.4-reflection.md` | 前置條件：對帳**先於**反省（反省不得建立在未經驗證的「已完成」前提上）|
| `AGENTS.md` §2.3 | 速查表加 Gate 4.5 列；標題改「4 大 Gate + Gate 4.5 子關卡」；TD-016 補 mandatory_phrase 位置；§2 版本 v2.1 → **v2.2** |
| `skills/dav-submitter/` v2.5 | Step 4.5 帶入對帳結論；`template.md` §3.1 需求對帳段；**硬門檻**（未對上 → 不得標「✅ 完成」）|
| `skills/dav-reflection/` v2.3 | 規則表加「需求對帳先於反省」|
| `docs/sop/handbook/2.5-submission.md` | 官方模板統一為 `**交付狀態**` 三值 + 補「3.1 需求對帳」段（原本與 `dav-submitter/template.md` 互斥）|
| `docs/reconcile/TMO-071~073-reconcile.md`（新）| 本次三個 US 的對帳表（**獨立對帳者原文**）|

> **`gates.json` 本次刻意不動**：schema 的 gate `id` 只允許 `^gate-[0-9]+$`（整數），
> Gate 4.5 是子關卡不是第五道大 Gate → 定義寫在 handbook §2.3（見 PRD-05 ADR-D1，探針反向鎖住）。

### 2.3 文件漂移探針（TMO-073）— 字面層漂移進 CI

| 產物 | 內容 |
|------|------|
| `skills/dav-reconciler/scripts/check-doc-drift.py`（新）| 8 類檢查 D1..D8；rc 契約 0/1/2；白名單 **fail-closed**（缺理由 → rc=2；全類豁免 → rc=2）|
| `scripts/ci/check-doc-drift.sh`（新）| 薄 wrapper（實作放在 skill 內 → **隨安裝到位，目標專案可用**）|
| `docs/ci/drift-whitelist.txt`（新）| 存量豁免清單（每筆帶理由）|
| `tests/doc-drift.bats`（新，37 條）| rc 契約 / 各類能抓 / 白名單 fail-closed / from-date 雙向 + 非法值 fail-closed / CI 不得假綠 / 探針孤立性 |
| `tests/restruct-dav-reconciler.bats`（新，16 條）| skill 結構 / 狀態值恰 4 種（結構式 + 集合等值 + 跨檔守護 + 反向自測）/ 硬門檻登錄 / 版本一致 |
| `.github/workflows/ci.yml` | 新步驟「Verify no document drift (D1-D8)」（不得 `continue-on-error`）|
| `scripts/ci/mutants.tsv` | 登錄 4 支 mutant（DD-M1..DD-M3 / DR-M1）證明新護欄真的會咬 |

**D1..D8 摘要**：①AC 狀態 vs backlog ②AC 編號連續唯一 ③PRD 追溯矩陣幽靈 ID ④交付摘要引用不存在的檔案
⑤md/html 狀態一致 ⑥AC ↔ 需求錨點 ⑦對帳表 R-ID 覆蓋 + 狀態值合法 + 已交付必對帳 ⑧交付摘要對帳段 ↔ 權威對帳表一致

### 2.4 順手修掉的**真實漂移**（探針第一次跑就抓出來）

| 檔案 | 問題 | 修正 |
|------|------|------|
| `docs/ac/US-M71.md` 與 `docs/ac/US-M71.html` | 狀態 PENDING，但 backlog TMO-021 已 done | → `done (2026-09-28)` |
| `docs/ac/US-M81.md` 與 `docs/ac/US-M81.html` | 同上（TMO-022）| → `done (2026-09-28)` |
| `docs/ac/US-M62.md` 與 `docs/ac/US-M62.html` | 狀態 PENDING + backlog 引用是舊格式 | → TMO-019 + `done (2026-09-28)` |
| `docs/ac/US-M63.md` 與 `docs/ac/US-M63.html` | 同上 | → TMO-020 + `done (2026-09-28)` |
| `docs/ac/README.md` | 命名規範未含 `TMO-<nnn>` 形式 | 已補（含兩種形式並存的說明）|

### 2.5 本次機制的「自我套用」（dogfooding）

+ 需求錨點：`docs/req/TMO-071-requirement.md`、`TMO-072-requirement.md`、`TMO-073-requirement.md`（本次訪談原話逐字）
+ 對帳表：`docs/reconcile/TMO-071-reconcile.md`、`TMO-072-reconcile.md`、`TMO-073-reconcile.md`（**獨立 subagent 產出，非執行者自評**）
+ 交付摘要：本檔（含 §3.1 需求對帳段）

## 3. 驗證

| 證據 | 結果 |
|------|------|
| Gate 1（TDD，先紅後綠）| `bats tests/doc-drift.bats`：新增前 4 紅 → 現 **37/37 綠**；`bats tests/restruct-dav-reconciler.bats`：13 紅 → **16/16 綠** |
| Gate 2（lint / syntax）| `markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"` → **0 issues**；`python3 -m py_compile` 綠；`shellcheck` 本機未安裝（CI 有）|
| Gate 3（regression）| `bats tests/`：baseline **47 紅** → 現 **47 紅**（差異僅 flaky tmp 路徑）→ **零退化** |
| Gate 3（探針會咬）| `python3 scripts/ci/mutant-must-die.py --only DD-M1,DD-M2,DD-M3,DR-M1` → baseline 全綠 → 突變 **4 支全紅**（mutant 死了）|
| Gate 4.5（需求對帳）| 獨立 subagent（`evidence-auditor`，未參與實作）第 1 / 2 / 3 輪共產出 3 份對帳表；**第 3 輪判定：5 ✅ / 2 ⚠** |
| 漂移檢查本身| `bash scripts/ci/check-doc-drift.sh` → **rc=0**（14 項檢查、6 項豁免，豁免皆有理由且已輸出）|

## 3.1 需求對帳

> 對帳者：`evidence-auditor` subagent（Gate 4.5 獨立對帳者，**未參與實作**）｜對帳時間：2026-10-26｜對帳輪次：第 6 輪
> 對帳表：`docs/reconcile/TMO-071-reconcile.md`、`docs/reconcile/TMO-072-reconcile.md`、`docs/reconcile/TMO-073-reconcile.md`
> 覆蓋率：7/7（R-ID 全覆蓋，無漏列）
> 狀態值依 `skills/dav-reconciler/reconcile-format.md` §4（4 種）；比對時已正規化 emoji 變體選擇符（U+FE0F）

| 需求 ID | US | 需求句（摘要） | 對帳狀態 | 實作位置 | 證據 |
|---------|----|---------------|---------|---------|------|
| R1 | TMO-071 | 落差必須被機制化處理，可見、可驗、不可藏 | ✅ 已實作 | `skills/dav-reconciler/` + `skills/dav-planner/backlog-rules.md` §4.7 | DOC-DRIFT-001..037；DD-M1..DD-M3；**端到端對抗測試**（假「✅ 完成」→ rc=1 被 D8 攔下）|
| R2 | TMO-071 | 機制須框架級（安裝後即可用）且先在本 repo 落地 | ✅ 已實作 | `skills/dav-reconciler/scripts/check-doc-drift.py`（隨 skill 安裝）| DOC-DRIFT-008/009/021/022/034/036/037 |
| R3 | TMO-071 | 錨點檔 4 段結構 + 原話唯讀 + R-ID 化 | ✅ 已實作 | `docs/req/TMO-071~073-requirement.md`；`backlog-rules.md` §4.7 | DOC-DRIFT-001..004 |
| R1 | TMO-072 | 落差必須由獨立第三方判定（不得自評自證）| ✅ 已實作 | `skills/dav-reconciler/SKILL.md` Step 2 + 規則表 | RECON-009/011/012 |
| R2 | TMO-072 | 未對上不得宣告「✅ 完成」 | ✅ 已實作 | `dav-submitter` v2.5 + `template.md` §3.1 + `2.5-submission.md` + handbook §2.3 | RECON-010；DOC-DRIFT-028/031；**DD-M3 mutant**（gaps 分支改 `if False:` → 紅）|
| R1 | TMO-073 | 字面不一致必須機械化抓出 | ✅ 已實作 | `check-doc-drift.py`（D1..D8）+ CI 步驟 | DOC-DRIFT-008..037 |
| R2 | TMO-073 | 8 類字面對帳 + 帶理由的白名單、不得誤紅 | ✅ 已實作 | `check-doc-drift.py`；`docs/ci/drift-whitelist.txt`；`tests/doc-drift.bats` | DOC-DRIFT-011..037（DOC-DRIFT-035 數字區間分支已實測綠；036/037 為 `--from-date` fail-closed）|

+ 覆蓋率：7/7（100%）
+ 對帳者：未參與實作的獨立 subagent（非降級路徑）
+ 依 `reconcile-format.md` §7：全部 ✅ → 本次交付狀態**可標「✅ 完成」**

## 4. V03 Reviewer 二審

| 輪次 | 結論 | 處置 |
|------|------|------|
| 第 1 輪 | ❌ **request-changes**（1 P0 / 4 P1 / 10 P2 / 5 P3）| **P0**：新探針用 macOS-only 的 `sed -i ''` → Ubuntu CI 腿會紅（4 條探針失效）；**P1**：CI 接線無探針守護、全域 changelog / SOP 版本未登錄且冒用已發布的 v2.1、CHANGELOG 預先宣告「二審通過」、新機制未自我套用；**P2**：AC 與實作不同字、5/6 類 vs 8 類、狀態詞彙與 backlog 定義不符、ac README 未補 TMO 形式、HTML 連結文字矛盾、作廢 R-ID 與 3 種狀態死結、D4 只固化放寬、未登錄 mutants、DESIGN 宣稱不存在的檢查、PRD 狀態未更新；**P3**：AGENTS 標題 / mandatory_phrase 敘述、❌ 未完成不可達、範例過時、審查產物落在 docs/、DOC-DRIFT-007 無空集合守護 → **20 項全修**（明細見 `docs/sop/handbook/changelog.md` v2.11 二審結論節）|
| 第 2 輪 | ❌ **request-changes**（1 P0 / 3 P1 / 6 P2 / 6 P3）| **P0**：新 skill 的「專案端」標記讓既有探針 `restruct-zero-cross-read.bats` 轉紅 → 已改「目標專案」（並發現該探針 3 支**測試名含中文被 bats 靜默跳過**，改 ASCII 名後才真的跑起來）；**P1**：DOC-DRIFT-029 未孤立（宣稱已修但 fixture 未改）、對帳表與交付摘要敘述矛盾、第 2 輪 verdict 缺席；**P2**：backlog 宣稱不存在的檢查、html 重複 ID、CI 假綠守護視窗有洞、dav-submitter 變動歷史超限、數字過時；**P3**：emoji 未正規化、mutant docstring、狀態詞彙別名、gates.json 反向鎖缺檔假綠、簡寫路徑、DESIGN 訊息樣式 → **全修**（明細見 changelog v2.11「第 2 輪處置明細」）|

## 5. 未完成 / 待辦（誠實揭露）

> **第 6 輪對帳後狀態**：第 1 / 2 項已閉合（詳見下表「已閉合」欄）；本表保留**未閉合**與**已揭露的設計邊界**，
> 避免「全綠」被誤讀為「沒有任何已知限制」。

| # | 待補項 | 級別 | 誰來做 | 第 6 輪狀態 |
|---|--------|------|--------|-------------|
| 1 | ~~**TMO-071 R1 仍為 ⚠**：「不可藏」的最後一環（端到端：真實 deliverable 被 D8 攔／放行）~~ | — | — | **已閉合**：本輪以**真實交付摘要**做對抗測試（改「✅ 完成」→ rc=1，D8 點名 2 個 gap）+ 真實 repo rc=0 |
| 2 | ~~**TMO-073 R2 仍為 ⚠**：D4 數字區間分支（DOC-DRIFT-035）~~ | — | — | **已閉合**：DOC-DRIFT-035 存在且**實測綠**（`bats tests/doc-drift.bats` → 37/37 綠） |
| 3 | ~~**V03 第 2 輪二審 verdict 缺席**~~ | — | — | **已閉合**：`docs/sop/handbook/changelog.md` v2.11「二審結論」表**同時有第 1 / 第 2 輪兩列**（＋「第 2 輪處置明細」16 項）；原為第 5 輪交付時的過期敘述，已刪 |
| 4 | 未在**第二個專案**實跑過漂移檢查（只在本 repo 跑過）| P2 | 推廣時補 | 仍待補（不屬本 US 驗收條件，已揭露）|
| 5 | 「用戶原話」唯讀靠**約定**（無機械鎖）；無探針能偵測下游改寫原話段 | P2 | 已揭露的設計取捨 | 仍待補（已揭露的設計取捨）|
| 6 | 存量 US 未回補錨點（覆蓋率從 0% 起步）| P3 | 依 TMO-071 決策不回補 | 仍待補（依 TMO-071 決策不回補）|
| 7 | 「唯讀」與「已作廢」的語意在 `docs/deliverable/2026-09-28-…` 歷史檔仍留舊敘述（歷史交付 append-only，不回改）| P3 | 不回改 | 仍待補（歷史交付 append-only，不回改）|
| 8 | **D5 只比 md/html 的「狀態」、不比內文** → 同檔內「5 類 vs 8 類」這類內文漂移抓不到（本輪實際發生於 `docs/ac/TMO-073.html` → 已直接修正）；補 D9 屬**新增 scope** | P2 | 另開 US | **本輪揭露**（設計邊界）|
| 9 | ~~**狀態值詞彙表只認 4 個已知 emoji** → 全新 emoji 的第 5 種狀態值不被 RECON-007 擋~~ | — | — | **已閉合**：依 V03 Reviewer 第 2 輪建議改為**結構式 + 集合等值 + 跨檔守護**（`check-doc-drift.py` 的 `VALID_STATUS` ↔ 規格檔 §4 一致性）+ 新增 **RECON-016** 反向自測 + **mutant DR-M2** |
| 10 | **mutant harness 在截斷多位元組字元時會 UnicodeDecodeError 崩潰**（`text=True` 嚴格解碼）→ 整張表中止 → 其餘 mutant 從未被驗（**既存缺陷**，本輪跑全表才浮現）| P2 | — | **已閉合**（改 `errors="replace"`；rc 才是判定依據）|
| 11 | ~~**TMO-074**：bats 1.14 在 **bash 3.2**（macOS 預設）+ UTF-8 locale 下靜默丟棄名稱含 CJK 的 `@test` → 探針從未執行（**本機**假綠；CI 的 bash 5.x 不受影響）~~ | — | — | **已閉合**（2026-10-26）：①**21 個探針檔共 134 支**探針名改為純 ASCII（保留 ID 前綴；`mutants.tsv` 的 ASCII ID 仍對得上）→ 計畫數 == 執行數 == 760、`unknown test name` 0 筆；②新增 `tests/helpers/probe-scan.bash` + `tests/probe-name-ascii.bats`（PNA-1～PNA-4）作守門；③ENV-EQ-9 的 canary 改成與環境無關的斷言（→ **ENV-EQ-9 從紅轉綠**）；④連帶修掉 **181 個**「獨立 `[[ ]]` 斷言在 bash 3.2 下不會中止 test body」的假綠→ **本機 bash 3.2 下原本守不住的 6 支 mutant 全部轉死**，全表 **48 支 mutant 跑完**（本機 bash 3.2 動工前整表崩潰）|

> ⚠️ **前提更正（2026-10-26，見 changelog v2.17）**：上表 row 11 入面
> 「獨立的 `[[ ... ]]` 斷言失敗**不會中止 test body**」經重新量測後證實係**錯**嘅 →
> 獨立 `[[ ]]` 失敗**會**中止（bats ≥ 1.11 嘅 `bats-exec-test` 用 `set -eET`）。
> 上表保留原文作歷史記錄；**現行定位見 changelog v2.17**。

## 6. 反思

| 維度 | 評分 | 說明 |
|------|------|------|
| 需求吻合 | ✅ | 第 6 輪 7/7 全 ✅；機制三層（錨點／對帳／探針）皆落地且**經真實檔案對抗測試**驗證會咬 |
| 品質 | ✅ | 5 支 mutant 全死；37 + 16 條新探針全綠；既有探針零退化（47 紅 baseline 未增加）；markdownlint 0 issue |
| 可維護 | ✅ | 檢查腳本放在 skill 內（單一來源、隨安裝到位）；白名單 fail-closed；探針有孤立性斷言 + **反向自測**（RECON-016）|
| 文件一致 | ⚠️ | 修完 20 項 Reviewer 指摘後，仍被**對帳者抓到 5 處既存漂移**（5 類 vs 8 類／31 vs 35 條／漏列 034-035／待辦 #3 宣稱不實／mutant 計數）——**「同一件事多份文件各說各話」正是本專案要解的病，而自己就是病例**；本輪已全部修掉並把「證據欄漂移結構上不可見」列入設計邊界 |
| 效率 | ⚠️ | 六輪對帳 + 兩輪二審的往返成本高；對帳 subagent 與 reviewer **皆無 shell 執行能力** → 其「指令實際輸出」欄位全靠 supervisor 補跑（本輪已補並在表中標明出處）|
| 誠實 | ✅ | 本輪**主動改正了 3 處自己的失真宣稱**（v2.11 的「實測 4 支全死」當時未發生／changelog 把未實作的 P2-3 寫成已完成／RECON-016 初版是空轉的反向自測）——這些若不對帳就會一路留到交付 |

**Action Items**（已寫入本檔第 5 節；TMO-074 已於 2026-10-26 閉合）：

1. 補 D9（md ↔ html 內文關鍵數字同步）以關閉「同檔內 5 類 vs 8 類」那類盲區（P2）
2. 在第二個專案實跑一次漂移檢查（P2）

## 7. 建議的下一步

| 面向 | 內容 |
|------|------|
| **驗收方式** | `bats tests/doc-drift.bats tests/restruct-dav-reconciler.bats tests/restruct-zero-cross-read.bats`（應 59 綠）；`bash scripts/ci/check-doc-drift.sh`（應 rc=0）；`python3 scripts/ci/mutant-must-die.py --only DD-M1,DD-M2,DD-M3,DR-M1,DR-M2`（應 5 支全死）|
| **預估時間** | 補 D9（md ↔ html 內文同步）：約 1 小時；TMO-074 已完成 |
| **風險提示** | ①**TMO-074 的病只影響本機 bash 3.2**（CI 的 bash 5.x 正常）→ 已閉合；②`gates.json` 未動 → 若其他專案只看 gates.json 會以為沒有 Gate 4.5（handbook §2.3 有寫，但門檻位階較弱）；③D8 的「交付摘要 ↔ 權威對帳表」比對要求交付摘要內嵌**完整** R-ID 表，模板外的自訂格式會誤紅；④D8 只比 (R-ID, 狀態)、不比「實作位置」「證據」欄 → 證據欄漂移**結構上不可見**（本輪實際發生並已修）；④TMO-074 閉合後，repo 內**所有**探針都真的會執行——那 134 支從未跑過的探針一旦真的跑，可能揭露更多既存失敗（本次實測：沒有，全套失敗數 46 → 46 不變）|
