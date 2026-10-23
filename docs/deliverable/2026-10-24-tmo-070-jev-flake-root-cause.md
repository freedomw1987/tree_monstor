# 交付 — TMO-070：Jev oracle M6.3 間歇紅的根因修正（process-randomized `hash()`）

**日期**：2026-10-24（收尾；實作 2026-10-23）
**Backlog ID**：TMO-070（依賴 TMO-066；承接 TMO-069 交付報告 §8 建議 4）
**作者**：Agent
**狀態**：✅ 完成

## 摘要

`tests/v2.1-jev-poc.bats` 的 M6.3-c／M6.3-e 長期間歇紅（約 1/3 機率），TMO-066 收尾時把它記為
「候選：尚未開票」，當時的推測是「把 `elapsed`／`timestamp` 從 state 抽掉」——**這個推測是錯的**。
本次挖到真因在 `skills/regression-guard/PoC/journey_runner.py`：用內建 `hash(step.id)` 產生
`elapsed_ms`，而 Python 對 `str` 的 `hash()` 受 `PYTHONHASHSEED` 隨機化影響 → 每個行程的值都不同
→ oracle payload（含 `Elapsed: N ms`）每次不同 → `jev_oracle._cache_key()` 每跑必 miss → 真的打網路
→ verdict 分佈漂移 → `re_validate._classify()` 誤判成 `regression`（rc=2）。

修法分三層：讓 `elapsed_ms` **跨行程穩定**（`stable_step_offset()`，sha256 前綴）、讓 M6.3 系列
**完全離線**（10 處 oracle 呼叫改走 `m63_hermetic_env()`，吃版控 fixture）、並把「根因修正」從
「靠不 flake 間接證明」升級為「**改回去必紅**」（新增 M6.3-m／M6.3-n 兩支確定性探針＋ RG-M5 mutant）。

## 1. 為什麼做這個改動

M6.3 系列探針的核心斷言是「patch 與 AC 無關 → 重跑後 verdict 分佈不變 → 判 `no_change`」。
這要求 **baseline 跑與 sandbox 重跑兩次的 verdict 分佈一模一樣**。三件事會破壞它：

| # | 破壞者 | 後果 |
|---|--------|------|
| 1 | oracle 打得到網路 | 結果隨當下 API 狀態浮動 |
| 2 | `elapsed_ms` 每行程不同（**真因**） | payload／cache key 每跑必變 → 快取永遠 miss → 每次都真打網路 |
| 3 | `PoC/.env`／`~/.claude/.../PoC/.env`／環境變數裡的 key | 同一件事的另一個入口 |

第 2 點是本次的真因；第 1、3 點是它的**放大器**（沒有 key 時 403 → 被歸類成 blocked → 判 regression）。

> **舊推測已被證偽**：TMO-066 收尾段寫「真因是 `_state_text()` 把 `Elapsed: {elapsed_ms} ms` 也算進
> state → 每次 content hash 不同」。那句話描述的是**症狀**（payload 含 elapsed），不是病灶
> （payload 為什麼會變）。病灶在產生 elapsed 的那一行。`docs/backlog.md` 已同步更正。

## 2. 做了什麼

### 2.1 根因（`skills/regression-guard/PoC/journey_runner.py`）

```python
# 舊（每行程不同）
elapsed = 500 + (hash(step.id) % 1500)
# 新（跨行程穩定）
elapsed = 500 + stable_step_offset(step.id)
```

`mock_observe()`（`:69`）與 `ac_aware_observe()`（`:183`）**兩處**都改用 `stable_step_offset()`。

### 2.2 `stable_step_offset()`

```python
def stable_step_offset(step_id: str) -> int:
    digest = hashlib.sha256(step_id.encode("utf-8")).digest()
    return int.from_bytes(digest[:4], "big") % 1500
```

- `US-M63-AC01-s1` → offset **1229** → `elapsed_ms` **1729**（與版控 fixture 內的值一致）
- 分布仍散在 0..1499（外觀像亂數），但**跨行程、跨機器恆定**

### 2.3 M6.3 系列離線化（`tests/v2.1-jev-poc.bats`）

新增 helper，**10 處** oracle 呼叫全數改走它（baseline 1 ＋ `sandbox_runner` 8 ＋ M6.3-n 1）：

```bash
m63_hermetic_env() {
  env -u OPENROUTER_API_KEY \
    JEV_CACHE_DIR="$POC_DIR/cache-fixtures" \
    JEV_ENV_FILE=/dev/null \
    "$@"
}
```

三個開關各斷掉一路 key／快取來源：`JEV_CACHE_DIR` 讓版控 fixture 成為唯一可命中來源、
`JEV_ENV_FILE=/dev/null` 讓本機 `.env` 等同不存在（TMO-045 的 seam）、`-u OPENROUTER_API_KEY`
拔掉環境變數來源。

實測（PoC venv）：

```
$ env -u OPENROUTER_API_KEY JEV_CACHE_DIR="$PWD/cache-fixtures" JEV_ENV_FILE=/dev/null \
    .venv/bin/python run_journey.py journeys/US-M63.yaml --json
   total latency:      0ms        ← 沒有任何網路往返
   total cost:         $0.000035
   cache hits:         1/15       ← step-1 命中版控 fixture
real  0m0.113s
```

對照：未隔離時同一支探針要真打網路（帶重試）→ 慢且結果隨當下 API 狀態浮動。

### 2.4 版控離線 fixture

`skills/regression-guard/PoC/cache-fixtures/bbfaa5bfe583507a.json`（新增）——
檔名即 `jev_oracle._cache_key()`（= sha256(payload)）：

| 欄位 | 值 |
|------|-----|
| `raw_response.answers.verdict.choice` | `fail` |
| `context.elapsed_ms` | `1729` |
| 檔名（cache key） | `bbfaa5bfe583507a` |

`cache-fixtures/README.md` 補上 fixture 索引、**「M6.3 為什麼需要它」**段（含三個破壞者）、
以及「改了 `stable_step_offset()` 就必須重錄、且檔名要跟著改」的重錄流程。

### 2.5 兩支確定性探針（把「靠不 flake 間接證明」→「改回去必紅」）

| 探針 | 斷言 |
|------|------|
| **M6.3-m** | 兩個**明確不同**的 `PYTHONHASHSEED`（0 / 12345）下 `stable_step_offset('US-M63-AC01-s1')` 必須相同，且 == `1229` |
| **M6.3-n** | US-M63 step-1 的實際 cache key 必須 == 版控 fixture 檔名 `bbfaa5bfe583507a`，且該檔必須存在 |

兩支都用**明確的差異輸入**而非「跑兩次看看會不會不同」，所以退回舊實作必紅（不靠運氣）。

> **reviewer P2（F2）後加強**：原本只綁「cache key == fixture 檔名」，fixture 內容被改（verdict
> `fail`→`pass`）或 journey step 數被改時全探針仍綠。現在 M6.3-n 另外鎖住
> ① fixture 內 verdict 必須 `fail` ② 實際 baseline 必須 15 筆 / fail=1 / blocked=14
> → README 寫的分布不變式終於有探針護住（負向測試見 Gate 4）。

### 2.6 7 支新 mutant（`scripts/ci/mutants.tsv`，43 → **50**）

| ID | 守衛的契約 | 探針 |
|----|-----------|------|
| QD-M1 | foreign symlink 不得被重新指向（Qoder 專屬守衛） | `install-qoder.bats` QODER-17 |
| QD-M2 | `ensure_merged_skill` 的 `protect_foreign` 不得失效 | QODER-31 |
| QD-M3 | 使用者自有的實體 `AGENTS.md` 不得被刪 | QODER-16 |
| QD-M4 | 未知 `--agent` 必須 `exit 2` | QODER-15 |
| QD-M5 | 卸載不得刪 foreign symlink | QODER-17 |
| QD-M6 | dry-run 不得寫檔 | QODER-23 |
| **RG-M5** | **`stable_step_offset()` 退回內建 `hash()` 必被咬** | `v2.1-jev-poc.bats` M6.3-m |

QD-M1~M6 同時補上了 TMO-069 交付報告 §8 建議 2（把 Qoder 的關鍵契約登記進 mutant 表）。

### 2.7 突變 harness：副本內 symlink PoC venv

`scripts/ci/mutant-must-die.py::make_copy()` 原本只複製**被追蹤**的檔，而 PoC 專用 venv 是
gitignored → 副本裡沒有 venv → 需要 venv 的探針（`need_poc_venv`）在副本直接紅 → baseline 紅 →
整個突變套件死。修法：副本內 symlink 原 venv（venv 是自解相對的，從任何路徑掛過去都可用）。

### 2.8 `CONTRIBUTING.md` 新增「改共用程式碼的兩條規則」

1. **共用 helper 的守衛行為 → 加參數，不改共用預設**（新參數預設值必須維持舊行為；
   新參數必須有兩種值各一支探針；守衛行為最好各補一支 mutant）
2. **會進 oracle payload 的欄位必須跨 process 穩定**（不得用 `hash()`／`random`／時間戳／PID；
   fixture 必須版控；探針必須完全離線；改了 payload 組法就要重錄 fixture）

### 2.9 收尾修正：ENV-EQ-17 紅燈（本次 commit 一併修掉）

實作階段新寫的兩行 `echo "…（$out0 / $out1）"` 把 `$out1` 緊接全形括號 `）` →
被專案自己的守門 **ENV-EQ-17** 咬住（bash 3.2 + UTF-8 locale 會吞掉首位元組），
導致全套 735 條紅 1 條、突變 harness baseline 直接紅而中止。修法為 `${out1}`（2 處）。

## 3. 變更清單

- `skills/regression-guard/PoC/journey_runner.py` — 新增 `stable_step_offset()`；2 處 elapsed 改用它
- `skills/regression-guard/PoC/cache-fixtures/bbfaa5bfe583507a.json` — **新增**版控離線 fixture
- `skills/regression-guard/PoC/cache-fixtures/README.md` — fixture 索引＋M6.3 說明＋重錄流程
- `tests/v2.1-jev-poc.bats` — `m63_hermetic_env()`；10 處呼叫改走它；M6.3-m／M6.3-n；`${out1}` 修正
- `scripts/ci/mutants.tsv` — 新增 7 列（QD-M1~M6、RG-M5）；表頭數字 43→50
- `scripts/ci/mutant-must-die.py` — 副本內 symlink PoC venv
- `CONTRIBUTING.md` — 兩條新規則＋mutant 數字更新
- `docs/backlog.md` — 新增 TMO-070 列；更正 TMO-066 收尾段對根因的錯誤推測
- `docs/install-reference.md`、`README.md` — markdownlint 收尾（blockquote 空行）
- `docs/deliverable/2026-10-23-tmo-069-qoder-support.md` — markdownlint 收尾（`**第 N 輪**` → `### 第 N 輪`，
  純格式、不影響行為；同一輪 lint 掃到的順帶修正，登記在此以免夾帶）
- `tests/mutant-must-die.bats` — MMD-1 的「>= 40 支」收緊成「**恰好 50 支**」＋ 新 target 必覆蓋（reviewer P1）
- `tests/v2.1-jev-poc.bats` — M6.3-n 加強：鎖住 fixture 內 verdict 與實際 baseline 分布（reviewer P2）
- `docs/deliverable/2026-10-24-tmo-070-jev-flake-root-cause.md` — **本檔（新增）**

## 4. 探針

| 檔案 | 變動 | 涵蓋 |
|------|------|------|
| `tests/v2.1-jev-poc.bats` | **+2**（M6.3-m、M6.3-n）；M6.3-n 再加 2 條分布斷言；10 處呼叫離線化 | 跨行程穩定性、cache key ↔ fixture 綁定、fixture 內容、離線可重現 |
| `tests/mutant-must-die.bats` | MMD-1 門檻「>= 40」→「**== 50**」＋ 4 個新 target 必覆蓋 | 防「有人偷偷刪掉新護欄」（reviewer P1） |
| `scripts/ci/mutants.tsv` | **+7**（QD-M1~M6、RG-M5） | Qoder 6 條安全契約 + 根因修正可逆性 |
| `tests/env-equivalence.bats` | — | ENV-EQ-17 自行咬出收尾期的 2 處 `$var`+非 ASCII |

## 5. 測試 / 驗收證據

### Gate 1（TDD：紅 → 綠）

```
# 紅（修改前）
$ bats tests/
not ok 89 ENV-EQ-17: no shell or CI file puts a non-ASCII byte right after a variable expansion
# FAIL: tests/v2.1-jev-poc.bats:1309: `$out1` 後面緊接非 ASCII 字元（bash 3.2 + UTF-8 locale 會吞掉首位元組）→ 改成 `${out1}`
# FAIL: tests/v2.1-jev-poc.bats:1313: `$out1` 後面緊接非 ASCII 字元 → 改成 `${out1}`
→ 734 ok / 1 not ok

# 綠（修改後）
$ bats tests/
1..735
ok 735 AC-V11: extract-video script avoids removed -vsync flag
→ 735 ok / 0 not ok   (EXIT=0)
```

### Gate 2（lint / syntax）

```
$ shellcheck --version | head -3     → ShellCheck 0.11.0
$ shellcheck -x -S style $(git ls-files '*.sh' '*.bash')
→ rc=0（0 error / 0 warning）

$ bash -n × $(git ls-files '*.sh' '*.bash')
→ OK: 23 shell files syntax-checked

$ bash scripts/ci/check-skill-size.sh
→ OK: 12 個 SKILL.md 皆 <= 150 行（最長 148 行：skills/dav-skill-creater/SKILL.md）

$ bash scripts/ci/check-python-heredocs.sh
→ OK: 9 embedded Python heredocs syntax-checked (9 files)

$ python3 -m py_compile skills/regression-guard/PoC/journey_runner.py scripts/ci/mutant-must-die.py
→ OK

$ markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"
→ Linting: 144 files
→ Summary: 0 issues in 0 files
```

### Gate 3（regression）

```
# 修改前 baseline：bats tests/ = 734 ok / 1 not ok（ENV-EQ-17）
# 修改後：        bats tests/ = 735 ok / 0 not ok（EXIT=0）

$ SKILLS_DIR_OVERRIDE="$PWD/skills" bats skills/*/tests/*.bats
→ 1..3 ／ ok 1..3 全綠

$ time bats tests/v2.1-jev-poc.bats -f "M6.3"
→ ok 13 M6.3-m: stable_step_offset is stable across PYTHONHASHSEED (no process-randomized hash)
→ ok 14 M6.3-n: US-M63 step-1 oracle cache key equals the version-controlled fixture name
→ real 0m4.864s（14 支合計，含每支的行程啟動；單次 oracle 呼叫 0.113s、latency 0ms）

$ python3 scripts/ci/mutant-must-die.py
→ baseline 綠（50 組）
→ QD-M1  tests/install-qoder.bats   -f QODER-17  → rc=1 紅（mutant 死了）
   QD-M2  tests/install-qoder.bats   -f QODER-31  → rc=1 紅（mutant 死了）
   QD-M3  tests/install-qoder.bats   -f QODER-16  → rc=1 紅（mutant 死了）
   QD-M4  tests/install-qoder.bats   -f QODER-15  → rc=1 紅（mutant 死了）
   QD-M5  tests/install-qoder.bats   -f QODER-17  → rc=1 紅（mutant 死了）
   QD-M6  tests/install-qoder.bats   -f QODER-23  → rc=1 紅（mutant 死了）
   RG-M5  tests/v2.1-jev-poc.bats    -f M6.3-m   → rc=1 紅（mutant 死了）
→ working tree 自證：25 個目標檔 md5 全數未變
→ OK: 50 支 mutant 全部死亡（每支都有綠 baseline 對照）   EXIT=0
```

**reviewer 修正後的最終重跑**（F1／F2 修完再跑一次，防止「修問題時弄壞別的」）：

```
$ bats tests/                        → 735 ok / 0 not ok   EXIT=0
$ SKILLS_DIR_OVERRIDE="$PWD/skills" bats skills/*/tests/*.bats → 3 ok
$ python3 scripts/ci/mutant-must-die.py → OK: 50 支 mutant 全部死亡   EXIT=0
$ markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"
  → Linting: 145 files ／ Summary: 0 issues in 0 files
$ shellcheck -x -S style $(git ls-files '*.sh' '*.bash') → rc=0
```

**Diff 對比**：既有測試結果一致（735 條全數保留，只多那 1 條由紅轉綠）；新探針如預期觸發
（M6.3-m／M6.3-n 在 `bats tests/` 內為 ok；退回舊實作時 RG-M5 mutant 由綠轉紅 → 證明「會咬」）。

### Gate 4（reviewer）

**審查者**：`reviewer` subagent（唯讀；原始回傳見
`~/.pi/agent/sessions/--Users-davidchu-www-tree_monstor--/subagent-artifacts/fa3be1be-29f0-4b67-9df1-dc6635c4645e_reviewer_output.md`）

**Merge verdict：`OK with notes`**（0 P0、1 P1、4 P2）

> **Correct（審查者原文要點）**
> - 根因與修法一致：`stable_step_offset()` = `sha256(step_id)` 前 4 bytes `% 1500`；`mock_observe()`（`:69`）
>   與 `ac_aware_observe()`（`:183`）**兩處**都改用它，內建 `hash()` 只剩說明註解 ✓
> - 10 處 oracle 呼叫全部隔離：呼叫點 `:54`（baseline）、`:1006/1039/1067/1103/1135/1193/1220/1256`
>   （8 個 sandbox_runner）、`:1330`（M6.3-n）→ 與本報告的「baseline 1＋sandbox 8＋M6.3-n 1」完全對上；
>   `sandbox_runner.py` 的 `subprocess.run` 未自訂 `env` → 繼承 hermetic 環境；三層 key 來源全斷 ✓
> - fixture 忠實度：`context` 鍵與 `ACContext` 13 欄一一對應；`given/when/then` 與 `docs/ac/US-M63.md` 逐字相同；
>   `elapsed_ms: 1729` = 500 + 1229；`verdict.choice = fail` 與 `_load_cache` 讀取路徑相符 ✓
> - 7 支 mutant 逐列驗過「**錨點唯一 + 語意死**」（不靠註解／名稱）：QD-M1~QD-M6、RG-M5 的突變字串在目標檔
>   全檔唯一，且各自撞上 QODER-17／QODER-31／QODER-16／QODER-15／QODER-17／QODER-23／M6.3-m ✓
> - 突變 harness 的 venv symlink 修法正確且必要（`.venv/` 被 gitignore → 進不了副本；`pyvenv.cfg` 在 `bin/`
>   上一層 → 從任何路徑掛過去都找得到）✓
> - ENV-EQ-17 自我修正到位：以掃描器的同一 regex 掃 `tests/` 全目錄，剩餘命中全在註解行（該鎖對註解豁免）✓

**審查發現與處置**（全部已修，reviewer 逐項驗收）

| # | 等級 | 問題 | 處置 |
|---|------|------|------|
| **F1** | P1 | MMD-1 的「只列到 ≥ 40 支」擋不住**刪掉本次新增的 7 列**（刪完剩 43 ≥ 40 → 全綠）；MMD-1 的必覆蓋清單也不含 4 個新 target → 本次新護欄可被靜默刪掉 | 門檻收緊成「**恰好 50 支**」＋ 4 個新 target 加進必覆蓋迴圈（用 `grep -qxF` 整行比對，避免 `install.sh` 是 `lib/install/logging.sh` 子字串的假通過） |
| **F2** | P2 | README 寫的「分布恆為 `{fail: 1, blocked: 14}`」**沒有任何探針鎖住**——把 fixture 的 verdict 改成 `pass` 全探針仍綠 | M6.3-n 加兩條硬斷言：① fixture 內 verdict 必須 `fail`；② 實際跑出的 baseline 必須 15 筆 / fail=1 / blocked=14 |
| **F3** | P2 | 文件把分類器歸錯檔：`sandbox_runner._classify()` 不存在，真正的是 `re_validate.py:67` 的 `_classify()` | backlog 與本報告兩處改正為 `re_validate._classify()` |
| **F4** | P2 | 交付報告當下是 untracked，而 backlog 已指向它 | 本次 commit 一併 `git add`（並確認檔尾換行 → ENV-EQ-16 才掃得到） |
| **F5** | P2 | 同一個 commit 夾帶了 TMO-069 交付報告的 6 行標題層級變更（TMO-070 變更清單未登錄） | 登記進 §3 變更清單（純 markdownlint 格式、不影響行為） |

**兩條新增斷言的負向測試**（證明「會咬」，不是只會綠）：

```
# F2：把 fixture 的 verdict 由 fail 改成 pass
$ bats tests/v2.1-jev-poc.bats -f "M6.3-n"
not ok 1 M6.3-n: ...
# FAIL: fixture 內的 verdict 應為 fail（step 1 命中 fail 是 M6.3 的分布前提），got pass
→ 還原後：ok 1 M6.3-n ✓

# F1：從突變表刪掉 RG-M5 一列（舊門檻 >= 40 會放行）
$ bats tests/mutant-must-die.bats -f "MMD-1"
not ok 1 MMD-1: 突變表契約（欄位齊、id 唯一、錨點唯一、探針名存在、覆蓋到決策碼）
# FAIL: 只列到 49 支 mutant（預期 50；增刪列必須同步 scripts/ci/mutants.tsv 檔頭的數字）→ 有人在偷偷刪表
→ 還原後：ok 1 MMD-1 ✓
```

**審查者要求由 supervisor 實跑的驗證指令**（皆已執行，見 Gate 3）：

```
bats tests/                                  # 735 ok / 0 not ok
python3 scripts/ci/mutant-must-die.py        # 50/50 全死
python3 scripts/ci/lint-shell-var-nonascii.py .   # 0 命中
```

**無 UI**：本次為 CLI／腳本／探針／文件變更，無介面可測 → playwright-cli E2E 不適用。

## 6. 已知問題

- **pre-existing（不是本次造成）**：`skills/regression-guard/PoC/journey_runner.py` 有 4 個未使用的
  import（`json`／`sys`／`time`／`dataclasses.asdict`），`ruff check` 會報 4 條 F401
  （HEAD 基線同樣 8 條、本次 8 條 → **零新增**）。本專案 CI 的 python 檢查是 `ast.parse`／`py_compile`，
  不跑 ruff，所以不會擋 CI。未在本次順手修：那是無關變更，應另開一張小票。
- **fixture 與程式綁死**：`stable_step_offset()`、`payload` 組法或 AC 文字任一改動 → cache key 改變
  → 版控 fixture 失命中 → 探針 M6.3-n 會紅（這是**設計上想要的**），但必須照 README 的流程重錄。
  （reviewer F2 修好後，fixture 的**內容**與**分布**也被鎖住，不再是「改了也沒人知道」。）
- **Qoder `rules/` 官方位置**：TMO-069 §8 建議 3 仍未查證（本票不處理）。

## 7. 下一步建議

- **驗收方式**：用戶端跑 `bats tests/`（應為 735 ok / 0 not ok）與
  `python3 scripts/ci/mutant-must-die.py`（應為 50 支全死）；再重跑一次
  `bats tests/v2.1-jev-poc.bats -f "M6.3"` 看 M6.3 系列是否**穩定**（本票修的正是間歇紅）。
- **預估時間**：驗收 5 分鐘內；把 `journey_runner.py` 的 4 條 F401 清掉約 10 分鐘（另開票）。
- **風險提示**：若日後有人改了 oracle payload 的組法卻沒重錄 fixture，M6.3-n 會紅——
  那是**預期**行為，但接手者若不清楚會誤以為是壞掉；README 已寫重錄流程，後續變更請一併更新。

## 8. 反思

**第一件事：一個「間歇紅」最容易被歸因到最像的地方。**

TMO-066 收尾時，我們看到探針的 FAIL 訊息裡出現 `Elapsed: {elapsed_ms} ms`，就判斷「payload 裡
混了 elapsed → content hash 每次不同 → 快取永遠 miss」。這個因果鏈**每一段都成立**，
但它描述的是**症狀**而不是**病灶**：payload 之所以每次不同，是因為 elapsed 每次不同；
而 elapsed 之所以每次不同，是因為 `hash()` 被 `PYTHONHASHSEED` 隨機化。
兩種說法都解釋得通「為什麼會 miss」，但只有一種能指出**要改哪一行**。
真正的教訓是：**當一個解釋「解釋得通」時，要問它能不能導出「可執行的下一步」**——
不能的解釋，往往是症狀的倒影。

**第二件事：「不 flake」不是證據，「改回去必紅」才是。**

修好之後，如果只說「現在連跑十次都綠」，那只是把機率問題換成信心問題。
所以這次特別加了兩支**用明確差異輸入**的探針（M6.3-m 用兩個指定的 `PYTHONHASHSEED`；
M6.3-n 把 cache key 與版控 fixture 檔名綁死），再加一支 RG-M5 mutant 證明「退回舊實作必被咬」。
把「間接證明」升級為「確定性鎖死」，代價只是兩支探針＋一行 mutant——
這個交換的性價比很高。

**第三件事：離線不是「錦上添花」，是讓探針可重現的前提。**

M6.3 系列原本會打網路，即使根因修好，只要當下 API 狀態不同，分佈就可能不同。
把它改成完全離線（10 處呼叫全走 `m63_hermetic_env()`）之後，這支探針才第一次真正
**在任何機器、任何時刻**給出同一個答案。副作用還意外地好：4.6 秒 → 0.1 秒。

**第四件事：自己寫的守門，會抓到自己的新程式碼——這正是守門存在的理由。**

收尾時 ENV-EQ-17 直接咬出本次新寫的兩行 `$out1）`（bash 3.2 + UTF-8 locale 吞首位元組）。
這是本專案最舒服的一次「被抓」：如果守門只是裝飾，這個問題會一路帶到 CI 的 macOS leg 才爆；
而它現在**在本機、提交前**就紅了。
**守門的價值不在於它擋下多少外來錯誤，而在於它願不願意指出「作者本人剛寫的那一行」。**

**第五件事：收尾本身也是交付物的一部分。**

本次 commit 裡有一格是「修掉自己前一輪留下來的紅燈」。如果我當時直接 commit，
這支 commit 會帶著紅燈進版控，而 backlog 上寫的是 `done`——
**狀態欄與事實不一致，比沒有狀態欄更危險**。
所以「backlog 標 done」必須意味著「全套綠 + 交付報告存在 + 已進版控」，三者缺一都叫未完成。
