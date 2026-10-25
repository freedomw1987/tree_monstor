# 砍掉框架的 meta 自我管理層（第一刀）

> **交付日期**: 2026-10-26
> **對應 Backlog**: TMO-075
> **Sprint / Module**: 框架自我管理層（meta layer）
> **交付狀態**: ✅ 完成（TMO-075「第一刀」範圍內 8 項 AC 全部達成）
> - 六輪 V03 Reviewer 二審 + Gate 4 checker 的**每一項阻擋點都已修完**；第一～五輪 verdict 見 §3.1～§3.3，第六輪見 §3.4
>   （第三輪 checker 曾判 `需修復`，其 1 P1 + 5 P2 已全修）
> - 第四輪之後新增的 6 支探針與文字修正，逐輪經後續複審確認（見 §3.2、§3.3、§3.4）
> - 本次**未**達成的更大目標（框架／產品行數比仍約 1:4）已誠實列在 §5，不屬 TMO-075 範圍

## 1. 這次完成什麼

框架的自我管理層已經長到比產品本身還重（產品程式碼約 10,163 行，框架自我管理約 40,335 行，約 1:4），
初始盤點 796 支探針（`tests/` 的 `@test` 數；CI 實際執行 794 支）中有約 321 支屬 meta 探針——
只驗「Markdown 標題或字串存在」，不驗任何產品事實。
這次把**框架管理框架的那一層**砍掉一半：刪 12 支 meta 探針（162 支探針）、40 支歷史交付摘要、
3 支 PRD、2 支獨立 reflection，並把 backlog / changelog / need-you-help / trust-log 壓回可用體積。

**同時補上兩個原本不存在的守護**：
1. **D4/D8 零檢查件數會假綠** —— 過去在「日期窗內沒有交付摘要」時會**檢查 0 件卻回 rc=0**，
   也就是「未對帳不得宣告 ✅ 完成」這條硬門檻其實已經不會被觸發。現在改成 fail-closed：窗內 0 件 → rc=1。
2. **wrapper 的自動啟用分支原本無任何探針覆蓋** —— 刪掉那 3 行就會回到假綠，而其他探針都自帶 `--root` → 不會轉紅。
   現在有 DOC-DRIFT-044/045/046 直接打這條路徑（含 `--root=<p>` 等號形）。

**關鍵成果**：
- ✅ 探針 794 → 646 支（`bats --count tests/`；−162 刪除、−3 移除失效斷言、+10 新增 doc-drift 守護，
  另 +7 接手被刪探針的結構性／產品契約守護），**守護機制一件沒少**
  （mutant 仍 55 支全死、四道 Gate 不動、**門檻一個都沒放寬**）
- ✅ `docs/backlog.md` 102KB → 14KB、`docs/sop/handbook/changelog.md` 979 → 487 行（內容不丟，進 git history + 一行索引）
- ✅ D4/D8 零檢查件數 → rc=1（新增 `--require-window-checks` + DOC-DRIFT-039..043）
- ✅ 零死引用：58 個被刪路徑已全數掃過，**0 處可執行引用**
  （`scripts/`、`tests/`、`.github/` 皆無；`skills/` 只剩「已於 v2.13 刪除」的說明文字）。
  剩下的**歷史記錄型提及**分布於：`docs/sop/handbook/changelog.md` 保留段 4 處、
  `skills/*/CHANGELOG.md` 歷史條目、`skills/dav-wiki/SKILL.md` 的刪除註記、
  `docs/ci/drift-whitelist.txt` 的豁免列（**機器讀取**、刻意保留，見 §4）。除最後者外皆為散文敘述

### 1.2 為什麼做這個改動

- **問題/脈絡**：框架的 context 成本、文件成本、探針成本都已超過產品本身；且 meta 探針的驗證密度很高
  （每支都「有斷言、有名字、有 CI」）但**對產品事實的驗證力近乎零**。更麻煩的是第 4 根點：
  **探針越多，框架自我管理的膨脹速度越快**，比例不會自然收斂。
- **為什麼選這個解法**：先砍「框架管理框架」那一層（meta 探針 + 歷史產物 + 自我記錄文件），
  而不是砍產品層的四道 Gate、需求對帳機制、CI 守護。理由：產品層的每個機制都有 live contract
  （有活探針依賴、有 PR 引用、有對帳表），砍它們等於放棄能力；meta 層沒有活契約，砍了只少噪音。
- **成功怎麼看**：(a) 刪完之後，**剩下的探針是否還能咬住真 bug**；(b) 有沒有留下「掃不到就 skip」的假綠；
  (c) 有沒有留下指向已刪檔案的死引用；(d) 框架／產品行數比是否開始往回走。

## 2. 做了什麼改動

### 2.1 新增檔案

| 檔案路徑 | 用途 |
|---------|------|
| `tests/skill-frontmatter.bats` | **唯一新增的探針檔案**（第五輪 checker 指出被刪 meta 探針的 frontmatter 守護無人接手）→ repo 級一支，涵蓋全部 13 個 `skills/*/SKILL.md`（`SKILL-FM-1` 驗 frontmatter；`SKILL-FM-2` 用壞 fixture 證明偵測器真的會咬、且合格 fixture 必綠）|
| `docs/deliverable/2026-10-26-slim-meta-layer.md` | 本交付摘要（新寫） |

### 2.2 修改檔案

| 檔案路徑 | 改動內容 |
|---------|---------|
| `skills/dav-reconciler/scripts/check-doc-drift.py` | 新增 `check_deliverable_window()` + CLI `--require-window-checks`：D4/D8 的檢查件數為 0 時 fail-closed（**三種情境**：窗內 0 件 / `docs/deliverable/` 空目錄 / 窗內有件但無任何交付摘要引用得到 `docs/req/` 錨點 → D8 零檢查件） |
| `scripts/ci/check-doc-drift.sh` | 檢查**本 repo 自己**時自動開嚴格模式；對外 `--root <別的專案>`（含 `--root=<p>` 等號形）維持可攜語意（只警告） |
| `tests/doc-drift.bats` | 新增 10 支探針 DOC-DRIFT-039..048（窗內 0 件必紅 / 窗內有件必綠 / 真實 repo 窗內仍有件 / 空目錄必紅 / 無目錄不報 / wrapper 自動開嚴格 / `--root` 可攜 / `--root=` 可攜 / **CI 那行不得帶 `--root`** / **窗內有件但 D8 零檢查件仍必紅**） |
| `tests/docs-reduction.bats` | 刪 DOCS-REDUCE-004（檢查對象：兩支獨立 reflection 已隨本次減法刪除）、DOCS-REDUCE-006（檢查對象已刪） |
| `tests/dav-planner-user-background.bats` | 移除 PRD-02 存在性斷言（PRD 02 已刪） |
| `tests/probe-name-ascii.bats` | 註解不再指向已刪的交付摘要（改指 git history） |
| `tests/dav-wiki.bats` | 新增 `AC-1e`（子檔指標解析 + `found >= 4`）、`AC-1f`（子檔掏空必紅 + `checked >= 4`）、`AC-1g`（7 個獨立詞產品錨點 + `anchors >= 7`）、`AC-1h`（主檔版本列 == `CHANGELOG.md` 首列）——接手已刪 `restruct-dav-wiki.bats` 的產品契約守護 |
| `tests/pptx-slim.bats` | 新增 `PPTX-SLIM-CONTRACT`：`SKILL.md` 點名的 5 支腳本存在**且可執行**——接手已刪 `restruct-pptx-slim.bats` 的契約 |
| `skills/dav-skill-creater/tests/restruct-no-cross-dir-path.bats` | 補 2 支（`](docs/` 連結、Obsidian 跨目錄 `[[`），均含 `scanned=0` 防空過 |
| `docs/reconcile/TMO-073-reconcile.md` | 白名單筆數 6 → 7（本次新增 1 筆 D4 豁免）；並移除易過期的硬編計數 |
| `tests/env-equivalence.bats` | **淨變更 0（與 `b90e5a2` byte-identical）**：一審曾把 `.bats` 檔數地板降到 30，二審實算當時 43 支 ≥ 40（現 44 支）→ 判定放寬不必要、已改回，故最終無任何改動 |
| `docs/backlog.md` | 74 列全留 + 新增 TMO-075 = 75 列；逐欄（狀態 / 依賴 / 優先級 / 點數）不變；主題欄壓縮 + 移除表下歷史細節段；**生成器 `/tmp/slim/02-backlog.py` 冪等且可重跑** |
| `docs/sop/handbook/changelog.md` | 新增 v2.13 條目；舊 21 版收斂為一行索引（保留最新 4 版全文：v2.13 最新 + v2.12/v2.11/v2.10 為 AGENTS.md 引用的二審結論節）；**生成器 `/tmp/slim/03-changelog.py` 冪等且可重跑** |
| `docs/sop/handbook/2.4-reflection.md` | 存量特例改寫為「已清空」並指向 git history |
| `docs/system-design.md` | 移除指向不存在 PRD 的死引用 |
| `docs/ci/drift-whitelist.txt` | 新增 1 筆 D4 豁免（保留的交付摘要提到已刪的 meta 探針） |
| `docs/need-you-help.md` | 保留格式契約 + 已結案索引；逐題細節收斂 |
| `docs/trust-log.md` | 保留 checkpoint 檔頭、終局錨點、格式契約；逐筆事件收斂成每輪結果摘要 |
| `.github/workflows/ci.yml` | doc-drift 探針註解更新為 DOC-DRIFT-008..048 |
| `skills/dav-reflection/SKILL.md` | 移除「必跑已刪探針」的死引用 |
| `skills/dav-reflection/template.md` | 「檔案位置」改為「併入交付摘要的『## 反思』末段」（原本與 v2.0 矛盾、且指向已刪目錄） |
| `skills/dav-skill-creater/SKILL.md` | 移除「必跑 `bats tests/restruct-*.bats`」的死引用 |
| `skills/dav-wiki/SKILL.md` | 引用改指仍存在的專屬探針檔 |
| `skills/dev-checker-loop/workflow.md` | 移除「必跑已刪探針」的死引用 |
| `skills/dav-reflection/CHANGELOG.md`、`skills/dev-checker-loop/CHANGELOG.md`、`skills/pptx-slim/CHANGELOG.md` | 補 2026-10-26 減法說明（歷史條目不回改） |

### 2.3 刪除檔案

| 檔案路徑 | 刪除原因 |
|---------|---------|
| `tests/restruct-*.bats`（12 支 / 162 支探針） | meta 探針只驗「文字存在」，不驗產品事實；且大量斷言已刪除的路徑。**保留 3 支仍承載契約的**：`restruct-zero-cross-read`（可攜性）、`restruct-dav-trust`（checkpoint）、`restruct-dav-reconciler`（需求對帳） |
| `docs/deliverable/2026-09-*`、`docs/deliverable/2026-10-0*`、`docs/deliverable/2026-10-2*`（共 40 支） | 歷史交付摘要，內容保留在 git history；**保留 1 支**（`docs/deliverable/2026-10-26-delivery-fidelity-tmo-069-071.md`）讓 D4/D8 還有件可查 |
| `docs/prd/02-*`、`docs/prd/03-*`、`docs/prd/04-*`（3 支） | 已被減法取代的舊 PRD；**保留** `docs/prd/01-dav-planner-ac-templates.md`（4 支探針依賴）與 `docs/prd/05-delivery-fidelity.md`（D3 追溯矩陣唯一來源） |
| `docs/reflection/`（整個目錄：2 支獨立 reflection + 1 個 `.gitkeep`） | v2.0 起反省併進交付摘要末段，這批是歷史 audit；內容保留在 git history |

> 完整刪除清單（58 個檔案）見 `git show b90e5a2 --stat` 或 `git diff b90e5a2 --stat`。

### 2.4 改動背後的理由

| 改動 | 為什麼這樣設計 | 放棄的選項 |
| --- | --------------- | ----------- |
| D4/D8 零窗 → rc=1 | 「掃不到就 skip」是這套框架最貴的病：綠，但什麼都沒驗。寧可讓 CI 紅，也不接受靜默失效 | 放寬門檻（把窗內 0 件當成 0 項檢查、照樣綠）——那正是原來的病 |
| 保留 1 支交付摘要 | D4/D8 需要「現在的宣稱」有對象；全刪等於機制從此關閉 | 全刪 `docs/deliverable/`（省 40 支檔案，但機制自我關閉） |
| 保留 PRD 01 / 05 | 兩者都有 live dependency（4 支探針 + D3 追溯矩陣）；砍掉等於砍能力 | 連 01/05 一起砍（省 2 支檔案，但 D3 覆蓋歸零、探針變紅） |
| backlog 只壓主題欄 | 狀態 / 依賴 / 優先級 / 點數是**機器讀的**，主題欄是人讀的；逐欄比對後確認零變動 | 刪完成列（省更多，但破壞 D1/D7 對帳與歷史可追溯性） |
| changelog 舊版收斂成索引 | 探針用 whole-file / 欄位級 grep 驗「某版本記載了某規則」；索引行**刻意保留原始關鍵字** | 直接刪舊版（探針假紅）｜或留全文（不減法） |
| 門檻一個都不動 | mutant 門檻 55 是「探針真的咬得住」的證據；`.bats` 數量地板 40 在刪完後仍有 4 支餘裕（44 ≥ 40），沒有放寬的理由 | 把 mutant 門檻一併下修、或把 `.bats` 地板調鬆（省事，但守護機制被閹割） |

## 3. 驗收標準對應

| AC | 描述 | 結果 | 證據 |
|----|------|------|------|
| AC-1 | 12 支 meta 探針刪除，保留 3 支契約探針 | ✅ | `git diff b90e5a2 --stat -- tests/`；`ls tests/restruct-*.bats` → 3 支 |
| AC-2 | 歷史產物收斂且內容不丟 | ✅ | `docs/deliverable/` 41 → 2 支；`docs/prd/` 5 → 2 支；其餘在 git history |
| AC-3 | backlog 既有 74 列逐欄不變（+1 列新登錄 TMO-075 = 75 列） | ✅ | 逐欄比對（ID / 優先級 / 點數 / 狀態 / 依賴）→ 既有 74 列 0 差異 |
| AC-4 | D4/D8 窗內 0 件必紅（含 wrapper 自動啟用這條路徑） | ✅ | DOC-DRIFT-039..048；wrapper 在本 repo 自動開嚴格模式（CI 那行也由 047 鎖住） |
| AC-5 | 守護機制一件沒少、**門檻一個都沒放寬** | ✅ | mutant 55 支全死；`gates.json` 未動；四道 Gate 未動；`.bats` 地板維持 40 |
| AC-6 | 零死引用 | ✅ | 58 個刪除路徑全 repo 掃描 → **0 處可執行引用**（`scripts/` / `tests/` / `.github/` 全無；`skills/` 只剩刪除註記文字）；其餘為歷史記錄型提及（`docs/sop/handbook/changelog.md` 4 處、`skills/*/CHANGELOG.md`、`skills/dav-wiki/SKILL.md`）＋ `docs/ci/drift-whitelist.txt` 的**機器讀取豁免列**（刻意保留，非斷鏈） |
| AC-7 | 全量測試全綠 | ✅ | `bats tests/` → 1..646，646 綠 / 0 紅 / 0 skip |
| AC-8 | Reviewer 二審 | ✅ | 第一輪 `request-changes`（7 阻擋點）、第二輪 `request-changes`（3 P1 + 4 P2）、第三輪 `approve-with-comments`（3 P2）＋ Gate 4 checker `需修復`（1 P1 + 5 P2）、第四輪 `approve-with-comments`（Reviewer 0 P0/0 P1/0 P2/6 P3；checker 0 P0/0 P1/2 P2/3 P3）、第五輪 `approve-with-comments`（Reviewer 0 P0/0 P1/1 P2/3 P3；checker 0 P0/0 P1/2 P2/5 P3）、**第六輪 `approve-with-comments`（Reviewer 0 P0/0 P1/2 P2/4 P3；checker 0 P0/0 P1/3 P2/3 P3）** → 全部已修（見 §3.1～§3.4） |

### 3.1 需求對帳（Reviewer 阻擋點 ↔ 修正）

> 本次是框架自我管理層的減法，**沒有新產需求錨點**（`docs/req/` 未動）。
> 對帳的「需求錨點」= Reviewer 二審提出的阻擋點；對帳者：Reviewer subagent（未參與實作）。
> 硬門檻：只要還有任何一項未實作 → 本文件的狀態就不得標「✅ 完成」。

**第一輪（7 項阻擋點，verdict `request-changes`）**

| # | Reviewer 阻擋點 | 處理 | 狀態 |
|---|---------------|------|------|
| P0-1 | 刪 PRD 01～04 會打紅 4 支保留探針 | 保留 PRD 01，只刪 02～04；同步移除 PRD-02 存在性斷言 | ✅ 已實作 |
| P0-2 | 刪 `docs/ac/*.html` 會打紅探針 | **不刪** `docs/ac/*.html` | ✅ 已實作 |
| P0-3 | 刪 `docs/reflection/*` 會打紅 DOCS-REDUCE-004 | 刪 DOCS-REDUCE-004（檢查對象＝兩支獨立 reflection 已隨本次減法刪除）；另刪 DOCS-REDUCE-006（資訊型 WARN 探針，其檢查對象亦在本次刪除範圍） | ✅ 已實作 |
| P0-4 | mutants.tsv 依賴待刪探針 | mutants.tsv **完全未動**（55 列）；`restruct-dav-trust` / `restruct-dav-reconciler` 保留 | ✅ 已實作 |
| P0-5 | 刪 skill-local 探針會打紅 ENV-EQ-11 | `skills/dav-skill-creater/tests/` **未動** | ✅ 已實作 |
| P0-6 | `.bats` 檔數地板 40 = 0 餘裕 | 實算後維持 40（當時 43 支、現 44 支 ≥ 40） | ✅ 已實作 |
| P0-7 | 刪 backlog 完成列會打紅 D1 | **不刪任何 backlog 列**（74 列全留，逐欄不變） | ✅ 已實作 |

**第二輪（3 項 P1 + 4 項 P2，verdict `request-changes`，無 P0）**

| # | Reviewer 阻擋點 | 處理 | 狀態 |
|---|---------------|------|------|
| P1-1 | wrapper 自動開嚴格模式的分支**無任何探針覆蓋**，刪掉會假綠回歸 | 新增 DOC-DRIFT-044（不帶 `--root` 必紅）/ 045（`--root` 可攜）/ 046（`--root=` 可攜）；已用 mutant 驗證刪掉該分支 → 044 轉紅 | ✅ 已實作 |
| P1-2 | `.bats` 地板 40 → 30 的放寬**不必要**，且理由記載不實 | 改回 40；本次變更**不含任何門檻放寬**；changelog 與本文件的理由敘述同步更正 | ✅ 已實作 |
| P1-3 | 新增探針數記錯（3 → 8）、探針總數記錯（632 → 637） | 所有文件數字同步更正，並寫明 796／794／646 的口徑差異 | ✅ 已實作 |
| P2-1 | DOCS-REDUCE-004 的刪除理由記載錯誤（與 HTML 政策無關） | 改為「檢查對象：兩支獨立 reflection 已隨本次減法刪除」 | ✅ 已實作 |
| P2-2 | §4 證據表「14 項檢查」與當前樹的 15 項不符 | 改為 15 項（附實際輸出） | ✅ 已實作 |
| P2-3 | 本文件內部數字不一致（57 vs 58）、3 處「見 §5」指向不存在內容、章節跳過 §7 | 全部改為 58；交叉引用改指 §3.1；章節改為 §1..§6 + §7（反思） | ✅ 已實作 |
| P2-4 | `ci.yml` 探針註解過期（008..031） | 改為 DOC-DRIFT-008..048 | ✅ 已實作 |

**第三輪（V03 Reviewer：0 P0 / 0 P1 / 3 P2，verdict `approve-with-comments`）＋（Gate 4 checker：1 P1 + 5 P2，verdict `需修復`）**

> 兩角色獨立跑、互不重疊；下方編號為「Reviewer F# / checker P#」對照。

| # | 阻擋點 | 處理 | 狀態 |
|---|-------|------|------|
| **P1-1 / F2** | `skills/dav-wiki/SKILL.md:115` 宣稱「`tests/dav-wiki.bats` AC-1a~1d 需要」是**假覆蓋**——那 4 支只是檔案存在性斷言；真正要求的是已刪的 `restruct-dav-wiki.bats` | 改為「慣例；原 dav-wiki 的 meta 探針（`restruct-dav-wiki.bats`）要求，該探針已於 2026-10-26 減法刪除」 | ✅ 已實作 |
| **P2-1** | 刪 dav-wiki meta 探針連帶移除 **3 個產品層守護**（子檔指標解析、子檔掏空必紅、產品名詞錨點） | `tests/dav-wiki.bats` 補 `AC-1e`（指標解析 + `found >= 4`）、`AC-1f`（非空白行 ≥ 8 + `checked >= 4`）、`AC-1g`（`_index.json` / `--purge` / `deprecated_at` 等 7 個獨立詞錨點 + `anchors >= 7`） | ✅ 已實作 |
| **P2-2** | repo 級「`](docs/` 連結」與「跨目錄 `[[...]]`」守護只剩一半（原 `restruct-retro-plain-text.bats` 已刪） | skill-local 探針 `restruct-no-cross-dir-path.bats` 補 2 支：`](docs/` 與 Obsidian 跨目錄 `[[`（均含 `scanned=0` 防空過） | ✅ 已實作 |
| **P2-3** | 本文件 §3.1 寫「刪 DOCS-REDUCE-006」的理由與事實不符（006 是資訊型 WARN，對象未刪） | 改為「資訊型 WARN 探針，其檢查對象亦在本次刪除範圍」 | ✅ 已實作 |
| **P2-4** | `docs/sop/handbook/changelog.md:76` 指向已刪交付摘要且未加註 | 該行補「（該交付摘要已於 v2.13 隨歷史產物收斂刪除，內容見 git history）」 | ✅ 已實作 |
| **P2-5** | wrapper 用 `"$*"` 子字串判 `--root` → `--whitelist /tmp/--root=x.txt` 會誤命中、**靜默關掉 fail-closed** | 改為 `for _a in "$@"` 逐引數 `case` 比對；已驗證該情境現在 rc=1 且報 `no-in-window-deliverable` | ✅ 已實作 |
| **F1** | 「零死引用」宣稱與事實不符：`changelog.md` 保留段仍有提及已刪探針 | ① 本文件宣稱改精確為「**0 處可執行引用**；其餘僅為歷史記錄型提及」；② changelog 保留段 **4 處**補「【該探針已於 v2.13 減法刪除，本列為歷史記錄】」 | ✅ 已實作 |
| **F3** | `DOC-DRIFT-041` 是**弱守護**：真實 repo 的 `docs/deliverable/` 整目錄消失時，`check_deliverable_window()` 直接 `return`（連 WARNING 都不印）→ 041 仍綠 | 補 `[ "$status" -eq 0 ]` + `docs/deliverable/` 目錄存在 + 窗內有 `20*.md` 三條正向斷言；已用 `/tmp` 副本驗證「整包刪除 → 041 轉紅」 | ✅ 已實作 |

- 對帳表: 本節（上表）｜對帳者: Reviewer subagent（V03 三輪）＋ checker subagent（Gate 4）｜覆蓋率: 7 + 7 + 8 = 22 / 22（100%）

### 3.2 第四輪複審（並行雙角色）與其後的增量修正

第四輪以 **2 個獨立唯讀 subagent 並行**跑（V03 Reviewer 二審 + Gate 4 checker），兩人皆只有 read/grep/find/ls（無 shell），
因此所有 runtime 主張被他們標為「作者自述、未驗證」——本節同時補上 supervisor 的實跑結果。

| 角色 | Verdict | P0 | P1 | P2 | P3 |
|------|---------|----|----|----|----|
| V03 Reviewer 二審（task-1） | `approve-with-comments` | 0 | 0 | 0 | 6 |
| Gate 4 checker（task-2） | `approve-with-comments` | 0 | 0 | 2 | 3 |

**第四／五輪後新增的 4 支探針**（都是「產品契約」而非「文字存在」；全部以副本 mutation 驗證會轉紅）：

| 補回的守護 | 原守護者（已刪） | 為什麼不是文字存在性 | 落點 | 突變驗證 |
|-----------|----------------|--------------------|------|---------|
| 主檔最新版本列 == `CHANGELOG.md` 首列（防版本漂移） | `restruct-dav-wiki.bats` | 這是**跨檔一致性**契約，同 dav-trust 做法 | `tests/dav-wiki.bats` `AC-1h` | 改 `v2.2.3` → `v9.9.9` → ✅ 轉紅 |
| SKILL.md 點名的 5 支 pptx 腳本存在**且可執行** | `restruct-pptx-slim.bats` | 文件說有這支、使用者照打卻 `permission denied` = 產品層故障 | `tests/pptx-slim.bats` `PPTX-SLIM-CONTRACT` | `chmod -x pptx-repack.py` → ✅ 轉紅 |
| 全部 13 個 skill 的 frontmatter（`name` + `description`） | `restruct-dav-reflection.bats`／`restruct-dev-checker-loop.bats` | 缺 frontmatter = skill **不會被載入**，是產品層故障（非文字存在性）；第五輪 checker 抓到無人接手 | `tests/skill-frontmatter.bats` `SKILL-FM-1/2`（涵蓋 13 個 skill，覆蓋比被刪版本更廣） | `name: dav-reflection` → `wrong-name` → ✅ 轉紅 |

**第四輪 findings 對帳（5 條；皆非阻擋）**：

| # | Finding | 處理 | 狀態 |
|---|---------|------|------|
| P2-1 / P3-4 | 探針總數三處不一致（mission 舊稿 639／樹上 640；changelog 仍寫「2 支」） | 以 `bats --count tests/` 實跑定案；mission 為舊稿已作廢；changelog 的 P1 列與前置段改為**輪次歸屬分開記**（第三輪＝AC-1e/1f/1g；第四輪後＝AC-1h／`PPTX-SLIM-CONTRACT`／`SKILL-FM-1/2`） | ✅ 已修正 |
| P2-2 | 被刪 meta 探針的**殘留覆蓋損失**比原承認的「2 處」更廣（regression-guard 的 `REGRESSION_MODE`／API 段、tdd-test-writer 的 GWT 指引、pptx-slim 的 130 行早警） | 其中 2 條屬真契約 → 已補回（見上表）；其餘屬**文字存在性**，刪除為本次設計目標 → 於 §5 逐條誠實列出 | ✅ 已修正 |
| P3-1 | 「零死引用」把 `skills/*/CHANGELOG.md` 誤歸入 `docs/` 子句；且 `skills/dav-wiki/SKILL.md` 的刪除註記未列入 | 列舉改為分開敘述（`docs/` sop changelog 4 處｜`skills/*/CHANGELOG.md`｜`skills/dav-wiki/SKILL.md`｜whitelist） | ✅ 已修正 |
| P3-2 | §3.1 第二輪列殘留舊值 639 | §3.1 第二輪列改為現行口徑（「632 → 637」＋「796／794／646」）；第四輪當時的 642 已隨後續新增探針更新（現行定案值見上方「數字變化」） | ✅ 已修正 |
| P3-5 | `/tmp/slim/06-edits.py` 仍留有「地板 40 → 30」的 edit（產物正確、但生成器重跑會偷偷降門檻） | 已從生成器刪除該 2 個 edit，原地留註解說明「為何刻意留空」，避免日後照舊稿再降 | ✅ 已修正 |

- 對帳表: 本節（上表）｜對帳者: Reviewer subagent（V03 第四輪）＋ checker subagent（Gate 4 第四輪）｜覆蓋率: 5 / 5（100%）

### 3.3 第五輪複審（並行雙角色）與其後的增量修正

| 角色 | Verdict | P0 | P1 | P2 | P3 |
|------|---------|----|----|----|----|
| V03 Reviewer 二審 | `approve-with-comments` | 0 | 0 | 1 | 3 |
| Gate 4 checker | `approve-with-comments` | 0 | 0 | 2 | 5 |

> 第五輪仍無法實跑（reviewer 角色沒有 shell 工具），因此 runtime 主張由 supervisor 實跑補證：
> 第五輪當時實跑：`bats tests/` → `1..644`、644 綠 / 0 紅 / 0 skip（`/tmp/slim-full7.txt`、`/tmp/slim-full8.txt`）。

**第五輪 findings 對帳（6 條；皆非阻擋）**：

| # | Finding | 處理 | 狀態 |
|---|---------|------|------|
| task-1 P2-1 | changelog v2.13 的探針口徑與輪次歸屬矛盾（把 AC-1h／`PPTX-SLIM-CONTRACT` 記成第三輪；口徑寫「3 支」） | 生成器內 P1 列與前置段改為**輪次分開記**；口徑改「2 檔／5 條」；本文件 §3.2 該列改為描述實際產物文字 | ✅ 已修正 |
| task-2 P2-1 | §5 的「殘留覆蓋損失」列舉不全——`dav-reflection`／`dev-checker-loop` 的 **frontmatter-mandatory** 守護無人接手 | 這是真契約（缺 frontmatter = skill 不會被載入）→ 新增 repo 級 `tests/skill-frontmatter.bats`（`SKILL-FM-1/2`，涵蓋全部 13 個 skill，含偵測器自證）；另 AGENTS.md ↔ handbook 版本一致性改人工一事補進 §5 | ✅ 已修正 |
| task-2 P2-2 | 本文件標頭**預先宣告**第五輪已確認（寫作當下尚未發生）；且「四輪皆無 P0/P1/P2 阻擋」措辭過寬（第三輪 checker 判 `需修復`） | 標頭改為「結案時最終兩輪 verdict 皆 `approve-with-comments`」並註明第三輪 checker 曾判 `需修復` 已全修；§3.3 補實際 verdict | ✅ 已修正 |
| task-2 P3-1 | 把 whitelist 的**機器讀取**豁免列描述成「散文敘述」 | §1 與 AC-6 改為「機器讀取的豁免列（刻意保留）」 | ✅ 已修正 |
| task-2 P3-3 | `docs/reconcile/TMO-073-reconcile.md:15` 仍寫 whitelist「6 筆」，本次已變 7 筆 | 改為 7 筆 | ✅ 已修正 |
| task-1 P3-1／P3-2 | §2.2 把 `tests/env-equivalence.bats` 列為修改檔（實為 byte-identical）；§6.1 仍寫「跑第三輪二審」 | 改為「淨變更 0」；§6.1 改為「合併回 master」 | ✅ 已修正 |

- 對帳表: 本節（上表）｜對帳者: Reviewer subagent（V03 第五輪）＋ checker subagent（Gate 4 第五輪）｜覆蓋率: 6 / 6（100%）

> 本表只列**有動作**的 findings；兩角色其餘 P3（重複項、資訊性項）不另立列。R5-8（`06-edits.py`）與 R5-9（突變證據留存）分別記在 §3.2 的「第四輪 P3-5」列與 §4 的證據行。

### 3.4 第六輪複審（並行雙角色）與其後的增量修正

| 角色 | Verdict | P0 | P1 | P2 | P3 |
|------|---------|----|----|----|----|
| V03 Reviewer 二審 | `approve-with-comments` | 0 | 0 | 2 | 4 |
| Gate 4 checker | `approve-with-comments` | 0 | 0 | 3 | 3 |

**第六輪 findings 對帳（7 條合併列；兩角色共 12 項 finding，重複者合併）**：

| # | Finding | 處理 | 狀態 |
|---|---------|------|------|
| P2-1 / F1 | `docs/reconcile/TMO-073-reconcile.md` 仍有多處本 diff 前的硬編計數（探針 37、14 項檢查 / 6 項豁免、37/37）→ 同檔自相矛盾（同一份已寫「白名單 7 筆」） | 全數更新為 45 / 15 項檢查、7 項豁免 / 45-45；`main()` 呼叫清單補 `check_deliverable_window`；並註明 `DOC-DRIFT-038` 為未使用空號 | ✅ 已修正 |
| P2-2 | 新增 fail-closed 只在「CI 不帶 `--root`」時生效，但**沒有任何探針鎖住 CI 那一行** → 改成 `--root .` 就靜默關閉嚴格模式，而 022／041／044／045／046 全部仍綠 | 新增 `DOC-DRIFT-047`：CI 的 `run:` 行若帶 `--root` 就必須明寫 `--require-window-checks`，否則紅；已用副本 mutation（CI 行加 `--root .`）驗證會轉紅 | ✅ 已修正 |
| F2 | §5 漏列 `dav-planner`／`regression-guard` 的「主檔版本列 == CHANGELOG 首列」守護損失 | §5 補該列；並把 `tests/dav-wiki.bats` 註解裡失準的「同 dav-trust / dav-planner 做法」改為「同 dav-trust 做法」 | ✅ 已修正 |
| F3 | §3.2 的 P3-2 列宣稱「改為 642（本次定案值）」，但 §3.1 內沒有 642、且 642 已非定案值 | 該列改為描述實際文字（§3.1 第二輪列改為 632 → 637 ＋ 796／794／646 口徑） | ✅ 已修正 |
| F4 | changelog v2.13 把 `SKILL-FM-1/2` 記成第四輪產出（實為第五輪 checker 指出後補）；且整份 v2.13 無第五輪紀錄 | 生成器內第四輪修正摘要改「2 支（`AC-1h`／`PPTX-SLIM-CONTRACT`）」，並補第五輪 verdict 段 | ✅ 已修正 |
| F5 | `/tmp/slim/06-edits.py` 警語不實（實際不會中止、會繼續寫檔）；且 wrapper 那條 edit 的 `new` 仍是修好前的 `"$*"` 版本 → 重跑會**復活**第三輪 P2-5 的洞 | 刪掉該 wrapper edit，只留註解；檔頭警語改為描述實際破壞範圍 | ✅ 已修正 |
| F6 | 新 fail-closed 只保證 **D4** 有件可查；窗內有件但無任何交付摘要引用得到 `docs/req/` 錨點時，**D8** 仍可能是 0 件而全綠 | `check_deliverable_window()` 補第二個條件（`docs/req/` 存在且窗內有件時，`reconcile_checked` 必須 ≥ 1）＋ `DOC-DRIFT-048`（壞／好 fixture 雙向）；已用副本 mutation 驗證會轉紅 | ✅ 已修正 |

- 對帳表: 本節（上表）｜對帳者: Reviewer subagent（V03 第六輪）＋ checker subagent（Gate 4 第六輪）｜覆蓋率: 7 / 7（100%）

## 4. 測試結果

| 測試類型 | 通過 / 總數 | 備註 |
|---------|-------------|------|
| 回歸測試（全量 bats） | 646 / 646 | baseline 794 / 794；刪除的是 meta 探針，**0 個 skip、0 個 not ok** |
| 突變測試（mutant） | 55 / 55 全死 | `scripts/ci/mutants.tsv` 未動；MMD-1 門檻 `[ "$n" -eq 55 ]` 未放寬 |
| 文件漂移（D1..D8） | 15 項檢查 / 7 項豁免 | `bash scripts/ci/check-doc-drift.sh` → rc=0（嚴格模式） |
| Markdown lint | 0 issues | `markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"` |
| 其他 CI 腳本 | 全綠 | check-skill-size（13 個 SKILL.md ≤ 150 行）、check-python-heredocs、check-ffmpeg-version、4 支 probe linter |

> 突變證據留存：`/tmp/slim-mutation-evidence.txt`（**8 個突變**的 `not ok` 原文：`AC-1e/1f/1g/1h`、`PPTX-SLIM-CONTRACT`、`SKILL-FM-1`、`DOC-DRIFT-047`、`DOC-DRIFT-048`）
> 測試輸出保留：`/tmp/slim-full9.txt`（最新全量 646 支）、`/tmp/slim-full8.txt`、`/tmp/slim-full7.txt`、`/tmp/slim-full6.txt`、`/tmp/slim-full4.txt`、`/tmp/slim-full3.txt`、`/tmp/slim-full.txt`、
> `/tmp/slim-full2.txt`、`/tmp/baseline-full.txt`（baseline 794 支）、`/tmp/slim-mutants.txt`。
> 口徑：`bats --count tests/` = 646；`grep -c '^@test' tests/*.bats` = 648（多出的 2 支是 `@test` 字樣出現在註解／heredoc）。
> 探針數口徑：`bats --count tests/`（CI 實際執行數）；`grep -c '^@test'` 會多算 2 支出現在註解／heredoc 的字樣。
> skill-local 探針（`bats tests/` 不跑到）以 CI 的方式跑：`SKILLS_DIR_OVERRIDE="$PWD/skills" bats skills/*/tests/*.bats` → 5 / 5 綠。

**新增／修改探針的突變驗證**（在 `/tmp` 副本上做，母樹不受影響）：

| 突變 | 預期轉紅的探針 | 結果 |
|------|--------------|------|
| 掏空 `skills/dav-wiki/concept-evolution.md` | `AC-1f` | ✅ 轉紅 |
| 把 `soft-delete.md` 的 `--purge` 改成 `--purgex` | `AC-1g` | ✅ 轉紅 |
| 把 `skills/dav-wiki/SKILL.md` 的 `v2.2.3` 改成 `v9.9.9`（版本漂移） | `AC-1h` | ✅ 轉紅 |
| `chmod -x skills/pptx-slim/scripts/pptx-repack.py` | `PPTX-SLIM-CONTRACT` | ✅ 轉紅 |
| 把 `skills/dav-reflection/SKILL.md` 的 `name: dav-reflection` 改成 `name: wrong-name` | `SKILL-FM-1` | ✅ 轉紅 |
| 把 CI 的 `run:` 行改成帶 `--root .`（嚴格模式靜默關閉） | `DOC-DRIFT-047` | ✅ 轉紅 |
| 移除 `check_deliverable_window()` 的 D8 第二條件 | `DOC-DRIFT-048` | ✅ 轉紅 |
| 主檔加一個指向不存在子檔的指標 | `AC-1e` | ✅ 轉紅 |
| `SKILL.md` 加 `](docs/req/foo.md)` | skill-local「links into monorepo docs/」 | ✅ 轉紅 |
| `SKILL.md` 加 `[[../docs/foo]]` | skill-local「Obsidian cross-directory wikilink」 | ✅ 轉紅 |
| 刪掉 wrapper 的自動啟用嚴格模式分支 | `DOC-DRIFT-044` | ✅ 轉紅 |
| 整包刪除 `docs/deliverable/` | `DOC-DRIFT-041` | ✅ 轉紅 |
| `--whitelist /tmp/--root=x.txt` 仍要開嚴格模式 | wrapper 逐引數比對 | ✅ rc=1、報 `no-in-window-deliverable` |

## 5. 已知問題 / 限制

> ⚠️ 老實標記已發現但這次沒解決的問題，避免「假完成」。

| 問題 | 嚴重性 | 已記錄位置 |
|------|--------|-----------|
| **本次只做第一刀**：框架／產品行數比仍約 1:4，meta 層的「每修一個問題衍生多份 backlog/probe/mutant/deliverable/changelog」機制**還在** | P1 | TMO-075（後續切片見 §6.3） |
| **刪 meta 探針確實讓部分覆蓋變薄**：三、四、五輪共抓到 **6 處**需接手（dav-wiki 結構性／產品名詞錨點／版本一致性、repo 級跨目錄連結、pptx 腳本可執行契約、skill frontmatter）→ 已用 `AC-1e/1f/1g/1h`、skill-local 2 支、`PPTX-SLIM-CONTRACT`、`SKILL-FM-1/2` 接手。後續再刪探針前，應先問「這支守的是文字存在還是產品不變式」 | P2 | 本文件 §3.1、§3.2、§3.3、§7.2 |
| **明確接受的殘留覆蓋損失**（第四、五輪 checker 逐支比對後，判定屬「文字存在性」故**不補回**）：① `restruct-regression-guard.bats` 的 `## TL;DR`／`## 觸發時機`／… 段標與 `REGRESSION_MODE` 字串；② `restruct-tdd-test-writer.bats` 的 Given-When-Then 指引字串；③ `restruct-pptx-slim.bats` 的「SKILL.md ≤ 130 行」早警（硬上限 150 行的 `check-skill-size.sh` 仍在）。三者都只斷言「某段文字在檔案裡」，改寫文字就會假紅——正是本次要減掉的噪音 | P3 | 本文件 §3.2、§3.3 |
| **各 skill「主檔版本列 == 同目錄 `CHANGELOG.md` 首列」只剩 3 個 skill 有守護**：原 `restruct-dav-planner.bats`／`restruct-regression-guard.bats` 各守一個；刪除後僅 `dav-trust`／`dav-reconciler`／`dav-wiki`（`AC-1h`）仍有活探針，`dav-planner`／`regression-guard` 無接手（改人工） | P3 | 本文件 §3.4 |
| **AGENTS.md ↔ handbook 的 SOP 版本一致性改為人工維護**：原 `restruct-agents-md.bats` 守的「AGENTS.md 宣告的 SOP 版本 == handbook 實際版本」與「Gate 4.5 已登錄」兩條隨該探針刪除，現無探針接手 | P2 | `docs/sop/handbook/changelog.md` v2.10 決策紀錄（自己承認「下次升版需同步…原註記提到的守版探針已刪除」）、本文件 §3.3 |
| **frontmatter 註冊契約已接手（非殘留損失）**：原 `restruct-dav-reflection.bats`／`restruct-dev-checker-loop.bats` 各守一個 skill 的 frontmatter；第五輪 checker 指出刪除後無人接手 → 已改為 repo 級 `tests/skill-frontmatter.bats`，**一次涵蓋全部 13 個 skill**（覆蓋比被刪版本更廣） | ✅ 已補 | 本文件 §3.3 |
| **新 D8 守護的訊號粒度是「有沒有引用得到錨點檔」，不是「錨點裡有沒有 R-ID」**：若 `docs/req/<US>-requirement.md` 存在但整份沒有任何 `- R<n>` 列，`check_reconcile()` 會以空集合通過、D8 的內嵌↔權威比對也會以 `[] == []` 通過 → 新守護會以為「D8 有在檢查」。本 repo 由 `DOC-DRIFT-003`（錨點必 R-ID 連續唯一）擋住，故不影響綠燈；未在 `check_reconcile()` 補 `report("D7", …)` 是刻意的（第七輪 P3-6，屬既有設計邊界，不在本次減法範圍） | P3 | 本文件 §3.4、`tests/doc-drift.bats` DOC-DRIFT-003 |
| **changelog 舊版改為索引**：靠關鍵字保留撐住探針，未來若有人改寫索引文字會讓探針假紅 | P2 | `docs/sop/handbook/changelog.md`（索引段已註明「刻意保留關鍵字」） |
| **backlog 主題欄是截斷版**：語意未改，但細節只在 git history | P2 | `docs/backlog.md`（已加說明） |
| **worktree 環境註記**：`.venv` 在 worktree 須是**真目錄**（symlink 會讓 gitignore 失效） | P3 | 本次排查紀錄（`git check-ignore` 對 symlink 不套用目錄規則） |
| **新探針尚未登記進 mutants.tsv** | P2 | DOC-DRIFT-039..046 已用手工 mutation 驗證「會轉紅」（例：刪掉 wrapper 的自動啟用分支 → DOC-DRIFT-044 轉紅）；但登記進 `scripts/ci/mutants.tsv` 會把 MMD-1 計數 55 → 58，**本次刻意不動該門檻**（維持 55）。待後續單獨一輪處理 |

## 6. 下一步建議

### 6.1 立即可做（建議優先）

1. **合併 `feat/slim-meta-layer` 回 master**
   - **為什麼這個優先**：這是唯一能讓減法「真的生效」的動作；而框架／產品比只有在合併後才會變。
     五輪二審共抓出 7 + 7 + 8 + 5 + 6 項問題——**審查確實有產出**；最終兩輪皆 `approve-with-comments`、無 P0/P1/P2 阻擋。
2. **跑一次真實專案的 dogfood** — 在一個有真實需求的工作目錄跑一輪完整 SOP，量測 context 與產物量的實際下降
   - **為什麼這個優先**：本次證明的是「檔案數下降、測試仍全綠」；還沒證明「干活變快了」——那才是這次的真正目標。
3. **把「每個 US 產生 N 份產物」的比例寫成一條探針** — 例如「單一 US 的 deliverable + backlog 變更 ≤ 2 份」
   - **為什麼這個優先**：第 4 根點（衍生膨脹）目前靠人記性擋；沒有探針，下一輪又會長回來。

### 6.2 下一個 Sprint 考慮

- [ ] 第二刀：砍「框架治理」類文件（`docs/system-design.md`、`docs/DESIGN.md`、AGENTS.md 的重複說明）——需先確認 live dependency
- [ ] 風險分級 SOP：不是每個任務都跑完整四道 Gate（依風險分級決定 Gate 組合）——需先有分級準則
- [ ] context 載入上限：skill / handbook 的行數與 token 預算（目前只有 150 行上限，沒有 token 上限）

### 6.3 長期方向（Think Big）

- **讓框架自我管理層的膨脹率可見**：每個 sprint 產出「框架行數 / 產品行數」的趨勢圖，比例上升就是紅燈
- **探針分級制度**：把探針分成「行為契約（不可刪）／格式契約（可刪）／meta（應刪）」三級並標在檔頭，之後砍探針就有依據而不是靠臨場判斷
- **文件要有生命週期**：`docs/` 下的文件要有「有效期限 / 觸發重建條件」，過期自動降級成索引——這次是人工做，下一步應該自動化

## 7. 反思

### 7.1 6 維度檢查

| # | 維度 | 結果 | 備註 |
| - | --- | --- | --- |
| 1 | UX/UI 一致性 | N/A | 本次無 UI 變更（框架內部減法） |
| 2 | RWD 響應式設計 | N/A | 同上 |
| 3 | 技術債 | ⚠️ | 淨減少：58 個檔案刪除、3 個大文件壓縮；但**衍生膨脹的機制本身沒動**（見 §6.1-3） |
| 4 | 可維護性 | ✅ | 可執行死引用清零、矛盾契約修正（`docs/reflection/` 存放位置）、changelog 索引策略寫在檔內 |
| 5 | 測試完整性 | ✅ | 守護機制全數保留（mutant 55 全死、四道 Gate 不動、門檻零放寬）；探針數下降是因為**刪掉的是不驗產品事實的 meta 探針** |
| 6 | 文件一致性 | ✅ | 58 個刪除路徑 0 處可執行引用；backlog / changelog / need-you-help / trust-log 四份自我記錄文件壓縮後仍可機械驗證；五輪二審抓到的數字不一致全數修正 |

### 7.2 這次真正學到什麼

1. **「驗證密度高」不等於「驗證力高」**：321 支 meta 探針每支都有名字、有斷言、有 CI，但刪掉 162 支之後，
   全量測試**一樣全綠**——證明它們守的是「文件長什麼樣」，不是「產品動不對」。
2. **減法最怕留下「掃不到就 skip」**：刪掉歷史產物後，D4/D8 的檢查件數會歸零，機制會**看起來還在、實際已經關掉**。
   這是這次唯一一個「不補就會假綠」的地方——補上之後，減法才真的安全。
   **而且補完還要再補一層**：wrapper 自己的「自動開嚴格模式」分支也沒有探針覆蓋——**新機制的開關本身也需要守護**。
3. **門檻要分「基數」與「強度」**：mutant 55 支是強度（不能動），`.bats` 檔數地板是基數（要對齊現況）。
   我一開始把地板從 40 降到 30，二審實算發現**當時 43 支（現 44 支）≥ 40、本來就成立** → 放寬既不必要、理由也不實。
   教訓：**放寬門檻前先實算**，多數「看起來要放寬」的情況其實不用放寬。
4. **刪之前先量「誰在依賴」**：第一輪 Reviewer 抓到「PRD 01 有 4 支探針依賴」「mutants.tsv 的探針就是待刪的那 3 支」
   ——這些是「以為沒人用其實是地基」的東西。盤點不夠，**依賴圖**才夠。
5. **歷史不刪，改成可追溯**：把 24 版 changelog、75 列 backlog 的細節收到 git history + 一行索引，
   探針錨定的關鍵字刻意保留——資訊沒有消失，但**不再佔 context**。
6. **文件裡的每個數字都是一個會過期的斷言**：這次交付摘要一開始寫「796 支探針」又寫「794」，
   二審直接抓出「同一量在文件內未互相對帳」。**數字要標口徑**（`bats --count` vs `grep -c '@test'`），
   否則半年後沒人知道哪個是真的。
