# TMO-029 PoC venv 一鍵建置 + CI 真的會跑（bats 全綠 506/506）

- **日期**：2026-10-04
- **Backlog ID**：TMO-029
- **作者**：pi agent（user 核准的 4 里程碑計畫第 4 站；V03.6 二審 4 輪）
- **狀態**：完成（Gate 1–4 全過；R4 verdict approve-with-comments / risk low / 0 P0 / 0 P1，並明示可進入 §2.5）

## 摘要

本票解三個連在一起的問題，讓「測試綠」變成**可被信任**的宣稱：

1. **CI 從未真正跑過**：`ci.yml` 只寫 `branches: [main]`，但 repo 預設分支是 `master` → push 從不觸發；`test` job 也從未安裝 PoC 依賴（httpx /
   PyYAML）。
2. **clean clone 站不起來**：repo 內沒有 requirements / setup 腳本，「怎麼建環境」只存在開發者腦中。
3. **缺環境時是噪音不是紅燈**：38 條 venv-dependent 測試各自以 `command not found`(127) 失敗，看不出是環境問題。

結果：**一鍵 `bash skills/regression-guard/PoC/setup-venv.sh`** 建好環境；CI 在 `master` 真的會跑並先建 venv；
缺 venv 時 **38 條各自一條清楚的紅＋修復指令、0 個 127 噪音**；`bats tests/` **0 not ok / 506 ok / 0 skip**。

## 變更清單

| 檔 | 改動 |
| --- | --- |
| `skills/regression-guard/PoC/requirements.txt` | **新增**：`httpx>=0.27,<1`、`PyYAML>=6.0`（上下界鎖定）＋涵蓋範圍聲明 |
| `skills/regression-guard/PoC/setup-venv.sh` | **新增 111 行**：uv 優先、`python3 -m venv` + `ensurepip` 退路、`--force`、`POC_VENV_DIR` 測試縫、危險值護欄（`_reject_venv_dir`）|
| `skills/regression-guard/PoC/.gitignore` | 加 `.venv/` |
| `skills/regression-guard/PoC/README.md` | 安裝步驟改 `bash setup-venv.sh`；目錄樹補新檔 |
| `.github/workflows/ci.yml` | `workflow_dispatch`；`push`/`pull_request` 分支 `[main, master]`；test job 加 `Build PoC venv`（排在 bats 前）；lint-only `continue-on-error: true`（→ TMO-037）|
| `.markdownlint-cli2.jsonc` | **新增**：ignores `**/.venv/**`、`**/node_modules/**`（規則仍由 `.markdownlint.json` 生效）|
| `tests/poc-bootstrap.bats` | **新增 8 條探針**（334 行）|
| `tests/v2.1-jev-poc.bats` | 38 條加 `need_poc_venv()`；新增 `make_us101_run()` 讓 M6-g / M6.1-c 真跑（原永遠 skip）；flaky-d 先 `rm -f` 清殘檔 |
| `README.md` | 移除兩個無鎖且已失真的數字 badge，只留 CI run badge |
| `docs/install-reference.md` | 更正依賴說明為 **38 / 98 條需 venv、其餘 60 條純靜態** |
| `CONTRIBUTING.md` | 揭露 markdownlint 目前 non-blocking（→ TMO-037）|
| `docs/backlog.md` | TMO-029 → done；新增 TMO-037 / 038 / 039 / 040；TMO-034 引用 4 → 3 處 |

## 測試 / 驗收證據

### Gate 1（TDD 紅→綠）

依 gates.json 規範，Gate 1 (TDD) 需要：測試先紅後綠，並在對話貼出 測試執行指令 + 失敗輸出 + 通過輸出。

```
新增探針（改後）：bats tests/poc-bootstrap.bats
ok 1 requirements.txt covers column-0 non-stdlib imports in PoC scripts
ok 2 setup-venv.sh exists, is executable and installs from requirements.txt
ok 3 setup-venv.sh falls back to python3 -m venv when uv is absent
ok 4 every venv-dependent test carries the fail-loud guard
ok 5 .venv is gitignored so the non-uv fallback cannot leak files
ok 6 setup-venv.sh refuses dangerous POC_VENV_DIR values
ok 7 setup-venv.sh runs the VENV_DIR guard before any destructive rm
ok 8 CI triggers on master and builds the PoC venv
```

#### V03.6 要求的「修改前 fail / 修改後 pass」（護欄尾斜線漏洞，R3 抓出）

```
修改前：not ok 1 ... refuses dangerous POC_VENV_DIR values
        # FAIL: POC_VENV_DIR=/tmp/ 未被擋（rc=2）
        # Creating virtual environment at: /tmp/          ← 護欄被 `/` 繞過
修改後：ok 6（7 個壞值帶 --force 全 rc=1；深層路徑 rc=0）
```

#### 突變證明（新增探針可證偽；全還原後回綠）

```
M10  M6-g 拿掉 need_poc_venv       → 紅「38 條、有守門 37 條」
M11  純靜態測試亂加守門             → 紅「38 vs 39」
M12  .gitignore 移除 .venv/        → 紅
M13  M6-g 改回永遠 skip            → 紅「仍有 1 處 skip」
M14  ci.yml 移除 workflow_dispatch → 不咬（探針⑤只查 master 觸發）→ TMO-038
M15  ci.yml 移除 setup-venv step   → 紅
M16  setup-venv 改讀 deps.txt      → 紅
M17  fallback 改 -m virtualenv     → 紅
M18  移除 python3 fallback 分支     → 紅
M19  fallback 不裝依賴              → 紅「pip/ensurepip 都沒被呼叫」
M20  移除 POC_VENV_DIR 縫           → 紅
M21  移除護欄                       → 紅
M22  護欄過寬（只接受 /）            → 紅
M23  shim 不再記錄呼叫              → 紅「未實際呼叫 python3 -m venv」
M24  拿掉 pip install               → 紅「fallback 分支未安裝依賴」
M25  移除整段護欄（-480 chars）      → 紅
M26b 精準回退成 R2 版護欄            → 紅「POC_VENV_DIR=/tmp/ 未被擋」
M27c 護欄移到 rm -rf 之後            → 紅「破壞性操作先於護欄」
```

### Gate 2（lint / syntax）

- `shellcheck skills/regression-guard/PoC/setup-venv.sh` → rc=0；`bash -n` → rc=0（`.bats` 不做 `bash -n`：對 bats 語法無效，改以實跑
  bats 當 parse check）
- `markdownlint-cli2 CONTRIBUTING.md README.md docs/install-reference.md` →
  `Linting: 3 files / Summary: 0 issues in 0 files`
- `PoC/README.md` 3 issue（MD031×1、MD013×2）**為既有**：`git show HEAD:` 版本同樣 3 issue，行號僅位移 → 本票零新增 lint 債
- PyYAML 語意解析
  `ci.yml`：`triggers: [workflow_dispatch, push, pull_request]`、`push branches: [main, master]`、`test continue-on-error =
  None`、`lint-only = True`
- 危險值矩陣（帶 `--force`，15 值含
  `/`、`/tmp/`、`//`、`//tmp`、`/tmp//x`、`/tmp/..`、`/tmp/../x`、`/tmp/x/..`、`/tmp/.`、`/./tmp`、`~`、`..`）→ 全 rc=1，`/tmp` 無殘骸

### Gate 3（regression）

```
有 venv：bats tests/  → rc=0  not ok=0   ok=506  skip=0
隱藏 venv：POC_PY=/nonexistent/bin/python bats tests/
                      → rc=1  not ok=38  ok=468  skip=0
                        缺 PoC venv=38   command not found=0
```

（38 條紅全在 `tests/v2.1-jev-poc.bats`；60 條純靜態測試在缺 venv 時仍綠 → 不會「全部紅」誤導。）

### Gate 4（V03 / V03.6 二審 4 輪）

| 輪 | 原因 | Verdict | 風險 | 計數 |
| --- | --- | --- | --- | --- |
| R1 | 初審 | approve-with-comments | low | 0 P0 / 1 P1 / 11 P2 |
| R2 | 回應 R1 11 條＋新增維運決策 | approve-with-comments | low | 0 P0 / 1 P1 / 7 P2 |
| R3 | 護欄邏輯改動（照 R2 自訂觸發條件）| approve-with-comments | low–medium | 0 P0 / 2 P1 / 4 P2 |
| R4 | 修 R3 的 `/tmp/` 繞道 | **approve-with-comments** | **low** | **0 P0 / 0 P1 / 3 P2** |

R4 明示「**可進入 §2.5 交付與 commit**」；3 個 P2 皆報告級（探針⑥ 補 2 個壞值＝已做、`$HOME --force` 邊界＝TMO-040、`""` 死碼分支＝無害）。

## 已知問題（已切票）

- **TMO-037**：markdownlint 債 246 處（MD013×184 等）→ lint-only 暫 `continue-on-error: true`，**清完必須移除該行**（`ci.yml` 與
  `CONTRIBUTING.md` 都已註明）
- **TMO-038**：探針①（縮排／子目錄 import ＋ module→dist 映射）、④（helper 清單硬編 → 新 helper 漏抓）、⑤（CI 契約語意、`workflow_dispatch` 鎖）
- **TMO-039**：首次真實 GitHub Actions 驗證（本機不可驗 runner 假設）
- **TMO-040**：護欄邊界（合法深層絕對路徑如 `$HOME` ＋ `--force` 仍會 `rm -rf`）

## 下一步建議

1. **驗收方式**：本地 `bats tests/` 應見 `506 ok / 0 not ok / 0 skip`；`POC_PY=/nonexistent/bin/python bats tests/` 應見
   `38 not ok / 468 ok` 且**沒有任何 127**。
2. **手動觸發首次 CI**（`workflow_dispatch` 已加）：GitHub → Actions → CI → Run workflow（master）。驗收看（a）test job 全綠（b）runner 的
   bats/python 版本假設（c）lint-only 以 annotation 呈現且不阻擋。**預估 5–10 分鐘**（含安裝依賴與全套 bats）。
3. **TMO-037 先做**（lint 債）→ 才能移除 `continue-on-error`，讓 lint 恢復把關。**預估 2–4 小時**（多為機械性改行長與末端換行）。
4. 風險提示：本機與 runner 環境不同（uv 可能不存在 → 走 `python3 -m venv` 退路，該路徑已由探針③真跑鎖住；但 GitHub 上的實際行為仍待 TMO-039 確認）。

## 反思

- **「有測試」與「測試會跑」是兩件事**：真正致命的是 CI 從未觸發（`branches: [main]` vs 預設分支 `master`）＋ `test` job 從未裝依賴 —— 一個字讓整套 209
  條測試整年沒跑。**最貴的債是「看起來有在防」的債**。
- **假綠不只一種**：`skip`（永遠不跑）與空過斷言（跑了但沒驗）本票各抓到一批；解法不是「補測試」而是**把假綠本身變成紅燈**（`本檔 skip 數必須 0`、不變式等號、`-ge 2` 防空過）。
- **缺環境要大聲紅、不要噪音**：38 條 127 會被誤讀成「測試壞了」；改成每條一條清楚的紅＋修復指令，才指得動人。
- **安全檢查要用「同義寫法矩陣」測，不是代表性值**：`/tmp` 擋住了、`/tmp/` 繞過去（`case` 的 `*` 可跨 `/`）—— 這是第 3 輪 reviewer 抓到的，我自己的探針⑥只測了代表值就給了假信心。
- **對抗性審查真的有效**：4 輪裡每一輪都抓到前一輪沒看到的東西（R1 抓到說明失真的 P1；R2 抓到新檔重犯同一個錯誤；R3 抓到護欄繞道；R4 給了 go-ahead 但補了覆蓋清單）。「一次過」不是目標，**能被反駁才是**。
- **我自己的失誤**：假突變（M10 awk 語法錯把檔案清空）、M17 未命中卻意外揭露探針③只是字串形狀、探針③第一版誤紅、`$status（` 全形括號 bug，以及最嚴重的一次 ——
  **用 `git checkout` 還原突變時誤刪整批未 commit 編輯**（靠 `cp` 備份重做；R3 從 diff 反向查出我漏補的兩處）。教訓：突變一律 `cp` 備份、禁 `git checkout`、改動清單逐檔
  grep 驗證（不抽樣）。
