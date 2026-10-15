# TMO-066 交付報告：跨 skill 護欄補 mutant（dav-wiki ＋ 探針機密遮罩 ＋ regression-guard）

> **交付日期**: 2026-10-05
> **對應 Backlog**: TMO-066（US 級，見 `docs/backlog.md`）；延伸 TMO-065 的突變測試自動化
> **Sprint / Module**: tree_monstor 建置／CI 護欄（`scripts/ci/`）＋ 三個 skill 的契約面
> **交付狀態**: ✅ 完成（39 支 mutant 全紅、全量 673 條探針 0 紅、markdownlint 137 檔 0 issue、
> V03 二審 verdict = **未完成（兩次自動二審皆逾時未產出 verdict，詳見 §4.4）**

## 1. 這次完成什麼

TMO-065 把「探針真的咬得住突變」從**一次性人工動作**變成 CI 每次都會跑的檢查，但那張表
（`scripts/ci/mutants.tsv`，26 支）只覆蓋 pptx-slim。本輪用**同一套 harness**（temp copy ＋ 精確錨點
＋ 綠 baseline 對照 ＋ md5 自證）把另外三個護欄面收進來，表 26 → **39 支**。

**關鍵成果**：

- ✅ **13 支新 mutant**：dav-wiki 6 支（缺工具不得降級／OCR 常數／cleanup 預設不得真刪除）、
  探針機密遮罩 3 支（遮罩直通、R2 停用、探針自己再定義一份）、regression-guard 4 支
  （`jest --ci`、gates.json 交叉引用、handbook 的 `< /dev/null`、SKILL.md 的對照表指標）。
- ✅ **MMD-1 兩處強化**：門檻 26 → **39**；新增「跨 skill 覆蓋清單」——dav-wiki 的 4 個目標檔與
  `skills/regression-guard/SKILL.md` **少一個就紅**，防有人只留 pptx-slim 那段而靜默丟掉別人的護欄。
- ✅ **實測 39/39 全紅**（每支都有綠 baseline 對照）＋ 跑完 md5 自證 18 個目標檔 working tree 未變；
  `real 0m55.374s`（26 支時 49.9s）。
- ✅ **抓到並修掉一個 commit 後才會現形的真 bug**：`ENV-EQ-17`（`$var` 緊接非 ASCII）掃描範圍
  原本只含 `git ls-files`（已追蹤）→ 新檔在 commit 前是 untracked，**本機全綠、push 後 CI 必紅**。
  本輪修掉 4 條違規（3 條是上一輪 commit 進去的）並把鎖改成 `git ls-files -co --exclude-standard`。
- ✅ **推翻一支候選突變（無害突變）並誠實記錄**：`SKILL.md` 把 `**TTY fail-fast**` 改成
  `**TTY fail-slow**` 後探針仍綠 —— 追下去是同字串在檔內另有兩處，規則還在 ⇒ 探針綠是**正確**行為，
  該突變不進表（記在 `tests/mutant-must-die.bats` 檔頭）。
- ✅ 文件對帳：`CONTRIBUTING.md`（39 支＋泛化措辭）、`docs/backlog.md`（TMO-065 row／詳細＋TMO-066
  row／詳細）、`skills/pptx-slim/` 的 v1.4 列（26 支改為 scoped 措辭）。

### 1.1 驗收標準對應（AC）

| AC | 內容 | 證據 |
|----|------|------|
| AC-1 | 表至少 39 支、且新增的 13 支每支都被對應探針咬死 | `mutants.tsv` 39 列；`--only` 13/13 紅（§4.1）；全表 39/39 紅 |
| AC-2 | 每支 mutant 都有「未突變必須綠」的 baseline 對照 | driver 內建 baseline 快取；輸出每組探針先印綠（§4.1 log）|
| AC-3 | 新 mutant 沒有破壞既有 CI 護欄（MMD-1..5 全綠） | `bats tests/mutant-must-die.bats` 5/5（§4.2）|
| AC-4 | 跨 skill 覆蓋清單存在且會紅（少一個目標檔即 FAIL） | MMD-1 迴圈（`skills/dav-wiki/...`×4 ＋ `skills/regression-guard/SKILL.md`）|
| AC-5 | 「無害突變」的判定有記錄、不是靜默丟掉 | `tests/mutant-must-die.bats` 檔頭 TMO-066 段 ＋ 本報告 §4.1 |
| AC-6 | 全倉文件數字一致（26 → 39）且 lint 全綠 | markdownlint 137 檔 0 issue；`grep` 對帳（§4.2）|
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
| `scripts/ci/mutants.tsv` | +13 資料列（26 → 39）|
| `tests/mutant-must-die.bats` | MMD-1 門檻 26 → 39；新增跨 skill 覆蓋清單迴圈；檔頭加 TMO-066 說明段（含無害突變案例）|
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
| 突變全表（`scripts/ci/mutant-must-die.py`）| **39 / 39 死亡** | 每支都有綠 baseline；md5 自證；`real 0m55.374s` |
| 新增 13 支單獨跑（`--only`）| 13 / 13 死亡 | `real 0m6.359s`；log `/tmp/mutant-only-tmo066.log` |
| 突變工具探針（`tests/mutant-must-die.bats`）| 5 / 5 | MMD-1（門檻 39＋覆蓋清單）、MMD-2..5 |
| 結構探針（`tests/restruct-pptx-slim.bats`）| 9 / 9 | 含「SKILL.md ≤ 130 行」預警線 |
| 守門探針（skill-local）| 3 / 3 | `bats skills/*/tests/*.bats` |
| 全量回歸（`bats tests/`）| 673 條：**673 綠 / 0 紅** | `/tmp/bats-full-v21.log`（同批碼在前一次 v20 有 2 紅：`ENV-EQ-17` 真 bug ＋ `M6.3-c` 間歇紅，皆已說明，見 §4.3）|
| markdownlint（CI 同款 4 globs）| **137 files / 0 issues** | `npx --no-install markdownlint-cli2 …` |

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
| `markdownlint-cli2`（CI 同款 4 globs）| **137 files / 0 issues** |
| `python3 scripts/ci/lint-shell-var-nonascii.py .` | OK：80 個 shell／CI 檔（含未追蹤）0 違規 |
| `shellcheck -x -S style` ＋ `bash -n` 自我列舉 | 由 `ENV-EQ-18` 在 §4.3 的全量裡跑（綠）|
| `bats tests/mutant-must-die.bats` | 5/5 綠（MMD-1 門檻與覆蓋清單、MMD-5 十種假綠反向自測）|

### 4.3 Gate 3（regression）

> 依 gates.json 規範，Gate 3（regression）需要：全量測試通過，且與改動相關的既有行為無退化。

- **全量**：`bats tests/` → **673 條：673 綠 / 0 紅**（`/tmp/bats-full-v21.log`，本輪最終定稿後跑的）。
  同批碼的前一次（v20，`/tmp/bats-full-v20.log`）有 2 紅，兩個都查清了：
  ① **`ENV-EQ-17` 是真 bug**（本輪修掉，見 §4.1(B)／§5）；
  ② **`M6.3-c`（`tests/v2.1-jev-poc.bats`）是既有間歇紅** —— 本輪兩次全量中 v20 紅、v21 綠；
    上一輪的 v15～v19 亦間歇紅過（`M6.3-c`／`M6.3-e`）。本輪改動不涉及 JEV／sandbox（§5④）。
- **skill-local**：`bats skills/*/tests/*.bats` → 3/3 綠。
- **突變全表連 working tree 一起驗**：39 支跑完 → 18 個目標檔 md5 全數未變（突變只發生在已刪除的副本）。
- **兩支被當探針的既有測試沒有被本輪改壞**：`tests/wiki-toolmissing-contract.bats`、
  `tests/wiki-cleanup.bats`、`tests/secret-masking.bats`、`tests/regression-guard-watch-mode.bats`
  在全量裡都是綠（它們是 mutant 的 baseline）。

### 4.4 Gate 4（reviewer 二審，V03）

**狀態：未完成（誠實記錄，不假裝已審）。**
依 V03，本輪動了 skill 檔（`skills/pptx-slim/SKILL.md`／`CHANGELOG.md`／`examples.md`）＋
探針（`tests/mutant-must-die.bats`）＋ CI 鎖（`scripts/ci/lint-shell-var-nonascii.py`），因此必須二審。實際發生：

| 次 | 時間（UTC）| 結果 | 診斷 |
|----|-----------|------|------|
| 1（完整審查）| 19:02 → 19:32 | **逾時 30 分鐘未產出 verdict** | reviewer 做大量工具探索（log 523 KB）後停滯，已中斷 |
| 2（有界：≤8 呼叫／15 分鐘）| 19:43 → 19:59 | **逾時 15 分鐘未產出 verdict** | run 統計 input 3,747／output 375 tokens、歷時 1,004 秒，只有讀檔沒有實質輸出 ⇒ 懷疑 provider 端太慢 |

**因此本報告沒有 verdict 可引** ——「沒有結論」不能寫成「通過」。缺口的補位方式：

1. 我做了一輪**自查**（非抽樣，見下方），把能量化的部分先釘住。
2. 二審材料已備好：`/tmp/review-bundle-tmo066.md`（440 行，含完整 diff、13 列新突變、請審 7 條重點）——
   使用者可直接人工審，或指定換一條 agent 路徑。
3. 修復路徑（**待使用者裁示**）：① 換 `codex-exec`（本機 Codex CLI，唯讀）跑同一份有界 prompt；
   ② `reviewer` 降 thinking（`:low`）再試一次；③ 接受缺口、記進 backlog 下一輪補審。

**自查清單**（用 python 掃 `mutants.tsv` 全 39 列，不是抽樣）：

```text
rows: 39
每列「原文」在目標檔的出現次數：全部 == 1（錨點唯一）
每列探針名 regex 在探針檔命中的 @test 數：全部 == 1（無誤配、不會假死）
沒有任何 no-op 列（原文 == 換成）
```

## 5. 已知問題 / 限制

- **`ENV-EQ-17` 這類「以 `git ls-files` 為準」的靜態鎖仍有同類盲點**：本輪只修了 `ENV-EQ-17`。
  `ENV-EQ-16`（檔尾換行）等鎖也是同一種列舉方式（同日稍早已發生過一次：新鎖檔缺檔尾換行，
  本機全綠、clean clone 才紅）。**建議**下一輪把同類鎖一起改成 `-co --exclude-standard`
  （列為 §6 建議①，本輪未自作主張擴大範圍）。
- **仍有 skill 沒有 mutant**：`dav-planner`／`dav-designer`／`dav-submitter`／`dav-reflection`／
  `dav-trust`，以及 dav-wiki 的 cross-ref／cleanup 進階路徑。本輪補的是「TMO-035／053 人工驗過、
  且可字串化重現」的那批。
- **跨檔案一致性探針只能用單點突變**：`RG-M4` 咬的是「四個檔案都指得到」的 CROSS 探針；咬不到
  「四份都寫錯但互相一致」的情境（那需要語意檢查，不是單行突變能表達的）。
- **CI 成本上升**：39 支＋baseline 本機約 55 秒（26 支約 50 秒）。
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
# 外加本報告本身（新檔，尚未 git add）：docs/deliverable/2026-10-05-tmo-066-cross-skill-mutants.md
```

## 反思（§2.4，US 級反省）

### 6 維度檢查

| 維度 | 檢查結果 |
|------|---------|
| **完整性** | 13 支新 mutant 全數落地並被咬死；MMD-1 兩處強化；文件（CONTRIBUTING／backlog／skill 三檔）數字對齊；lint＋全量回歸有實跑證據 |
| **正確性** | 門檻與清單是「少就紅」的方向；13 支都有綠 baseline（紅不是因為探針本來就壞）；md5 自證 working tree 未變 |
| **一致性** | 「26 支」只保留在歷史語境（TMO-065／v1.3）；現況一律 39；`examples.md` 改成 scoped 措辭避免與共用表衝突 |
| **可維護性** | 沒有新增機制（只加表列）；覆蓋清單把「別人的護欄也在表內」變成斷言；`--only` 讓單支除錯只花 6 秒 |
| **風險** | 已揭露：其他 `git ls-files` 鎖的同類盲點未修（§5①）、跨檔一致性探針咬不到「一致地錯」（§5③）|
| **效率** | 全表 55 秒（+5 秒換 13 個護欄面）；`--only` 13 支 6.4 秒；沒有把 CI 成本推高到需要分流的程度 |

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
