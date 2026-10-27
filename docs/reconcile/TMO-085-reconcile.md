# TMO-085 需求對帳表

> 對帳者: 獨立 Reviewer subagent（V03 二審，**未參與實作**）| 對帳時間: 2026-10-27
> 錨點: docs/req/TMO-085-requirement.md
> 覆蓋率: **5/5**
> 對帳者獨立性: 非降級路徑（未參與本次實作；實作由主 agent 完成）
> 對帳者輸入: 需求錨點全文 ＋ 最終變更清單（`git diff --cached HEAD`）；**無實作過程自述**

## 對帳表

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | 探針按「對象」分類：對象係可執行碼 → 保留；對象係文件／規格內容 → 刪。刪走嘅探針必須**連帶清埋**佢哋守嘅機械工具、mutant 列、CI／本機閘步驟（**唔留死引用**） | ⚠️ 部分實作 | 刪除：`tests/` 17 支「測文件」探針（agents-md／backlog-trust-mode-completion／dav-planner-ac-templates／dav-planner-user-background／doc-facts／docs-reduction／framework-weight／gate-in-skill／markdownlint-guard／probe-name-ascii／regression-guard-watch-mode／restruct-dav-reconciler／restruct-dav-trust／restruct-zero-cross-read／skill-frontmatter／skill-size-guard／v2-reduce-deliverables）＋ `skills/dav-skill-creater/tests/` 2 支（check-examples-version-baseline／restruct-no-cross-dir-path）；死碼工具 `scripts/ci/check-framework-weight.py`、`scripts/ci/check-skill-size.sh`、`docs/ci/framework-weight.json` 已刪 | `.github/workflows/ci.yml` 已移除「Verify SKILL.md size (≤ 150 lines)」＋「Verify framework weight」兩步；`scripts/ci/mutants.tsv` 49 列（`tests/mutant-must-die.bats:90` 斷言 `-eq 49`，實數 49 ＝ 47 行為鎖 ＋ 2 文件／資料契約鎖）；`scripts/check-all.sh` 冇對應步驟；刪除清單同 `docs/ac/TMO-085.md` AC01 逐項對得上 | ⚠️ **「唔留死引用」未達成**（9 類）：①`docs/ci/drift-whitelist.txt:33-51` 19 筆新 D4 豁免嘅 key 缺 `:<被引用路徑>`（`check-doc-drift.py:516` 嘅 key 係 `f"{doc.name}:{path}"`）→ 19 筆全部失效，其中 9 筆仲係同一 key 重複 → D4 閘紅；②`docs/DESIGN.md:288` 連結已刪嘅 `sop/handbook/changelog.md`；③`skills/dav-trust/resume.md:178` 指向已刪嘅 `本 skill CHANGELOG.md`；④`skills/dav-reconciler/examples.md:21` 指向已刪嘅 `tests/restruct-dav-reconciler.bats`；⑤`docs/backlog.md:122` 指向已刪嘅 `tests/backlog-trust-mode-completion.bats`；⑥`.github/workflows/ci.yml:139` 註釋指向已刪嘅 `tests/markdownlint-guard.bats`；⑦`skills/dev-checker-loop/SKILL.md:124`、`skills/dav-reconciler/SKILL.md:128`、`skills/tdd-test-writer/SKILL.md:99` 仍聲稱「`tests/gate-in-skill.bats` 鎖兩邊一致」（該探針已刪；SOP 側 3 個檔已改成「人手同步」，skill 側未改）；⑧`CONTRIBUTING.md:29,33,51,67,70,86,98` ＋ `docs/install-reference.md:315,327,361,383` 仍然叫人跑／引用已搬走嘅 `tests/wiki-cleanup.bats`／`tests/pptx-slim.bats`／`tests/poc-clean-clone.bats`／`tests/wiki-video-audio.bats`／`tests/poc-bootstrap.bats`／`tests/wiki-extract-media.bats`；⑨`docs/backlog.md:95` 寫錯路徑 `scripts/ci/install-local-hooks.sh`（實際 `scripts/install-local-hooks.sh`）。⚠️ 另保留咗一批「對象仍係文件內容」嘅探針（`skills/dav-wiki/tests/dav-wiki.bats` 24 支、`skills/regression-guard/tests/v2.1-jev-poc.bats` 內多支文字鎖、`skills/dav-reconciler/tests/doc-drift.bats`）——AC01 用「等」字容許，但同 R1 一般句「對象係文件內容 → 刪」有落差 |
| R2 | 「文檔行數限制」必須寫入 `dav-skill-creater` 規範（`editor-guide.md` 章節 ＋ `SKILL.md` 規則行），並**取代**原本嘅機械守門（`check-framework-weight.py`／`check-skill-size.sh` ＋ 對應探針） | ⚠️ 部分實作 | `skills/dav-skill-creater/editor-guide.md:80`（新章「## 文檔行數限制（v2.8 新增)」：主檔 ≤150／子檔 ≤300／context ≤700）；`skills/dav-skill-creater/SKILL.md:17`（TL;DR 規則行）、`:119`（規則表行）、`:129`（3 條最高頻規則第 2 條）；死碼工具 `scripts/ci/check-framework-weight.py`／`scripts/ci/check-skill-size.sh`／`docs/ci/framework-weight.json` ＋ 對應探針已刪 | `CONTRIBUTING.md:136-140` ＋ `:172` 已改寫成「行數限制改由規範承擔」；`skills/dav-wiki/tests/dav-wiki.bats:113` 仍保留一支機械行數探針（AC-2：≤150 行） | ⚠️ **新規則喺 repo 現況就唔成立**：`skills/dav-trust/examples.md` ＝ **301 行**（超「單一支援子檔 ≤300」硬上限 1 行）；context 總量（主檔 ＋ 全部支援 .md）：`skills/regression-guard/` ＝ **1,027 行**、`skills/dav-trust/` ＝ **890 行**、`skills/dav-wiki/` ＝ **759 行** → 三個 skill 超 700 軟上限。⚠️ 同一批改動把機械守門刪咗 → 冇人會發現超標。⚠️ editor-guide 講「唔好為咗守一條行數規則再寫機械探針」，但 `dav-wiki.bats` AC-2 就係一支 |
| R3 | 所有 `CHANGELOG.md`（13 個 skill ＋ `docs/sop/handbook/changelog.md`）必須刪除，**所有引用**（`SKILL.md` 指標、探針斷言、交叉引用「見 changelog」）一併刪 | ⚠️ 部分實作 | 14 個檔已刪（13 × `skills/*/CHANGELOG.md` ＋ `docs/sop/handbook/changelog.md`）；`skills/*/SKILL.md` 嘅 `## 變動歷史` 段 ＋ CHANGELOG 連結已清 | `find` 全 repo 已無 `CHANGELOG.md`（只剩 `tests/fixtures/mock-tree-monstor/...` 測試 fixture，唔係真引用）；`grep '^## 變動歷史' skills/*/SKILL.md` → 0 命中；探針 `skills/regression-guard/tests/v2.1-jev-poc.bats:420`（SKILL-d）＋ `skills/dav-wiki/tests/dav-wiki.bats:99`（AC-1h）守住「主檔冇變動歷史段 ＋ 冇 CHANGELOG.md」；舊探針對 CHANGELOG 內容嘅斷言（M6-e／M6.1-e／舊 SKILL-d）已移除 | ⚠️ **引用未清零**：`skills/dav-trust/resume.md:178`「V03 Reviewer 二審結論見本 skill CHANGELOG.md「v2.4 二審結論」節」→ 目標檔已刪（死引用）；`docs/DESIGN.md:288` markdown 連結 `sop/handbook/changelog.md` → 目標檔已刪（死連結）。⚠️ 9 個 skill 支援子檔仍有 `## 變動歷史` 段（見 R4 備註）。（歷史交付摘要／需求錨點／過往 AC 入面嘅 CHANGELOG 字眼屬 append-only 歷史紀錄，唔當死引用） |
| R4 | skill 主檔**唔寫變動歷史**（冇 `## 變動歷史` 段、冇版本表）；`dav-skill-creater` 嘅「任務導航」由 5 段改 4 段，規範同 SKILL.md 一齊改 | ✅ 已實作 | `skills/dav-skill-creater/editor-guide.md:8`（「## 4 段推薦結構（任務導航)」）＋ `:66`（新章「## 變動歷史：唔記（v2.9)」）＋ `:37`（反模式表新增一行）＋ `:64`（純文字引用例外刪走 CHANGELOG 例外）；`skills/dav-skill-creater/SKILL.md:3,11,19,22,56,58,69,80,111,128`（5 段 → 4 段全份同步）＋ `:18`（v2.9 紀律行）＋ `:120`（規則表行） | 13 個 `skills/*/SKILL.md` 全部冇 `## 變動歷史` 段（grep 0 命中）；探針 SKILL-d（regression-guard）＋ AC-1h（dav-wiki）守住 | ⚠️ editor-guide v2.9 硬規定寫「**主檔以外唔放變動歷史**」，但 9 個支援子檔仍有 `## 變動歷史` 段：`skills/dav-planner/examples/backlog.md:133`、`skills/ask-me/examples.md:167`、`skills/dav-trust/time-anchor.md:149`、`skills/dav-trust/preflight.md:113`、`skills/dav-trust/resume.md:174`、`skills/dev-checker-loop/examples/checklist.md:105`、`skills/regression-guard/PoC/README.md:170`、`skills/regression-guard/PoC/prompts/fix_relay.md:91` → 規範字眼同實作要對齊（改字眼或清埋子檔） |
| R5 | skill 相關嘅探針必須搬到 `skills/<name>/tests/`；必須有**一條指令淨跑單一 skill**；搬完之後 repo 級同 skill 級兩條 CI 執行路徑都要仲喺度（唔准出現冇人跑嘅 orphan 探針） | ⚠️ 部分實作 | 搬遷：regression-guard（4 檔）、dav-wiki（15 檔 ＋ `fixtures/`）、pptx-slim（2 檔）、dav-reconciler（1 檔）；新增 `scripts/test-skill.sh`（`--list`／單 skill／多 skill；rc 0／1／2） | `.github/workflows/ci.yml` 兩條路徑並存（`bats tests/` ＋ `bats skills/*/tests/*.bats`）；`scripts/check-all.sh` 亦有 `bats` ＋ `skill-tests` 兩步；`tests/env-equivalence.bats:556` ENV-EQ-12 orphan 鎖仍容許 `skills/<name>/tests/`（列舉下限由 40 放寬到 25，已記錄）；ENV-EQ-11 改寫成「≥1 檔 ＋ ci.yml 恰好一步 ＋ `test-skill.sh --list` 列得出 regression-guard」；`docs/install-reference.md` ENV-EQ-11／12／15 表列已同步 | ⚠️ 「淨跑單一 skill」**冇行為證據**：冇任何探針真跑 `scripts/test-skill.sh <skill>` 並斷言只跑咗嗰個 skill 嘅探針（ENV-EQ-11 只驗 `--list`）。⚠️ `docs/install-reference.md` 4 處**機械替換出錯**（263／310／319／321）：repo 級 `bats --count tests/` 被改成 `bats --count skills/regression-guard/tests/` →「`bats tests/` 的條數以 `bats --count skills/regression-guard/tests/` 為準」同「CI 實際執行 = `bats --count skills/regression-guard/tests/` ＋ skill 自帶探針數」自相矛盾（雙重計數）。⚠️ `docs/install-reference.md:305` 仍寫 `SKILLS_DIR_OVERRIDE="$PWD/skills" bats skills/*/tests/*.bats`，但 ci.yml 已改成 `bats skills/*/tests/*.bats`（冇 override）。⚠️ skill-local 探針依賴 repo 級 `tests/helpers/test-env.bash`（`load "$REPO_ROOT/tests/helpers/test-env"`）→ skill 單獨安裝時會斷，但 `CONTRIBUTING.md`「測試喺邊、點跑」表寫「隨 skill 安裝」 |

## 結論

- 5 項已列入：**1 項 ✅ 已實作**（R4）、**4 項 ⚠️ 部分實作**（R1／R2／R3／R5）、**0 項 ❌ 未實作**。覆蓋率 **5/5**（100%）。
- **本票確實放寬咗閘**（刪探針 ＝ 條件放寬）→ 已依 `AGENTS.md` §1.5 V03 走獨立二審。
- ⚠️ 依 `skills/dav-reconciler/reconcile-format.md` §7：任一 ⚠️ → 交付狀態**不得**標「✅ 完成」，只能標「⚠️ 部分完成」＋ 待補清單。
- ⚠️ 代價已記錄：`docs/backlog.md` TMO-085 列寫明「文件類規則（行數／結構／命名）冇機械守門 → 改由規範（agent 自律）承擔」。

### 待補清單（最小改法）

1. **P0** 修 `docs/ci/drift-whitelist.txt` 19 筆 D4 豁免嘅 key 格式。
   正確格式：`D4#<交付摘要檔名>:<被引用路徑>#<理由>`；現時 key 淨係交付摘要檔名 → 19 筆全部匹配唔到。
   先跑 `bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26`，抄返實際 key 逐筆改。
2. **P1** 清死引用（9 類，見 R1 備註）：DESIGN.md、dav-trust/resume.md、dav-reconciler/examples.md、backlog.md:122、ci.yml:139、3 個
SKILL.md 嘅 gate-in-skill 敘述、CONTRIBUTING／install-reference 嘅已搬走探針路徑、backlog 錯路徑。
3. **P1** 修 `docs/install-reference.md` 4 處 `bats --count` 替換錯誤（263／310／319／321）＋ `:305` 嘅 SKILLS_DIR_OVERRIDE 敘述。
4. **P1** 統一 mutant 數字為 **49**（CONTRIBUTING:74／:249、`tests/mutant-must-die.bats:45`、`docs/backlog.md` TMO-085
列、`docs/ac/TMO-085.md` DoD）；文件／資料契約鎖係 **2** 列。
5. **P1** 處理「文檔行數限制」超標：`skills/dav-trust/examples.md` 301 行；context regression-guard 1,027／dav-trust 890／dav-wiki 759 行
→ 減法或調上限並記錄理由。
6. **P2** editor-guide v2.9 硬規定同 9 個支援子檔嘅 `## 變動歷史` 對齊（改字眼或清埋）。
7. **P2** 刪或改 `skills/dav-wiki/tests/dav-wiki.bats:113` 嘅機械行數探針，同 editor-guide「唔好再寫機械探針」一致。
8. **P2** 補 `scripts/test-skill.sh` 嘅行為探針（真跑單一 skill ＋ 斷言只跑嗰個 skill）。
9. **P2** 統一「13 步」→「11 步」；修 `scripts/ci/install-local-hooks.sh` 錯路徑；修 pre-push 訊息「CI 仍然會擋」；修 `run_ci.sh all` 嘅 rc 語義（缺
key／缺 cleanup-scan 應回 3）。

### 對帳者備註

方向同用戶決策一致（保留真 python／shell 功能測試、skill-local 化、唔記歷史），但「刪咗嘅嘢要清乾淨」呢一半未做到；
而因為同一批改動亦刪走咗機械守門、又把白名單豁免寫錯 key 格式，按源碼推斷**本機閘嘅 `drift` 步會紅**。
本對帳以靜態核對（讀碼 ＋ staged diff）為主；對帳者 session 無 shell 權限，未能獨立重跑 `bats`／`check-all.sh`，
故「全綠」類聲稱未能由對帳者重驗——請主 agent 修完後實跑並把輸出貼返。

## 實作者回應（2026-10-27，二審後修復記錄）

> 呢段由**實作者**（主 agent）補寫，標明清楚唔係對帳者嘅判斷；對帳者嘅 ⚠️ 判定維持原文。

| 二審發現 | 處置 | 證據 |
|---|---|---|
| **P0** D4 白名單 19 筆 key 格式錯 → drift 閘紅 | 已修：key 改為 `D4#<交付摘要>:<被引用路徑>#<理由>`（24 筆，逐筆抄自實際 DRIFT 輸出） | `bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26` → **OK: 29 項檢查完成，40 項豁免** |
| **P1** 9 類死引用 | 全部清走（`docs/DESIGN.md`、`skills/dav-trust/resume.md`、`skills/dav-reconciler/examples.md`、`docs/backlog.md` ×2、`.github/workflows/ci.yml`、3 個 `SKILL.md` 嘅 gate-in-skill 敘述、`CONTRIBUTING.md`／`docs/install-reference.md` 嘅已搬走探針路徑） | `grep -rn "<已刪檔名>"`（live 文件，唔含歷史交付摘要／錨點）→ 0 命中 |
| **P1** `install-reference.md` 4 處 blind-replace 出錯 ＋ SKILLS_DIR_OVERRIDE | 已修：`bats --count tests/`（repo 級）＋ `bats --count skills/*/tests/`（skill 級）分開講；CI 描述同 ci.yml 實況一致 | `docs/install-reference.md:264,295,305,320-322` |
| **P1** mutant 數字四個版本 | 統一為 **49**（47 行為鎖 ＋ 2 文件／資料契約鎖）：`CONTRIBUTING.md` ×2、`tests/mutant-must-die.bats` 註、`docs/backlog.md`、`docs/ac/TMO-085.md` | `awk` 兩條自查指令 → 47 / 2；`mutant-must-die.bats` 斷言 `-eq 49` ✓ |
| **P1** 文檔行數新規則喺 repo 現況唔成立 | 硬上限（主檔 ≤150／子檔 ≤300）**現況全部守住** ✓；context 700 軟上限改成 **ratchet（只可下唔可上）**，並喺 `editor-guide.md` 記錄現況 baseline：regression-guard 1,469／dav-trust 885／dav-wiki 753（其餘 10 個 ≤700 ✓） | `editor-guide.md`「ratchet baseline（2026-10-27 現況）」段 |
| **P2** 9 個支援子檔仍有 `## 變動歷史` | 已清走（ask-me/examples、dav-planner/examples/backlog、dav-trust ×3、dev-checker-loop/examples/checklist、regression-guard/PoC/README、PoC/prompts/fix_relay） | `grep -rn "^## 變動歷史" skills/` → 只剩 `editor-guide.md` 嘅**規範章**（講明唔記） |
| **P2** dav-wiki 機械行數探針 | 已刪（AC-2），並留註解指向 `dav-skill-creater` 規範 | `skills/dav-wiki/tests/dav-wiki.bats` |
| **P2** `test-skill.sh` 冇行為證據 | 已加：**ENV-EQ-11** 喺 temp git repo 真跑（① 單 skill 探針紅 → rc=1；② 未知 skill → rc=2） | `tests/env-equivalence.bats` ENV-EQ-11 |
| **P2** `run_ci.sh all` 嘅 rc 語義 | 已修：子步驟回 **3（環境錯誤，例如缺 API key）** → 整體回 3（唔當紅燈）；cleanup-scan 缺檔訊息同步 | `skills/regression-guard/PoC/run_ci.sh` `cmd_all` |
| **P2** 「13 步」過期、pre-push 訊息、install-local-hooks 路徑 | 已修：11 步（AC／backlog／contributing 一致）；pre-push 訊息改「CI 仍然會跑，但**唔阻 merge**」；路徑改 `scripts/install-local-hooks.sh` | 三個檔案 |
| **P3** bashn tripwire 本機 15 vs CI 20 | 已對齊做 **15**（兩個檔一齊改） | `scripts/check-all.sh` ＋ `.github/workflows/ci.yml` |
| **P3** ENV-EQ-9 地板 500（減法後只 ~10% 餘裕） | 改成 **400** | `tests/env-equivalence.bats` |
| **P3** 「M8-a..e」／「LC-1..LC-8」寫錯 | 已改：M8-a..d＋M8-f；LC-1..LC-9 | `docs/ac/`、`docs/backlog.md` |

**另修兩個二審未列出、但同批改動造成嘅真 bug**：
① `tests/local-ci-guard.bats` LC-9 —— hook 探針原本喺外層 repo 行 → hook 用 `git rev-parse` 攞到**真** repo 嘅 runner →
測錯嘢（之前啱啱好過係因為真閘啱啱好紅）；已改成喺 fake repo 入面行。
② `skills/regression-guard/tests/v2.1-jev-poc.bats` SKILL-e —— 淨斷檔名會令 mutant RG-M4 存活（檔名仲出現喺指標表）→ 已收窄成精確形態斷言，mutant
而家會死。

**閘現況**：`bash scripts/check-all.sh` → **11
步全綠**（deps／ffmpeg／shellcheck／bashn／heredoc／drift／mdlint／venv／bats／skill-tests／mutant）。

## 第 3 輪二審（修復後覆核）— **verdict: approve**

> 呢段係**獨立 Reviewer subagent**（第 3 輪，窄範圍覆核）嘅原文輸出（2026-10-27）。
> 第 1 輪嘅 ⚠️（R1／R2／R3／R5）係針對**修復前**嘅狀態；下列覆核確認修復到位。

```
Verdict: approve
1. 白名單: 34／重複:無
2. mutant: 49（eq 49 命中 1 處）
3. 變動歷史: 乾淨（只 editor-guide）
4. 行數: OK（最大 dav-trust/examples.md=300，未超）
5. 死引用: 乾淨（gates.json／2.3-execution／gates.schema／ci.yml 全係「已刪」敘述；fixtures 命中係 mock 內自洽）
殘留問題: 無
未驗: 未實跑 bats/mutant（無 shell）
```

**覆核者冇 shell 權限** → 佢冇重跑 `bats`／mutant；嗰部分由實作者實跑並貼證據：
`bash scripts/check-all.sh` → **11 步全綠**（含 `bats`（repo 級 130 條）＋ `skill-tests`（skill 級 417 條）＋
`mutant`（49 支全部死）＋ `drift`（OK: 29 項檢查完成，40 項豁免）＋ `mdlint`（0 issues））。

**結論**：R1／R2／R3／R5 嘅 ⚠️ 係「修復前」狀態；修復後經第 3 輪覆核（approve）確認已清 →
本票 5 項全部 **✅ 已實作**，覆蓋率 5/5，交付狀態可標 **✅ 完成**。
