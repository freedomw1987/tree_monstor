---
name: aws-codecommit-git-setup
description: AWS CodeCommit SSH 設定與常見錯誤排除
---


Last-verified: 2026-07-28
# AWS CodeCommit Git Setup

## 快速設定

```bash
# 確認 SSH 登入成功
ssh -T git-codecommit.ap-east-1.amazonaws.com

# 如果出現 "You have successfully authenticated" = 成功
```

## 常見錯誤

### "Repository does not exist" 但 SSH 認證成功

原因：remote URL 的 region 寫錯了（如 `ap-southeast-1` 而非 `ap-east-1`），或 IAM User 沒有該 repository 的權限。

檢查：
```bash
# 驗證 repository 存在
aws codecommit get-repository --repository-name YOUR_REPO --region ap-east-1

# 檢查 current remote URL
git remote -v

# 修正 URL（如果 region 錯）
git remote set-url origin ssh://git-codecommit.ap-east-1.amazonaws.com/v1/repos/YOUR_REPO
```

## SSH config 格式

```ssh-config
Host git-codecommit.*
  User YOUR_IAM_USER_ID（如 APKAZGGVGP6VXLIGUROB）
  IdentityFile ~/.ssh/id_rsa
```

注意：User 是 IAM User 的 SSH User ID，不是 AWS Account ID，也不是 region。Host pattern 用 `git-codecommit.*` 即可匹配所有 region。

## 建立新 Repository

```bash
aws codecommit create-repository \
  --repository-name lemontree_aws \
  --repository-description "Description" \
  --region ap-east-1
```

## 錯誤對照

| 錯誤訊息 | 原因 | 解決 |
|----------|------|------|
| Permission denied (publickey) | SSH key 未上傳到 IAM，或 config 錯誤 | 上傳 public key 到 IAM Console |
| Repository does not exist | URL region 錯或 repo 真的不存在 | `aws codecommit get-repository` 確認 + 檢查 URL |
| Authentication failed | IAM User 沒有 codecommit:* 權限 | 檢查 IAM Policy |

## URL 冇 repo name 時 (e.g. `.../v1/repos/` 結尾係空)

用戶可能會貼一個冇指定 repo name 嘅 URL, 例如:

```
ssh://APKAZGGVGP6VZXN4AXXD@git-codecommit.ap-east-1.amazonaws.com/v1/repos/
```

呢個 URL 結構唔完整, 唔可以 clone / push。要做嘅:

1. **問用戶 / 從 context 推斷 repo name** (例如個 project 叫 `llm-acp` 就用 `llm-acp`)
2. **`aws codecommit create-repository`** 建立新 repo (需要 `--region`, 因為 CLI default region 可能唔同):
   ```bash
   aws codecommit create-repository \
     --repository-name llm-acp \
     --repository-description "..." \
     --region ap-east-1
   ```
3. 用 `cloneUrlSsh` response 入面嘅 URL 設 remote:
   ```bash
   git remote add origin ssh://git-codecommit.ap-east-1.amazonaws.com/v1/repos/llm-acp
   ```

## 驗證 push 成功嘅方法（避免 false alarm）

`git push` 嘅 stdout "To ssh://..." 唔代表成功 — AWS CodeCommit 嘅 git-receive-pack 唔回 success message。要驗證有幾個方法，按可信度排序：

### ✅ 最可靠：`git clone` 完整 clone 一次

```bash
rm -rf /tmp/verify-clone
git clone ssh://git-codecommit.ap-east-1.amazonaws.com/v1/repos/<repo> /tmp/verify-clone 2>&1 | tail -5
# 如果有 "Receiving objects: 100% (N/N), done" + "Resolving deltas: 100%, done" = 成功
ls /tmp/verify-clone | head -5  # 確認有 files
```

### ✅ 次可靠：`git ls-remote`

```bash
git ls-remote origin
# 應該見到:  <commit-hash>  HEAD
#            <commit-hash>  refs/heads/main
```

### ⚠️ 唔可靠：`aws codecommit get-commit` / `list-branches`

**就算 push 真係成功，呢啲 command 都有可能返 `CommitDoesNotExist` / 空 list**：

| 失敗原因 | 解釋 |
|---|---|
| IAM User 冇 read permission | `david.chu` 可能只有 push 權限 (e.g. `AWSCodeCommitPowerUser` 寫入) 冇 read metadata |
| Region 唔啱 | 同上 Region 不一致陷阱 — `aws codecommit` CLI 默認 region 唔一定係 repo 嗰個 |
| Stale cache | CodeCommit metadata 有時 lag 幾秒，retry 一次可能得 |

**所以**：用 `git clone` / `git ls-remote` 驗證，唔好用 AWS CLI。如果一定要用 CLI，先確認 IAM 權限：

```bash
aws iam list-attached-user-policies --user-name <username>
# 至少要有 AWSCodeCommitReadOnly 或 AWSCodeCommitPowerUser
```

### 教訓案例 (2026-06-04)

頭先我見到 `aws codecommit get-commit` 返 `CommitDoesNotExist` 同 `list-branches` 返 `[]`，就以為 push 失敗，差啲 panic 重新做。後來 `git clone` 拎到 47 個 objects / 89KB，先確認 push 真係成功，係 `david.chu` IAM 冇 CodeCommit read 權限。

## Region 不一致陷阱

AWS CLI 嘅 `~/.aws/config` 通常 default region 設一個 (e.g. `ap-southeast-1`), 但用戶個 CodeCommit repo 喺另一個 region (e.g. `ap-east-1`)。**所有 codecommit CLI command 要顯式 `--region ap-east-1`**, 否則會撞 `RepositoryDoesNotExistException` 或者操作咗第個 region。
