# TMO-039 首次真實 GitHub Actions 驗證：34 紅 → 4 紅的真因與修復（本機假綠）

- **日期**：2026-10-04
- **Backlog ID**：TMO-039（新增 TMO-042 / TMO-043；修正 TMO-029 deliverable 的錯誤歸因）
- **作者**：pi（david 的 agent）
- **狀態**：待用戶驗收（第三輪修復已 push，CI run 結果見 §測試驗收證據 → Gate 4）

## 摘要

第一輪（run `37213235272`）：CI 從未真的跑過 → 首跑 ubuntu **34 紅**，但本機同時 506/506 全綠。
六類真因修完後第二輪（run `37215560458`）：**34 紅收斂到 4 紅**，剩下的 4 紅在**本機任何驗證下都是綠的**。

第三輪（本輪）把最後 4 紅拆成 2 類真因：

| # | 真因 | 紅燈 | 為什麼本機看不到 |
| --- | --- | --- | --- |
| 7 | 3 條探針會呼叫**真 Jev oracle**（OpenRouter）| ubuntu `M5-runtime-b` / `M6-g` / `M6.1-c` | 本機 shell 有 `OPENROUTER_API_KEY`、`PoC/cache/` 有 8233 筆暖快取（**被 gitignore**）；CI 兩者皆無 → `RuntimeError` |
| 8 | **ffmpeg 8 移除了 `-vsync`**（brew 版）；同旗標也在**產品腳本**裡 | macos `AC-V4` | 本機 ffmpeg 7.1、ubuntu apt 6.x 都還接受 `-vsync` |

第 7 類是第 5 種假綠「**依賴本機狀態**」——它躲過了 clean clone、躲過了 bash 5.3、躲過了我所有本機驗證，
只有真的在別人的 runner 上跑才會現形。

## 變更清單（第二／三輪）

| 檔案 | 變更 |
| --- | --- |
| `skills/regression-guard/PoC/jev_oracle.py` | 新增 `JEV_CACHE_DIR` 環境變數 seam（預設仍是 `PoC/cache`）→ 測試可指向版控 fixture |
| `skills/regression-guard/PoC/fixtures/US-101-run.json`（新，版控）| 離線用 run json（9 筆 fail、無絕對路徑）|
| `skills/regression-guard/PoC/cache-fixtures/`（新，版控）| 1 筆 Jev 回應 fixture + `README.md`（用途／重錄步驟／防線）|
| `skills/regression-guard/PoC/sandbox_runner.py` | **P2-1**：抽出 `_sandbox_relative_path()`，`..` 相對路徑不再逃出 sandbox（原碼會把複本寫到 repo 上層）|
| `skills/dav-wiki/scripts/wiki-extract-video.sh` | **產品 bug**：`-vsync vfr` → `-fps_mode vfr`（ffmpeg 4.3+）|
| `.github/workflows/ci.yml` | `bash -n` 從 3 支寫死 → glob 掃全部 9 支腳本 |
| `tests/v2.1-jev-poc.bats` | `M5-runtime-b` 改注入 stub；`M6-g`/`M6.1-c` 改讀版控 fixture + 離線快取；新增 `M6.3-l`；移除已無用的 `make_us101_run` |
| `tests/wiki-video-audio.bats` | `AC-V4` 改 `-fps_mode`；新增 `AC-V11`（產品腳本禁用已移除旗標）|
| `tests/poc-clean-clone.bats` | 新增 `CLEAN-POC-f`（oracle 探針離線可跑）、`CLEAN-POC-g`（CI glob 語法檢查）；`CLEAN-POC-b` 補防空過、`CLEAN-POC-c` regex 修正假陽性 |
| `tests/wiki-cleanup.bats` | **二審 P2-3**：靜態鎖補 3 項防空過（檔案存在／≥50 行／含 `deprecated`），否則改名或搬走後它會永久綠 |
| `CONTRIBUTING.md` | 加「本機綠 ≠ CI 綠」的 oracle 段落、CI 等價指令、ffmpeg 8 註記 |
| `docs/backlog.md` | TMO-039 第二輪詳細、狀態定義補 `doing`/`blocked`、新增 TMO-042 / TMO-043 |

## 測試驗收證據（4 Gates）

依 `docs/sop/gates.json`，四個 Gate 的 `mandatory_phrase` 已於對話中逐條引用（Gate 1 TDD 先紅後綠／
Gate 2 lint 語法／Gate 3 regression／Gate 4 reviewer 原文回傳）。

### Gate 1（TDD：先紅後綠）

| 探針 | 修前（紅） | 修後（綠） |
| --- | --- | --- |
| `M6.3-l`（相對 `..` 不得逃出 sandbox）| 紅，且**實測外洩**檔案到 `Sites/localhost/tmp/US-M63-leak-*.py`（已清除）| ok |
| `AC-V11`（產品腳本禁 `-vsync`）| 紅（`git worktree add HEAD` 跑新探針對舊碼）| ok |
| `CLEAN-POC-f`（oracle 探針離線）| 紅（清成 CI env 後 3 條 oracle 探針紅）| ok |
| `CLEAN-POC-g`（CI glob 語法檢查）| 紅（`ci.yml` 只有 3 支寫死）| ok |
| `M5-runtime-b` / `M6-g` / `M6.1-c` | CI 紅（`AssertionError` / `FAIL: … CLI failed`）| ok（stub + 離線 fixture）|

### Gate 2（lint / syntax）

- `bash -n` × **全部 9 支** dav-wiki 腳本 → rc=0（同時把 CI 那一步改成 glob）
- `shellcheck -x skills/dav-wiki/scripts/wiki-cleanup.sh` → rc=0；
  `wiki-extract-video.sh` 有**既有** `SC2329`（`probe_metadata` 死碼，HEAD 版同樣有 → TMO-043）
- `python -m py_compile`（`jev_oracle.py`、`sandbox_runner.py`）→ rc=0
- `markdownlint-cli2`：新增 `cache-fixtures/README.md` → 0 issue；`CONTRIBUTING.md` → 0 issue；
  `docs/backlog.md` **53 → 61**（+8，本 repo backlog 既有 49 處長行慣例；TMO-037 統一清）
- 全套 lint 總數 **273 錯 / 66 檔**（建立 TMO-037 時記為 246，差額來自後續新增文件 → TMO-037 數字已更新）

### Gate 3（regression）

| 環境 | 結果 |
| --- | --- |
| **CI 等價**：`PoC/.env` 與 8233 筆暖快取**移走** + `env -u OPENROUTER_API_KEY HOME=/tmp/fakehome` | **517 ok / 0 not ok / 0 skip** |
| 本機 bash 3.2（`/bin/bash` 3.2.57）| **517 ok / 0 not ok / 0 skip** |
| 本機 bash 5.3（`PATH=/opt/homebrew/bin:$PATH`，≈ubuntu 5.2）| **517 ok / 0 not ok / 0 skip** |
| clean clone（從 commit `2437914` `git clone` 到 `/tmp/cc4`，路徑含 symlink）| **517 ok / 0 not ok / 0 skip** |

> 第一列是本輪最重要的證據：把本機的 oracle 依賴全部拔掉後仍全綠，代表那 3 條探針**不再靠我的機器**。

### Gate 4（reviewer）

### V03.6 分類與放寬申報（含 reviewer 補正）

- **新增探針（嚴格化）**：`M6.3-l`、`AC-V11`、`CLEAN-POC-f`、`CLEAN-POC-g`、`wiki-cleanup` 靜態鎖防空過。
- **條件放寬（明示 1 處）**：`CLEAN-POC-c` regex 由 substring 改為需邊界（消假陽性）→ 已附前後輸出與敏感度測試。
- **放寬申報補正（reviewer P2-E）**：`M5-runtime-b`/`M6-g`/`M6.1-c` 由「真 API」改「stub／版控 fixture」，
  依 V03.6 條件①「讓原本會 fail 的情況改為 pass」的字面定義**亦屬放寬語意**，本輪原本只寫「語意替換」→ 現補申報。
  不視為弱化的理由：三者被驗的性質未變（stale 偵測／CLI 端到端＋cache-key 推導），產品邏輯壞掉仍會紅；
  此為「移除環境依賴」而非「削弱斷言」。

### Reviewer 判決（round 3）

- **`approve-with-comments`：0 P0 / 0 P1 / 6 P2**（原文回傳於對話，未經改寫）。
- 前輪 5 個 P2：**全數已收尾**（P2-1 sandbox 逃逸、P2-2/P2-3 防空過、P2-4 檔數→本輪再修正計數、P2-5 狀態定義）。
- 本輪 6 P2 去向：P2-A（計數一致性）**本 commit 已修**；P2-F（`-fps_mode` 版本註解）**本 commit 已修**；
  P2-E **已補申報**（上方）；P2-B（`PoC/.env` 未被現行機制中和）、P2-C（無探針防 `git add -f .env`／暖快取）、
  P2-D（`CLEAN-POC-f` 是定點鎖，非通則）→ 切票 **TMO-045**；reviewer 另指出的 CI `Verify Python heredoc syntax`
  恆綠步驟 → 切票 **TMO-044**。
- 唯讀 reviewer 的限制已由其自行聲明（無 git/bats 執行權，以凍結檔內容 + 我提供的原始輸出交叉驗證）。
- Reviewer 判決與真實 CI run 結果：§下一步建議 前的補記（原文回傳，未經我改寫）。
- **真實 CI（第三輪，commit `2437914`）**：run `37218446930` → **conclusion: success**；
  `Test on ubuntu-latest` ✓、`Test on macos-latest` ✓（macos log 可見 `ok 510 AC-V4` = ffmpeg 8 修好）、
  `Markdown lint` ✗ 但 job 級 `continue-on-error: true`（TMO-037）。
- **clean clone（從 commit `2437914` clone 到 `/tmp/cc4`）**：**517 ok / 0 not ok**。

## 已知問題

- **TMO-037**：markdownlint 債（2026-10-04 實測 273 錯 / 66 檔；`lint-only` 仍 `continue-on-error: true`，清完須移除）。
- **TMO-041**：bash 5.x 變體未自動化（本輪仍以 `brew bash` 手動跑）、`bats` 未釘版、其他狀態依賴未掃完。
- **TMO-042**（新）：ffmpeg 版本漂移（apt 6.x vs brew 8.x）——下一批移除無法預期。
- **TMO-043**（新）：`wiki-extract-video.sh:67 probe_metadata()` 死碼（SC2329），本輪未動以免擴大範圍。
- **TMO-044**（新，reviewer 發現）：`ci.yml` 的 `Verify Python heredoc syntax` 是**恆綠步驟**（開不存在的
  `wiki-cleanup.yaml` + `|| true`，且 PYEOF 計數判斷式會對正常值發假警告，CI 實測輸出 2 次 `::warning::` 但 step 仍 success）。
- **TMO-045**（新，reviewer P2-B/C/D）：oracle 假綠的殘餘護欄——`PoC/.env` 未被 `CLEAN-POC-f` 中和、
  無探針擋 `git add -f .env`／暖快取進版控、`CLEAN-POC-f` 屬定點鎖（新 oracle 依賴仍只有 CI 兜底）。
- **reviewer P2-3 已收尾**：`wiki-cleanup.bats` 靜態鎖補防空過（附「指向不存在檔案／空殼檔／真的把 bug 種回去」三種紅燈證據）；
  仍只擋 `${#arr[@]}` 形狀（行為面由同檔 20 條測試覆蓋）。
- 本機無 ubuntu 容器（docker daemon 未啟動）→ clean clone + bash 5.3 + 拔掉 oracle 是最接近的等價。

## 下一步建議

1. **驗收方式（最推薦）**：看 GitHub Actions 上本 commit 的兩個 test job 是否**綠**
   （`gh run list --workflow=CI --limit 1`；`Markdown lint` 紅屬 TMO-037，不阻擋）。
   - 預估時間：**約 10–15 分鐘**（push 後全矩陣）。
   - 風險提示：若仍有紅，最可能是 macOS ffmpeg 8 的**其他**已移除旗標（TMO-042）或 apt bats 1.10 行為差異；
     請把紅燈清單給我，我會照同一套「先寫紅探針再修」處理。
2. 綠燈後：把 TMO-039 收成 `done`（附 run id），並把 TMO-041／TMO-042 排進下一輪。
3. 若要把「本機假綠」徹底關掉：讓 Gate 3 固定跑「拔掉 key/暖快取 + bash 5.x + clean clone」三件套（本輪已手動跑，
   可寫成 `scripts/gate3-ci-parity.sh`）；需要 Docker 才能真的跑 ubuntu 容器。

## 反思

- **假綠第 5 型：依賴本機狀態**。前 4 型（skip、空過斷言、未版控素材、路徑寫法）我都已經有防線，
  這一型躲過了所有本機驗證——本機有 key、有暖快取，於是**永遠不會紅**。
  教訓：驗證的維度不是「跑幾次」，而是「有沒有把環境換成別人的」。
- **探針紅了，不一定是探針的錯**。`-vsync` 看起來像「只有 CI 環境紅」，實際同旗標就在產品腳本
  `wiki-extract-video.sh:141`；P2-1 的 `..` 逃逸也一樣。**紅燈要先問「產品有沒有同樣的問題」**。
- **空過的探針比沒有探針更危險**：`M6.3-l` 第一版寫出來就「綠」——因為它只驗了「原檔沒被改壞」，
  而 pathlib 的逃逸是**往外複製**，不會改壞原檔。是「故意留一個檔名搜尋外洩」才讓它真的咬。
  與 reviewer P2-2/P2-3 同一個家族：**沒有防空過條件的探針，遲早會變裝飾品**。
- **等價環境要花錢也要花時間，但值得**：本輪為了 CI 等價，把 8233 筆快取搬走、`HOME` 換成空目錄、
  用 `brew bash` 5.3 跑第二遍（本機 §Gate 3 共 3 種環境）。這成本換到的是：**第一次在 push 前就知道 CI 會不會綠**。
- **切票是誠實的一部分**：`ffmpeg` 版本漂移（TMO-042）與死亡碼（TMO-043）我沒有順手改掉假裝乾淨，
  而是明寫「看到但沒做」；同時把「新增探針」與「放寬 regex」在 V03.6 語意下分開申報。