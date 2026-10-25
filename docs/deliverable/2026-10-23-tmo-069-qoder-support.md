# 交付 — TMO-069：install.sh 支援 Qoder

> 日期：2026-10-23 ｜ 範圍：`install.sh`、`lib/install/{agents,symlink}.sh`、`tests/install-qoder.bats`（新增）、
> `tests/env-equivalence.bats`、`README.md`、`docs/install-reference.md`、`docs/system-design.md`、
> `docs/backlog.md`、`.gitignore`
> 起因：2026-10-23 用戶委託「install.sh 可以為 qoder 都安裝」

## 1. 為什麼做這個改動

Qoder 是新的 agent runtime（CLI + IDE），有自己的記憶與 skill 目錄：

| 層 | 路徑 | 誰讀 |
|---|---|---|
| 使用者層 | `~/.qoder/AGENTS.md` | Qoder **CLI**（IDE 不讀） |
| 專案層 | `<project>/AGENTS.md` | Qoder **CLI 與 IDE** 都讀 |
| 使用者層 skill | `~/.qoder/skills/<name>/SKILL.md` | Qoder |
| 專案層 skill | `<project>/.qoder/skills/<name>/SKILL.md` | Qoder |
| subagents | `<qoder_root>/agents/<name>.md` | Qoder |

安裝器原本只認 `claude` 與 `pi`。Qoder 使用者只能手動搬檔案——而手動搬最容易出錯的地方，
正是「我的 `AGENTS.md` 跟你的撞了怎麼辦」。所以這個改動的**核心不是「多支援一個 agent」，
而是「在不踩到使用者既有內容的前提下多支援一個 agent」**。

## 2. 做了什麼

### 2.1 Agent 選擇

- `KNOWN_AGENTS` 與預設 `AGENTS` 加入 `qoder`（預設＝三個都裝）。
- `--agent` 改為**可重複**、支援 `all`；同名自動去重。
- **未知 agent 名稱直接 `exit 2`**，不再默默略過（這是既有行為的強化：漏裝比失敗更難察覺）。
- `resolve_source()` 一律把 `SOURCE_DIR` 正規化為絕對路徑（`abs_path`）——否則卸載認不出自己建的 symlink。

### 2.2 安裝路徑

| scope | 安裝內容 |
|---|---|
| `--global` | `~/.qoder/AGENTS.md`（symlink）＋ `~/.qoder/skills/<name>`（per-skill merge）＋ `~/.qoder/agents/<name>.md`（subagents） |
| `--local` | `<project>/AGENTS.md` ＋ `<project>/.qoder/skills/<name>` ＋ `<project>/.qoder/agents/<name>.md` |
| `--target <dir>` | 同 `--local`，但目標是指定目錄 |

`~/.agents/tree_monstor` 本機副本（`install_agents_dir`）**保留不變**——Qoder 支援不取代它。

### 2.3 「不踩使用者既有內容」的三道閘

| 使用者已有的東西 | 行為 | 實作 |
|---|---|---|
| `~/.qoder/AGENTS.md`（實體檔） | 跳過 + 警告，**不中斷整個安裝** | `ensure_symlink_if_absent()` |
| `~/.qoder/AGENTS.md`（指向別處的 symlink） | 跳過 + 警告（不 repair、不刪） | `ensure_symlink_if_absent()` 的 `-L` 分支比對 `readlink` |
| `~/.qoder/skills`（指向使用者自己目錄的 symlink） | 不合併、不替換 + 警告 | `install_qoder()` 的 dir 層守衛 |
| `~/.qoder/skills/<name>`（指向別處的 symlink） | 跳過 + 警告（**不**重新指向） | `ensure_merged_skill` 的 `protect_foreign` 參數 |

> 為什麼 per-skill 要跟 Claude／Pi 不一樣？共用 helper 的預設行為是「repair」——
> 把指向別處的同名 symlink 重新指向本 repo。那對「本 repo 搬家後修復舊連結」很有用，
> 但對「使用者自己 symlink 了一個 skill」就是摧毀。Qoder 是新路徑，沒有歷史包袱，
> 所以選了保守的那一邊，並在 `docs/install-reference.md` 明確寫出這個差異。

### 2.4 卸載

`uninstall_qoder()` + `remove_symlink_to()`：**只刪「指向本 repo source」的 symlink**。
使用者自己寫的 `AGENTS.md`、自裝的 skill、指向別處的 symlink，全部保留。

### 2.5 dry-run

dry-run **不寫任何檔案**，而且**不說謊**：
- 輸出 `would create symlink: …` / `would merge: …`，不再印「symlink created」這種假成功訊息；
- skills 的計畫印真實會做的事（per-skill merge），不是會誤導的 whole-tree symlink。

## 3. 探針

| 檔案 | 條數 | 涵蓋 |
|---|---|---|
| `tests/install-qoder.bats`（新增） | **31** | 三種 scope、merge、冪等、dry-run、卸載安全性、不覆寫使用者檔、foreign symlink、subagents、`--agent all`／可重複／去重、`--source` 自動偵測、相對 `--source` 的絕對 `@path` |
| `tests/env-equivalence.bats` | +1（ENV-EQ-20） | `install.sh` 必須在**每個本機 bash 版本**下跑得過（含 macOS 內建 bash 3.2） |

## 4. 驗證

| 項目 | 結果 |
|------|------|
| `bats tests/install-qoder.bats` | 31/31 綠 |
| `bats tests/install.bats` | 41/41 綠 |
| `bats tests/env-equivalence.bats` | 20/20 綠 |
| `bats tests/`（全套 733 條） | 一次 732/732 全綠；重跑 731/733，僅 `M6.3-c`／`M6.3-e` 失敗 |
| `shellcheck -x -S style $(git ls-files '*.sh' '*.bash')` | clean |
| `bash -n`（每個 tracked shell 檔） | clean |
| `lint-shell-var-nonascii` / `lint-probe-tmp-paths` / `lint-probe-secrets` / `lint-probe-tools` | 全綠 |
| `git diff --cached --check` | clean |

> `M6.3-c` / `M6.3-e` 是**既有**的 PoC timing／狀態 flake：本次 diff 完全沒碰
> `tests/v2.1-jev-poc.bats` 或 `skills/regression-guard/PoC/**`；同一輪 `--filter "M6.3-"` 連跑 3 次
> 結果為 失敗／失敗／全綠，且在 stash 掉本次修改的乾淨樹上同樣失敗 → 與本次變更無關。

## 5. Gate 4 reviewer 三輪審查軌跡

| 輪次 | verdict | 發現 | 處置 |
|---|---|---|---|
| 1 | `request-changes` | F1–F7 | 全數處置（見下） |
| 2 | `approve-with-comments` | P1-1、P2-1～P2-10 | 全數處置 |
| 3 | **`approve`** | P2-A～P2-D（非阻斷） | 4 條全部折進本次變更 |

### 第 1 輪

- **F1**（P0 級）：使用者自有 `~/.qoder/AGENTS.md` 實體檔會讓 `ensure_symlink` 回傳 1 → `set -e` **中斷整個安裝**。
  且 qoder 已在預設清單 → 連只想裝 Claude／Pi 的使用者都會踩到。全域層改用 `ensure_symlink_if_absent`。
- **F2**：`ensure_symlink_if_absent` 只擋實體檔，**使用者自有 symlink 會被 repair 掉** → 新增 `-L` 分支比對 `readlink`。
- **F3**：`~/.qoder/skills` 若是使用者自有 symlink，會被 tree-level symlink 蓋掉 → qoder 專屬守衛。
- **F4**：文件宣稱會安裝 `~/.pi/agent/SOUL.md`，但 `install_pi` 明擺不裝 → 文件改正。
- **F5**：`SOURCE_DIR` 未正規化 → 卸載認不出自己建的 symlink、Claude wrapper 會寫成相對 `@path` → `resolve_source()` 正規化。
- **F6**：新探針未 `git add` → ENV-EQ-15/16 掃不到 → 已追蹤。
- **F7**：dry-run 的 skills trace 與真實的 per-skill merge 不符 → dry-run 改印真實計畫。

### 第 2 輪

- **P1-1**：文件專案層 Pi 樹寫成 `.pi/AGENTS.md`（實作是 `.pi/agent/`）→ 改正。
- **P2-1**：文件殘留 `~/.pi/AGENTS.md` → 改正。
- **P2-2**：backlog 預先宣稱審查結果 → 改為事實描述。
- **P2-3**：QODER-19 只測安裝、沒測卸載 → 補上卸載半邊。
- **P2-4**：沒有探針鎖住 dry-run 的 `per-skill` 字樣 → QODER-11 補上。
- **P2-5**：QODER-22 沒真的證明去重 → 改成數 `Installing for Qoder` 出現次數 == 1。
- **P2-6**：`--source` 自動偵測從未被測 → 新增 QODER-30。
- **P2-7**：F5 的 Claude wrapper 半邊沒測 → 新增 QODER-29（相對 `--source` 必須產出絕對 `@path`）。
- **P2-8**：`lib/install/agents.sh` 的 Requires 清單漏 `abs_path`／`log_plan` → 補上。
- **P2-9**：dry-run 印假成功訊息 → `log_dry` 分流。
- **P2-10**：bash 3.2 的安全性宣稱沒有任何 CI 腿咬得到 → 新增 ENV-EQ-20。

### 第 3 輪（非阻斷建議，亦全數折入）

- **P2-A**：`ENV-EQ-20` 只在「給了 `--agent`」時跑，**沒**真的踩到它宣稱要保護的「`AGENT_REQ` 空陣列」路徑
  → 每個 bash 版本再補一次「不給 `--agent`」的執行。
- **P2-B**：`lib/install/symlink.sh` 的 Requires 清單漏列 `log_dry` → 補上。
- **P2-C**：`docs/system-design.md` §5.2 仍寫舊的 `~/.pi/skills/` ＋ `~/.pi/AGENTS.md` → 改正並補 Qoder 路徑。
- **P2-D**：Qoder 的 per-skill slot 若是指向別處的 symlink，會被共用 helper repair 掉
  → 新增 `protect_foreign` 參數，Qoder 路徑傳 1；Claude／Pi 維持原行為。

## 6. 未完成 / 待辦（誠實揭露）

| # | 事項 | 處置 |
|---|------|------|
| 1 | `.qoder/rules/` 的 user/global 正式安裝位置仍未確定 | 未做；目前以 `AGENTS.md` 作為規則入口，不建立獨立 `.qoder/rules/` |
| 2 | Qoder IDE 只可靠支援工作區內的 `<project>/AGENTS.md` | 已知限制，安裝時會主動提示需用 `--local` / `--target` |
| 3 | `scripts/ci/mutants.tsv` 未登記本次的文字契約鎖 | 未做；本次以「三輪 reviewer 逐條指認 + 專屬探針」證明探針會咬 |
| 4 | `M6.3-c` / `M6.3-e` 的既有 flake | 未修（與本次變更無關，另案處理） |

## 7. 反思

**第一件事：真正危險的不是「不支援」，是「支援了但會踩到人」。**

如果我今天只做「加一個 qoder 分支、複製 pi 的做法」，最可能的結局是：
使用者已經有 `~/.qoder/AGENTS.md` → 安裝器 `rm` 掉或報錯 → **而且因為 qoder 在預設清單，
連只想裝 Claude 的人都被綁架**。F1 就是這個情境。也就是說，
「加一個 agent 到預設清單」本身就是一個**放大器**：它把新路徑的邊界案例，
從「只有 Qoder 用戶會遇到」變成「所有使用者都會遇到」。
所以正確的順序是：先證明新路徑**不會傷人**，再把它放進預設。

**第二件事：「不覆寫」有三種形狀，只做一種等於沒做。**

實體檔、指向別處的 symlink、以及「同名 slot 已被別的 skill 占用」——這三種在檔案系統上長得很像，
但在使用者心智裡完全不同。F1／F2 打到前兩種，第 3 輪的 P2-D 打到第三種。
每一輪 reviewer 找出來的都是「同一個原則的下一個形狀」，
這提醒我：**「不覆寫使用者內容」不是一個 if 分支，是一整組判定**。

**第三件事：共用 helper 的「貼心」有時正是破壞。**

`ensure_merged_skill` 會把指向別處的同名 symlink「repair」成本 repo 的路徑——
對「repo 搬家後修復舊連結」是對的，對「使用者自己 symlink 了一個 skill」是摧毀。
修法不是二選一，而是**把這個判斷變成參數**（`protect_foreign`），
讓新路徑能選保守的那一邊，而不改變既有路徑的行為。
回頭看，F1 的修法（`ensure_symlink_if_absent`）其實也是同一個思路：
**新增專用守衛，而不是改寫共用 helper 的預設**。共用 helper 的預設行為一旦被改，
所有呼叫端都會跟著變——這在安裝器這種「別人的電腦」工具裡風險特別高。

**第四件事：宣稱的防線必須真的被踩到，否則它只是裝飾。**

P2-10 是最有代表性的一例：我寫了 `ENV-EQ-20` 宣稱「install.sh 必須在每個本機 bash 版本下跑得過」，
但它其實只跑了「給了 `--agent`」那一條——而它宣稱要保護的正是「`AGENT_REQ` 是空陣列」的路徑。
**探針跑過 ≠ 踩到過**。第 3 輪 reviewer 這句「你只測了給定參數的那一半」很值得記。
同樣地，QODER-22 原本只斷言「檔案存在」，那對「去重」是 vacuous——存在與「只裝一次」是兩件事。

**第五件事：三輪二審的邊際效益遞減，但最後一輪仍值回票價。**

第 1 輪抓到 P0 級的安裝中斷，第 2 輪抓到「文件與程式不一致」與「探針沒咬到真正的洞」，
第 3 輪抓到 4 條非阻斷但都實質的問題。**第三輪已經是 approve**，
但那 4 條若不折進去，下次有人讀文件還是會被 P2-C 誤導。
換句話說：reviewer 的 verdict 是「可不可以合併」，不是「要不要再改」——
兩者要分開看。

## 8. 建議的下一步

1. **TMO-070（建議）**：把「共用 helper 的守衛行為做成參數」這個套路寫進 `CONTRIBUTING.md`
   ——新 agent 路徑一律用專用守衛 + 參數化共用 helper 的行為。
2. `scripts/ci/mutants.tsv` 登記本次的關鍵契約（例如「`~/.qoder/AGENTS.md` 不得被覆寫」）。
3. 確認 Qoder 的 user/global `rules/` 正式位置後，再決定要不要支援 `~/.qoder/rules/`。
4. 另案處理 `M6.3-c` / `M6.3-e` 的 PoC flake（本次全套 733 條裡唯一的紅燈來源）。
