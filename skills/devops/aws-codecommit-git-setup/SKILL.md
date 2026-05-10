---
name: aws-codecommit-git-setup
description: AWS CodeCommit SSH 設定與常見錯誤排除
---

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
