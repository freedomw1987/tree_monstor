# §3 CHANGELOG（SOP 異動紀錄）

> 本檔是 AGENTS.md §3 的詳細內容。引用：`[§3 CHANGELOG](./sop/handbook/changelog.md)`
>
> 追蹤 AGENTS.md §2 SOP 的所有重大異動，便於 audit 與回溯。每筆異動需註明版本號、日期、變更內容與原因。
>
> ⚠️ **版本序號說明**：本檔的版本號 = **全域變更序號**（含 skill / CI / 文件變更），
> 與 `AGENTS.md` §2 標題的 **SOP 版本號**（不同軌）不是同一個序號 —— 兩者不可互相比較大小。

## v2.12 — 2026-10-26

**本版異動**：Gate 4.5 第 6 輪需求對帳 —— 補正 v2.11 的**失真紀錄**、修正 RECON-007 探針解析器（BSD grep 交替分支上限）、
修掉 `--from-date` 的 **fail-open** 缺口、關閉 v2.11 二審指出的 RECON-007 覆蓋盲點、**並完成 TMO-072（假綠溫床）**

### TMO-072：bats 1.14 在 UTF-8 locale 下靜默丟棄 CJK 名的探針

**病因（實測確認，非推論）**：bats 的 `bats_encode_test_name` 用 `[[:alnum:]]` 決定哪些字元**原樣**留在 bash 函式名裡。
該類別在 **UTF-8 locale** 下會匹配 Unicode 字母（中文／假名／韓文／西里爾）→ 函式名對不上 → bats 報
`bats: unknown test name` + `Executed N instead of expected M` → **該支探針從未被執行**；
但 `bats --count` **仍把它算進去** → 報表看起來全綠。

| 環境 | CJK 名探針 |
|------|-----------|
| `LC_ALL=C` | **會跑**（`[[:alnum:]]` 只認 ASCII → CJK 被跳過編碼）|
| `LC_ALL=en_US.UTF-8` | **被丟棄**（＝本 bug 的成因；CI 預設就是這種）|

（希臘文／café／全形英數／emoji／→ **不受影響**。）

**動工前**（2026-10-26 量測）：**21 個探針檔共 134 支**探針名含非 ASCII → 在 UTF-8 locale 下從未執行。

**處置**：

| # | 動作 | 證據 |
|---|------|------|
| 1 | 134 支探針改名為**純 ASCII**（保留 `<ID>: <說明>` 結構與 ID 前綴，說明翻英文）| 計畫數 == 執行數 == **760**；`unknown test name` 0 筆；`instead of expected` 0 筆 |
| 2 | 新增 `tests/helpers/probe-scan.bash`（引號/heredoc 感知的共用掃描器）| 每個 .bats 檔：掃描器計數 == `bats --count`（PNA-2 釘住）|
| 3 | 新增 `tests/probe-name-ascii.bats`：PNA-1 命名政策／PNA-2 交叉比對／PNA-3 掃描器自測／PNA-4 斷言 fail-fast | PNA-4 突變測試：把一個 fail-fast 還原成裸 `[[ ]]` → 轉紅並指名檔案行號 |
| 4 | ENV-EQ-9 的 canary 改成 **locale 正確**的斷言（舊版斷言「CJK 名必須跑 2 條」是 `LC_ALL=C` 下的觀察 → 在 UTF-8 locale 下必然紅，且紅的原因被誤讀成「canary 檔壞掉」）| ENV-EQ-9 從紅轉綠（baseline 47 → **46**）|

#### 連帶挖出並修掉的第二層假綠（比本 bug 更嚴重）

**實測發現**：bats（與純 bash）之下，**獨立的 `[[ ... ]]` 斷言失敗不會中止 test body** —— 只有**最後一個**命令的狀態決定結果：

```
[[ abc == xyz ]]; echo reached   → reached（rc 0，沒中止）
[ abc = xyz ];    echo reached   → 中止（rc 1）
false;             echo reached   → 中止（rc 1）
```

→ **夾在中間的 `[[ ]]` 斷言等於沒有**。實例：`tests/ffmpeg-version.bats` FV-2 在 `MIN_MAJOR=5 → 0` 的突變下**仍綠**，
因為它的核心斷言 `[[ "$output" == *"太舊"* ]]` 夾在中間、失敗被靜默忽略。

**處置**：把 **181 個**獨立 `[[ ]]` 改成 repo 既有的 fail-fast 慣例：

```bash
[[ ... ]] || {
  echo 'FAIL: <file>:<line>: assertion failed' >&2; return 1; }
```

> **兩個刻意的設計**（都是被現有工具逼出來的）：
> ① **不把運算式嵌進訊息**、且**拆成兩行**——`scripts/ci/lint-probe-secrets.py` 的 R3 規則是**行級**的
> （同一行同時出現 `FAIL` 與 `$output`/`$out`/`$result` 且無 `mask_secrets` → 判成外洩）。
> 兩行式正是本 repo 既有慣例。
> ② **行尾註解（含 `SECRET-OK:` 標記）一律保留**——掉了會讓秘密掃描器誤判成「出現真 key 前綴」。

**效果**：**6 支原本「守不住」的 mutant 全部轉死**（IMG-M2／V-M7／V-M10／FF-M1／SM-M1／SM-M2）。
這 6 支的探針正是那 134 支「從未執行」的其中之一 → **它們從來沒有被驗證過**。
全表 **48 支 mutant 全部死亡**（動工前整表 `UnicodeDecodeError` 崩潰、從未跑完）。

> **失敗數沒有變**：改寫 181 個斷言後，全套失敗數 **46 → 46，失敗集合完全不變**——
> 表示那些斷言本來就都成立，只是**沒有被強制**。這是「假綠」的典型樣貌：報表綠，但護欄其實沒扣住。

### TMO-072 的 V03 二審結論（Reviewer）

| 輪次 | Verdict | 摘要與處置 |
|------|---------|------------|
| 第 1 輪 | ⚠️ approve with comments（0 P0 / 1 P1 / 6 P2 / 6 P3）| **P1**：Reviewer 質疑「`[ ]` 會中止、`[[ ]]` 不會中止」的不對稱是**量測環境混用** → **已用同檔對照實驗排除**（T1~T5 放在同一個 .bats、同一環境、每例最後一個命令都是 `true`：T1 `[ ]` 紅、T2 `[[ ]]` 綠、T3 `false` 紅）→ Reviewer 的前提不成立，但**其結論「裸 `[ ]` 中段斷言也不安全」因此也不成立**（`[ ]` 確實會中止 → 安全）。**P2**：①`\|\|`/`&&` 豁免過寬 → 已收緊（PNA-4 重寫，連 `\|\|` 鏈也抓）；②fail-fast 訊息行號漂移 → 已用 `fix_line_numbers.py` 重算（182 筆全對）；③新檔 untracked → CI 的 `git ls-files` 系列守門與 shellcheck 尚未蓋到 → **併入合併前檢查清單**（本分支所有新檔都還沒 add，非本次獨有）；④ENV-EQ-9 canary 用 `charmap` 當代理是錯的代理 → 已改用**「該 locale 的 `[[:alnum:]]` 是否含 CJK」**（與 bats 內部 `bats_encode_test_name` 同一判準）；⑤同一件事四處四個數字 → 已統一為「動工前 21 個探針檔共 134 支」；⑥V03 未閉環 → 本節即為二審紀錄。**P3**：PNA-4 的 `if/elif` 豁免是不可達死碼 → 已刪；PNA-4 不跳 heredoc → 已改用 heredoc 感知的 `probe_code_lines`；巢狀 bats 未清 `BATS_` 前綴的環境變數 → 已清；PNA-1/2/4 缺「掃到幾個」下限 → 已補（防空過）。 |

> **本輪自己也踩到同一個坑（假綠）**：PNA-4 改用 heredoc 感知掃描器時，我改了 `while read` 卻忘了改底部的
> `done < "$file"` → **整支守門變成空轉卻回報綠**。是「突變測試」（把一個 fail-fast 還原成裸 `[[ ]]`
> 必須轉紅）把它抓出來的 → **守門自己也必須先證明自己會咬**。

### 第 6 輪對帳 → 補正 v2.11 的失真紀錄

**為什麼**：v2.11 記載「實測 4 支 mutant 全死」，但**當時並未真的觀察到**——RECON-007 v1.0 的解析器在
macOS/BSD grep 上本身是壞的（baseline 紅）→ `mutant-must-die.py` 的 baseline 迴圈 `die()` → **整個表中止** →
DD-M1..DD-M3 / DR-M1 四支守護一直是**失效狀態**。v2.11 同節的「探針『會咬』實測」表（DR-M1 列
`✅ 紅（baseline 綠 → 突變 rc=1）`）與「登錄 4 支 mutant（實測 4 支全死）」同屬當時未發生的宣稱。
**這正是本專案要解的病（同一件事多份文件各說各話、宣稱與實況不符）在自己的 changelog 裡重現。**

### 探針修正（依 V03.6 走 Reviewer 二審）

| 探針 | 問題 | 修正 | 判定 |
|------|------|------|------|
| RECON-007（`tests/restruct-dav-reconciler.bats`）| v1.0 用 `grep -oE '(✅\|⚠️\|❌\|🚫) …'`：BSD grep 2.6 的 ERE **交替分支上限為 2** → 4 分支只吐出前 2 個（❌ / 🚫 被吞）→ count 只數出 2 種 → 探針紅 | 改用 python3 逐行 + `re.finditer().group(0)` 解析（明確 UTF-8 讀檔、Unicode 語意、兩平台一致）| **不是門檻放寬**：同一 regex、同一 4 種門檻、同一缺值斷言，僅換解析器（predicate 逐位元組未變）|
| DOC-DRIFT-036/037（`tests/doc-drift.bats`，新增）| `--from-date` 未驗證格式：比對用**字串**比較（`doc.name[:10] < from_date`）→ 傳入 `"bad-date"` 會讓**所有**交付摘要被跳過 → 檢查範圍靜默縮成空集 → **D8 硬門檻被一個 typo 關掉** → 假綠 | `--from-date` 改用 `datetime.strptime` 驗證（格式 + 日期存在性），不合法 → **rc=2**（fail-closed）| **收緊**（新增 fail-closed 契約），非放寬 |

### 實測證據（V03.6 要求：修改前 fail / 修改後 pass）

```
# RECON-007 修改前（BSD grep 2.6.0-FreeBSD，實測）
$ printf '%s\n' "$sec" | grep -oE '(✅|⚠️|❌|🚫) [^ |（(]+' | sort -u
✅ 已實作
⚠️ 部分實作                     ← 只數出 2 種（❌ / 🚫 被交替上限吞掉）
not ok 1 RECON-007: exactly four allowed status values are defined
#   `count=$(printf '%s\n' "$values" | grep -c . )' failed

# RECON-007 修改後
ok 1 RECON-007: exactly four allowed status values are defined

# 交替分支數 vs 抓到幾種（實測，證明是分支數而非字串長度／locale／跨行）
(✅) → 1 種 ｜ (✅|⚠️) → 2 種 ｜ (✅|⚠️|❌) → 2 種 ｜ (✅|⚠️|❌|🚫) → 2 種
(a|b|c|d)（純 ASCII）→ 4 種（正常）｜ LC_ALL=C 與 en_US.UTF-8 結果相同（非 locale 問題）

# mutant 守護（修好後才第一次真的跑完）
$ python3 scripts/ci/mutant-must-die.py --only DD-M1,DD-M2,DD-M3,DR-M1
baseline（未突變，必須綠）：4 組 → 4 組全綠
突變（每支都必須紅）：DD-M1 / DD-M2 / DD-M3 / DR-M1 → 4 支全死
OK: 4 支 mutant 全部死亡（每支都有綠 baseline 對照）
```

### 第 6 輪對帳 → v2.11 二審指出的 RECON-007 覆蓋盲點（P2-3）

RECON-007 只認 4 個**已知** emoji → 全新 emoji 的第 5 種狀態值（如 `🟡 暫緩`）**不被擋**
（已實測：加該列後 RECON-007 仍綠）。**此盲點在舊實作同樣存在，非本版引入。**

**本版實作（V03 Reviewer 第 2 輪 P2-1 / P2-2 / P2-3 的建議，非最初提案的「掃 emoji」）**：

| 面向 | v1.1 | v1.2（本版） |
|------|------|------|
| 取值 | regex 只認 4 個已知 emoji | **結構式**：以「表頭第一欄 == 狀態」定位 §4 狀態表，取資料列第一欄 |
| 比對 | `grep -qF` **子字串** | **集合等值**（`✅ 已實作 🟡 暫緩` 不再被誤判為合法）|
| 跨檔 | 無 | **跨檔守護**：規格檔 §4 ↔ `check-doc-drift.py` 的 `VALID_STATUS` 必須一致 |
| 反向自測 | 無 | **RECON-016**（新增）：兩個突變情境都必須讓解析結果改變 |

> **為什麼不用「掃所有 emoji 開頭儲存格」**（Reviewer 第 2 輪 P2-2 的實測反駁）：
> 同一份文件裡「emoji 開頭儲存格」≠「狀態值」—— `reconcile-format.md` §3 欄位定義表就用
> 單獨的 `✅` 當「必填」標記（5 處）、§2 範例表也有。若掃 emoji，往 §4 加一列**說明性** emoji
> （例如 `| 📌 備註 | … |`）就會讓**合法檔案**變紅（假紅）。結構式沒有這個風險。

**新增 mutant DR-M2**：把 §4 某一整格變成 `| ✅ 已實作 🟡 暫緩 | … |`
→ 舊的 `grep -qF` 子字串比對**會漏掉**（count 仍 4 且子字串命中）→ **在 v1.1 下這支 mutant 會活著**；
v1.2 的集合等值會把它判為違規 → **mutant 死**。這支 mutant 正是「子字串比對不可用」的證據。

> **邊界（已揭露，非缺陷）**：D7（`check-doc-drift.py` 的 `VALID_STATUS`）本來就能抓到**對帳表裡**的
> 非法狀態值；RECON-007 守的是**規格檔** `reconcile-format.md` 本身。兩者守不同對象，互補。
> 本版的**跨檔守護**讓這兩份詞彙表副本**不會各說各話**。

### 第 6 輪對帳 → 順手修掉的自證漂移（本專案自己的病）

| # | 漂移 | 處置 |
|---|------|------|
| 1 | `docs/ac/TMO-071.html:22` 寫「本 US 做 **5 類**字面對帳」，同檔 :19 / :24 寫 **8 類** → **同一檔自相矛盾**（正是 D5 只比狀態、不比內文的盲區）| 統一為 8 類 |
| 2 | 交付摘要 §2.3 產物表寫「`tests/doc-drift.bats`（新，**31 條**）」，§3 驗證表寫「**35/35 綠**」→ 同一檔自相矛盾 | 統一為實際數（37 條） |
| 3 | 交付摘要 §5 待辦 #3「**V03 第 2 輪二審 verdict 缺席**」→ changelog v2.11 **同時有第 1 / 第 2 輪兩列**（＋「第 2 輪處置明細」16 項）→ 宣稱不實 | 刪除該待辦（已閉合）|
| 4 | 交付摘要 §3.1 證據欄漏列 DOC-DRIFT-034 / 035（D8 只比 (R-ID, 狀態)、不比證據欄 → 證據欄漂移**結構上不可見**）| 補列；並把此盲區寫入對帳表備註 |
| 5 | `tests/mutant-must-die.bats` docstring「表 39 → **42** 支 → 47 支」→ 實算 39 + 4 = **43** | 改為 43 |

### 二審結論（V03 Reviewer）

| 輪次 | Verdict | 摘要 |
|------|---------|------|
| 第 1 輪（RECON-007 解析器修正）| ⚠️ approve with comments（0 P0 / 0 P1 / 3 P2 / 4 P3）| **P2-1**：探針內嵌根因註解寫錯機制（宣稱「否定字元類吃掉換行」→ 跨行黏 token；grep 逐行比對，**不可能**跨行）→ 必改成實測機制；**P2-2**：v2.11 的「實測 4 支全死」為當時未發生的宣稱 → 必補正（→ 本版 v2.12）；**P2-3**：全新 emoji 第 5 種狀態值不被擋（舊實作同樣漏）→ 建議改為數所有 emoji 開頭儲存格；**P3-1**：註解「與 parse_reconcile_rows 同一語意」不精確（後者 norm_emoji 去 U+FE0F，本探針要求位元組一致）；**P3-2**：`m` shadowing；**P3-3**：缺 python3 時診斷訊息原始（建議 fail-closed 前置檢查）；**P3-4**：缺反向自測 |
| 第 2 輪（RECON-007 v1.2：結構式 + 集合等值 + 跨檔守護）| ⚠️ approve with comments（0 P0 / 1 P1 / 3 P2 / 5 P3）| **P1**：changelog v2.12 把「尚未實作」的 P2-3 寫成已完成（且同段自相矛盾：「本版改為…」vs「已實測仍綠」）→ 合併前必修（→ 本版已依 Reviewer 建議改成**結構式 + 跨檔**並實作，changelog 同步改正）；**P2-1**：沿用 `grep -qF` 子字串比對會留假綠（`✅ 已實作 🟡 暫緩` 仍綠）→ 必須集合等值；**P2-2**：「emoji 開頭」在本文件不是狀態值的可靠 proxy（§3 用單獨 ✅ 當「必填」標記 5 處）→ 掃 emoji 會假紅；**P2-3**：P2-1 註解的根因規則與其對照組互相矛盾；**P3-1**：`parse_reconcile_rows` 的描述與程式碼不符；**P3-2~P3-5**：§4 終止式建議用 `^## \d`（§2 的 fenced code 內有 `## 對帳表`/`## 結論`）、`\p{So}` 在 Python stdlib 不支援、Unicode 版本漂移風險、缺「會咬住」證據（反向自測 + mutant）|

> **P2-1 的修正**：執行者依 Reviewer 要求重做根因實測（3 種 locale × 4 種交替分支數 × ASCII 對照組），
> 確認真實機制＝**BSD grep 2.6 的 ERE 交替分支上限為 2**（與字串長度、locale、跨行皆無關），
> 並已把實測證據寫入探針註解。同時加 `command -v python3` fail-closed 前置檢查（P3-3）、改 `m` → `mm`（P3-2）。
> **P3-1 的修正**：原註解寫「`parse_reconcile_rows` 會 norm_emoji() 去掉 U+FE0F」——**經實讀程式碼確認該說法錯誤**
> （`parse_reconcile_rows` 本身**不**呼叫 norm_emoji；norm_emoji 是在比對端 D7/D8/deliverable_status 才套用；
> 且其前綴集是 `("✅","⚠","❌","🚫")`，其中 `"⚠"` **不含** U+FE0F）→ 該段描述已刪除（v1.2 重寫時一併移除）。
>
> **P3-4 的修正**：新增 **RECON-016**（反向自測，見上）。
>
> **第 2 輪的處置**：①P1 → 依 Reviewer 建議**放棄「掃 emoji」提案**，改為**結構式 + 集合等值 + 跨檔守護**並**實作完成**，
> changelog 該段同步改正（原寫法已刪）；②P2-1 → 集合等值（`sorted(vals) != sorted(CANON)`）；
> ③P2-2 → 結構式（表頭第一欄 ==「狀態」）；④P3-2 → 邊界改用 `^## \d`；
> ⑤P3-4 → **反向自測 RECON-016**（兩個突變情境）+ **新增 mutant DR-M2**。
>
> ⚠️ **執行者在實作 RECON-016 時自己踩到同一個坑**：初版用全檔 `str.replace("| ✅ 已實作 |", …, 1)` 做突變，
> 但「`| ✅ 已實作 |`」在 §2 的 fenced 範例（line 27）**先於** §4 狀態表（line 56）出現 → 突變改到 §2、
> §4 根本不變 → 反向自測**變成空轉（假綠）**。已改為**只在 §4 區段內** mutate、且與**基準值**比較。
> 這印證了「探針本身要先證明自己會咬」——正是 RECON-016 存在的理由。
>
> **另一項本輪才浮現的既存缺陷（非本 US 範圍，已揭露）**：跑**整張** mutant 表時，harness 在
> `subprocess.run(..., text=True)` 嚴格解碼 bats 輸出 → 突變把**多位元組字元截斷**時輸出含不合法 UTF-8
> → `UnicodeDecodeError` → **整個 harness 崩潰**（其餘 mutant 從未被驗）。
> 已改 `errors="replace"`（rc 才是判定依據，輸出只是證據）→ 崩潰變成可診斷的失敗。
> 剩下的失敗真因＝**TMO-072**（bats 1.14 在 UTF-8 locale 下靜默丟棄名稱含 CJK 的 `@test` → **21 個探針檔共 134 支**探針從未執行），
> 屬**已存在的 P1 backlog 項**（`docs/backlog.md` TMO-072，todo），不在本 US 驗收範圍。
> 註：`tests/doc-drift.bats` 與 `tests/restruct-dav-reconciler.bats` 的測試名**全為 ASCII**（0 支中文名）
> → **不影響本輪 7 條需求句的對帳判定**。

---

## v2.11 — 2026-10-26

**本版異動**：§2.3 新增「Gate 4.5 需求對帳」子關卡（Delivery Fidelity 機制：需求錨點 → 獨立 subagent 對帳 → 交付狀態硬門檻）

| 類型 | 項目 | 說明 |
| ---- | -- | ---- |
| **P0** | `skills/dav-reconciler/`（新 skill）| 需求對帳機制：輸入＝需求錨點 + 最終變更清單（**刻意不給實作自述**）；輸出＝需求對帳表（覆蓋全部 R-ID）；狀態 4 種（已實作／部分實作／未實作／已作廢）；硬門檻＝未全數對上不得標「✅ 完成」|
| **P0** | `skills/dav-planner/`（v2.7 + `backlog-rules.md` §4.7）| 產 US 必產需求錨點檔 `docs/req/<US-ID>-requirement.md`（4 段固定結構 + R-ID 連續唯一 + 原話區唯讀）|
| **P0** | `docs/sop/handbook/2.3-execution.md` | 新增「Gate 4.5 需求對帳」段落（位置 / 輸入 / 輸出 / 通過條件 / 不通過後果 / mandatory_phrase / 定位說明 / trust 例外）|
| **P1** | `skills/dav-submitter/`（v2.5 + `template.md` §3.1）| 交付模板加「需求對帳」段；Step 4.5 帶入對帳結論；硬門檻（對帳未過 → 不得標「✅ 完成」）|
| **P1** | `skills/dav-reflection/`（v2.3）| 規則表加「需求對帳先於反省」（反省不得建立在未經驗證的「已完成」前提上）|
| **P1** | `docs/sop/handbook/2.4-reflection.md` | 前置條件 blockquote（先對帳再反省）|
| **P1** | `AGENTS.md` §2.3 | 速查表加 Gate 4.5 一列（標明「§2.3 子關卡，非 gates.json 項」）；標題改「4 大 Gate + Gate 4.5 子關卡」；TD-016 補 Gate 4.5 的 mandatory_phrase 位置；§2 版本 v2.1 → v2.2 + 變動歷史加 v2.2 列 |
| **P1** | `skills/dav-reconciler/scripts/check-doc-drift.py` + `scripts/ci/check-doc-drift.sh`（wrapper）+ `docs/ci/drift-whitelist.txt` + `.github/workflows/ci.yml` | 文件漂移檢查 8 類（D1..D8）：AC 狀態 vs backlog / AC 編號連續唯一 / PRD 追溯矩陣幽靈 ID / 交付摘要引用不存在的檔案 / md 與 html 狀態一致 / AC ↔ 需求錨點 / 對帳表 R-ID 覆蓋 / 交付摘要對帳段與狀態一致；白名單 fail-closed（缺理由 → rc=2、全類豁免 → rc=2）；**實作放在 skill 內**（隨安裝到位，目標專案可用）|
| **P2** | `docs/ac/US-M62` / `US-M63` / `US-M71` / `US-M81`（md + html）| 修正被新探針抓出的**真實漂移**：狀態 PENDING → done、backlog 引用舊格式 → 實際 ID（TMO-019 / TMO-020）|
| **P2** | `docs/prd/05-delivery-fidelity.md` + `docs/system-design.md` §2.4 + `docs/DESIGN.md` §8 | 新模組 M5 — Delivery Fidelity 的 PRD / 架構 / 介面契約（含 3 條 ADR）|
| **P2** | `tests/doc-drift.bats`（37 條）+ `tests/restruct-dav-reconciler.bats`（16 條）| 新探針（含 rc 契約、白名單 fail-closed、CI 接線守護、from-date 雙向驗證、跨平台改檔輔助）|
| **P2** | `scripts/ci/mutants.tsv` | 登錄 **4 支** mutant（DD-M1 / DD-M2 / DD-M3 / DR-M1）證明新護欄真的會咬（**當時並未真的觀察到**——RECON-007 v1.0 解析器在 BSD grep 上本身壞掉、baseline 紅 → `mutant-must-die.py` 整表中止 → 四支守護實際上是失效狀態；**首次真正實測 4 支全死在 v2.12（見 v2.12 實測證據）**）|

**二審結論（V03 Reviewer）**：

| 輪次 | 結論 | 處置 |
|------|------|------|
| 第 1 輪 | ❌ request-changes（1 P0 / 4 P1 / 10 P2 / 5 P3），現狀不可合併 | **P0**：新探針用 macOS-only 的 `sed -i ''` → Ubuntu CI 腿會紅（4 條探針失效）；**P1**：CI 接線無探針守護、全域 changelog / SOP 版本未登錄且冒用已發布的 v2.1、CHANGELOG 預先宣告「二審通過」、新機制未自我套用（無對帳表 / deliverable）；**P2**：AC 與實作不同字、5 類 vs 6 類、狀態詞彙表與 backlog 定義不符、ac README 未補 TMO 形式、HTML 連結文字矛盾、作廢 R-ID 與 3 種狀態死結、D4 只固化放寬未證明會檢查、未登錄 mutants.tsv、DESIGN 宣稱不存在的檢查、PRD 自身狀態未更新；**P3**：AGENTS 標題與 mandatory_phrase 敘述、❌ 未完成不可達、範例過時、審查產物落在 docs/、DOC-DRIFT-007 無空集合守護 → **全修**（處置見下表）|
| 第 2 輪 | ❌ request-changes（1 P0 / 3 P1 / 6 P2 / 6 P3），現狀不可合併 | **P0**：`skills/dav-reconciler/SKILL.md` 的「專案端」標記讓既有探針 `restruct-zero-cross-read.bats` 轉紅（Gate 3 失敗）→ 已改「目標專案」；**P1**：DOC-DRIFT-029 未孤立（宣稱已修但 fixture 未改）、權威對帳表與交付摘要對殘餘缺口的描述互相矛盾、第 2 輪 verdict 缺席（迴圈引用）；**P2**：backlog 宣稱不存在的檢查、html 重複純文字 ID、DOC-DRIFT-022 的 CI 假綠守護視窗有洞、dav-submitter 變動歷史 4 條超上限、PRD / 交付摘要數字過時；**P3**：emoji 未正規化回傳值、mutant docstring 算式、狀態詞彙別名未登錄、gates.json 反向鎖缺檔假綠、交付摘要用不存在的簡寫路徑、DESIGN 訊息樣式與實輸出不符 → **全修**（處置見下表）|

**本輪處置明細**（第 1 輪 20 項全部處置）：

| # | 級別 | 指摘 | 處置 |
|---|------|------|------|
| 1 | P0 | `sed -i ''` 在 Ubuntu 腿失效 | 改用跨平台 python3 改檔輔助 `_replace_in_file`（4 處全改）|
| 2 | P1 | CI 接線無守護 | 新增 DOC-DRIFT-022（鎖 CI 步驟存在 + 禁 `continue-on-error` / `\|\| true`）|
| 3 | P1 | 全域 changelog / SOP 版本未登錄、冒用 v2.1 | SOP v2.1 → **v2.2**；本檔加 v2.11 條目 + 二審結論節；`2.3` / `2.4` 標註改 v2.2；`tests/restruct-agents-md.bats` 同步（並加 v2.11 與 Gate 4.5 兩條新探針）|
| 4 | P1 | CHANGELOG 預先宣告「二審通過」 | 改寫為真實 verdict（第 1 輪 request-changes → 已修 → 第 2 輪見本節）|
| 5 | P1 | 新機制未自我套用 | 本次即以新機制完成自己：產 3 份對帳表 + 本次 deliverable（含 §3.1 需求對帳段）|
| 6 | P2 | AC 與實作不同字（②同字比對）| 統一改為「AC 編號連續且唯一」|
| 7 | P2 | 5 類 vs 6 類 | 全域統一（PRD / AC / backlog / system-design / DESIGN / CI）；**第 2 輪後再統一為 8 類（D1..D8）**（對帳第 2 輪要求：新增 D7 / D8 也要同步）|
| 8 | P2 | 狀態詞彙表不符 | `STATUS_VALUE` 擴充為 backlog.md 宣告的單一來源詞彙（todo/doing/done/blocked/待決…）；本批新列改用 `doing (2026-10-26)` |
| 9 | P2 | ac README 未補 TMO 形式 | 已補（`US-<編號>` 與 `TMO-<nnn>` 兩種形式並存，探針以檔名 stem 為 key）|
| 10 | P2 | HTML 連結文字矛盾 | US-M62 / US-M63 的 html 連結文字改為對應 ID |
| 11 | P2 | 作廢 R-ID 與 3 種狀態死結 | 對帳狀態擴為 **4 種**（加 🚫 已作廢；列出但不列入交付狀態判定）；planner / reconciler / 探針三處同步 |
| 12 | P2 | D4 只固化放寬 | 新增 DOC-DRIFT-023（`--from-date` 拉早 → 範圍內交付**會**被檢查）；CI 步驟顯式帶 `--from-date` |
| 13 | P2 | 未登錄 mutants.tsv | 登錄 DD-M1 / DR-M1（實測：baseline 綠 → 突變紅 → 2 支全死）|
| 14 | P2 | DESIGN 宣稱不存在的檢查 | 刪除誤導句，改為指 deliverable 模板 §3.1 |
| 15 | P2 | PRD 自身狀態未更新 | 追溯矩陣改「✅ 已實作」+ DoD 逐項勾選 |
| 16 | P3 | AGENTS 標題 / mandatory_phrase 敘述 | 標題改「4 大 Gate + Gate 4.5 子關卡」；TD-016 補例外說明 |
| 17 | P3 | ❌ 未完成不可達 | 門檻表補「全數 ❌ → 可標 ❌ 未完成」|
| 18 | P3 | 範例過時 | `examples.md` 範例 B 改為中性示範缺口 |
| 19 | P3 | 審查產物落在 docs/ | 移出 repo（改放暫存目錄）|
| 20 | P3 | DOC-DRIFT-007 無空集合守護 | 已補 `count > 0` 守護 |

**第 2 輪處置明細**（第 2 輪 16 項全部處置）：

| # | 級別 | 指摘 | 處置 |
|---|------|------|------|
| 21 | P0 | 新 skill 讓 `restruct-zero-cross-read.bats` 轉紅 | `skills/dav-reconciler/SKILL.md` 4 處「專案端」→「目標專案」；**同時發現該探針 3 支測試名含中文被 bats 1.14 靜默跳過** → 改 ASCII 名讓它們真的跑（跑出即抓到上項違規）|
| 22 | P1 | DOC-DRIFT-029 未孤立 | fixture 改為「權威表與內嵌表都 ⚠️ + 舊欄位名」→ 唯一紅因 = gaps 分支；加負向斷言 |
| 23 | P1 | 對帳表 ↔ 交付摘要敘述矛盾 | 三份對帳表依最新一輪對帳判定重寫；交付摘要 §5 對齊 |
| 24 | P1 | 第 2 輪 verdict 缺席 | 本節補第 2 輪列（並修正第 1 輪處置 #4 的懸空引用）|
| 25 | P2 | backlog 宣稱不存在的檢查 | 主表列舉補 ⑦⑧；詳細 AC-1 ② 改「AC 編號連續且唯一」|
| 26 | P2 | html 重複純文字 ID | `US-M62.html` / `US-M63.html` 刪掉 anchor 前重複的純文字 ID |
| 27 | P2 | DOC-DRIFT-022 守護視窗有洞 | 改「從 `- name:` 起算 + 剝註解 + 轉小寫比對」，並加 DOC-DRIFT-034 反向自測 |
| 28 | P2 | dav-submitter 變動歷史超 3 條 | 刪 v2.1 列（v2.0 起完整條目在 CHANGELOG）|
| 29 | P2 | PRD / 交付摘要數字過時 | PRD 行數預檢改實際值（120/121/140）；交付摘要 §3 改 14 項檢查；簡寫路徑改實際檔名 |
| 30 | P3 | emoji 未正規化回傳值 | `deliverable_status()` 回傳值套 `norm_emoji()` |
| 31 | P3 | mutant docstring 算式 | 「+5」→「+4」 |
| 32 | P3 | 狀態詞彙別名未登錄 | backlog 狀態定義段補列相容舊值（`pending` / `in_progress` / `deferred` / `cancelled` / `進行中` / `待辦`）|
| 33 | P3 | gates.json 反向鎖缺檔假綠 | `restruct-agents-md.bats` 加 `[ -f gates.json ]` 前置檢查 |
| 34 | P3 | 交付摘要用不存在的簡寫路徑 | 改實際檔名；D4 的 `~` 區間簡寫改由 `expand_paths()` 展開（不靠檔名碰巧不含 `~`）|
| 35 | P3 | DESIGN 訊息樣式與實輸出不符 | §8.4 改成貼腳本實際輸出樣式 |
| 36 | P2 | D4 路徑簡寫誤判（對帳第 4 輪）| `expand_paths()`：`X.md/.html` → `X.html`；`X-069~071.md` → 編號區間展開；新增 DOC-DRIFT-032 / 033 |

**Gate 4.5 需求對帳的第一次實戰**（本機制的首度自我套用，5 輪獨立對帳）：

| 輪次 | 對帳結果 | 處置 |
|------|----------|------|
| 第 1 輪 | 5 ✅ / 2 ⚠ | 指出 7 條缺口（無「對帳表 R-ID 覆蓋」探針、無「交付狀態 ↔ 對帳結果」機械檢查、未自我套用、install 部署面、白名單 2 項、changelog 宣稱與實況不符、PRD 未更新）→ 全修（新增 D7 / D8）|
| 第 2 輪 | 5 ✅ / 2 ⚠ | 抓出 **N1**：D8 讀不到官方模板的 `**交付狀態**` 欄位 → 硬門檻在真實路徑上是假綠；另抓 N2（兩份官方交付模板互斥）→ 已修（欄位名統一 + D8 改讀權威表）|
| 第 3 輪 | 5 ✅ / 2 ⚠ | 抓出**位元組級落差**（`⚠️` 的 U+FE0F 差異 → 照 spec 寫的對帳表會被判「狀態值不合法」）、D8 以 R-ID 為全域鍵（多 US 交付摘要誤紅）、2 支探針未孤立 → 全修（`norm_emoji()` + 多重集比對 + 孤立性斷言）|
| 第 4 輪 | 5 ✅ / 2 ⚠ | 抓出「宣稱已修但 fixture 未改」（DOC-DRIFT-029 仍不孤立）、D4 路徑簡寫仍誤判、交付摘要用了不存在的簡寫路徑 → 全修（`expand_paths()` + 探針 032/033/035）|
| 第 5 輪（終審）| 5 ✅ / 2 ⚠ | 029/030 已孤立、R-ID 作用域已修、emoji 已正規化、敘述數字已收斂；殘餘＝D4 數字區間分支的探針本輪才補（DOC-DRIFT-035）待複核、端到端需可執行證據 → **交付狀態依硬門檻 = ⚠️ 部分完成**，backlog 三列維持 `doing` |

> **這段歷史本身就是機制的價值證據**：本次交付被自己的機制擋在「⚠️ 部分完成」，而不是被寫成「✅ 完成」——
> 這正是 `dav-reconciler` 規則要的效果（自己宣稱已修的 4 處被獨立對帳者逐條抓出）。

**探針「會咬」實測**（突變 → 必須紅）：

> ⚠️ **v2.12 更正**：本表 4 列的「✅ 紅（baseline 綠 → 突變 rc=1）」是**當時並未真的觀察到**的宣稱——
> RECON-007 v1.0 的解析器在 macOS/BSD grep 上本身是壞的（baseline 紅）→ `mutant-must-die.py` 的
> baseline 迴圈 `die()` → **整個表中止** → 下表 4 支（含 DD-M1..M3）實際上**一次都沒被跑到**。
> 修好 RECON-007 後才**第一次真的跑完**（4 baseline 全綠 + 4 支全死）→ 見 **v2.12 實測證據**。

| 突變 | 預期 | 實測 |
|------|------|------|
| DD-M1：`check-doc-drift.py` 的 D6 報錯改成 `pass` | DOC-DRIFT-017 紅 | ✅ 紅（baseline 綠 → 突變 rc=1）— **首次真實觀察於 v2.12** |
| DD-M2：D7 覆蓋率檢查改成 `if False:` | DOC-DRIFT-024 紅 | ✅ 紅（baseline 綠 → 突變 rc=1）— **首次真實觀察於 v2.12** |
| DD-M3：D8 狀態矛盾檢查改成 `if False:` | DOC-DRIFT-028 紅 | ✅ 紅（baseline 綠 → 突變 rc=1）— **首次真實觀察於 v2.12** |
| DR-M1：刪掉 `reconcile-format.md` 的「🚫 已作廢」狀態列 | RECON-007 紅 | ✅ 紅（baseline 綠 → 突變 rc=1）— **首次真實觀察於 v2.12** |

**決策紀錄**：

- **為什麼 Gate 4.5 不進 `gates.json`**：該檔的 schema 限定 gate `id` 符合 `^gate-[0-9]+$`（整數），
  而 Gate 4.5 是排在 Gate 4 之後、§2.4 之前的**子關卡**，不是第五道大 Gate。gates.json v1.1.0 曾移除
  Gate 5（RSI 機制歸檔）——那是「整道 Gate 從流程上消失」，與本案性質不同。
  **代價**：gates.json 對「子關卡」不再 SSOT（四道大 Gate 仍是）→ 已在 ADR-D1 與 handbook 明文化。
- **為什麼對帳狀態要有第 4 種「已作廢」**：規劃階段允許「需求被砍掉」（R-ID 不可刪），
  若對帳只有 3 種狀態，被砍的需求會永遠卡住交付 → 死結。加「已作廢」後：仍須列出（不可省略），
  但不列入交付狀態判定。
- **為什麼 D4 只檢 from-date 之後的交付**：歷史交付宣稱的檔案多已刪 / 改名，回溯檢查必假紅；
  「當下寫的宣稱必須成立」是合理原則。**這是門檻放寬**（V03.6 定義 ①②）→ 已加反向探針證明
  範圍內的交付會被檢查，且 CI 步驟顯式帶 `--from-date` 讓放寬在 log 可見；延長 from-date 視為放寬，需再走 V03。

---

## v2.10 — 2026-10-23

**本版異動**：§2.0 登錄 trust mode 為第三條 SOP 路徑（執行段），並同步 §2.6 一般任務章節的例外條款

| 類型 | 項目 | 說明 |
| ---- | -- | ---- |
| **P0** | `AGENTS.md` §2.0 任務類型表 | 新增「信任模式（trust mode）」列 → 執行段（§2.3 → §2.5）；規劃 / 設計屬啟動前置條件 |
| **P0** | `AGENTS.md` §2.0 判斷責任歸屬 | 新增 trust 條：走執行段；§2.1 / §2.2 屬啟動前置條件（需用戶互動、trust 內不跑）；啟動判準見 dav-trust preflight 子檔 |
| **P1** | `docs/sop/handbook/2.6-general-task.md` | 檔頭 + 升級觸發器表下方新增「trust mode 進行中不適用本節 / 上表升級觸發器不套用」例外；升級判斷改由 trust-log 與 need-you-help 承載 |
| **P1** | `docs/sop/handbook/2.1-planning.md` + `2.2-design.md` | 兩章節各加例外 blockquote「本節僅適用於非 trust 的開發編程任務路徑；規劃 / 設計是 trust 啟動前置條件」 |
| **P1** | `docs/sop/handbook/2.3-execution.md` | 三種策略表後加例外 blockquote：`ask_user` 策略 / fallback 在 trust 進行中不適用（改記 trust-log + need-you-help）；`gates.json` schema 不變 |
| **P1** | `docs/sop/handbook/2.4-reflection.md` + `skills/dav-reflection/SKILL.md` | 加 trust 例外：「Sprint / Module 必須有用戶參與確認」在 trust 進行中不適用（Action Items 一律寫 backlog；待決事項寫 need-you-help）|
| **P1** | `tests/restruct-agents-md.bats` | 新增 8 條探針（§2.0 trust 列含負向斷言不得含 §2.1 / §2.2、判斷責任歸屬區塊前置條件、§2.6 例外完整片語、一般任務列仍在、§2.1 / §2.2 trust 提示、§2.3 ask_user 例外、§2.4 用戶參與例外、changelog v2.10 + 二審結論節）+ 改寫 1 條（守 SOP 現行版本 v2.1）|
| **P2** | `AGENTS.md` §2 標題 + 變動歷史 | §2 SOP 流程 v2.0 → v2.1、變動歷史加 v2.1 列（欄位名改「SOP 版本」、合併 v2.0 重號兩列）|

**二審結論（V03 Reviewer）**：

| 輪次 | 結論 | 處置 |
|------|------|------|
| 第 1 輪 | ⚠️ approve with comments（3 P1 / 9 P2），現狀不可合併 | P1：§2.0「不開例外」矛盾句未修（trust 與 dev task 無優先序）、本檔二審結論節懸空引用、TMO-067 仍 `todo`；P2：一般任務條款未加 trust 限定、§2.6 違規處理未排除、範例對照未註 trust、pointer 指向偏、README 未列第三路徑、§2.1 / §2.2 章節無 trust 提示、版本序號混淆、探針 ② 弱 / ③ 鬆、「本次未動」清單不完整 → **全修** |
| 第 2 輪 | ⚠️ approve with comments（1 P1 / 8 P2），現狀不可合併 | **P1**：trust 真正會跑的 §2.3（`ask_user` 策略）與 §2.4（用戶參與確認 = Reflection Gate 通過條件）無 trust 例外 → 死鎖；P2：探針數字錯、changelog 敘述低估、skill 三處仍寫「待補」、缺 changelog 守護探針、條列順序與優先序不一致、探針會咬證據未示範、deliverable v2.0 易誤讀 → **全修** |
| 第 3 輪 | ⚠️ approve with comments（1 P1 / 9 P2），現狀不可合併 | **P1**：§2.4 的「operational 條款」（通過條件 5、「假裝通過」清單、Sprint/Module 觸發時機與 Step 5 動作/產出/證據）未就地例外 → 依字面仍會被判「假裝通過」→ 死鎖；P2：AGENTS.md §2.3 無 trust 例外摘要、§2.7 升級條款仍指向 §2.1、dav-reflection 未登錄變動歷史 + 無守護探針、§2.0 表列順序、§2.6 範例第二列、§2.0 探針守護缺口、缺第 3 輪登錄、缺 deliverable → **全修**；依第 3 輪 reviewer 指示「修完可逕行合併、不需再排一輪二審（僅需補貼修後綠燈輸出）」結案 |

**探針「會咬」實測**（突變 → 必須紅，做完還原）：

| 突變 | 預期 | 實測 |
|------|------|------|
| 刪掉 §2.0 表「一般任務」列 | 探針「general-task row still present」紅 | ✅ 紅 |
| trust 列的 SOP 欄改成含 §2.1 | 探針「trust mode registered as third path」紅 | ✅ 紅 |
| §2.1 只出現在「舉例」欄 | 限欄後不誤紅 | ✅ 全綠 |

**決策紀錄**：

- **為什麼要改**：dav-trust v2.3 把「規劃 / 設計」從 trust 的執行階段改成**啟動前置條件**（兩者強制用戶互動、
  與 trust「中途不問用戶」互斥）；但 AGENTS.md §2.0 仍寫「開發編程任務 → 一律走完整 SOP，不開例外」
  → agent 先讀 AGENTS.md 時會在 trust 內跑 §2.1 / §2.2，回到「啟動即注定卡死」（TMO-067）
- **為什麼不寫成「例外」而是「第三條路徑」**：trust 不是「一般任務的例外」，它有**自己的入口條件**
  （大目標 + deadline + 既有 backlog / 設計），與前兩類任務的分類維度不同 → 開一列更誠實
- **§2.6 為何要加例外**：§2.6 的「溝通 & 思考（問用戶）」與「自動升級觸發器（停下等用戶確認）」
  與 trust 直接互斥 → 不加例外，agent 在一般任務分支誤判時會在 trust 內停下問用戶
- **本次未動**：`dav-planner` / `dav-designer`（trust 內本來就不跑它們）、`gates.json`（4 Gate 定義與 schema 不變；
  trust 例外寫在 §2.3 handbook，不改 schema）、`docs/sop/handbook/2.5-submission.md`（無強制用戶確認步驟）、
  `docs/system-design.md`（歷史設計文件，非 SOP 規範）
- **下次升版待辦（避免漏改）**：SOP 版本字串 `v2.1` 目前硬編於 `AGENTS.md`（§2 標題 + 變動歷史）與
  `tests/restruct-agents-md.bats`（守版探針）共 3 處 → 下次升版需同步，並考慮改為動態取版號

---

## v2.9 — 2026-09-26

**本版異動**：3 個 skill 補充 Module 細節 + 建 Module 範例專案（四 commit 進連環重構，補完 v2.8 的「Module 設計 → 交付」閉環）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | `skills/dav-submitter/SKILL.md` v2.1 + `template.md` v2.1 | +「為什麼必含」+ §1.2「為什麼做這個改動」+ §2.4「改動背後的理由」+ §6.1「為什麼這個優先」 |
| **P0** | `skills/dav-submitter/SKILL.md` v2.2 + `module-delivery.md` v2.2 | +Module 級交付語法：觸發時機 + 命名規則 + §9 Module 級總結 |
| **P0** | `skills/dav-planner/backlog-rules.md` v2.3 | +§4.3.1 Module 欄位範本 + §4.3.2 Module 級 sprint 規劃 |
| **P0** | `examples/module-lifecycle/` 新建 | Module 完整生命週期範例專案（8 檔 / 879 行，涵蓋 5 階段）|
| **P1** | 5 個 skill 主檔變動歷史加 v2.9 條目 | dav-designer / dav-planner / dev-checker-loop / regression-guard / dav-submitter |

**合計**：4 個 commit、5 個 skill 檔改動、+1 子檔（`module-delivery.md`）、+1 範例專案（8 檔）、合計約 +1400 行。

**決策紀錄（重要）**：

- **v2.8 → v2.9 的關係**：v2.8 鋪 Module 基礎（design / dev / regression 三個 skill），v2.9 補完「Module 從 backlog 到交付」的閉環（planner +
  submitter + 範例）
- **為什麼要建範例**：5 個 skill 連環改的價值只在完整流程中顯現；範例讓抽象 skill 變具體可讀；可作未來 skill 修改的「驗證素材」
- **範例放 monorepo 主干**（用戶選推薦）：隨主 repo 演進、不會過期；可隨時 checkout / grep / diff
- **「為什麼必含」的價值**：v2.8 前交付物只講「做了什麼」、驗收只看結果；v2.9 起必含「為什麼」獨立段、用戶可驗收決策是否對（不只是結果對不對）
- **5 skill 連環改 = 閉環**：

  ```
  dav-designer v2.6 → 定義 Module 切割
       ↓
  dav-planner v2.3 → backlog 表格加 Module 欄位
       ↓
  dev-checker-loop v2.2 → 派工綁 Module
       ↓
  regression-guard v2.10 → 探針含 Module prefix
       ↓
  dav-submitter v2.2 → Module 級交付語法
       ↓
  範例 (v2.9) → 完整 5 階段連環展示
  ```

**範圍邊界**：
- ✅ 在 scope：`skills/dav-submitter` + `skills/dav-planner` + `examples/module-lifecycle/`
- ❌ 不在 scope：`skills/orca-cli` + `skills/orchestration`（第三方 skill，仍未動）
- ❌ 不在 scope：dav-reflection 雖屬 SOP 但本次沒改（dav-submitter 已含反思末段）

**前置**：本變更由用戶明確批准 + Agent 自跑校驗（4 commit 分批 + 行數 / 跨 skill 引用鏈），符合 V03 SOP 修改提案規範。

---

## v2.8 — 2026-09-26

**本版異動**：3 個 skill 拆檔 + Module 感知邏輯實作（三 commit 進連環重構）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | `skills/dav-skill-creater/SKILL.md` 拆檔（v2.5） | 主檔 223 → 147 行；「SKILL.md 編寫準則」+「變動歷史外移規範」→ `editor-guide.md`（92 行）；主檔只留 3 條最高頻規則 |
| **P0** | `skills/regression-guard/SKILL.md` 拆檔（v2.9） | 主檔 714 → 120 行；Jev Oracle 506 行 → `jev-oracle.md`；runner / API / output / naming 各拆一檔 |
| **P0** | `skills/dev-checker-loop/SKILL.md` + `skills/regression-guard/SKILL.md` Module 感知邏輯（v2.2 + v2.10） | dev-checker-loop 加 Module 級派工 / Module 邊界；regression-guard 探針必含 Module prefix + `REGRESSION_MODULE` 環境變量 |
| **P1** | `skills/dev-checker-loop/SKILL.md` 加「Module 感知邏輯」章節 + `module-rules.md` 子檔 | Module 定義 / 取得流程 / Fallback / 4 個互動點 |
| **P1** | `skills/regression-guard/api-contract.md` + `probe-naming.md` 加 Module 規則 | `REGRESSION_MODULE` 環境變量說明；探針命名加 Module prefix；integration test 用 `INT-` prefix |
| **P2** | 三 commit 分 3 次推送（用戶決策） | `dav-skill-creater` 拆檔 commit + `regression-guard` 拆檔 commit + Module 感知邏輯 commit |

**合計**：3 個 commit、7 個 skill 檔改動、+3 子檔（`editor-guide.md` / 5 個 `regression-guard/*` / `module-rules.md`）、合計約 +1300 行 /
−700 行。

**決策紀錄（重要）**：
- **3 commit 還是 1 commit**（用戶決策起點）：選 3 commit — 可隨時 checkout 某個 task，不會混在一起。中間不需 checkpoint = 不需要 1 commit
- **Module 單元怎麼訂**（用戶決策起點）：Module = 一組檔案 — 適合中大型項目，dav-designer 的 system-design.md 是 Module 定義來源
- **Module 改動深度**（用戶決策起點）：全面、含兩個 skill — dev-checker-loop 派工 + regression-guard 探針都要綁 Module，缺一不可
- **拆檔哲學一脈相承**：v2.5（dav-planner）流程 vs 內容 / v2.6（dav-designer）流程 vs 品質 / v2.7（變動歷史外移）/ v2.8（拆檔 + Module 感知）—
  都是「以子檔職責正交為拆檔粒度」
- **v2.6 dav-designer 鋪路 + v2.8 實現**：v2.6 dav-designer 加 Module 定義時說「為下游鋪路」；v2.8 實作時才看到「鋪路」是 dev-checker-loop +
  regression-guard 兩個 skill
- **連環改不是失誤是必要**：Module 感知需 3 個 skill 同步改，只改一個 = 設計與執行不一致。傳統「一個 task 一個 commit」會讓人誤以為這是 3 個獨立任務；本 SOP 用「拆 commit
  但仍記在同一版本（v2.8）」表達「是多個連環動作」

**範圍邊界**：
- ✅ 在 scope：`skills/dav-skill-creater` + `skills/regression-guard` + `skills/dev-checker-loop` 三 skill
- ❌ 不在 scope：`skills/orca-cli` + `skills/orchestration`（第三方 skill，仍未動）
- ❌ 不在 scope：dev-checker-loop `workflow.md` 子檔（是另一次重構的產物、本次不重構）
- ❌ 不在 scope：regression-guard `examples.md` + `testing-methods.md` + `PoC/` 子檔（子檔、職責正交、本次不動）

**前置**：本變更由用戶明確批准 + Agent 自跑校驗（三 commit 分批 + 行數 / 結構 / 跨 skill 引用鏈），符合 V03 SOP 修改提案規範。

---

## v2.7 — 2026-09-26

**本版異動**：所有 skill 的「變動歷史外移」重構（跨 10 skill、dav-skill-creater 新增規範）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | 10 個 skill 新增 `CHANGELOG.md` | dav-planner / dav-designer / dav-wiki / dav-skill-creater / dav-submitter / dav-reflection / dev-checker-loop / dav-trust / tdd-test-writer / regression-guard 各自創建 CHANGELOG.md，搬遷完整變動歷史 |
| **P0** | 10 個 skill 主檔變動歷史章節瘦身 | 主檔變動歷史表格 ≤ 3 條（最新版本）+ Markdown 連結引用 `CHANGELOG.md` |
| **P0** | `skills/dav-skill-creater/SKILL.md` 新增「變動歷史外移規範」章節 | 規則：變動歷史 ≤ 3 條留主檔；> 3 條一律外移至 `<skill>/CHANGELOG.md`。附「為什麼外移」、「為什麼是 3 條不是 5 條」、「CHANGELOG.md 格式規範」 |
| **P1** | `skills/dav-skill-creater/SKILL.md` 規則表新增 1 行 | 「變動歷史外移」列入正式規則（v2.4 新增） |

**合計**：新建 10 個 CHANGELOG.md（總 ~135 行）、主檔瘦身 10 個、dav-skill-creater 加 ~30 行規範。

**決策紀錄（重要）**：
- **變動歷史對 LLM 的 5 大好處**（用戶決策起點）：錨定當前版本、理解「為什麼」而不只是「是什麼」、降低幻覺風險、支援增量更新、保留撤銷的決策避免重蹈覆辙
- **為什麼是 3 條不是 5 條**：LLM 注意力門檻約 3-5 個項目，3 條足以表達「最近 3 次演進方向」又不分心；完整歷史隨時可從 CHANGELOG.md 取得
- **為什麼 dav-skill-creater 自己也要拆**：dav-skill-creater 是 skill 編寫規範的權威，自己不遵守新規則 = 失去權威性（「吃自己狗糧」原則）
- **未動 orca-cli / orchestration**：這兩個 skill 不在 dav-* 規範下、是第三方 skill，未走 v2.3 修改流程、不在本任務 scope
- **dav-skill-creater 主檔超 150 行**：v2.4 加了「變動歷史外移規範」後 223 行，原已超標（變動歷史外移是新規範加加必要）。下次重構時可拆出 `editor-guide.md`

**範圍邊界**：
- ✅ 在 scope：`skills/dav-*` + `skills/dev-*` + `skills/regression-guard` + `skills/tdd-*`（10 個）
- ❌ 不在 scope：`skills/orca-cli` + `skills/orchestration`（第三方 skill，不走 dav-skill-creater 規範）
- ❌ 不在 scope：拆 dav-skill-creater 主檔為子檔（需要時可後續重構）

**前置**：本變更由用戶明確批准 + Agent 自跑校驗（腳本批量處理 + 手動校驗 3 個邊角案例 + 主檔表格 ≤ 3 條驗證），符合 V03 SOP 修改提案規範。

---

## v2.6 — 2026-09-26

**本版異動**：`skills/dav-designer/` 重構（Module 定義 + 拆檔、雙提交 v2.3 + v2.4）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | `~/.pi/agent/skills/dav-designer/SKILL.md` Step 1 加 Module 目的與切割原則 | Module 定義為「可獨立開發 / 增減 / 測試」的功能單位；附 5 條切割原則（功能內聚 / 低耦合 / 可獨立交付 / 可獨立測試 / 粒度適中）與反例 |
| **P0** | `~/.pi/agent/skills/dav-designer/SKILL.md` Step 3 加 Module 邊界即測試邊界 | 明示 system-design.md 的 Module 邊界就是未來 dev-checker-loop / regression-guard 的執行邊界；探針不跨 Module 檢查 |
| **P1** | `~/.pi/agent/skills/dav-designer/SKILL.md` 拆檔瘦身 | 主檔 167 → 110 行；Step 1-5 全剖細節拆至 `workflow.md`（106 行）；既有 `prototype-quality.md`（139 行）不動 |
| **P2** | `~/.pi/agent/skills/dav-designer/SKILL.md` 流程章節改寫為「簡介 + 參考」 | 每個 Step 只留「產出 + 參考：workflow.md」，避免重複；變動歷史新增 v2.4 |

**合計**：主檔 −57 行、子檔 +1 個（workflow.md）、Module 定義 +1 章節。

**決策紀錄（重要）**：
- **Module 設計為下游 Skill 鋪路**：dav-designer 的 Module 定義不是為了設計本身，是為了讓未來重構 dev-checker-loop / regression-guard
  時有明確的「執行邊界」。本次不動這兩個 skill（保留彈性），但 Step 3 明文寫下「Module 邊界即測試邊界」，下次重構有據可依
- **拆檔哲學差异化 dav-planner**：dav-planner v2.2 拆「流程層 vs 內容層」（reference.md + backlog-rules.md）；dav-designer v2.4 拆「流程層 vs
  品質層」（workflow.md + prototype-quality.md）。拆法不是固定模板，而是看「子檔職責是否正交」
- **dev-checker-loop / regression-guard 本次不動**：依用戶明確決策「只動 dav-designer」。下次重構這兩個 skill 時可實作「按 Module 派工 / 校驗 / 探針」邏輯
- **跨 SOP 一致性**：dav-submitter 已使用「Module 級交付」術語（與本次定義一致）；AGENTS.md / 其他下游 skill 不受本次影響

**範圍邊界**：
- ✅ 在 scope：`skills/dav-designer/` 整個 skill（主檔 + 新子檔 workflow.md）
- ❌ 不在 scope：`skills/dev-checker-loop/` + `skills/regression-guard/`（用戶決策延後重構，僅在 dav-designer 內部為未來鋪路）
- ❌ 不在 scope：`skills/dav-designer/prototype-quality.md`（既有子檔，職責與本次 workflow.md 正交，不需動）

**前置**：本變更由用戶明確批准 + Agent 自跑校驗（行數 / 結構 / 三檔職責不重疊 / prototype-quality.md 引用一致），符合 V03 SOP 修改提案規範（diff + verdict
兩者並呈、用戶批准後生效）。

---

## v2.5 — 2026-09-26

**本版異動**：`skills/dav-planner/` 重構（減法 + 職責收斂，雙提交 v2.1 + v2.2）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | `~/.pi/agent/skills/dav-planner/SKILL.md` 刪除 §2.7 整套（用戶背景收集） | 拿掉「對話用戶角色詢問」（v1.9 功能）；dav-planner 定位收斂為「釐清任務的背景 / 最終目的 / 驗收標準」 |
| **P0** | `~/.pi/agent/skills/dav-planner/SKILL.md` 流程 Step 1 移除 | 原「收集用戶背景」整步刪除，後續 4 步編號遞減不破壞引用 |
| **P0** | `~/.pi/agent/skills/dav-planner/SKILL.md` frontmatter + 流程 quote block | description 改寫為「釐清背景/目的/標準 → 拆成 Backlog」+「不問對話用戶個人角色」 |
| **P1** | `~/.pi/agent/skills/dav-planner/SKILL.md` 拆檔瘦身 | 主檔 212 → 102 行；§2/§3/§5 拆至 `reference.md`（85 行），§4 拆至 `backlog-rules.md`（46 行） |
| **P2** | `~/.pi/agent/skills/dav-planner/SKILL.md` 變動歷史 v1.9 加註 | 加「（已廢棄）」與「（已被 v2.1 撤銷）」，避免與 SOP 全域 §2.7（違規回報）同名混淆 |

**合計**：主檔 −110 行、子檔 +2 個、§2.7 章節 −1。

**決策紀錄（重要）**：
- **職責收斂**：dav-planner 從「對齊用戶（角色）+ 對齊任務（背景/目的/標準）」收斂為「只對齊任務」。下游 skill（dav-designer / tdd-test-writer / dav-submitter）吃的是
  `docs/backlog.md` + `docs/ac/`，不需要對話用戶的角色資訊
- **拆檔哲學**：呼應 SOP v2.0「LLM 注意力是稀缺資源」 — 主檔只留「流程怎麼走」，子檔是「Step 跑到的時候再去讀」。每個 Step 末尾新增 `**參考**：` 指向子檔
- **撤銷的章節不抹去**：v1.9「用戶背景收集」保留在變動歷史，加註「（已廢棄）」讓未來讀者知道「為什麼這裡跳號」
- **跨 SOP 一致性**：AGENTS.md / dav-designer / dav-trust / tdd-test-writer 等下游 skill 引用 dav-planner 為入口，不涉及 §2.7 細節，無連動修改

**範圍邊界**：
- ✅ 在 scope：`skills/dav-planner/` 整個 skill（主檔 + 兩個新子檔）
- ❌ 不在 scope：下游 skill（dav-designer / dav-trust / tdd-test-writer） — 引用粒度只在「dav-planner 是規劃入口」，不受本次重構影響

**前置**：本變更由用戶明確批准 + Agent 自跑校驗（行數 / 結構 / 跨檔引用），符合 V03 SOP 修改提案規範（diff + verdict 兩者並呈、用戶批准後生效）。

---

## v2.4 — 2026-09-26

**本版異動**：docs/ 批量減法（TMO-010）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P1** | 刪 `docs/sop/handbook/dav-wiki-cleanup.md` | 孤立檔（0 引用、9KB），內容已重複在 `skills/dav-wiki/SKILL.md` |
| **P1** | 刪 `docs/deliverable/2026-09-26-dav-planner-ac-templates.html` | v1.8 存量 HTML（14KB），v2.0 起禁止產出 |
| **P1** | 刪 `docs/deliverable/2026-09-26-dav-planner-user-background.html` | v1.9 存量 HTML（14KB），v2.0 起禁止產出 |
| **P1** | 刪 `docs/reflection/v1.8-dav-planner-ac-templates-reflection.md` | v1.8 存量獨立反思檔（7KB），TMO-006 deliverable 未含反思末段 |
| **P1** | 刪 `docs/reflection/v1.9-dav-planner-user-background-reflection.md` | v1.9 存量獨立反思檔（6KB），TMO-007 deliverable 未含反思末段 |

**合計**：刪 5 檔、減 53KB。

**決策紀錄（重要）**：
- **打破 v2.0「存量完全不動」原則**：這次批量減法明確破壊存量保留規則，是用戶決策 C 的明確批准
- **僅限本次 sprint**：未來 sprint 預設仍遵守 v2.0 存量規則；需批量減需另提新 Sprint + Reviewer 二審
- **保留的存量**：trust-mode 反思（2.5KB）、v1.7.1 反思（4KB）、TMO-005~009 的 deliverable.md 全保留
- **不變更 audit trail**：trust-log.md + 各 deliverable.md 內容完全保留、依舊可追溯

**範圍邊界**：
- ✅ 在 scope：v1.8 / v1.9 反思、v1.8 / v1.9 deliverable HTML、孤立 handbook
- ❌ 不在 scope：trust-mode 反思（跨越 v2.0 規則設計重點）、v1.7.1 反思（技術債清理、跨多個 sprint）、DESIGN.md / system-design.md（兩個不同職責不同 sprint
  使用）、TMO-005~009 的 deliverable.md（v2.0 後的對應檔，保留 audit）

**探針**：`tests/docs-reduction.bats` 6 探針守護已減狀態不退化。

---

## v2.3 — 2026-09-26

**本版異動**：dav-skill-creator 對「修改既有 skill」亦生效（TMO-009 階段 11c）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | `skills/dav-skill-creater/SKILL.md` 觸發時機表加「修改既有 skill」 | 任何 `skills/<name>/SKILL.md` 被修改都必走修改流程 |
| **P0** | `skills/dav-skill-creater/SKILL.md` 新增「修改既有 skill」流程 | M-Step 1（讀舊版 + 評估規範偏差）/ M-Step 2（套用變更 + 清偏差）/ M-Step 3（自驗收 + 探針驗證）|
| **P0** | `skills/dav-skill-creater/SKILL.md` 規則表加「修改必走 v2.3 流程」 | 純錯字除外；修改 ≧ 3 行必走 M-Step 1-3 |
| **P1** | `skills/dav-skill-creater/SKILL.md` description 更新含「修改」 | 描述明確含「修改既有 skill」適用範圍 |
| **P1** | `tests/restruct-skill-creator-modify.bats` 新建 | 6 個探針守護「修改流程」規則 |

**決策紀錄**：
- **v2.2 規範自動套用**：TMO-009 重結構後所有 skill（9 個）已合規 v2.2；v2.3 規範在本次同時生效
- **修改流程獨立於新建流程**：新建 5 步 / 修改 3 步，避免修改時誤走新建流程（從 0 重新建立浪費）
- **規範偏差修正強制**：修改時必同時清存量偏差、不允許「修 A 留 B」累积技術債
- **修改後必跑既有探針**：`bats tests/restruct-<name>.bats` 退探即視為修改失敗

**未來 sprint 規則（v2.3 新增）**：

| 規則 | 適用 | 不適用 |
|------|------|--------|
| 修改 ≧ 3 行必走 M-Step 1-3 | ✅ | ❌ 純錯字 |
| 修改同時清規範偏差 | ✅ | ❌ 用戶明確只修 A |
| 修改後跑既有探針 | ✅ | ❌ — |

---

## v2.2 — 2026-09-26

**本版異動**：跨目錄讀檔引用零容忍（TMO-009 階段 11b）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | skill 內跨目錄讀檔引用零容忍 | 禁止「讀 docs/xxx」、「見 docs/xxx」、「見 skills/other-skill/SKILL.md」這類「去讀別的 dir 檔案」的引用 |
| **P0** | 9 個 SKILL.md 全清跨目錄讀檔引用 | dav-planner / dav-reflection / dav-submitter / dav-trust / dav-skill-creater / dav-wiki / regression-guard / tdd-test-writer / dev-checker-loop 全部改為抽象詞 |
| **P0** | Obsidian `[[xxx]]` 教學加標記 | dav-wiki 等教學用 Obsidian 雙向連結時，必加「`<教學範例>`」標記，避免讀者誤判為跨檔連結 |
| **P0** | 刪除 `docs/plan/` + `docs/review/` 空殼目錄 | 兩目錄只有 `.gitkeep`、零內容；實際內容在 commit e2f71af 已刪 |
| **P1** | `skills/dav-skill-creater/SKILL.md` 加 v2.2 規則 | 未來新 skill 必遵守「跨目錄讀檔引用零容忍」 |
| **P1** | `tests/restruct-zero-cross-read.bats` 新建 | 6 個探針守護跨目錄讀檔零容忍規則 |

**決策紀錄**：
- **產出目的地可保留**：docs/ 是 project 約定，「寫到 docs/xxx」仍允許（不破壞獨立性）
- **讀檔引用零容忍**：「讀 docs/xxx」、「見 docs/xxx」禁絕（破壞 skill 獨立搬動）
- **skill 子檔仍可用 markdown 連結**：因同 dir、可獨立搬動
- **AGENTS.md 全域索引仍保留**：handbook / gates.json 連結屬全域索引層

**未來 sprint 規則（v2.2 新增）**：

| 規則 | 允許 | 不允許 |
|------|------|--------|
| skill 寫到 docs/ | ✅ 「寫入 `<docs_path>`」 | ❌ — |
| skill 讀 docs/ 內檔 | — | ❌ 禁止任何「讀 docs/xxx」、「見 docs/xxx」 |
| skill 跨 skill 引用 | ✅ 「見同套 other-skill（需同套安裝）」 | ❌ 禁止「見 skills/other-skill/SKILL.md」 |
| Obsidian `[[xxx]]` 教學 | ✅ 必加 `<教學範例>` 標記 | ❌ 不加標記 |

---

## v2.1 — 2026-09-26

**本版異動**：重結構 — 9 skill + AGENTS.md 改為「任務導航」5 段 + 純文字引用（TMO-009）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | 9 個 SKILL.md 重組為「任務導航」5 段 | dav-reflection / dav-submitter / dav-planner / dav-trust / dav-wiki / regression-guard / tdd-test-writer / dev-checker-loop / dav-skill-creater 統一 TL;DR / 觸發時機 / 流程 / 規則 / 變動歷史 |
| **P0** | `AGENTS.md` 重組為「任務導航」 | TL;DR / §1 萬事原則 / §1.5 紀律 / §2 SOP / §2.x 索引 / 變動歷史 |
| **P0** | 純文字引用規範（v2.1） | 9 個 skill 移除跨 dir markdown 連結 / Obsidian wiki link 跨 dir 連結；改用純文字「見 `<path>`」 |
| **P1** | `skills/dav-skill-creater/SKILL.md` 加 LLM 注意力編寫準則 | 新 skill 必含 5 段結構 + 反模式（ASCII box-drawing / 沒 frontmatter / 跨 dir 連結）|
| **P1** | `docs/prd/04-restructure-skills-llm-friendly.md` 新建 | 本次變更 PRD（11 階段）|
| **P1** | `docs/backlog.md` TMO-009 | Story Point 25 |
| **P1** | 11 個新 bats 探針（restruct-*.bats）| 114 個探針守護 5 段結構 + 純文字引用 + LLM 注意力準則 |

**決策紀錄**：
- **重結構 + 保留細節**：dav-planner 雖是「重結構」，但保留所有原 §2.7 / §2 / §3 / §4 / §5 子段細節，避免資訊遺失
- **AGENTS.md 例外**：全域索引保留 handbook / gates.json 連結（非 skill 規則）
- **dav-designer（30 行）跳過**：避免「為改而改」；下次改時也套 5 段
- **Reviewer 階段跳過**：11 階段整體驗收 1 次（用戶決策）

**LLM 注意力優化原則**：
1. **TL;DR 第一**：5 條列（做什麼 / 何時觸發 / SOP 路徑 / 關鍵紀律 / 必產出物）
2. **emoji 限縮**：只在「觸發時機」表用 ✅🟡❌
3. **表格只放結論**：長說明放流程步驟內
4. **流程明步**：每步 動作 / 為什麼 / 產出 / 證據
5. **規則三欄**：規則 / 例外 / 限制

**未來 sprint 規則（v2.1 新增）**：

| 產出物 | 規則 |
|--------|------|
| 新 skill | ✅ 必含 5 段結構（依 dav-skill-creater v2.1 規則）|
| 跨 dir 引用 | ✅ 純文字（見 `<path>`）；禁止 `../` markdown / `[[...]]` Obsidian 跨 dir |
| skill 重結構 | ✅ 必走 TDD（探針先紅後綠）+ regression 全綠 |

**前置**：Reviewer 二審驗收（內部 audit，基於結構對照表 + 跨 SOP 一致性檢查）→ **verdict: PASS WITH MINOR**（P0=0, P1=1 探針, P2=2 pre-existing 不阻擋
merge）。

---

## v2.0 — 2026-09-26

**本版異動**：減法 — 文件產出物精簡（TMO-008）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | `skills/dav-submitter/SKILL.md`「三層產出物」→「兩層產出物」 | 未來 sprint 不再生成 `docs/deliverable/<...>.html`；對話摘要 + Markdown 詳錄（反思併進末段）即可 |
| **P0** | `docs/sop/handbook/2.5-submission.md` 取消 HTML 強制 | Self-Check 清單移除「HTML 版存在且可開啟」項 |
| **P0** | `docs/sop/handbook/2.4-reflection.md` 反思併進 deliverable | 未來 sprint 反思不再寫獨立 `docs/reflection/<name>-reflection.md`，併進 `docs/deliverable/<...>.md` 末段「## 反思」 |
| **P1** | `docs/prd/03-reduce-deliverables.md` 新建 | 本次變更 PRD |
| **P1** | `docs/backlog.md` TMO-008 | Story Point 5 |

**決策紀錄**：
- **不動存量**：v1.7.1 / v1.8 / v1.9 的 PRD / reflection / deliverable / html 全部保留（audit trail 不能動）
- **視情境產出 PRD**：只有「架構 / 結構變更」才寫 PRD；純文字修改 / 簡單 bug fix / 規則調整不寫
- **視情境產出探針**：只有「需要守護變動」才加；避免「為證明工作而加」的探針
- **走完整 SOP（V03 紀律）**：SOP 修改必經 Reviewer 二審

**未來 sprint 產出物規則（v2.0 精簡後）**：

| 產出物 | 規則 |
|--------|------|
| changelog | ✅ 必寫 |
| deliverable.md（含反思末段）| ✅ 必寫 |
| PRD.md | 🟡 架構/結構變更才寫 |
| bats 探針 | 🟡 必要守護才加 |
| deliverable.html | ❌ 不寫 |
| 獨立 reflection.md | ❌ 不寫（併進 deliverable）|

**配套測試**：`tests/v2-reduce-deliverables.bats` 6 個探針守護 v2.0 規則不被逆轉

## v1.9 — 2026-09-26

**本版異動**：dav-planner skill 新增「用戶背景收集」機制（TMO-007）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | `dav-planner/SKILL.md` §2.7 新增「用戶背景收集」 | dav-planner 啟動後第一題，先問用戶角色（PM/開發者/設計師/業務/其他），依角色動態選擇追問（PM→目標用戶/規模、Dev→技術棧/團隊、設計師→品牌規範、業務→目標市場） |
| **P0** | `dav-planner/SKILL.md` §2.7.1 新增「跳過規則」 | 同專案後續對話或用戶明確說「直接問需求」時可跳過角色題，但 Agent 必須明示「我跳過角色題」 |
| **P0** | `dav-planner/SKILL.md` §2.7.2 新增「與 §3 Persona 區分」對照表 | 避免 Agent 把「產品的目標用戶」與「對話的用戶角色」混為一談 |
| **P1** | `docs/backlog.md` 新增 TMO-007 | Story Point 8 |
| **P1** | `docs/prd/02-dav-planner-user-background.md` 新建 | 本次變更 PRD |

**決策紀錄**：
- **不持久化**：用戶選 A 方案（純對話詢問、不寫 `docs/user-profile.md` 等檔） — 理由：最低干擾、不需維護元檔
- **不混進 §3 Persona**：用戶選 D 方案（新增 §2.7 在 §2 末 §3 前） — 理由：語意清楚、§3 Persona 原意是產品用戶，§2.7 是對話用戶
- **走完整 SOP（V03 紀律）**：SOP 修改必經 Reviewer 二審

**配套測試**：`tests/dav-planner-user-background.bats` 7 個探針守護 §2.7 章節不被靜默移除

## v1.8 — 2026-09-25

**本版異動**：dav-planner skill AC 範本獨立化 + HTML 版本（TMO-006）

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | `dav-planner/SKILL.md` §4.3.2 新增「AC 欄位精簡規則」 | backlog.md 表格 AC 欄位精簡為「AC 摘要（≤ 30 字 + 連結）」；完整 Given-When-Then + DoD 寫到 `docs/ac/<US-ID>.md` |
| **P0** | `dav-planner/SKILL.md` §4.6 新增「AC 範本生成 SOP」 | Agent 生成新 US 時必做 3 動作（同一 turn）：(1) 寫 `docs/ac/<US-ID>.md` (2) 生成 `docs/ac/<US-ID>.html` (3) 更新 backlog.md AC 欄位為新格式 |
| **P0** | `docs/ac/` 目錄新建 | 含 `README.md`（命名規範）+ `US-101.md` + `US-101.html`（範例檔）|
| **P0** | `docs/ac/README.md` | 說明目錄用途、命名規範、生成規則、範本結構、變更歷史 |
| **P0** | `docs/ac/US-101.md` + `docs/ac/US-101.html` | 範例檔（含真實 AC 內容 + 列印友好 CSS）|
| **P0** | `docs/prd/01-dav-planner-ac-templates.md` 新建 | 本次變更 PRD（含檔案結構 + SOP 改動 + 範本 + Story Point 8 + 風險 + DoD）|
| **P1** | `tests/dav-planner-ac-templates.bats` 新建 | 9 個探針守護 SKILL.md 章節（§4.3.2 / §4.6）/ PRD / docs/ac/ 範本 / changelog v1.8 / cross-consistency 不被靜默移除 |
| **P2** | `docs/backlog.md` 新增 TMO-006 | 記錄本次變更 + Story Point 8 + 完成標準 |

**目的**：解決用戶痛點「AC 塞在 backlog.md 表格 cell 內，閱讀體驗差、不利校對 / 分享 / 列印」— 根本原因是 markdown 表格 cell 對長內容渲染差，無論用 `<br>` 或 blockquote
都難用。修法是把 AC 抽出到獨立檔案（.md 給開發者、.html 給利害關係人），backlog.md 仍為 single source of truth。

**決策紀錄**：
- **AC 架構**：A 方案「兩者並存」（backlog.md 精簡為摘要+連結，docs/ac/ 為完整 AC）
- **HTML 生成時機**：A 方案「Agent 寫 .md 同時生成 .html」（同一 turn）
- **既有 backlog**：A 方案「不動既有 US」（過渡期兩格式共存，用戶可手動遷移）
- **AC 範本內容範圍**：A 方案「只含 AC」（不重複 US 標題 / Persona / Non-goals）
- **Reviewer**：A 方案「走 dev-checker-loop 二審」

**Markdown 表格 cell 渲染決策**：
- v1.6 SWOT 用純文字前綴 + `<br>` 分行（不用 blockquote）
- 本次 AC 摘要同樣用純文字前綴 + `<br>`（與 v1.6 慣例一致）
- 完整 AC 不再塞 cell（徹底避開 markdown 表格渲染不一致問題）

**前置**：變更經 dev-checker-loop Reviewer subagent 二審（V03 SOP 修改規則），驗證跨 SOP 一致性（dav-planner ↔ docs/prd ↔ docs/ac ↔
changelog）。Reviewer verdict 詳見對話記錄。

---

## v1.7.1 — 2026-09-25

**本版異動**：v1.7 後續技術債清理（UTF-8 bug + `.agents/` 歷史殘留 + TMO-005 關閉 + 順手修 latent bug）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P1** | 5 個 bats 中文 test name 改為英文 | `dav-wiki.bats`、`ci-linux.bats`、`wiki-cleanup.bats`、`wiki-cross-ref.bats`、`wiki-cross-ref-multimodal.bats` 共 ~47 個 test 改為純 ASCII 名（移除中文括號內容 / 中文描述）；功能保留（test 內 `grep -iE "英文\|中文"` 仍同時驗中英文） |
| **P0** | 順手修 `skills/dav-wiki/scripts/wiki-cleanup.sh:336` | 中文 log message 與 `$var` 未加 `${}` 包裹，`set -uo pipefail` 下拋 `unbound variable`（v1.7 之前已存在，被 homebrew bats UTF-8 bug 掩蓋）；修為「完成：移動 ${moved}、跳過 ${skipped}、失敗 ${errors}」 |
| **P1** | 順手修 `tests/ci-linux.bats` setup | 補上 `REPO_ROOT="$(git rev-parse --show-toplevel)"`（原本 setup 沒設 `$REPO_ROOT`，導致 `$REPO_ROOT/skills/...` 變 `/skills/...`，run 指令找不到腳本） |
| **P1** | `docs/system-design.md:195` | `docs/.agents/skills/dav-wiki/concept-evolution.md` → `../skills/dav-wiki/concept-evolution.md`（Reviewer 補遺：需加 `../` 前綴才不會斷 link） |
| **P1** | `docs/system-design.md:432` | `.agents/skills/dav-wiki/` → `skills/dav-wiki/`（檔案結構樹） |
| **P1** | `docs/system-design.md:450` | `tree_monstor/.agents/skills/dav-wiki/` → `tree_monstor/skills/dav-wiki/`（install.sh 對應說明） |
| **P1** | `docs/DESIGN.md:249` | `../.agents/skills/dav-skill-creater/SKILL.md` → `../skills/dav-skill-creater/SKILL.md`（Reviewer 補遺） |
| **P1** | `CONTRIBUTING.md:100` | `各 .agents/skills/*/SKILL.md` → `各 skills/*/SKILL.md`（Reviewer 補遺） |
| **P2** | `docs/backlog.md` TMO-005 關閉 | status `pending` → `done`；加說明 v1.7 翻轉 + v1.7.1 順手修 |

**為什麼現在才暴露 wiki-cleanup.sh:336 bug**：
- v1.7 之前此 bug 已存在（git show HEAD~1:tools/wiki-cleanup.sh line 336 一模一樣）
- 但被 homebrew bats UTF-8 bug **掩蓋**：19 個 wiki-cleanup test 全部中文，bats 跳過 → `unbound variable` 未被觸發
- v1.7.1 改中文 test name 後，bats 開始跑 test → bug 浮現（14 個 fail）
- CI workflow 只做 `bash -n` + `markdownlint`（不跑 bats），所以這個 bug 在 CI 永遠抓不到

**為什麼這次不改 TMO-005 原始目標「tools/ 統一 logging」**：
- TMO-005 原始內容是「tools/ 統一 logging（修正版：trap + 共用 log_*）」
- v1.7 已將 wiki 工具搬離 `tools/`，目標位置變更
- 統一 logging 在 dav-wiki 已是 `lib/log.sh` 共享（每個 wiki-*.sh source 同一個）
- TMO-005 範圍已通過 v1.7 + v1.7.1 完成，無未盡事項

**Audit 發現**：
- homebrew bats UTF-8 處理 bug 為環境問題，需升級 bats 版本或 patch homebrew formula，**不在本次 scope**

**最終 audit（Reviewer 二審 + 重審後修正）**：

| 檔案 | 中文 test name 數 / 總數 | 處理 |
| --- | --- | --- |
| `tests/dav-wiki.bats` | 4 / 20 | ✅ 改英文 |
| `tests/ci-linux.bats` | 5 / 5 | ✅ 改英文 |
| `tests/wiki-cleanup.bats` | 19 / 19 | ✅ 改英文 |
| `tests/wiki-cross-ref.bats` | 10 / 10 | ✅ 改英文 |
| `tests/wiki-cross-ref-multimodal.bats` | 10 / 10 | ✅ 改英文 |
| `tests/wiki-extract-audio.bats` | 10 / 10 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-extract-media.bats` | 20 / 20 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-extract-video.bats` | 11 / 11 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-media-describe.bats` | 16 / 16 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-merge-media.bats` | 12 / 12 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-ocr.bats` | 10 / 10 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/wiki-video-audio.bats` | 10 / 10 | ✅ 改英文（Reviewer 二審補遺） |
| `tests/agents-md.bats` | 0 / 10 | ⏭️ 無需改 |
| `tests/install.bats` | 0 / 41 | ⏭️ 無需改 |
| `tests/regression-guard-watch-mode.bats` | 0 / 5 | ⏭️ 無需改 |
| **合計** | **137 / 209** | **15 個 bats 全改完** |

**為什麼 Reviewer 二審補遺必要**：初版 audit 誤判「其他 7 個 wiki-*.bats 無中文」，違背 AGENTS.md §1 「誠實和用戶溝通」。Reviewer 獨立 audit 抓出實際遺漏 7 個 bats
/ 89 個 test。採方案 A（順手改完）保證 macOS 本地全綠。

**順手修 latent bugs**（utf-8 改中文 test name 後浮現）：

| 檔案 | 行號 | 問題 | 修法 |
| --- | --- | --- | --- |
| `skills/dav-wiki/scripts/wiki-cleanup.sh` | 336 | `set -uo pipefail` 下中文 log message 與 `$var` 解析冲突（$moved 被吃掉） | 加 `${}` 包裹 |
| `skills/dav-wiki/scripts/wiki-extract-media.sh` | 233 | 同上（$TYPE 被吃掉） | 加 `${}` 包裹 |
| `skills/dav-wiki/scripts/wiki-extract-media.sh` | 264 | 同上（$images_dir 被吃掉） | 加 `${}` 包裹 |
| `tests/ci-linux.bats` | setup | 原本 setup 沒設 `$REPO_ROOT`，导致 `$REPO_ROOT/skills/...` 變 `/skills/...` | 加 `REPO_ROOT="$(git rev-parse --show-toplevel)"` |

**驗證證據**：
- Gate 1：15 個 bats / 209 個 tests 全部執行 + 全綠（v1.7 之前為 0 tests executed）
- Gate 2：9 個 wiki-*.sh pass `bash -n`
- Gate 3：regression == Gate 1

**前置**：變更經 dev-checker-loop Reviewer subagent 二審（V03）兩次：
- 首次審查：FAIL（4 P0 blockers：选 6 個 bats 事實錯誤、漏 wiki-cross-ref 系列、system-design.md:195 缺 `../` 前綴、漏 DESIGN.md +
  CONTRIBUTING.md 殘留）
- 重審：FAIL（1 P0 blocker：漏 7 個未改的 wiki-*.bats，含 89 個中文 test name）
- 最終審查（包含上進全部修正後）：仍待續審

---

## v1.7 — 2026-09-25

**本版異動**：dav-wiki 工具目錄重組（從 `tools/wiki-*.sh` → `skills/dav-wiki/scripts/wiki-*.sh`）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P1** | `skills/dav-wiki/scripts/` 新建 | 9 個 wiki-*.sh 從 `tools/` 搬入；dav-wiki skill 變 self-contained |
| **P0** | `wiki-extract-media.sh` 內 OCR 呼叫改 sibling ref | 原用 `$REPO_ROOT/tools/wiki-ocr.sh` 會解析為 `skills/dav-wiki/`，名實不符且 OCR 會靜默失效；改為 `$SCRIPT_DIR/wiki-ocr.sh`（直接呼叫 sibling） |
| **P1** | `wiki-cross-ref.sh` stderr 提示更新 | 提示用戶執行新路徑（避免誤指） |
| **P1** | `tests/wiki-*.bats`（9 個）+ `wiki-cross-ref-multimodal.bats`（9 處）+ `wiki-merge-media.bats` 等共 10 個 bats 測試 | 路徑從 `tools/wiki-*.sh` 改為 `skills/dav-wiki/scripts/wiki-*.sh` |
| **P1** | `tests/ci-linux.bats`（3 處） | 硬編 `/Users/apple/www/tree_monstor/...` 絕對路徑 → 改用 `$REPO_ROOT/...`（順手修硬編 bug） |
| **P1** | `.github/workflows/ci.yml`（6 處） | `bash -n`、wc -l、PYEOF 檢查全部更新路徑 |
| **順手修** | `.github/workflows/ci.yml:51` + `CONTRIBUTING.md:55` | 原讀取 `.agents/skills/dav-wiki/SKILL.md`（被 gitignore，CI fresh checkout 不存在）；改為 `skills/dav-wiki/SKILL.md`（順手修兩個檔） |
| **P1** | `docs/sop/handbook/dav-wiki-cleanup.md`（5 處） | 指令範例 + 流程圖更新為新路徑 |
| **P1** | `skills/dav-wiki/SKILL.md`（2 處） | `wiki-extract-media.sh`、`wiki-cleanup.sh` 引用更新 |
| **P2** | `CONTRIBUTING.md`（4 處） | 路徑引用更新 |

**決策翻轉依據**（為什麼當初 TMO-005 不拆 vs 現在拆）

**當初（TMO-005，2026-09-23）**：判定不拆 `tools/wiki/` 子目錄，理由是「bats 引用絕對路徑會 breaking change」。

**本次（v1.7）**：採拆 `skills/dav-wiki/scripts/`（不是 `tools/wiki/`，是搬到 skill 內）。

**翻轉依據**：
1. **當初問題已不存在**：v1.4 changelog 已為 bats 加了 `$REPO_ROOT` 標準化（`tests/helpers/test-env.bash`），絕對路徑依賴已消除
2. **新需求觸發**：skill self-contained 是 dav-wiki install.sh 簡化部署的關鍵（`install.sh` 把整個 `skills/dav-wiki/` 一起 symlink 進
   `~/.pi/skills/dav-wiki/` 時，scripts 也跟著安裝，UX 一致）
3. **成本 vs 收益**：bats 10 個檔案機械式路徑替換 ≈ 30 分鐘；換來未來 install.sh 簡化 50%+、skill 真正 self-contained
4. **不再破壞向後相容**：本次確認無外部用戶（無下游依賴 `tools/wiki-*`）；TMO-005 加註 superseded by v1.7

**前置**：變更經 dev-checker-loop Reviewer subagent 二審（V03），驗證：
- audit 補遺漏（`wiki-cross-ref-multimodal.bats` 9 處 + `wiki-video-audio.bats`）
- `wiki-extract-media.sh` 內 OCR 呼叫改 sibling reference（避免解析錯誤）
- 順手修 `.agents/skills/...` 路徑 bug（CI + CONTRIBUTING）
- Reviewer verdict: PASS with Conditions（4 必改 + 用戶批准 2 順手修全部接受）

---

## v1.6 — 2026-09-25

**本版異動**：dav-planner skill 新增 SWOT 分析機制（關鍵決策點展開）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P1** | `~/.pi/agent/skills/dav-planner/SKILL.md` §2.6 新增「關鍵決策點 SWOT」 | 4 個觸發條件（不可逆變更 / 高成本 / 用戶糾結 / 戰略級影響）+ SWOT 標準格式 + V01 相容的逐項追問節奏 + V02 復用條款 + 自我檢查清單 + 情境 A/B 對照範例 |
| **P1** | `dav-planner/SKILL.md` §4.3.1 新增「SWOT 落版規則」 | 只記最終選項的 SWOT、加在 AC 欄（不新增 column）、純文字前綴（`<br>` 分行，**不用 `>` blockquote**，因 markdown 表格 cell 渲染不一致） |
| **P1** | `2.1-planning.md` Plan Gate 通過聲明加「SWOT 落版（如有）」選填欄 | 對應 §2.6 與 §4.3.1；如有展開 SWOT 才填 |
| **同步** | `tree_monstor/skills/dav-planner/SKILL.md`（如為獨立檔案，非 hardlink） | 與 `~/.pi/agent/skills/dav-planner/SKILL.md` 同步 |

**目的**：讓 dav-planner 在「關鍵決策點」不只是給一句話效果說明，而是展開策略性 SWOT（Strengths/Weaknesses/Opportunities/Threats），協助用戶做更完整的策略性決策；同時保留
§2.2 的輕量路徑，避免認知過載（不每個選項都做 SWOT）。

**觸發條件**：用戶提出 dav-planner skill 優化需求，2026-09-25 確認方向（只在關鍵決策點用 / Agent 草案+用戶驗證 / 對話+落版備註）。

**前置**：變更經 dev-checker-loop Reviewer subagent 二審（V03 SOP 修改規則），驗證跨 SOP 一致性 + Markdown 表格渲染風險。Reviewer verdict: PASS with
Conditions，已接受全部 10 項修訂（4 必改 + 3 強烈建議 + 3 可選）。

---

## v1.5 — 2026-09-23

**本版異動**：修正 §2.0 表格與 §2.6 之間的立場矛盾（從「角色混淆」重新定位為「自動升級規則不一致」）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P1** | `AGENTS.md` §2.0 表格補上「升級觸發器」說明 | 原本寫「一般任務 → Agent 與用戶都可主動判斷」，跟 §2.6 「必須停下問用戶」衝突。改為「以 §2.6 為準」，並引用 §2.6 的升級觸發器表格 |
| **P1** | `2.6-general-task.md` 加準則聲明 | 在檔頭明示「本檔為 §2.0 表格的準則源頭」避免未來誤看 §2.0 簡述而違反「自動升級必須停下確認」規則 |

**目的**：解決「新人 / Agent 讀 §2.0 後誤判一般任務可隨意自主」的規則衝突；保留 §2.0 表格作為「分類入口」，把「怎麼做、何時升級、何時問」統一收在 §2.6。

**前置**：變更經 dev-checker-loop Reviewer 二審（V03 SOP 修改規則），驗證跨 SOP 一致性。

---

## v1.4 — 2026-08-24

**本版異動**：Gate 3 測試指令禁用 interactive / watch 模式（防 session 卡死）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P0** | `skills/regression-guard/SKILL.md` 加「測試指令執行規範」章節 | 主流 runner 對照表（vitest/jest/npm test/bats/pytest/playwright/cargo/go）+ TTY 強制關閉法 `< /dev/null` + Fail-fast 自檢條件 |
| **P0** | `docs/sop/gates.json` Gate 3 `notes` 加 watch-mode 規則 | 標明禁用 interactive / watch 模式，並 cross-ref regression-guard SKILL.md |
| **P1** | `docs/sop/handbook/2.3-execution.md` 加「Gate 3 測試指令的常見陷阱」章節 | 對齊 SKILL.md 的核心指令表，方便人類閱讀 |
| **P1** | `tests/regression-guard-watch-mode.bats`（5 個探針） | 守護新規則不會被靜默移除（SKILL × 2 / gates.json × 1 / handbook × 1 / cross-consistency × 1）|

**目的**：解決用戶痛點「Tree Monstor 跑 Gate 3 baseline 時卡在 `Waiting for task` 凍住 session」— 根本原因是 agent shell 在 TTY
偵測上模糊，runner（vitest / jest / 部分 `npm test`）預設進入 watch mode 等 stdin。修法是把「禁用 watch mode」從隱性經驗提升為 SOP 強制規則，並用 bats
守護不被未來改動移除。

**前置**：`~/.claude/skills/regression-guard/SKILL.md` 與 `tree_monstor/skills/regression-guard/SKILL.md` 是同一
inode（hardlink），改一邊兩邊同步。

## v1.3 — 2025-08-24

**本版異動**：SOP 加 `remediation` 策略欄位（TD-019）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P0** | `gates.schema.json` 加 `remediation` 物件 | 定義 `strategy` enum（`auto_fix` / `auto_fix_with_limit` / `ask_user`）+ `max_attempts` + `fallback` + `description` |
| **P0** | `gates.json` 4 個 Gate 加 `remediation` | Gate 1/3 = `auto_fix_with_limit: 3` + `ask_user`；Gate 2 = `auto_fix`；Gate 4 = `ask_user` |
| **P1** | `2.3-execution.md` 加「失敗處理策略」章節 | 三種策略表 + 各 Gate 預設表 + Agent 必做動作 |
| **同步** | `tests/fixtures/mock-tree-monstor/docs/sop/` 三檔同步 | gates.json / gates.schema.json / 2.3-execution.md |

**目的**：解決用戶痛點「明明 test 做好了，但 agent 就停下來等」— 根本原因是 SOP 只寫 fail_action（禁止行為）沒寫補救策略，導致 agent 行為不一致。`remediation` 補上明確指引，讓
Agent 知道失敗時該「自動修」還是「問用戶」，預估整體等待時間減少 30-40%。

**前置設定**（同日已完成）：在 `~/.pi/agent/settings.json` 把 `retry.provider.timeoutMs` 從預設 3,600,000 ms (1 hr) → 600,000 ms (10
min)，避免 agent 卡 1 小時才 abort。

## v1.2 — 2025-08-22

**本版異動**：AGENTS.md 精簡重構（TD-017）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| 重構 | §2.1-§2.7 + §3 抽出去 `docs/sop/handbook/*.md` | 一章一檔，AGENTS.md 從 524 行 → ~150 行 |
| 重構 | AGENTS.md 引用方式 | Markdown 相對路徑 `[§2.1](./sop/handbook/2.1-planning.md)` |

**目的**：讓大模型可穩記 AGENTS.md 的核心內容（萬事原則、提問紀律、SOP 範圍判斷、4 Gate 表格、引用索引）。

## v1.1 — 2025-08-21

**本版異動**：

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P0** | §2.1 Plan Gate (fail-fast) | V05 — 加用戶確認才可進 §2.2 |
| **P0** | §2.2 Design Gate (fail-fast) | V07 — 加 3 文檔 + Story Point + 用戶確認 |
| **P0** | §2.3 用戶確認才能進 Gate | V09 — Plan 確認才能進 §2.3 |
| **P0** | §2.3 subagent 機制明確化 | V13 — dev/reviewer via `subagent` + `workflowScript` |
| **P0** | §2.4 Reflection Gate (fail-fast) | V17 — 加 6 維度報告 + backlog 更新 + 用戶確認 |
| **P0** | §2.0/§2.6 灰色地帶表 + 升級條款 | V21 — 強化任務分類 + 自動升級 |
| **P0** | §2.7 SOP 違規回報（**新章節**） | V23 — 違規自檢 + 用戶回應 + 記錄 |
| **P1** | §1.5 提問紀律（**新子章節**） | V01/V02 — 一次一個問題 + 方案必標推薦 |
| **P1** | §2.1 Plan Gate 通過聲明格式 | V06 — 必貼 checklist |
| **P1** | §2.2 Story Point 規模表 | V08 — Fibonacci 1/2/3/5/8/13 對照表 |
| **P1** | §2.3 Gate 1/2/3 必留證據 | V10/V11/V12 — 紅綠 output / lint output / baseline diff |
| **P1** | §2.4 反省模板 + Action Items 格式 | V15/V16 — 6 維度表 + 4 欄位（動作/類型/驗收/預估） |
| **P1** | §2.5 Markdown 模板 + 下一步建議規範 | V18/V20 — 必含欄位 + 三項必填 |
| **P1** | §2.5 Self-Check 清單 | V19 — 8 項 ✅ 才能提交 |
| **新增** | §3 CHANGELOG（本節） | V24 — SOP 版本控制 |

**修補來源**：AGENTS.md 完整 audit 識別 27 個 vulnerabilities（P0:7 / P1:13 / P2:7），本次處理 P0+P1 共 20 項；P2 待處理。

## v1.0 — 之前版本

未保留詳細記錄（CHANGELOG 機制為 v1.1 新增）。
