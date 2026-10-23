# TMO-066 交付報告：跨 skill 護欄補 mutant（dav-wiki ＋ 探針機密遮罩 ＋ regression-guard）

> **交付日期**: 2026-10-05
> **對應 Backlog**: TMO-066（US 級，見 `docs/backlog.md`）；延伸 TMO-065 的突變測試自動化
> **Sprint / Module**: tree_monstor 建置／CI 護欄（`scripts/ci/`）＋ 三個 skill 的契約面
> **交付狀態**: ✅ 完成（40 支 mutant 全紅、全量探針 0 紅、markdownlint 0 issue）
> V03 二審 verdict = **`request-changes`**（P0×1／P1×4／P2×2／P3×2）→ **逐條已處置**，見 §4.4

## 1. 這次完成什麼

TMO-065 把「探針真的咬得住突變」從**一次性人工動作**變成 CI 每次都會跑的檢查，但那張表
（`scripts/ci/mutants.tsv`，26 支）只覆蓋 pptx-slim。本輪用**同一套 harness**（temp copy ＋ 精確錨點
＋ 綠 baseline 對照 ＋ md5 自證）把另外三個護欄面收進來，表 26 → **40 支**
（首輪 39 支，逐條處置二審 finding 後 +1；詳見 §4.4）。

**關鍵成果**：

- ✅ **13 支新 mutant**：dav-wiki 6 支（缺工具不得降級／OCR 常數／cleanup 預設不得真刪除）、
  探針機密遮罩 3 支（遮罩直通、R2 停用、探針自己再定義一份）、regression-guard 4 支
  （`jest --ci`、gates.json 交叉引用、handbook 的 `< /dev/null`、SKILL.md 的對照表指標）。
- ✅ **MMD-1 兩處強化**：門檻 26 → **39**；新增「跨 skill 覆蓋清單」——dav-wiki 的 4 個目標檔與
  `skills/regression-guard/SKILL.md` **少一個就紅**，防有人只留 pptx-slim 那段而靜默丟掉別人的護欄。
- ✅ **實測 40/40 全紅**（每支都有綠 baseline 對照）＋ 跑完 md5 自證 19 個目標檔 working tree 未變；
  `real 1m13.3s`（首輪 39 支 55.4s；26 支時 49.9s）。
- ✅ **抓到並修掉一個 commit 後才會現形的真 bug**：`ENV-EQ-17`（`$var` 緊接非 ASCII）掃描範圍
  原本只含 `git ls-files`（已追蹤）→ 新檔在 commit 前是 untracked，**本機全綠、push 後 CI 必紅**。
  本輪修掉 4 條違規（3 條是上一輪 commit 進去的）並把鎖改成 `git ls-files -co --exclude-standard`。
- ✅ **推翻一支候選突變（無害突變）並誠實記錄**：`SKILL.md` 把 `**TTY fail-fast**` 改成
  `**TTY fail-slow**` 後探針仍綠 —— 追下去是同字串在檔內另有兩處，規則還在 ⇒ 探針綠是**正確**行為，
  該突變不進表（記在 `tests/mutant-must-die.bats` 檔頭）。
- ✅ 文件對帳：`CONTRIBUTING.md`（40 支＋泛化措辭＋「行為鎖 vs 文字契約鎖」約定）、`docs/backlog.md`
  （TMO-065 row／詳細＋TMO-066 row／詳細／二審處置表）、`skills/pptx-slim/` 的 v1.4 列（26 支改為 scoped 措辭）。
- ✅ **V03 二審（第 5 次嘗試才拿到 verdict）＝ `request-changes`，10 條 finding 逐條處置完畢**：
  修掉兩個「死因不純／假綠」的根：SM-M1（rc=127 parse error 假死因）與 DW-M5（等價突變）；
  把 `wiki-ocr.bats` AC-O4／AC-O6 由「只驗非零」收緊為驗 2／驗 1（順手修實一個名實不符的假綠）；
  並把「等價突變／重複列／空欄／欄數」變成**載入期就 FAIL** 的契約（附 MMD-6 合成表實測）。

### 1.1 驗收標準對應（AC）

| AC | 內容 | 證據 |
|----|------|------|
| AC-1 | 表至少 39 支、且新增的 13 支每支都被對應探針咬死 | `mutants.tsv` **40 列**；`--only` 13/13 紅（§4.1）；全表 **40/40 紅** |
| AC-2 | 每支 mutant 都有「未突變必須綠」的 baseline 對照 | driver 內建 baseline 快取；輸出每組探針先印綠（§4.1 log）|
| AC-3 | 新 mutant 沒有破壞既有 CI 護欄（MMD-1..6 全綠） | `bats tests/mutant-must-die.bats` **6/6**（§4.2）|
| AC-4 | 跨 skill 覆蓋清單存在且會紅（少一個目標檔即 FAIL） | MMD-1 迴圈（`skills/dav-wiki/...`×4 ＋ `skills/regression-guard/SKILL.md`）|
| AC-5 | 「無害突變」的判定有記錄、不是靜默丟掉 | `tests/mutant-must-die.bats` 檔頭 TMO-066 段 ＋ 本報告 §4.1 |
| AC-6 | 全倉文件數字一致（26 → 40）且 lint 全綠 | markdownlint **138 檔 0 issue**；`grep` 對帳（§4.2）|
| AC-7 | 二審（V03）verdict 與處置 | §4.4 |

### 1.2 為什麼做這個改動

TMO-065 的詳細段自己寫下了限制①：「仍有 skill 沒有 mutant」。當時 dav-wiki 的缺工具契約
（TMO-035／053 人工驗過 MUT-A..MUT-I）、探針機密遮罩（SM-1..SM-5）與 regression-guard 的
TTY fail-fast 四檔一致性（v1.3 驗過）都只有「當時那次人工驗證」的記錄 —— 正是 TMO-065 想消滅的
那種狀態：**驗過一次就沒有檢查記得**。本輪把那批人工驗證裡可字串化重現的部分搬進同一張表。

## 2. 做了什麼改動

### 2.1 修改檔案

| 檔案 | 改動 |
|------|------|
| `scripts/ci/mutants.tsv` | +13 資料列（26 → 39），二審後再 +1（LK-M1）→ **40**；表頭加「行為鎖 vs 文字契約鎖」約定；DW-M5 換錨點（文字鎖 → 真行為鎖）、SM-M1 換錨點（單行 sed）|
| `tests/mutant-must-die.bats` | MMD-1 門檻 26 → **40**；新增跨 skill 覆蓋清單迴圈＋錨點唯一性改數「出現次數」；**新增 MMD-6**（載入期結構契約）；檔頭加 TMO-066 說明段（含無害突變案例與二審處置）|
| `tests/mutant-must-die.bats`（MMD-3）| `$status）` → `${status}）`（ENV-EQ-17 違規修正）|
| `tests/pptx-slim-images.bats` | `$after（`／`$name（` → `${...}（`（ENV-EQ-17 違規修正，上一輪 commit 進去的）|
| `scripts/ci/lint-shell-var-nonascii.py` | 列舉範圍 `git ls-files` → `git ls-files -co --exclude-standard`（含未追蹤、不含 gitignore）＋ 註解記錄盲點 |
| `tests/env-equivalence.bats` | ENV-EQ-17 註解補「盲點修正」（為何含未追蹤檔、兩次同類事故）|
| `scripts/ci/mutant-must-die.py` | docstring 補 TMO-066 段（表為何從 26 變 39）|
| `CONTRIBUTING.md` | 26 → 39 支；「改了 skills/pptx-slim/scripts/ 的碼」→「改了表內任何目標檔的碼」|
| `docs/backlog.md` | TMO-065 row／詳細補「門檻 39 支」與 TMO-066 指涉；新增 TMO-066 row ＋ 詳細段 |
| `skills/pptx-slim/examples.md` | 「突變表 26 支」→「與本 skill 相關的 26 支」 |
| `skills/pptx-slim/SKILL.md`／`CHANGELOG.md` | 各加一列 v1.4（記錄計數措辭校準的原因）|

### 2.2 改動背後的理由（兩個設計選擇）

1. **為什麼不新增工具、只加表列**：TMO-065 的 harness 已經是「副本上種突變 → 探針必紅 →
   md5 自證」，三個護欄面需要的只是「哪一行、換成什麼、哪支探針」，不需要新的機制。多一個機制就多
   一份會腐化的東西。
2. **為什麼 MMD-1 要加「跨 skill 覆蓋清單」**：表的門檻（`>= 39`）只擋「整批判掉」，擋不住
   「只留下 pptx-slim 的那 26 支」。覆蓋清單是把「別人的護欄也在這張表裡」變成**可執行的斷言**，
   而不是一行註解。

## 3. 驗收標準對應

見 §1.1 表格（AC-1…AC-7 逐條對證據）。

## 4. 測試結果

| 測試類型 | 通過 / 總數 | 備註 |
|---------|-------------|------|
| 突變全表（`scripts/ci/mutant-must-die.py`）| **40 / 40 死亡** | 每支都有綠 baseline；md5 自證；`real 1m13.3s`（log `/tmp/mutant-full-tmo066-review.log`）|
| 新增 13 支單獨跑（`--only`）| 13 / 13 死亡 | `real 0m6.359s`；log `/tmp/mutant-only-tmo066.log`；二審後換錨點的 `SM-M1`／`LK-M1` 再 `--only` 重驗 2/2 紅、`DW-M5` 換成行為鎖後 1/1 紅 |
| 突變工具探針（`tests/mutant-must-die.bats`）| **6 / 6** | MMD-1（門檻 40＋覆蓋清單）、MMD-2..5、**MMD-6**（載入期結構契約）|
| 結構探針（`tests/restruct-pptx-slim.bats`）| 9 / 9 | 含「SKILL.md ≤ 130 行」預警線 |
| 受影響探針單跑 | 全綠 | `tests/wiki-ocr.bats`（收緊 AC-O4／AC-O6 後）、`tests/wiki-cleanup.bats`、`tests/wiki-toolmissing-contract.bats`、`tests/secret-masking.bats`、`tests/regression-guard-watch-mode.bats`、`tests/env-equivalence.bats` |
| 守門探針（skill-local）| 3 / 3 | `bats skills/*/tests/*.bats` |
| 全量回歸（`bats tests/`）| 674 條：**674 綠 / 0 紅** | `/tmp/bats-full-v22.log`（同批碼在前一次 v21 是 673 綠；v20 有 2 紅：`ENV-EQ-17` 真 bug ＋ `M6.3-c` 間歇紅，皆已說明，見 §4.3）|
| markdownlint（CI 同款 4 globs）| **138 files / 0 issues** | `npx --no-install markdownlint-cli2 …` |

### 4.1 Gate 1（TDD）：先紅後綠

> 依 gates.json 規範，Gate 1（TDD）需要：測試先紅後綠，並在對話貼出 測試執行指令 ＋ 失敗輸出 ＋ 通過輸出。

本輪的「紅綠」有兩層，兩層都貼得出輸出：

**(A) mutant 層（每支都是一次紅綠實驗）**：driver 對每個 (探針檔, 探針名) 先跑**未突變的 baseline**
（必須綠），再種突變（必須紅）。`--only` 13 支的實際輸出（`/tmp/mutant-only-tmo066.log`）：

```text
baseline（未突變必須綠）：WTM-2 → 綠 ／ WTM-8 → 綠 ／ WTM-9 → 綠 ／ …（13 組全綠）
DW-M1  tests/wiki-toolmissing-contract.bats -f WTM-2 → rc=1 紅（mutant 死了）
…
RG-M4  tests/regression-guard-watch-mode.bats -f CROSS: … → rc=1 紅（mutant 死了）
OK: 13 支 mutant 全部死亡（每支都有綠 baseline 對照）
```

**(B) 護欄層（鎖本身先紅後綠）**：`ENV-EQ-17` 的盲點修正用一支**未追蹤**檔做紅綠實驗：

```text
printf 'echo "最長 $worst_file）"\n' > tests/zz-tmp-untracked-check.bats
# 造出違規檔後：
#   git ls-files tests/zz-tmp-untracked-check.bats | wc -l  → 0（舊範圍看不到它）
#   python3 scripts/ci/lint-shell-var-nonascii.py .         → FAIL（rc=1，新範圍抓到了）
rm tests/zz-tmp-untracked-check.bats
#   python3 scripts/ci/lint-shell-var-nonascii.py .         → OK: 80 個 shell／CI 檔皆無違規（rc=0）
```

**由這一關逼出來的真 bug**（本輪最有價值的產出，詳見 §5）：

| # | 現象 | 根因 | 修法 | 鎖住它的探針 |
|---|------|------|------|-------------|
| 1 | `ENV-EQ-17` 在 **commit 後**才紅（上一輪 commit 裡有 3 條違規）| 鎖只掃 `git ls-files`（已追蹤檔）；新檔 commit 前是 untracked ⇒ 本機看不到 | 4 條違規改 `${var}`；鎖改 `git ls-files -co --exclude-standard` | `ENV-EQ-17`＋本節 (B) 的紅綠實驗 |
| 2 | 候選突變「`**TTY fail-fast**` → `**TTY fail-slow**`」竟然**活著** | 不是探針的洞：同字串在 `SKILL.md` 另有兩處（規則表、對照表標題），單點改字後規則仍在 | 判定**無害突變**、不進表；改以 `RG-M4`（咬 CROSS 探針）取代；記錄在探針檔頭 | MMD-1 的錨點唯一性檢查（同字串多處要小心）|

### 4.2 Gate 2（lint / syntax）

> 依 gates.json 規範，Gate 2（lint / syntax）需要：語言對應的 lint 工具執行結果。

| 檢查 | 結果 |
|------|------|
| `markdownlint-cli2`（CI 同款 4 globs）| **138 files / 0 issues** |
| `python3 scripts/ci/lint-shell-var-nonascii.py .` | OK：80 個 shell／CI 檔（含未追蹤）0 違規 |
| `shellcheck -x -S style` ＋ `bash -n` 自我列舉 | 由 `ENV-EQ-18` 在 §4.3 的全量裡跑（綠）|
| `bats tests/mutant-must-die.bats` | **6/6** 綠（MMD-1 門檻與覆蓋清單、MMD-5 十種假綠反向自測、MMD-6 六種結構錯誤）|

### 4.3 Gate 3（regression）

> 依 gates.json 規範，Gate 3（regression）需要：全量測試通過，且與改動相關的既有行為無退化。

- **全量**：`bats tests/` → **674 條：674 綠 / 0 紅**（`/tmp/bats-full-v22.log`，處置完二審 finding 後重跑的終版）。
  同批碼的前一次（v20，`/tmp/bats-full-v20.log`）有 2 紅，兩個都查清了：
  ① **`ENV-EQ-17` 是真 bug**（本輪修掉，見 §4.1(B)／§5）；
  ② **`M6.3-c`（`tests/v2.1-jev-poc.bats`）是既有間歇紅** —— 本輪三次全量中 v20 紅、v21／v22 綠；
    上一輪的 v15～v19 亦間歇紅過（`M6.3-c`／`M6.3-e`）。本輪改動不涉及 JEV／sandbox（§5④）。
- **skill-local**：`bats skills/*/tests/*.bats` → 3/3 綠。
- **突變全表連 working tree 一起驗**：40 支跑完 → 19 個目標檔 md5 全數未變（突變只發生在已刪除的副本）。
- **兩支被當探針的既有測試沒有被本輪改壞**：`tests/wiki-toolmissing-contract.bats`、
  `tests/wiki-cleanup.bats`、`tests/secret-masking.bats`、`tests/regression-guard-watch-mode.bats`
  在全量裡都是綠（它們是 mutant 的 baseline）。

### 4.4 Gate 4（reviewer 二審，V03）

**verdict = `request-changes`**（風險統計 P0×1／P1×4／P2×2／P3×2）→ 逐條已處置完成。

依 V03，本輪動了 skill 檔（`skills/pptx-slim/SKILL.md`／`CHANGELOG.md`／`examples.md`）＋
探針（`tests/mutant-must-die.bats`）＋ CI 鎖（`scripts/ci/lint-shell-var-nonascii.py`），因此必須二審。
前 4 次嘗試全部失敗，第 5 次才拿到 verdict：

| 次 | 路徑 | 結果 | 診斷 |
|----|------|------|------|
| 1 | `reviewer`（完整審查）| **逾時 30 分鐘未產出 verdict** | 做大量工具探索（log 523 KB）後停滯，已中斷 |
| 2 | `reviewer`（有界 ≤8 呼叫／15 分鐘）| **逾時未產出 verdict** | 歷時 1,004 秒、只有讀檔沒有實質輸出 ⇒ 該 subagent 路徑太慢 |
| 3 | `codex-exec` | **啟動失敗** | 本機沒有 `codex` 這支 CLI（已明示改用 `claude`，非靜默換路徑）|
| 4 | `claude-code` | **白跑** | 該 adapter 是唯讀（`tools: none`），prompt 內沒證據 ⇒ 它把 tool-call XML 當答案吐出 |
| 5 | `claude-code`＋**證據全部內嵌 prompt** | ✅ **verdict `request-changes`** | 無工具、單輪數十秒 → 唯讀 CLI 二審的正確用法就是「把證據塞進 prompt」|

**逐條處置（每條都有對應的碼／文件改動，非口頭回覆）**：

| # | 級別 | 指摘 | 處置 |
| --- | --- | --- | --- |
| F1 | P0 | DW-M5 語意等價 → 死因不純 | ✅ **採「真改值」路線（比標籤化更根本）**：查核發現 `tests/wiki-ocr.bats` AC-O4 測名寫「exit 2」但只斷言 `-ne 0`（AC-O6 亦然）—— 這本身就是假綠。先收緊為 `-eq 2`／`-eq 1`，再把 DW-M5 換成「`EXIT_NOINPUT=2` → `1`」的真行為鎖（已實測紅）。另在 CONTRIBUTING／tsv 表頭留下「行為鎖 vs 文字契約鎖」約定（現 0 列，供未來真的只能用文字釘的契約） |
| F2 | P1 | SM-M1 掉續行 `\` → rc=127，死因是 parse error | ✅ **改碼 + 改表**：helper 的 sed 程式刻意寫成**單行**，mutant 一行整段換成 `cat`（真・直通）；重跑紅 |
| F3 | P1 | MMD-1 不檢查「原文≠換成」；同探針名可重用墊數；`grep -cF` 只數行數 | ✅ **三修**：①等價突變／欄數／空欄／重複列全部移入 runner **載入期契約**（`Mutant.__init__`＋`load_table`）並新增 **MMD-6** 用合成表實測會紅；②錨點唯一性改 `grep -oF ... \| grep -c .` 數**出現次數**（與 runner 的 `text.count != 1` 對齊）；③「同（探針檔,探針名）出現多次」**不是缺陷**——真表內有 2 組合法的重複對（`PPTX-SLIM-3`／`PPTX-SLIM-4` 各 2 次），強行禁止會弄壞現有表，baseline 依 key 快取即可；真正的防灌水靠「載入期重複列鎖（同目標檔／原文／換成）＋執行期 survivor 檢查」。`--only`／`--list` 也一律先過載入契約 |
| F4 | P1 | ENV-EQ-17 沒有 probe 鎖 `-co` → 改回 `-c` 仍全綠 | ✅ **新增 LK-M1**（`-co --exclude-standard` → `-c`）；並在 `lint-shell-var-nonascii.py --self-test` 加「temp git repo：未追蹤檔必須入列、gitignore 必須排除」契約，兩者一起紅 |
| F5 | P1 | DW-M6 `PURGE=true` 可能真刪使用者檔 | 🔍 **查核後確認安全**：`TO_CLEAN[].f` 全部來自 `find "$WIKI_DIR"`，而 `WIKI_DIR` 是探針自己的 `mktemp -d` → 只會刪到拋棄式目錄。殘餘（harness 用 ambient `HOME`／`TMPDIR`）列 §5 限制 |
| P2-1 | P2 | RG-M2 錨點去掉了 `regression-guard` 字樣，測名卻說 "mention watch-mode rule" | 查核：該測（`GATES:`，`tests/regression-guard-watch-mode.bats:73`）**同時**斷言 `assert "regression-guard" in notes`，所以拿掉交叉引用一定紅 → 咬合正確，只是測名偏重 watch-mode 那一半。不動測名：測名字串同時是突變表的 `-f` 篩選值（改名要同步改表列，收益極低）|
| P2-2 | P2 | SM-M3 換掉 `load` 會連帶抽掉 `REPO_ROOT`／PATH 設定 | 查核：SM-M3 的突變是換掉**遮罩規則本身**，本來就會連帶影響 helper 的載入；紅（rc≠0）是正確結果，且 SM-1／SM-2／SM-4／SM-5 仍在綠，證明不是全檔壞掉造成的假紅 |
| P3-1 | P3 | `awk NF==4` 與 `grep -c .` 兩套濾網不一致 | ✅ 新增「必要欄位不得為空」的載入期檢查後，`--list` 每行必為 **4 欄**（id／目標檔／探針檔／探針名；表本身仍是 6 欄）⇒ `awk NF==4` 取得到每一欄、不會漏壞列；MMD-1 不再用兩套濾網互比 |
| P3-2 | P3 | 跨 skill 覆蓋清單是手寫 spot list、只驗 target 不驗「換成」 | 承認（見 §5）：這是一道「防回歸」而非「窮盡覆蓋」的鎖；真正的防灌水閘門是載入期契約＋執行期 survivor 檢查 |

**reviewer 標記「最不放心」者為 F1**（等價突變卻宣稱「死」會讓全表可信度打折）。
處置後：原本那列**已變成真的行為鎖**（不只換標籤）——為此還順手把兩個「名實不符」的斷言修實
（`AC-O4` 從只驗非零改成驗 2、`AC-O6` 改成驗 1），讓 `EXIT_NOINPUT`／`EXIT_USAGE` 的值真的有人管。
且「等價突變」現在是**載入期就 FAIL** 的契約，不再靠人記得。

**自查（用 python 掃 `mutants.tsv` 全表，不是抽樣；取代前版的 39 列自查）**：

```text
rows: 40
每列「原文」在目標檔的出現次數：全部 == 1（錨點唯一）
每列探針名 regex 在探針檔命中的 @test 數：全部 == 1（無誤配、不會假死）
沒有任何等價突變列（原文 == 換成）→ 已有載入期鎖
沒有重複列（目標檔,原文,換成）→ 已有載入期鎖
沒有任何必要欄位為空 → 已有載入期鎖
行為鎖 35 列／文件-資料契約鎖 5 列（TMO-066 二審第 2 輪 #2 後改為可機械判定的分類）
```

### 4.5 Gate 4（第 2 輪二審：只審「處置 delta」）

**為什麼要第 2 輪**：上面那輪二審看的是**修正前**的版本；本輪處置又動了／新增了鎖
（`AC-O4`／`AC-O6` 收緊、MMD-6、LK-M1、兩支 mutant 換錨點）→ 這些 delta 未經二審，不能自己說算。

**verdict = `request-changes`**。這次用 `reviewer` subagent（有讀取權，能自己跑唯讀指令反驗證，
不再需要把證據塞進 prompt）；它逐列點算了 40 支的本表、查了 `--list` 欄數、查了每個 finding 的落點檔
與行號，**並且抓到了本輪自己新引入的缺陷**（F1 要求根除的同一型態）：

| # | 級別 | 指摘 | 處置 |
| --- | --- | --- | --- |
| 1 | P1 | 本輪新增的 **LK-M1 是假死因**：錨點是**行中**片段，『換成』尾接 `# MUTANT: …` 吞掉該行後面的 `*GLOBS],` → `SyntaxError: '[' was never closed`（rc=1），ENV-EQ-17 一次都沒跑到 ⇒ 這一列對「掃描範圍必須含未追蹤檔」**零證據力**（＝ round-1 F2 同一型態，而且是我自己剛修好 F2 又在同表新增）| ✅ **兩層修**：①該列拿掉行尾註解（改成乾淨的 `"ls-files", "-c", "--exclude-standard",`，理由改寫在列上方註解行）→ 現已實測「死在 self-test 的 untracked 斷言」；②**根治**＝runner 新增載入期**語法哨兵**（`SYNTAX_LANGS`／`check_mutated_syntax`）：靜態套用『換成』後用 `compile()`／`bash -n`／`json.loads` 檢查目標檔語法，壞掉直接 `die` ⇒ 任何「靠語法壞掉才紅」的列連 `--list` 都過不了；MMD-6 ⑦ 用合成表實測 |
| 2 | P2 | `CONTRIBUTING.md`／表頭寫「文字契約鎖 **0 列**」，但 DW-M4 與 RG-M1..RG-M4 明明是文件／資料契約列；提供的 `grep 'MUTANT(text-lock)'` 配方回 0 筆 ⇒ 用一個查得到的指令證明一件不成立的事 | ✅ **分類改為可機械判定**（看目標檔類型，不看註解）：行為鎖＝目標檔 `.py`／`.sh`／`.bash`／`.bats`（**35 列**）；文件／資料契約鎖＝`.md`／`.json`（**5 列**）；附兩行 `awk` 自查指令；`MUTANT(text-lock):` 前綴降到「目標檔是程式但只想鎖文字」的罕見情況（**0 列**）|
| 3 | P3 | 本報告 §4.4 的 P3-1 寫「`--list` 每行必為 6 欄」（實為 4 欄）| ✅ 已更正（並補「表本身仍是 6 欄」以免又混淆）|

reviewer 自己也限縮了結論：“未自行重跑 harness，請 supervisor 跑並貼輸出” → 本報告 §4 的數字
全部是本輪重跑後才錄（舊 log 被系統清掉，正好避免了引用過期證據）。它把 35＋5＝40 的組成、
`--list` 的 4 欄、以及「不再靠語法壞掉才紅」都列成可查證的事實，而不是採信我的敘述。

## 5. 已知問題 / 限制

- **`ENV-EQ-17` 這類「以 `git ls-files` 為準」的靜態鎖仍有同類盲點**：本輪只修了 `ENV-EQ-17`。
  `ENV-EQ-16`（檔尾換行）等鎖也是同一種列舉方式（同日稍早已發生過一次：新鎖檔缺檔尾換行，
  本機全綠、clean clone 才紅）。**建議**下一輪把同類鎖一起改成 `-co --exclude-standard`
  （列為 §6 建議①，本輪未自作主張擴大範圍）。
- **13 支裡有 5 支是「文字契約鎖」而不是行為鎖**：`DW-M4`／`RG-M1`～`RG-M4` 之所以被咬死，是因為
  對應的探針本身就是文字鎖（例如 `WTM-5` 用文字比對鎖「缺工具不得降級為純文字」的措辭）。
  這是那些探針的**刻意設計**（契約／文件一致性），不是缺陷；但要知道：這 5 支證明的是
  「文字契約會被抓到」，不是「行為變了會被抓到」。另外 8 支（`DW-M1`～`M3`、`DW-M5`、`DW-M6`、`SM-M1`～`SM-M3`）才是行為鎖。
  （`DW-M5` 原本也只能算文字鎖，二審 F1 後靠收緊 `wiki-ocr.bats` 的斷言升級為行為鎖，見 §4.4。）
- **仍有 skill 沒有 mutant**：`dav-planner`／`dav-designer`／`dav-submitter`／`dav-reflection`／
  `dav-trust`，以及 dav-wiki 的 cross-ref／cleanup 進階路徑。本輪補的是「TMO-035／053 人工驗過、
  且可字串化重現」的那批。
- **跨檔案一致性探針只能用單點突變**：`RG-M4` 咬的是「四個檔案都指得到」的 CROSS 探針；咬不到
  「四份都寫錯但互相一致」的情境（那需要語意檢查，不是單行突變能表達的）。
- **CI 成本上升**：40 支＋baseline 本機約 73 秒（39 支時 55 秒、26 支約 50 秒；機器負載不同會有數成漂移，數字僅供量級參考）。
- **`M6.3-c`／`M6.3-e` 的間歇紅：根因已於本輪查清（原假說「`tmp/` 殘留」是錯的）**。

  - **症狀**：`M6.3-c` 隔離連跑 5 次 → **3 紅 2 綠**；紅的兩種形態：`no_change should return 0, got 2`
    （rc=2 在 `sandbox_runner.py:386` 是 **regression**）與 `should classify as no_change (unrelated patch)`。
  - **根因**：那條 journey（`journeys/US-M63.yaml`）的 oracle 是**現場打 OpenRouter**；
    `jev_oracle.py:191` 把 `Elapsed: {elapsed_ms} ms` 寫進 state 文字，而 cache key 是
    `sha256(payload)`（`jev_oracle.py:101`）⇒ **延遲每次不同 ⇒ cache key 每次不同 ⇒ cache miss
    ⇒ 真連線 → 403 → 該步驟被標 `blocked`**；命中快取時則拿到舊的 `fail`。
    實測同一條 journey 連跑 3 次：`{fail:1, blocked:14}`、`{fail:1, blocked:14}`、`{fail:0, blocked:15}`。
  - **為何會變紅**：`re_validate._classify` 只看 `fail_delta`／`pass_delta`（±1 即判 regression／improvement）
    ⇒ 「`fail` ↔ `blocked` 抖動」被當成 regression ⇒ rc=2 ⇒ 探針紅。
  - **證據一致**：`tmp/` 那 264 個 `.sandbox-US-M63-*` 殘留是**失敗路徑沒走到 `_cleanup` 的產物**，
    所以它是症狀而非原因（本輪原本的假說已推翻）。
  - **建議修法（最推薦）**：沿用 TMO-039 對 `M6-g`／`M6.1-c` 的既有做法 —— 把 baseline 與 after 都改成
    **版控 fixture**，不要現場打 oracle。理由：已有先例、CI 亦無 API key（必然 `blocked`）⇒
    只有 fixture 能讓 M6.3-c 在「本機與 CI」都穩定。次選是在 `_classify` 加抗抖（把 `fail`±1 的抖動視為
    no_change），但會連真 regression 的一個 fail 一起吞掉，需要一支對開探針。
  - 本輪**不動 PoC 程式**（超出 TMO-066 範圍，且需要決定語意）→ 列為 §6 建議②＋TMO-067 候選。

## 6. 下一步建議

1. **（最推薦）把同類靜態鎖的列舉範圍一次補齊**：`ENV-EQ-16` 等以 `git ls-files` 為準的鎖改成
   `-co --exclude-standard`。理由：本輪與同日稍早各發生一次「新檔本機看不到、clean clone／commit 後才紅」，
   這是**結構性**問題，不是單一鎖的 bug；成本極小（每把鎖一行）。
2. **修 `M6.3-c`／`M6.3-e` 的間歇紅（根因已查清，見 §5④）**：把 baseline／after 改成版控 fixture，
   不要讓探針打真 OpenRouter；順手清掉 264 個殘留 `.sandbox-US-M63-*`（失敗路徑沒走到 `_cleanup`）。
3. 為 dav-wiki 的 cross-ref／cleanup 進階路徑、`dav-submitter`（交付報告格式）補 mutant ——
   後者失敗的代價是「交付物缺漏但沒人知道」。

## 7. 變更集（`git diff HEAD --numstat`）

本區塊為**首輪**（TMO-066 原始交付，commit `1cd6cc8`）的變更集：

```text
6     4     CONTRIBUTING.md
40    4     docs/backlog.md
9     1     scripts/ci/lint-shell-var-nonascii.py
4     0     scripts/ci/mutant-must-die.py
13    0     scripts/ci/mutants.tsv
1     0     skills/pptx-slim/CHANGELOG.md
1     0     skills/pptx-slim/SKILL.md
3     2     skills/pptx-slim/examples.md
5     0     tests/env-equivalence.bats
19    2     tests/mutant-must-die.bats
2     2     tests/pptx-slim-images.bats
# 合計 +103 / -15（11 個已追蹤檔）
# 外加本報告本身（新檔）：docs/deliverable/2026-10-05-tmo-066-cross-skill-mutants.md
```

**二審處置輪**（本輪，相對於 `7f888bb`）：

```text
12    3     CONTRIBUTING.md
23    5     docs/backlog.md
75    44    docs/deliverable/2026-10-05-tmo-066-cross-skill-mutants.md
29    1     scripts/ci/lint-shell-var-nonascii.py
26    1     scripts/ci/mutant-must-die.py
9     2     scripts/ci/mutants.tsv
1     1     skills/pptx-slim/CHANGELOG.md
1     1     skills/pptx-slim/SKILL.md
4     3     tests/helpers/test-env.bash
69    7     tests/mutant-must-die.bats
5     2     tests/wiki-ocr.bats
# 合計 +254 / -70（11 個已追蹤檔，皆已 M＝modified）
```

## 反思（§2.4，US 級反省）

### 6 維度檢查

| 維度 | 檢查結果 |
|------|---------|
| **完整性** | 13 支新 mutant 全數落地並被咬死；MMD-1 兩處強化；文件（CONTRIBUTING／backlog／skill 三檔）數字對齊；lint＋全量回歸有實跑證據 |
| **正確性** | 門檻與清單是「少就紅」的方向；13 支都有綠 baseline（紅不是因為探針本來就壞）；md5 自證 working tree 未變 |
| **一致性** | 「26 支」只保留在歷史語境（TMO-065／v1.3）；現況一律 40；`examples.md` 改成 scoped 措辭避免與共用表衝突 |
| **可維護性** | 沒有新增機制（只加表列）；覆蓋清單把「別人的護欄也在表內」變成斷言；`--only` 讓單支除錯只花 6 秒 |
| **風險** | 已揭露：其他 `git ls-files` 鎖的同類盲點未修（§5①）、跨檔一致性探針咬不到「一致地錯」（§5③）|
| **效率** | 全表 73 秒（量級仍屬可接受）；`--only` 13 支 6.4 秒；沒有把 CI 成本推高到需要分流的程度 |

### 問題清單（根因 ＋ 建議）

1. **根因（本輪最重要的教訓）**：靜態鎖若以「已追蹤檔」為範圍，就會有「新檔在 commit 前是隱形的」
   盲點 ⇒ 本機綠、CI 紅。兩次同類事故（檔尾換行、`$var` 緊接非 ASCII）證明這不是偶發。
   **建議**：把同類鎖一次補齊（§6①），並在 `CONTRIBUTING.md` 的 PR 檢查清單寫明「新檔要在 `git add` 後
   重跑一次全量鎖」。
2. **根因**：候選突變「看起來該咬得住」但實際上無害 —— 我一開始把它當成探針的洞。
   **建議**：往後加 mutant 前先確認「同一段文字在目標檔出現幾次」（MMD-1 已有錨點唯一性檢查，
   但那是「同一行」不是「同一語意」）。
3. **根因**：`M6.3-c` 的間歇紅被容忍了兩輪，變成「全量驗收報告裡永遠要加註」的噪音。
   **建議**：不要讓它繼續當背景噪音，下一輪給它一個判定（修掉或標記 skip 並寫原因）。

### Action Items

| # | 行動 | 負責 | 期限 |
|---|------|------|------|
| 1 | 把同類靜態鎖改成 `-co --exclude-standard`（ENV-EQ-16 等） | 下一輪 | TMO-067 候選 |
| 2 | `CONTRIBUTING.md` PR 清單加「新檔 commit 前要重跑全量鎖」| 下一輪（與①同時）| TMO-067 候選 |
| 3 | `M6.3-c`／`M6.3-e` 改走版控 fixture（根因：`Elapsed` 讓 cache key 每次不同⇒現場 oracle 403⇒`fail`↔`blocked` 抖動）| 下一輪 | TMO-067 候選 |
| 4 | 為 dav-submitter／dav-wiki 進階路徑補 mutant | 使用者決定優先序 | 未排入 |
| 5 | 把「測名寫了什麼就驗什麼」當作探針自審項目（本輪 `AC-O4` 寫 exit 2 只驗非零，正是二審 F1 的根）| 下一輪 | TMO-067 候選 |
