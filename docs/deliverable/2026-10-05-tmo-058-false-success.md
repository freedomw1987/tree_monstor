# TMO-058 交付報告 — `wiki-media-describe.sh` real 模式假成功

- **日期**：2026-10-05
- **票**：TMO-058（P2／2pt；TMO-035 Round-1 二審 P1-1 揭露）
- **SOP**：完整流程 §2.1 → §2.5（開發編程任務）
- **一句話**：把「零產出卻回報成功」的整條路徑封死 —— real 未實作改 `exit 5`、批次改聚合
  回報（成功／失敗／截斷）、輸出寫入／輸出目錄建立／`--max-concurrency` 非法值不再假成功
  （`exit 6`／`exit 1`），並用 12 條新探針 + 9 個突變鎖住。

## 1. 問題與複現（修前逐字）

```console
$ env -u DAV_WIKI_MOCK wiki-media-describe.sh --mode describe --input in/red.png --output-json o.json
→ Single mode: describe
ERROR: real Vision API not implemented yet
  set DAV_WIKI_MOCK=1 or pass --mock for testing
rc=0                     # ← 假成功；o.json 不存在

$ env -u DAV_WIKI_MOCK wiki-media-describe.sh --mode describe --input-dir in --output-dir out
ERROR: real Vision API not implemented yet
  set DAV_WIKI_MOCK=1 or pass --mock for testing
  ⚠ skipped: in/blue.png
ERROR: real Vision API not implemented yet
  set DAV_WIKI_MOCK=1 or pass --mock for testing
  ⚠ skipped: in/red.png

✅ 批次完成：0 個檔案      # ← 零產出卻印成功
rc=0                     # ← out/ 是空的
```

根因（兩處）：

1. 單檔：`real_*` 有 `return 4`，但 `process_single "$INPUT" "$OUTPUT_JSON"` **沒接回傳值**，
   而 `set -uo pipefail` 沒有 `-e` → 腳本尾端 `exit "$EXIT_OK"` 蓋掉。
2. 批次：失敗只 `continue`，計數器 `count` 只數成功 → 全失敗照樣印「✅ 批次完成」。

## 2. 決策（§2.1 規劃，用戶 2026-10-05 裁決）

| 選項 | 裁決 |
|------|------|
| 未實作的 exit code | **採 A：新碼 `EXIT_NOTIMPL=5`**，並刪除死常數 4。理由：4 在本檔語意錯（本檔無任何工具檢查，`SKILL.md` 也寫明「不要期待安裝提示」），且 `wiki-extract-{audio,video,media}.sh` 的 4 是「缺工具」——混用會讓未來的 caller 分不出「未實作」與「缺工具」 |
| 批次聚合 | **fail-closed**：任一檔失敗 → 整體 rc 非零（第一個失敗碼），且不得再印 ✅ |
| `--max-concurrency` 截斷 | 本票做**誠實 WARN**（`尚有 K 個未處理`，rc 仍 0）＋限正整數；語意 bug 另開 **TMO-060** |
| 寫入失敗（Round-1 後補） | 順修並揭露：`echo "$result" > "$output"` 與 `mkdir -p "$outdir"` 原本不看 rc（寫不進去照印 `✓ wrote` + ✅）→ 新碼 `EXIT_WRITE=6`；**不另開票**（同一家族、同一次交付、有探針）|

### 最終 rc 契約

| 情境 | 修前 rc | 修後 rc | 產出 | 訊息 |
|---|---|---|---|---|
| 單檔 mock | 0 | 0 | 有 | 不變 |
| 單檔 real（未實作） | **0（假）** | **5** | 無 | `ERROR: real … not implemented yet` ＋ `ERROR: 未產生任何輸出（…）` |
| 單檔 `--dry-run` | 0 | 0 | 無 | 不變 |
| 單檔輸出寫不進去 | **0（假）** | **6** | 無 | `ERROR: 寫入輸出失敗（…）` |
| 批次全 mock 成功 | 0 | 0 | 有 | `✅ 批次完成：N 個檔案` |
| 批次 real 全失敗 | **0（假）** | **5** | 無 | `❌ 批次失敗：成功 0 / 失敗 N` |
| 批次部分失敗 | **0（假）** | 第一個失敗碼 | 部分 | `❌ 批次部分失敗：成功 A / 失敗 B` |
| 批次被 `--max-concurrency` 截斷 | 0（且靜默丟檔） | 0 | 部分 | `✅ 批次完成：N 個檔案` ＋ `⚠ 已達 --max-concurrency 上限（N），尚有 K 個未處理` |
| `--max-concurrency 0`／非數字 | **0（假：零產出卻 ✅）**／默默不限制 | **1** | 無 | `ERROR: --max-concurrency 需為正整數（…）` |
| output-dir 建不出來 | **0（假）** | **6** | 無 | `ERROR: 無法建立 output-dir（…）` |
| usage／mode／輸入錯 | 1／3／2 | 不變 | — | usage 補 `5 未實作`／`6 輸出寫入失敗`、刪 `4 必要工具缺失` |

## 3. Gate 1（TDD）：先紅後綠

依 `docs/sop/gates.json` 規範，Gate 1 (TDD) 需要：測試先紅後綠，並在對話貼出
「測試執行指令 + 失敗輸出 + 通過輸出」。

### 3.1 紅（實作未改時）

```console
$ bats tests/wiki-media-describe.bats
not ok 19 AC-D19: real mode single file → rc=5 and NO artifact
#   `[ "$status" -eq 5 ]' failed
not ok 20 AC-D20: real mode batch all-failed → rc≠0 and NO success message
#   `[ "$status" -ne 0 ]' failed
ok     21 AC-D21: batch mock all-success stays rc=0 + ✅（回歸鎖）
ok     22 AC-D22: real mode + --dry-run stays rc=0
not ok 23 AC-D23: usage/實作一致：有 5 未實作、無死的 4 必要工具缺失
#   `[[ "$output" == *"5  未實作"* ]]' failed
not ok 24 AC-D24: SKILL.md 限制表寫明 rc 5（不再是『回 rc 0＝假成功』）
# FAIL: file .../skills/dav-wiki/SKILL.md must NOT contain: 回 rc 0＝
not ok 25 AC-D25: batch truncated by --max-concurrency prints WARN, rc=0
#   `[[ "$output" == *"未處理"* ]]' failed
```

- **真 RED（5）**：D19、D20、D23、D24、D25。
- **誠實申報**：D21、D22 **首輪即綠** = characterization 回歸鎖（前後皆綠），不是紅→綠。
- D26~D29 是後續輪次新增，其 RED 取證以突變 M7／M8／M9 提供（見 §4）。

### 3.2 綠

```console
$ bats tests/wiki-media-describe.bats
ok 19 AC-D19 … ok 29 AC-D29
1..30       # 30 ok / 0 not ok
```

### 3.3 新探針清單（12 條）

| 探針 | 內容 | 性質 |
|---|---|---|
| AC-D19 | real 單檔 → rc=5、無產物、含 `not implemented`、且不得出現 `[MOCK]` | 紅→綠 |
| AC-D20 | real 批次全失敗 → rc≠0、**無**「✅ 批次完成」、含「失敗」、輸出目錄零檔案 | 紅→綠 |
| AC-D21 | 批次 mock 全成功 → rc=0 ＋ `✅ 批次完成：2 個檔案` ＋ 2 個產物 | 回歸鎖 |
| AC-D22 | real ＋ `--dry-run` → rc=0、無產物（不執行 ≠ 失敗） | 回歸鎖 |
| AC-D23 | usage 有 `5  未實作`、無「必要工具缺失」；檔內有 `EXIT_NOTIMPL`、無 `EXIT_TOOLMISSING` | 紅→綠 |
| AC-D24 | `SKILL.md` **內文**（排除變動歷史）不得再寫「回 rc 0＝」，且須寫出 `rc 5`／`exit 5` | 紅→綠 |
| AC-D25 | 5 檔 + `--max-concurrency 2` → rc=0、`✅ … 2 個檔案` ＋ WARN 含「未處理」 | 紅→綠 |
| AC-D26 | 部分失敗**可達**（同名目錄佔住輸出路徑）→ rc=6、`❌ 批次部分失敗`、無 ✅、他檔仍成功 | RED＝M7 |
| AC-D27 | 單檔輸出路徑被佔 → rc=6、無 `✓ wrote` | RED＝M7 |
| AC-D28 | `--output-dir` 建不出來 → rc=6、含專屬訊息 `無法建立 output-dir`、無 ✅ | RED＝M8 |
| AC-D29 | `--max-concurrency 0` → rc=1／零產物／無 ✅；`2x` → rc=1／含「需為正整數」（Round-1 P2-2） | RED＝舊碼實測 |
| AC-D30 | 合法值 `10`／`1000` **不得**被新驗證誤擋 → rc=0 ＋ `✅ 批次完成：1 個檔案`（Round-2 P3-6） | 回歸鎖（防過度收緊）|

「部分失敗」分支原本在 mock 全成功／real 全失敗的世界裡是**不可達死碼**；D26 讓它可達，
這是接上寫入檢查的直接原因。

## 4. 突變測試（探針敏感度）

| 突變 | 打回的舊行為 | 結果 |
|---|---|---|
| M1 | 單檔不接回傳值（原始真 bug） | ✅ D19 紅 |
| M2 | `real_*` 改回 `return 0` | ✅ D19 + D20 紅 |
| M3 | 批次失敗計數被吞（`fail=0`） | ✅ D20 紅 |
| M4 | 截斷不計數（WARN 消失） | ✅ D25 紅 |
| M5 | usage 改回「4 必要工具缺失」 | ✅ D23 紅 |
| M6 | `SKILL.md` 現行說明改回「回 rc 0＝假成功」 | ✅ D24 紅 |
| M7 | 還原「寫入不看 rc」 | ✅ D26 + D27 紅 |
| M8 | 還原「mkdir 不看 rc」 | ✅ D28 紅（**收緊斷言後**才咬住） |
| M9 | 限制表拔掉 `exit 5`（歷史列仍在） | ✅ D24 紅（**改 body-only 後**才咬住；修前因正面錨點掃全檔而假綠） |

誠實記錄三個中間事故：

- **M8 第一次沒咬住**：D28 原本只斷言 `rc=6`＋無 ✅，而下游寫入檢查也會回 6 → 該護欄無法
  隔離驗證。修法是把 D28 斷言收緊到**專屬訊息** `無法建立 output-dir`，之後 M8 才紅。
- **M9 第一次沒咬住（reviewer Round-1 P3-3）**：D24 的正面錨點 `grep -qE 'rc 5|exit 5'` 掃
  **全檔**，會被 `## 變動歷史` 的 v2.2.2 列滿足 → 限制表拔掉也能綠。改 `awk` 排除變動歷史
  後才咬住（Round-2 複驗後再確認一次：`not ok 24 AC-D24`，見下第三點）。
- **M9 第二次也沒咬住（我自己的突變字串在說謊）**：Round-2 後複驗時我把限制表改成
  `` `exit 0`（M9 突變：拔掉 exit 5） ``，結果 D24 仍綠 —— 因為**突變字串自己含 `exit 5`**，
  正面錨點照樣命中。改成「未實作就回報成功（M9 突變）」後才紅（`not ok 24`），還原後 30 ok。
- 三者的教訓相同：**斷言（與突變）都要綁到「唯一的因果證據」**（專屬訊息／正確章節／不含
  被鎖字面），否則多重滿足或自我指涉會互相遮蔽，探針給的是假的安全感。

## 5. Gate 2（lint／syntax）

```console
$ shellcheck -x -S style $(git ls-files '*.sh' '*.bash')
（零輸出）rc=0
$ bash -n …（自我列舉）
bad=0
$ npx markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"
Linting: 131 files / Summary: 0 issues in 0 files
$ python3 scripts/ci/lint-probe-tmp-paths.py .   → OK: 48 個探針檔皆無固定 /tmp/ 寫入（6 行 TMP-OK）
$ python3 scripts/ci/lint-probe-secrets.py .     → OK: 48 檔（2 個碰 _load_api_key）；0 violation；5 個 SECRET-OK 標記
$ python3 scripts/ci/lint-probe-tools.py .       → OK: 48 個探針檔皆未直接執行 gh / brew
```

**Gate 2 抓到的真紅燈（全部已修）**：

1. 第一版 `usage` 文字用反引號包 `--mock`／`DAV_WIKI_MOCK=1` → shellcheck `SC2006` +
   `SC2215`（warning）→ 移除反引號。這是「Gate 2 不放行不得繼續寫 code」的實例。
2. 本報告初版有 2 行超過 120 字元（`MD013`）→ 折行。

## 6. Gate 3（regression）

依 `docs/sop/gates.json` 規範，Gate 3 (regression) 需要：baseline + 修改後 output + Diff 對比。

| 階段 | 指令 | 結果 |
|---|---|---|
| baseline | `bats --count tests/` @ `609bf50` | **600** |
| 修改後 | `bats tests/`（完整輸出：`/tmp/t58-gate3.txt`） | **612 ok / 0 not ok**（plan `1..612`） |
| 尾行原文 | `tail -1` | `ok 612 AC-V11: extract-video script avoids removed -vsync flag` |
| `not ok` 計數 | `grep -c '^not ok'` | `0` |
| name-set diff | `@test` 靜態數（`tests/wiki-media-describe.bats`） | HEAD **18** → 現在 **30** = **+12**，0 刪、0 改名 |
| 子檔重構鎖 | `bats tests/restruct-dav-wiki.bats` | 15 ok / 0 not ok（`SKILL.md` 刪列後仍綠） |
| clean clone | 暫移 `PoC/.venv` → `bats tests/` | **569 ok / 43 not ok**（43 不變，全為 venv/oracle 相依；新探針皆 mock／純 bash） |

**Gate 3 抓到的真紅燈（已修）**：

1. `ENV-EQ-17`：新寫的 `echo "…（$file）"`、`echo "…（$MAX_CONCURRENCY），…"` 變數展開後
   **緊接全角括號** → bash 3.2 + UTF-8 會吞位元組 → 改 `${file}`／`${MAX_CONCURRENCY}`。
2. `AC-D24` 自我誤報：`SKILL.md` 的 **v2.2.2 變動歷史列**寫了「原本零產出卻回 rc 0＝假成功」，
   被自己的字面鎖咬到 → 負面鎖改用 `refute_file_body_contains`（排除變動歷史）：歷史列談舊行為
   是合法的，違規的是**現行說明**；正面錨點同步改 body-only（Round-1 P3-3）。

## 7. Gate 4（reviewer gate）

| 輪次 | 觸發 | verdict | 處置 |
|---|---|---|---|
| Round 1 | V03（新增探針 + 改 `SKILL.md` + usage 契約） | **`request-changes`**（唯一 P1＋4 P2＋5 P3；明示「功能與契約層找不到 defect」）| 逐條見下 |
| Round 2 | P1/P2 處置後複審 | **`approve-with-comments`**（**0 P0 / 0 P1 / 0 P2**，7 條 report-only P3；明示「無新功能 defect、無 regression、9 條 Round-1 處置全部真的做到、無修過頭、無資訊遺失」）| 6 條便宜且**只從嚴**的 P3 已修（下表 R2）；第 7 條（既有白名單靜默略過）併入 TMO-060 |

### Round-1 逐條處置

| # | 級 | 問題 | 處置 |
|---|---|---|---|
| P1 | P1 | `SKILL.md` 變動歷史被我加成 **4 列**，違反同節自述「只留最近 3 條 + v2.0 錨點」（`dav-skill-creater` 規則） | **已修**：刪 `v2.1` 列（`CHANGELOG.md` 已有逐字同列）→ 134 行、3 列 + 錨點；`restruct-dav-wiki.bats` 仍綠 |
| P2-1 | P2 | `docs/install-reference.md` 套件／紅燈數字過期（600／603／557+43）| **已修**：實測後改 **611／614／568+43**（43 組成不變）|
| P2-2 | P2 | `--max-concurrency 0` → 每檔算截斷＝零產出＋✅＋rc 0；`2x` → `[[ ]]` 算術報錯後默默不限制 | **已修**：旗標限正整數（否則 `exit 1`）＋探針 AC-D29；另把 reviewer 指出的「截斷額度只計成功數」「批次 dry-run 仍印 ✅」記入 TMO-060 |
| P2-3 | P2 | `docs/need-you-help.md:71` 仍是現在式「失敗仍回 rc 0＝假成功…另開票」| **已修**：補「已修（TMO-058）」註記 |
| P2-4 | P2 | 本報告變動量寫「+83/−17」不實（實為 67+16 的誤植）| **已修**：改為逐檔實測數字（§10）|
| P3-1 | P3 | `tests/wiki-toolmissing-contract.bats:21` 現在式落差敘述失效 | **已修**：加「已修：TMO-058／本段為修前狀態」|
| P3-2 | P3 | `docs/backlog.md:53`「自帶同名常數（`:37`，未受影響）」已被本票刪除 | **已修**：加註「TMO-058 已刪除該常數」|
| P3-3 | P3 | D24 正面錨點掃全檔，可被歷史列滿足（假綠） | **已修**：改 body-only；M9 突變確認現在咬得住 |
| P3-4 | P3 | 批次 `--dry-run`／空目錄仍印 `✅ 批次完成：N 個檔案`（本票前後相同）| **記錄即可**（reviewer 亦建議不擴範圍）→ 已寫入 TMO-060 附帶項 |
| P3-5 | P3 | Gate 3 未附原始輸出檔路徑；§7 待填 | **已修**：§6 補 `/tmp/t58-gate3.txt`＋尾行原文＋`not ok` 計數；§7 本表即填 |
| — | — | reviewer 明確認可「範圍切割」（寫入／mkdir 留在本票、`--max-concurrency` 語意另開票）| 不需處置 |
| — | — | reviewer 要求實跑複驗（`bats --count`、clean clone、M1~M9、兩把鎖）| **已跑**，數字見 §4／§6／§5 |

### Round-2 P3 逐條處置（本輪新增，全部「只從嚴」）

| # | 級 | 問題 | 處置 |
|---|---|---|---|
| R2-P3-1 | P3 | `CHANGELOG.md:9`／`SKILL.md:119` 的 v2.2.2 只記 `exit 5`，漏記同批的 `exit 6` 與 `--max-concurrency` 限正整數 | **已補**：CHANGELOG 加「順修：輸出寫入／mkdir 失敗改 `exit 6`、`--max-concurrency` 限正整數（`exit 1`）」；SKILL.md 摘要列加「（…；寫入失敗 `exit 6`）」 |
| R2-P3-2 | P3 | `EXIT_NOTIMPL=5` 與兄弟腳本 `wiki-extract-media.sh` 的 `EXIT_EXTRACT=5` 同號不同義，本檔註解只對比過 4 | **已補**：`wiki-media-describe.sh:37` 註解就地聲明「5 為本檔語意、勿跨腳本比對 rc」（本檔無 skill 級 exit code 總表）  |
| R2-P3-3 | P3 | `need-you-help.md:72` 現在式殘留；`:75` 探針行讀起來像 TMO-058 的（實為 TMO-035/053）| **已修**：改「**修前**失敗仍回 rc 0＝假成功」；探針行加「（**TMO-035／TMO-053 的**，非 TMO-058）」|
| R2-P3-4 | P3 | `backlog.md:67` 寫「M1~M8」，與本報告 §4 的 M9 不一致 | **已修**：改 `M1~M9` |
| R2-P3-5 | P3 | §8「條件放寬 ❌」說得太絕對（AC-D24 的**負面**鎖確實由全檔改 body-only）| **已補**：§8 加註「負面鎖全檔→body-only＝字面放寬①（歷史列合法引用舊行為）；正面錨點同步 body-only＝嚴格化；淨效果為嚴格化」|
| R2-P3-6 | P3 | AC-D29 只鎖「拒絕」方向，缺「接受」證據 | **已補**：新增 **AC-D30**（`10`／`1000` → rc=0 ＋ ✅）＝回歸鎖（防過度收緊）|
| R2-P3-7 | P3 | 批次靜默略過不符 mode 白名單的檔（單檔模式會 WARN）；**修前既有、非本票造成** | **不擴範圍**：已寫入 TMO-060 附帶③（reviewer 亦建議如此）|

### Round-3 複審（V03.6：本輪新增探針 AC-D30，故再走一輪）

| 輪次 | verdict | 處置 |
|---|---|---|
| Round 3 | **`approve-with-comments`**（**0 P0 / 0 P1 / 0 P2**；2 條 report-only P3，明示「本輪 delta 未引入功能 defect、未修過頭、無新矛盾」；並靜態複驗 AC-D30 為**真**回歸鎖（過度收緊時兩條斷言同時失敗）、無 ENV-EQ-5/17/errexit 陷阱）| 2 條皆本輪修完（下表 R3）|

| # | 級 | 問題 | 處置 |
|---|---|---|---|
| R3-P3-1 | P3 | `docs/backlog.md:67` TMO-058 列 ⑧ 仍寫 `611／614／568+43`、⑤ 仍寫 `AC-D19~D28`（我自己的 done 記錄又漂了一次）| **已修**：⑧ → `612／615／569+43`、⑤ → `AC-D19~D30`（附註 D29／D30 各是什麼）|
| R3-P3-2 | P3 | `tests/wiki-media-describe.bats:240` 區塊標題仍寫 `（AC-D19~D25）` | **已修** → `（AC-D19~D30）` |

> **第三輪不再開**：本輪兩條均為 reviewer 指定的**純文字修正**（不涉行為、不涉探針語意），且都是把字串改成 reviewer 自己寫的最小修法 → 依 V03.6「純文字修正不觸發 V03」處理。

## 8. V03.6 申報（分類）

| 類別 | 是否觸發 | 內容 |
|---|---|---|
| 新增探針 | ✅ | `tests/wiki-media-describe.bats` +12（AC-D19~D30；含 Round-2 P3-6 的 AC-D30） |
| 條件放寬 | ⚠️ 一字面放寬①（已揭露，淨效果為嚴格化）| D24 的**負面**鎖由「全檔」改 body-only＝**字面放寬①**（原因：`## 變動歷史` 合法引用舊行為，字面鎖若掃全檔會逼歷史列說謊）；同一處的**正面**錨點同步改 body-only＝嚴格化（修前可被歷史列滿足＝假綠，M9 佐證）。其餘皆嚴格化（D28 由 `rc=6` 收緊到專屬訊息）|
| 既有探針修改 | ❌（僅新增 `load`） | 該檔 diff 為 +167/−0：既有 18 條探針**內文未被改動**，只有新增 `load 'helpers/test-env'` 與新探針 |
| SOP 檔修改 | ❌ | `AGENTS.md`／`docs/sop/**`／`gates.json` 未動 |
| skill 主檔修改 | ✅ | `skills/dav-wiki/SKILL.md` 限制表 1 行 + v2.2.2 一列（P1 修完後仍為 3 列 + 錨點）；`CHANGELOG.md` +1 列 |

## 9. V03.5 主檔行數

`skills/dav-wiki/SKILL.md`：**134 → 135 → 134 行**（Round-1 P1 刪 v2.1 列後回到 134）。
未觸發 <150 硬上限；本次為「改既有列文字 + 換列」，未新增結構。變動歷史現為
`v2.2.2 / v2.2.1 / v2.2` + `v2.0` 錨點 = 合規（3 條 + 錨點）。

## 10. 交付檔案（`git diff --numstat` 實測）

| 檔案 | 變動 |
|---|---|
| `skills/dav-wiki/scripts/wiki-media-describe.sh` | **+77 / −17** |
| `tests/wiki-media-describe.bats` | **+167 / −0** |
| `docs/install-reference.md` | +4 / −4 |
| `docs/backlog.md` | +3 / −2 |
| `tests/wiki-toolmissing-contract.bats` | +2 / −1 |
| `skills/dav-wiki/SKILL.md` | +2 / −2 |
| `skills/dav-wiki/CHANGELOG.md` | +1 / −0 |
| `docs/need-you-help.md` | +4 / −2 |
| `docs/deliverable/2026-10-05-tmo-058-false-success.md` | 新增（本檔） |

## 11. 未做 / 新票

- **TMO-060（新，P3／2pt）**：`--max-concurrency` 是「同時處理幾個」的語意，實作卻當「最多
  處理 N 個檔案」→ 第 N+1 個以後靜默不處理（本票只讓它變誠實 WARN ＋限正整數）。附帶：
  截斷額度只計成功數；批次 dry-run／空目錄仍印 `✅ 批次完成`；批次靜默略過不符 mode 白名單的檔。
- 真實 Vision／Whisper API：不在本票範圍（real 模式仍是明確的「未實作 → 不許假成功」）。
- TMO-057（六腳本死引用）維持獨立。

## 12. 反省（§2.4）

1. **最該記住的**：這條 bug 的形狀是「**錯誤碼有回傳，但沒有人接**」。修 bug 時若只盯著被回傳
   的那一層（`real_*`），就會漏掉真正說謊的那一層（腳本尾端的 `exit 0`）。→ 診斷「假成功」要
   沿著**資訊流的方向**追到最後一個出口。
2. **我自己製造了 P1，而且還寫論文說「下次再處理」**：`SKILL.md` 主檔「只留最近 3 條」的規則
   就在我改的那張表上面兩行。我把「本票範圍控制」當成延後的理由，但那其實是**讓文件自己說謊**，
   而本票的主題正是「不准假成功」。→ 紀律：**動 SOP 檔時，該檔自己的規則要先讀一遍**；範圍控制
   不能拿來合理化明知違規。
3. **Gate 3 沒有白跑**：`ENV-EQ-17`、`AC-D24` 兩個紅燈都是我自己製造的（前者違反我已知道的規範、
   後者是自己鎖自己）＋Gate 2 的 2 個 MD013。若省略 Gate 2／3，交付出去就是「新增 4 個違規」。
4. **三次突變「沒咬住」（M8、M9）比咬住更有價值**：M8＝下游檢查遮蔽；M9＝掃描範圍過寬被歷史列
   滿足。→ 斷言要綁到**唯一的因果證據**（專屬訊息、正確章節），否則探針只是假的安全感。
5. **reviewer 的價值在「文件一致性」而非功能**：功能層 reviewer 找不到 defect，但抓到 P1 與
   4 個 P2 全部是「文件與現實脫節、現在式殘留」。→ 這類漂移只有「把每份文件的數字都當成待驗
   聲明」才擋得住，我下次要在交付前自己先掃一遍「本票改了什麼 → 誰在描述它」。
6. **「套件總數」這種數字每加一條探針就會漂一次，本票漂了兩次**：`install-reference.md` 的
   600→611（Round-1 P2-1）→ 612（Round-2 加了 D30 之後）。我自己在報告裡預言這個風險，然後
   同一票內又親手示範一次。→ 這證明「靠人工同步」不可行；下一步該把數字改成**由探針自動核對**
   （或文件直接寫「以 `bats --count tests/` 為準」而不寫死），已記入建議。
7. **「數字漂移」在同一票內發生三次，都是我自己造成的**：600→611（Round-1 P2-1）→ 612
   （Round-2 加 D30）→ backlog 列忘記同步 612／615／569+43（Round-3 P3-1）。我在反思第 6 點
   剛寫完「靠人工同步不可行」，下一輪又漂一次。→ 這是**結構性**問題，不是細心度問題：**同一份
   事實被寫在 4 個地方（install-reference／backlog／deliverable／探針註解），就一定會漂**。
   下一步該做的是「單一來源」：文件只寫「以 `bats --count tests/` 為準」，或寫一條探針去核對。
8. **reviewer 三輪分工很清楚**：Round-1 抓契約與文件漂移（P1＋4 P2），Round-2 抓「揭露完整性」
   與「邊界解鎖」（P3-5／P3-6）；第二輪的價值不在找 bug，而在檢查**你有沒有誠實地把自己的
   例外講清楚**（例如負面鎖放寬那 1 條）；第三輪則只剩我自己的複製貼上漂移。→ 對上 §1「誠實」
   原則：reviewer 抓到的每一條，最後幾乎都是「文件與現實不一致」，而不是「程式不對」。
