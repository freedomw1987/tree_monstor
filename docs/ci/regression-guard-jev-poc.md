# CI Integration — regression-guard Jev PoC

> **狀態**：✅ 2026-09-28 落地（commit 83336eb + workflow + 本 SOP）
> **範圍**：把 `run_pipeline.sh` + bats 探針整合進 GitHub Actions，加 return code gate

---

## 1. Workflow 結構

`.github/workflows/regression-guard-jev-poc.yml`：

| Job | 用途 | 觸發條件 |
|---|---|---|
| **bats** | 跑 25 個探針（不靠 API） | push / PR / manual dispatch |
| **pipeline** | 跑 `run_pipeline.sh US-101`（真 API） | push / PR / manual dispatch |

兩個 job 是 `pipeline` needs `bats`（先探針過、再跑 pipeline）。

### Triggers

- **push** 到 `master` / `main`（paths filter 限 `skills/regression-guard/**` + `docs/ac/**` + workflow 本身）
- **pull_request** 到 `master` / `main`（同 paths filter）
- **workflow_dispatch**（手動觸發 + 帶 `story_id` 參數）

### Return code 對照

| `run_pipeline.sh` 退出碼 | 含義 | GitHub Actions 行為 |
|---|---|---|
| `0` (green) | Jev 判 overall_health=green | ✅ 通過 |
| `2` (yellow) | Jev 判 overall_health=yellow | ⚠️ warning（不擋 merge）|
| `1` (red) | Jev 判 overall_health=red | ❌ error，擋 merge |

對應 `batch_report.main()` return code 邏輯：

```python
if report.overall_health == "red":
    return 1
if report.overall_health == "yellow":
    return 2
return 0
```

---

## 2. Secrets 設定

CI 跑 pipeline 需要 `OPENROUTER_API_KEY`：

```bash
# 一次性設定
gh secret set OPENROUTER_API_KEY --body "sk-or-v1-..."
```

或在 GitHub UI：
- Settings → Secrets and variables → Actions → New repository secret
- Name: `OPENROUTER_API_KEY`
- Value: `<你的 OpenRouter key>`

---

## 3. Branch Protection Rules

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

---

## 4. 手動觸發 + 自訂 story_id

```bash
# UI：Actions → regression-guard Jev PoC → Run workflow
# 填 inputs:
#   story_id: US-201
#   use_stale_test: false

# CLI:
gh workflow run regression-guard-jev-poc.yml \
  -f story_id=US-201 \
  -f use_stale_test=false
```

---

## 5. Artifact 與 PR Comment

CI 跑完會：

1. **上傳 artifact**：`regression-report-<story_id>` 包含 `report.json` + `report.md`（30 天保留）
2. **PR 自動 comment**：在 `$GITHUB_STEP_SUMMARY` 貼 markdown report（人讀格式）

下載 artifact：

```bash
gh run download <run-id> -n regression-report-US-101
```

---

## 6. 本機 debug

CI 跑掛的時候，本機直接重現：

```bash
cd skills/regression-guard/PoC

# 1. 重跑 bats
bats ../../tests/v2.1-jev-poc.bats

# 2. 重跑 pipeline（要 OPENROUTER_API_KEY 環境變量）
REGRESSION_REPORT_PATH=/tmp/debug-report ./run_pipeline.sh US-101
echo "exit: $?"

# 3. 檢查 /tmp 產物
ls -la /tmp/US-101-run.json /tmp/debug-report.{json,md}
```

---

## 7. 已知限制

- **Workflow 路徑 filter**：push/PR 只在 `skills/regression-guard/**` 或 `docs/ac/**` 變動時觸發；改 SKILL.md 全文也會觸發（路徑覆蓋）
- **單 story_id**：目前手動觸發只支援 1 個 story_id；多 story 並行留給「真實 PENDING US 多個同時跑」時再 matrix
- **Artifact 30 天**：超過 30 天自動清；長期歸檔需改用 S3 / Pages
- **No PR review comment（自動）**：目前只上傳到 `$GITHUB_STEP_SUMMARY`（要看要進 Actions UI）；要自動 comment PR 需加 `gh pr comment` 步驟
- **Branch protection 沒強制啟用**：需 admin 手動設（見 §3）；未設的 repo CI 跑紅色不會擋 merge

---

## 8. 變動歷史

| 版本 | 日期 | 變動 | 為什麼 |
|---|---|---|---|
| v1.0 | 2026-09-28 | 初版：workflow + branch protection SOP + return code gate | TMO-015 收尾 |
