# CI Integration — dav-developer（**本機跑**）

> **狀態**：✅ 2026-09-28 落地（commit 83336eb + workflow + 本 SOP）
> **改動**：🔄 2026-10-27 —— **本 repo 唔再喺 GitHub Actions 跑**（用戶決策：「dav-developer 的 ci 在本地跑都得，不用在 github 上跑」）
> **範圍**：把 `run_pipeline.sh` ＋ bats 探針整合進**本機 runner**，保留 return code gate 語義

---

## 1. 本 repo：一條指令本機跑

```bash
# 由 repo 根目錄行（runner 喺 skill 入面，跟安裝一齊到位）
bash skills/dav-developer/PoC/run_ci.sh list          # 列 subcommand
bash skills/dav-developer/PoC/run_ci.sh probes       # 跑探針（唔使 API key）
bash skills/dav-developer/PoC/run_ci.sh pipeline US-101
bash skills/dav-developer/PoC/run_ci.sh matrix        # 預設 US-101 / US-M62 / US-M63
bash skills/dav-developer/PoC/run_ci.sh cleanup-scan  # 文件減法盤點
bash skills/dav-developer/PoC/run_ci.sh all           # probes → matrix → cleanup-scan
```

### Subcommand 對照（原本 GH workflow 嘅 4 個 job → 而家 4 個 subcommand）

| 原本 job | 而家 | 用途 | 需 API key |
|---|---|---|---|
| `bats` | `probes` | 跑 `skills/dav-developer/tests/v2.1-jev-poc.bats` | ❌ |
| `pipeline` | `pipeline` | 跑 `run_pipeline.sh <story>` | ✅（本機環境變數 `OPENROUTER_API_KEY`）|
| `aggregate-matrix` | `matrix` | 跑多個 story ＋ 匯總 `matrix-summary.md` | ✅ |
| `cleanup-scan` | `cleanup-scan` | 跑 `docs/cleanup/cleanup-scan.py` | ❌ |

### Return code（gate 語義同原本 workflow 一致）

| 退出碼 | 含義 | 行為 |
|---|---|---|
| `0` | green | 通過 |
| `2` | yellow | 警告（唔擋）|
| `1` | red | 擋 |
| `3` | 用法／環境錯誤（缺 key、缺 venv、缺檔案）| 擋 |

> ⚠️ **verdict 由 batch report JSON 讀，唔靠 `run_pipeline.sh` 嘅離開碼**：
> `run_pipeline.sh` 接住 M4 嘅 return code（0/1/2）但最後以 `echo` 收尾 → **離開碼永遠係 0**。
> → 原本 workflow 其實捉唔到紅燈；`run_ci.sh` 改讀 `batch_report.overall_health`（同原本 aggregate job 一致）。

### 環境變數

| 變數 | 用途 | 預設 |
|---|---|---|
| `OPENROUTER_API_KEY` | 真 API key（`pipeline`／`matrix` 必需；冇 → rc 3）| — |
| `RG_REPORT_DIR` | 報告輸出目錄 | `<repo>/tmp/rg-reports`（已 gitignore）|
| `RG_CI_MOCK_VERDICT` | **只供探針用**嘅 seam：`green`／`yellow`／`red` → 唔真跑 pipeline，直接走 rc mapping（會大聲印「MOCK MODE」）| 未設 |

### 報告產物

| 檔案 | 內容 |
|---|---|
| `<RG_REPORT_DIR>/<story>.json` | batch report（`batch_report.overall_health` ＋ 4 維度）|
| `<RG_REPORT_DIR>/<story>.md` | 人讀版 Markdown 報告 |
| `<RG_REPORT_DIR>/matrix-summary.md` | 矩陣匯總（`## Per-Story Results` 表）|

---

## 2. 目標專案：想用 GitHub Actions（可選）

> ⚠️ **呢一節只係俾「安裝咗 tree_monstor 嘅目標專案」參考**；本 repo 自己**唔用**（已改本機跑，見 §1）。

目標專案如果想喺自己 repo 跑同一套 Jev CI（需要跨 OS 偵測 ＋ PR 上自動出報告），可以照以下步驟自己開 workflow：

### 2.1 Secrets 設定

CI 跑 pipeline 需要 `OPENROUTER_API_KEY`：

```bash
# 一次性設定
gh secret set OPENROUTER_API_KEY --body "sk-or-v1-..."
```

或在 GitHub UI：
- Settings → Secrets and variables → Actions → New repository secret
- Name: `OPENROUTER_API_KEY`
- Value: `<你的 OpenRouter key>`

### 2.2 Branch Protection Rules

要讓 CI gate 真的擋 merge，要設 branch protection：

```bash
# 啟用 required status check + 限制 pipeline job
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/OWNER/REPO/branches/master/protection \
  -F required_status_checks[strict]=true \
  -F required_status_checks[contexts][]="pipeline" \
  -F required_status_checks[contexts][]="bats" \
  -F enforce_admins=true \
  -F required_pull_request_reviews[dismiss_stale_reviews]=true \
  -F required_pull_request_reviews[required_approvals]=1 \
  -F restrictions=null
```

或 GitHub UI：
- Settings → Branches → Add rule
- Branch name pattern: `master`
- ✅ Require status checks to pass before merging
  - Search: `bats` + `pipeline`
- ✅ Require pull request reviews before merging（1 approval）
- ❌ Do not allow bypassing the above settings

### 2.3 手動觸發 + 自訂 story_id

```bash
# UI：Actions → 你的 workflow → Run workflow
# 填 inputs:
#   story_id: US-201
#   use_stale_test: false

# CLI:
gh workflow run <你嘅-workflow>.yml \
  -f story_id=US-201 \
  -f use_stale_test=false
```

### 2.4 Artifact 與 PR Comment

CI 跑完可以：

1. **上傳 artifact**：`regression-report-<story_id>` 包含 `report.json` ＋ `report.md`（30 天保留）
2. **PR 自動 comment**：貼 markdown report（人讀格式）

下載 artifact：

```bash
gh run download <run-id> -n regression-report-US-101
```

---

## 3. 本機 debug

CI／本機 runner 跑掛的時候，直接重現：

```bash
# 1. 重跑探針
bats skills/dav-developer/tests/v2.1-jev-poc.bats

# 2. 重跑 pipeline（要 OPENROUTER_API_KEY 環境變量）
OPENROUTER_API_KEY=sk-or-v1-... \
REGRESSION_REPORT_PATH=/tmp/debug-report \
  bash skills/dav-developer/PoC/run_pipeline.sh US-101
echo "exit: $?"

# 3. 用 runner 跑（會印 verdict → rc 對照）
OPENROUTER_API_KEY=sk-or-v1-... \
  bash skills/dav-developer/PoC/run_ci.sh pipeline US-101
echo "rc: $?"

# 4. 檢查產物
ls -la /tmp/US-101-run.json /tmp/debug-report.{json,md}
```

---

## 4. 已知限制 ＋ 誠實記錄代價

| 限制 | 影響 | 緩解 |
|---|---|---|
| **cleanup-scan 冇自動每週跑**（原本係 workflow 嘅 `cron` job）| 文件減法盤點要人手／自己排程先會做 | `bash skills/dav-developer/PoC/run_ci.sh cleanup-scan`；或自己用 `cron`／`launchd` 排程 |
| **跨 OS／跨版本差異冇人偵測**（本機 runner 只係一部機）| 同 TMO-084 記錄嘅 CI 降級代價一致 | repo 嘅**通用** CI（`.github/workflows/ci.yml`）仍然跑（探針／lint／mutant）→ 通用部分照舊有跨環境偵測 |
| **真 API key 只喺本機** | 冇 secret 洩漏風險，但要自己 export | `OPENROUTER_API_KEY` 放喺本機環境變數／`.env`（已 gitignore）|
| **冇 artifact／PR comment** | 本機冇 30 天留存、唔會自動贴 PR | 報告落 `<RG_REPORT_DIR>`；要分享就直接貼檔 |
| **`run_pipeline.sh` 離開碼永遠係 0** | 單靠佢做唔到 gate | `run_ci.sh` 改讀 batch report JSON 嘅 `overall_health`（§1）|

---

## 5. 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|---|---|---|---|
| v1.0 | 2026-09-28 | 初版：workflow ＋ branch protection SOP ＋ return code gate | TMO-015 收尾 |
| v1.1 | 2026-10-27 | **刪 GitHub Actions workflow，改本機 runner**（`run_ci.sh`：probes／pipeline／matrix／cleanup-scan）；保留目標專案用 GH Actions 嘅參考章節 | 用戶決策：「dav-developer 的 ci 在本地跑都得，不用在 github 上跑」；順帶修正兩個原 workflow 嘅靜默 bug（pipeline 離開碼永遠 0 → 捉唔到紅燈；cleanup-scan `--json` 結構讀錯 → 計數永遠讀唔到）|
