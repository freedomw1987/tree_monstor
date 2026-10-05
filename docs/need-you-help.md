# 需要你決定的事（trust mode 期間累積）

> trust mode run：2026-10-05 01:21–08:00（本地分支 `trust/2026-10-05-tmo-cleanup`）
> 規則：不中斷、不 push；遇爭議採保守預設並寫在這裡。

## NYH-1（✅ 已結案：用戶決定接受風險、不輪替）

- [x] ✅ **繼續做（2026-10-05 ask-me）**：撤銷並輪替 key。用戶到 OpenRouter 撤銷舊 key、產生新 key 並更新
  `skills/regression-guard/PoC/.env`（人工操作，Agent 無法代為撤銷）；更新後 Agent 複驗 `.env` sha256 已變、
  且新值未出現在任何被追蹤檔或本輪 diff。
  **抉擇理由（2026-10-05）**：session log 可能被同步／保存，保守視為已洩漏；輪替成本低（幾分鐘），
  而「不輪替」需長期承擔未知洩漏面。
  ✅ **backlog 對照：TMO-054**（2026-10-05 開票，人工項；狀態 `⏸️ 跳過（接受風險，2026-10-05）`）。

**事件**：02:41 做 TMO-045 的「反向驗證」時（故意把 `JEV_ENV_FILE` seam 改成半套實作，
確認探針咬得住），探針的 FAIL 訊息把**本機真實的 `OPENROUTER_API_KEY`** 印進了本次 session log
（開頭 `sk-or-v1-****…（前綴已遮罩）`，完整值在對話記錄中）。

**影響**：
- 沒有進 git（`.env` 被 gitignore、本輪也不 push）；洩漏面僅限「本次對話／session log」。
- 但 session log 可能被同步或保存 → 保守估計應視為已洩漏。

**最推薦**：到 OpenRouter 撤銷並重新產生該 key，再更新 `PoC/.env`。
（我沒有動 `.env` 內容；輪替前後 sha256 一致。）
**替代**：若該 key 本來就只在本機、你接受風險，可選擇不輪替。

### ✅ 結案紀錄（2026-10-05）｜決策＝接受風險、不輪替

用戶將 key 改放到系統環境變數（`~/.zshrc`）。Agent 複驗發現該值與 `PoC/.env` 的 key
**sha256 相同**（`6d5179cd…`）→ 只是搬存放位置、**未輪替**；原洩漏舊 key 仍有效，
且現存於 `.env` 與 `~/.zshrc` 兩處。用戶拍板：**接受此風險、不撤銷、保留現狀**。

- 存放點 `.env` / `~/.zshrc` / 系統環境變數：**維持不動**（舊 key 續用）
- `_load_api_key()` 讀取順序 env > `PoC/.env` > `~/.claude/...`（symlink 同一份）；目前實際來源＝系統 env
- 殘留風險：若 session log／dotfiles 備份外流，該 key 可被使用
- ✅ **backlog 對照：TMO-054 → `⏸️ 跳過（接受風險，2026-10-05）`**

<details><summary>（已作廢）原人工輪替 checklist，僅保留可追溯</summary>

> 現況基準 sha256：`706ef9601fc90c63ae589661e905c03655e34f62a1790ad8a519413f97de5028`
> 唯一要動的檔：`skills/regression-guard/PoC/.env`
> （`~/.claude/skills/regression-guard` 是 symlink 指向 repo，同一份檔，不必分開改）
> ⚠️ **全程不要把新 key 貼進對話**（會再洩進 session log）；只在本機終端操作。

- [ ] **① 撤銷舊 key**：開 <https://openrouter.ai/keys> → 找到 `sk-or-v1-…` 舊 key → `Revoke`/刪除。
- [ ] **② 產生新 key**：同頁 `Create Key` → 複製完整 `sk-or-v1-…`（**只顯示一次**）。
- [ ] **③ 更新本機 `.env`**（整行替換，保持權限 600）：

  ```bash
  cd /Users/davidchu/Sites/localhost/tree_monstor
  printf 'OPENROUTER_API_KEY=%s\n' '<貼上新key>' > skills/regression-guard/PoC/.env
  chmod 600 skills/regression-guard/PoC/.env
  ```

- [ ] **④ 驗證新 key 載入**（不印出完整值）：

  ```bash
  cd skills/regression-guard/PoC
  .venv/bin/python -c "from jev_oracle import _load_api_key; k=_load_api_key(); print('loaded:', bool(k), (k[:8]+'...') if k else '')"
  # 預期：loaded: True sk-or-v1...
  ```

- [ ] **⑤ 回報 Agent 完成** → Agent 複驗：舊 sha256 已變、`git status` 乾淨（`.env` 被 gitignore）、
  `git grep 'sk-or-v1-'` 追蹤檔查無真值，然後把 TMO-054 標 `done (2026-10-05)`。

</details>

## NYH-2

- [x] ✅ **繼續做（2026-10-05 ask-me）**：做成通則＋靜態鎖。**已完成（2026-10-05）**：
  ①`mask_secrets()` 上移共用 `tests/helpers/test-env.bash`（`tests/poc-clean-clone.bats` 的本地副本移除）；
  ②新靜態鎖 `scripts/ci/lint-probe-secrets.py`（鎖 4）：R1 真 `sk-or-v1-` 前綴／R2 碰 `_load_api_key`
  的檔必須有遮罩能力／R3 FAIL 訊息展開 `$output` 必過遮罩／R4 單一真相＋防空過下限；
  ③新探針 `tests/secret-masking.bats`（SM-1~5），含**反向實測**：真的讓 `CLEAN-POC-i` 失敗，
  斷言 bats 輸出不得含密鑰（實測輸出為 `值已遮罩：'sk-***MASKED***'`）。走 V03 二審。
  **抉擇理由（2026-10-05）**：NYH-1 的實際外洩就是這條缺失造成；只修單點無法防止同類探針再犯，
  而靜態鎖能把「不得印出密鑰」變成可回歸的規則。
  ✅ **backlog 對照：TMO-053**（2026-10-05 完成；狀態 `done (2026-10-05)`）。

**已結案**：探針 FAIL 訊息不得印出密鑰的通則已實作（見上），不再只靠單點遮罩。

## NYH-3

- [x] ✅ **繼續做（2026-10-05 ask-me）**：push `trust/2026-10-05-tmo-cleanup` 上 origin，讓 CI 真跑一次
  （`workflow_dispatch` 也可，但 push 分支最直接）。若 CI 紅 → 立即修到綠；若綠 → 回報並等你決定 merge。
  **抉擇理由（2026-10-05）**：這是本輪唯一「本機證明不了」的部分（bats 釘版後 `git clone` 安裝、
  ffmpeg step 雙平台、lint job 真擋）；代價僅是分支會上遠端（可事後刪）。
  ✅ **backlog 對照：已結案**（2026-10-05 複驗）——`trust/2026-10-05-tmo-cleanup` 已開 PR #3 並合併
  （`67c2c0e`），master 複驗綠燈（TMO-039／TMO-049／TMO-052 皆已 `done`）。

**影響**：本輪所有 commits 都在本地分支 `trust/2026-10-05-tmo-cleanup`，**沒有 push**
（trust 底線規則）。其中 TMO-044 / TMO-042 / TMO-041 動到 `.github/workflows/ci.yml`（CI 行為），
本輪只能做「本地等價驗證」，**無法在真 CI 驗證**。

**最推薦 A：push 這條分支讓 CI 真跑一次** — 原因：這是本輪唯一「本地證明不了」的部分
（bats 釘版後 git clone 安裝、ffmpeg step 雙平台、lint job 真擋）；代價：分支會上遠端（可事後刪）。
- **B：先不 push，等你把 verdict／P 項修完再一次 push** — 少一次 CI 噪音，但驗證時點延後。
- **C：不 push，改成你自己在本機 merge** — 零遠端風險，但 CI 語意永遠沒被真實驗證。

## NYH-4

- [x] ✅ **繼續做（2026-10-05 ask-me）**：改文件對齊現實。`skills/dav-wiki/SKILL.md` 的限制表那一列
  改為「未裝時該模組直接停並提示安裝指令（`exit 4`）」，與 `require_tool()` 實作一致；**不實作降級**。
  純文字修正，走 V03 二審後施工。
  **抉擇理由（2026-10-05）**：保留 TMO-025「抽不到檔一律大聲失敗、不得假成功」的紀律；
  降級模式會創造「部分成功」的模糊驗收面，成本（M）與風險都高於直接改文。
  ✅ **backlog 已同步**：TMO-035 狀態 `待決（NYH-4）` → `done (2026-10-05)`（見 `docs/backlog.md` 表下註腳）。

✅ **已結案（2026-10-05，TMO-035 ＋ TMO-053 合批、走 V03 二審）**：A 案施工完成——`SKILL.md` 限制表
改成「缺必要工具（poppler / ffmpeg / pandoc / python-pptx）＝該模組直接 `exit 4` ＋安裝提示」，
OCR（缺 tesseract 走 mock placeholder）為唯一例外；`wiki-ocr.sh` usage 同步（移除死常數
`EXIT_TOOLMISSING`）。**衍生 TMO-058**：`wiki-media-describe.sh` real 模式（Whisper / Vision）未實作，
**修前**失敗仍回 rc 0＝假成功；已從「缺工具就停」的承諾中**拆出另列**（不再算缺工具），行為修正另開票。
→ **已修（TMO-058，2026-10-05）**：real 未實作改 `exit 5`、單檔接回傳值、批次 fail-closed（任一失敗不得印 ✅）、
輸出寫入／output-dir 建立失敗改 `exit 6`；`--max-concurrency` 限正整數（`exit 1`；**TMO-060 起 `0` 亦合法＝無限制**，並正名為 `--batch-limit`）。
探針（**TMO-035／TMO-053 的**，非 TMO-058）：`tests/wiki-toolmissing-contract.bats`（WTM-1~9）＋ `tests/secret-masking.bats`（SM-1~5）。

以下為 2026-10-05 當時的提問原文（保留可追溯）：

> **當時的待決（TMO-035，文實矛盾）**：`skills/dav-wiki/SKILL.md:94-95` 寫「未安裝時降級為純文字模式」，
> 但三支腳本（`wiki-extract-media.sh` / `wiki-extract-video.sh` / `wiki-ocr.sh`）的 `require_tool()`
> 是硬 `exit 4`，**沒有降級路徑**。
>
> **最推薦 A：改文件對齊現實（只動 SKILL.md 文字，不動行為）** — 原因：零行為風險、矛盾立即消失；
> 代價：拿掉「降級」這個承諾（若你其實想要降級，就得選 B）。此案要走 V03 二審。
> - **B：實作降級模式**（缺工具 → 只出文字層 + 警告、exit 0）— 功能變更，要新探針＋新測試，工作量 M。
> - **C：維持現狀** — 不推薦：下次 reviewer 會再抓一次同一條。

**保守默認（trust 期間照此辦理）**：**不修改任何檔案**，只記錄在此（改 skill 語意需你點頭）。

## NYH-5

- [x] ✅ **繼續做（2026-10-05 ask-me）**：危險清單＋二次確認。①`$HOME` 本體、`/private/tmp`、`/usr`、
  `/etc` 等危險路徑 → 即使 `--force` 也拒；②`--force` 對其他自訂目錄需輸入目錄名二次確認（CI 以 `--yes` 豁免）；③新探針＋新測試（工作量 M）。
  **抉擇理由（2026-10-05）**：保留「自訂目錄」能力（先給空目錄的合法用法），只擋最常見手誤；
  選項 B（只允許空／像 venv）會破壞既有合法流程，選項 C 等於沒護欄。
  ✅ **已實作並經二審**：commit `b2a775b`（Round-1 `approve-with-comments`）＋ Round-2 修 1×P2/3×P3
  （大小寫變體 `/private/TMP` 繞道、刪前重驗 TOCTOU、文件舊數字）→ 探針 `tests/poc-venv-guard.bats` **10 條**。
  遺留缺口（不阻 merge）：`/Volumes/<碟>` 這種一層子項未入清單 → 已開 **TMO-056**。
  ✅ **backlog 已同步**：TMO-040 狀態 `待決（NYH-5）` → `doing (2026-10-05)` → `done (2026-10-05)`（見 `docs/backlog.md`）。

**✅ 已結案（TMO-040，2026-10-05）**：`setup-venv.sh` 的 `POC_VENV_DIR` guard 原本只擋 `/`、`/tmp/` 這類；
指到合法但危險的目錄（例：`$HOME`、`/private/tmp`，≥2 層絕對路徑）＋ `--force` 仍會 `rm -rf`。
現已加危險清單＋二次確認（commit `b2a775b` ＋ Round-2 補正），探針 10 條。遺留 `TMO-056`（容器一層子項）。

**最推薦 A：危險清單（`$HOME` 本體、`/private/tmp`、`/usr`…）＋ `--force` 需輸入目錄名二次確認** —
原因：保留自訂目錄能力，同時擋掉最常見手滑；代價：`--force` 互動語意改變（CI 用 `--yes` 需一併豁免）。
- **B：只允許「不存在」或「看起來像 venv（有 `pyvenv.cfg`／`bin/python`）」的目錄** — 更嚴，
  但會擋掉「先給一個空目錄」這種合法用法。
- **C：不動程式，只在 README 加警告** — 最便宜，但護欄等於沒有。

**保守默認（trust 期間照此辦理）**：**不修改**（破壞性路徑語意屬你的決策）——已由你於 2026-10-05 ask-me 拍板採 A 並實作。

## NYH-6

- [x] ✅ **繼續做（2026-10-05 ask-me）**：**兩件合併（方案 A）**。待實作：①在 `test` job 加一步
  `shellcheck -x -S style $(git ls-files '*.sh' '*.bash')`；②把 `Verify bash syntax` 改成自我列舉
  （或直接刪除，交給 shellcheck）。若 macOS runner 未預裝 shellcheck → 只在 ubuntu leg 跑，並在
  `docs/install-reference.md` 揭露「macOS leg 未涵蓋 shellcheck」。改 `ci.yml` 屬 V03.6（CI 語意變更）→ 走二審。
  **抉擇理由（2026-10-05）**：CI 首跑已證明「CI 與本機不等價」是真風險（macOS leg 靜默丟 31 條測試、
  bash 3.2 bug 本機看不到）；shellcheck 含語法檢查，一次補齊 TMO-049＋TMO-052 兩洞最省。
  ⚠️ **backlog 對照：TMO-049 與 TMO-052 皆為同一決策**（已在 `docs/backlog.md` 同步為 `done (2026-10-05)`，並附 CI 複驗證據）。
  **✅ 已實作（2026-10-05，`f600385`）**：`test` job 新增「ShellCheck every tracked shell file」步驟
  （自我列舉 `git ls-files '*.sh' '*.bash'`）；`Verify bash syntax` 也改成自我列舉後逐一 `bash -n`。
  macOS leg 以 `brew install shellcheck` 安裝（runner 未預裝）→ **待 CI 複驗**；若 macOS 裝不起來，
  會改成 ubuntu-only 並在本檔＋`install-reference.md` 揭露「macOS leg 未涵蓋 shellcheck」。
  守門探針：`tests/env-equivalence.bats` 的 `ENV-EQ-18`。

**待決（TMO-049／TMO-052，CI 覆蓋面）**：①CI **完全沒跑 shellcheck**（Gate 2 只在開發者本機跑），
所以「本機 Gate 2 全綠」不等於 CI 會擋 shellcheck 類問題；②CI 的 `Verify bash syntax` 步驟只 glob
`skills/dav-wiki/scripts/*.sh`（硬編子集），漏掉 `install.sh`、`lib/**`、`scripts/ci/*.sh`、`skills/*/PoC/*.sh`、
`tests/helpers/*.bash`。緩解：ENV-EQ-13 的靜態宣告鎖跑在 CI 內，且 `tests/install.bats` 真的會執行 `install.sh`，
所以不是完全裸奔。

**最推薦 A：兩件合併——在 `test` job 加一步 `shellcheck -x -S style $(git ls-files '*.sh' '*.bash')`，
並把 `Verify bash syntax` 改成自我列舉（或直接刪除，交給 shellcheck）** — 原因：一次補齊兩洞、
且 shellcheck 已含語法檢查；代價：需 push 才能驗證 runner 是否預裝 shellcheck（若 macOS runner 沒有，
可只在 ubuntu leg 跑並在文件揭露「macOS 未涵蓋」）。
- **B：只加 shellcheck、保留原 `bash -n` 步驟** — 冗餘但保守，零風險（多花幾秒）。
- **C：維持現狀（只留 TMO-049/052 記錄）** — CI 對 installer 核心永遠只有「被 tests 執行到才擋」。

**保守默認（trust 期間照此辦理）**：**不修改 CI**（需 push 才驗、且 trust 禁 push），只記錄在此。

## NYH-7

- [x] ✅ **繼續做（2026-10-05 ask-me）**：修 handbook 那一條（`../../skills/regression-guard/SKILL.md`
  → `../../../skills/regression-guard/SKILL.md`），走一次 V03 Reviewer 二審。歷史交付物那 2 條**不動**
  （append-only 慣例）。
  **抉擇理由（2026-10-05）**：handbook 是 SOP 文件、是使用者真的會點的連結；純文字修正成本極低，
  而留著壞連結會讓後續讀者以為該 skill 不存在。
  ⚠️ **backlog 對照：TMO-051**（已在 `docs/backlog.md` 同步為 `done (2026-10-05)`）。
  **✅ 已實作（2026-10-05，`f600385`）**：`docs/sop/handbook/2.3-execution.md` 的連結已改為
  `../../../skills/regression-guard/SKILL.md`（從 `docs/sop/handbook/` 解析到 repo 根 ✓，已用
  `pathlib` 實測 `exists()==True`）。歷史交付物那 2 條依 append-only 慣例不動。

**待決（TMO-051，docs 連結）**：`docs/sop/handbook/2.3-execution.md` 有一條壞連結
`../../skills/regression-guard/SKILL.md`（從 `docs/sop/handbook/` 算只到 `docs/`，應為 `../../../skills/...`）。
另 2 條壞連結在 `docs/deliverable/2026-09-26-reduce-deliverables.md`（歷史交付物，append-only 慣例不動）。

**最推薦 A：修 handbook 那一條（加一層 `../`）並走 V03 二審** — 原因：handbook 是 SOP 文件、
是使用者實際會點的連結；代價：要走一次 Reviewer（純文字修正，成本低）。
- **B：連 2 條歷史交付物的連結一起修** — 一次清乾淨，但違反本 repo 對歷史文件的 append-only 慣例。
- **C：不修，只保留 ticket** — 成本 0，但連結繼續壞。

**保守默認（trust 期間照此辦理）**：**不修改 handbook**（V03 需二審），只記錄在此。
