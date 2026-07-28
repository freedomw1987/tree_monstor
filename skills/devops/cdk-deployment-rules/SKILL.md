---
name: cdk-deployment-rules
description: AWS CDK 部署規則 — 只對 CDK 修改，嚴禁 CLI 手動建立生產資源。所有資源必須由 CDK 管理。
trigger: 任何 CDK 部署、生產環境變更、或 AWS 資源操作之前
applicability: generic-pattern
---


Last-verified: 2026-07-28
# CDK 部署規則

## 核心原則

> **所有生產基礎設施變更，必須只通過 CDK 進行。CLI 只用於查詢、smoke test、或臨時診斷，絕對不用來建立或修改生產 resource。**

### 為什麼要 CDK-only
- CLI 手動修改會造成 drift，CDK 無法追蹤
- 下次 `cdk deploy` 可能覆蓋或失敗
- 難以追踪誰改了什么、什麼時候改的
- 用戶明確拒絕 CLI drift

---

## 鐵則

### 1. 禁止 CLI 生產資源
```bash
# ❌ 嚴禁
aws rds create-db-instance ...
aws ec2 create-security-group ...
aws ecs update-service ...
aws secretsmanager put-secret-value ...
aws route53 change-resource-record-sets ...

# ✅ 正確
# 這些都應該寫進 CDK stack，然後 cdk deploy
```

### 2. 所有資源必須 CDK 管理
- VPC、Subnet、Route table → CDK import 或 new
- RDS → CDK new 或 import
- ECS Cluster、Service、Task Definition → CDK new
- ALB、Target Group、Listener → CDK new
- Security Group → CDK new
- Secrets Manager → CDK new 或 import
- Route53 Record → CDK new
- ACM Certificate → CDK new

### 3. 部署前必須 synth
```bash
cdk synth --quiet
```
確認無 error 才能 deploy。

### 4. 部署失敗怎麼辦
1. 檢查 CloudFormation events：`aws cloudformation describe-stack-events --stack-name <name> --region ap-east-1`
2. 找到第一個失敗的 resource
3. **回到 CDK 修正**（不是用 CLI 補）
4. 重新 `cdk synth` → `cdk deploy`
5. 重複直到成功

### 5. 已存在的 CLI drift 處理
- 發現有 CLI 建立/修改的資源
- 評估是否該刪除、重建、或 import 到 CDK
- **千萬不要留著 CLI 資源假裝是 CDK 的一部分**

### 6. 刪除 CDK Stack
```bash
# 先查 status
aws cloudformation describe-stacks --stack-name <name> --region ap-east-1

# 如果 ROLLBACK_COMPLETE 或 DELETE_FAILED，先刪乾淨
aws cloudformation delete-stack --stack-name <name> --region ap-east-1
aws cloudformation wait stack-delete-complete --stack-name <name> --region ap-east-1
```

### 7. 清理落後資源（在 deploy 新 CDK 棧前）
- 舊 Lambda、旧 REST API、旧 ALB、旧 RDS（不在 CDK 管理內的）
- 舊 CloudFormation stack 的殘留資源
- 先清理乾淨再部署新 stack，避免 conflict

### 8. ECS Fargate 部署流程
```
1. cdk synth --quiet  ✅
2. cdk deploy UMacAiEcsAllInOneStack --require-approval never
3. 等 CREATE_COMPLETE（可能需要 5-10 分鐘）
4. 如果失敗：回到 CDK 修正，不能用 CLI 補
```

### 9. ECS Service 無法啟動的排查
- 看 CloudFormation events：`CREATE_IN_PROGRESS` → 失敗 resource
- 常見原因：
  - ECR image 不存在或 tag 錯 → 正確 build + push image
  - RDS 連不上 → 檢查 SG ingress、Secrets Manager DATABASE_URL
  - 沒有 health check route → 後端要有 `/health` endpoint
- **所有修正都在 CDK 做**：改完重新 deploy

### 10. Route53 Alias 失敗
- 常見原因：ALB 被刪除後，stale alias 導致 `CREATE_FAILED`
- 解決：**在 CDK 裡面讓 Route53 record 正確指向 ALB**，然後 deploy
- 不要用 `aws route53 change-resource-record-sets` 手動刪

---

## 快速查詢命令（可用的 CLI 部分）

```bash
# 狀態查詢（這些 OK）
aws cloudformation describe-stacks --stack-name <name> --region ap-east-1
aws cloudformation describe-stack-events --stack-name <name> --region ap-east-1
aws ecs describe-services --cluster <cluster> --services <svc> --region ap-east-1
aws elbv2 describe-load-balancers --region ap-east-1
aws rds describe-db-instances --region ap-east-1
aws route53 list-resource-record-set --hosted-zone-id <zone> --query "ResourceRecordSets[?Name=='api.board-ai.site.']"
nslookup api.board-ai.site 8.8.8.8

# 健康檢查（這些 OK）
curl https://api.board-ai.site/health
curl https://api.board-ai.site/api/courses
```

---

## 典型錯誤與修復

| 錯誤 | 修復 |
|------|------|
| `ApiAliasRecord CREATE_FAILED` (stale Route53) | 確認 ALB DNS name 正確，在 CDK 裡面更新 Route53 |
| `BackendService CREATE_IN_PROGRESS` timeout | 等更久，或檢查 ECR image 是否存在 |
| ECR image not found | 正確 build + push：`docker build --platform linux/amd64` |
| RDS can't connect from ECS | 檢查 SG ingress、Secrets Manager DATABASE_URL |
| Security group dependency blocked delete | 清理依賴的 resources，再刪 stack |

---

## 禁止的模式

```bash
# ❌ 絕對禁止
aws rds create-db-instance ...                    # 必須用 CDK
aws ec2 authorize-security-group-ingress ...    # 必須用 CDK SG resource
aws secretsmanager put-secret-value ...         # 必須用 CDK Secret resource
aws route53 change-resource-record-sets ...     # 必須用 CDK Route53 record
aws ecs update-service --force-new-deployment   # 除非 debug，否則不準
```

---

### 9. 整合新 CDK Stack 到現有 App

當新增一個 CDK stack（如 CodeBuild pipeline）要和現有 stack（如 ECS）一起部署：
- **不要創建新的 bin entry**（如 `infra/bin/codebuild-pipeline.ts`）
- 把新 stack 直接加進現有的 `infra/bin/umac-ai-app.ts`
- 這樣 `cdk deploy` 可以一次部署所有 stacks

```typescript
// ✅ 正確：所有 stacks 在同一個 app
const app = new cdk.App();
new EcsAllInOneStack(app, 'EcsStack', { ... });
new CodeBuildPipelineStack(app, 'CodeBuildStack', { ... });
app.synth();
```

### 10. CodeBuild Pipeline CDK 整合

創建 CodeBuild project 作為部署 pipeline 的 CDK 模式：
- Image: `codebuild.LinuxBuildImage.STANDARD_7_0`
- Compute: `codebuild.ComputeSize.MEDIUM`
- Privileged: true（才能 build Docker image）
- Source: CodeCommit，使用 `Repository.fromRepositoryName(..., 'umac_ai')`
- Role: 自定義 custom role，attach `AmazonEC2ContainerRegistryPowerUser` + inline policy（含 ECS update/describe、S3、CloudFront、Secrets Manager、IAM/STS）
- **不要加 VPC config**，否則 security group empty 會 deploy fail；等確認 Docker/ECR/ECS 流程穩定後再研究 VPC

### 11. CodeBuild buildspec.yml 關鍵規則

```yaml
# ✅ 正確：所有路徑用 $CODEBUILD_SRC_DIR 絕對路徑
install:
  commands:
    - cd $CODEBUILD_SRC_DIR/backend && npm install
    - cd $CODEBUILD_SRC_DIR/frontend && npm install
    - cd $CODEBUILD_SRC_DIR/infra && npm install

build:
  commands:
    - docker build -t umac-ai-backend:latest -f $CODEBUILD_SRC_DIR/backend/Dockerfile $CODEBUILD_SRC_DIR/backend
    - docker tag umac-ai-backend:latest $ECR_REGISTRY/umac-ai-backend:latest
    - docker push $ECR_REGISTRY/umac-ai-backend:latest
    - docker build -t umac-ai-frontend:latest -f $CODEBUILD_SRC_DIR/frontend/Dockerfile $CODEBUILD_SRC_DIR/frontend
    - docker tag umac-ai-frontend:latest $ECR_REGISTRY/umac-ai-frontend:latest
    - docker push $ECR_REGISTRY/umac-ai-frontend:latest
```

**為什麼要用絕對路徑：** CodeBuild 的 phase 工作目錄會繼承上一條 command 的 `cd`，所以 `cd backend` 在 phase 內執行時可能當前目錄已經是 `../infra`，導致 `can't cd to backend`。

**每個 phase 的第一條 command 一定要 `cd $CODEBUILD_SRC_DIR` 回到起點。**

### 12. Node.js 版本問題

CodeBuild 標準 image `STANDARD_7_0` 的 Node.js 是 `v18.20.8`，但有些 package（含 AWS SDK packages）要求 `>=20.0.0`。如果遇到 EBADENGINE npm warn，在 buildspec 的 `install` phase 加：
```yaml
install:
  commands:
    - nvm install 20
    - nvm use 20
```

### 13. Prisma migrate deploy ≠ seed（補充）

**新發現：** `prisma migrate deploy` 只執行 schema migration，`seed` 必須另外執行。Production 環境密碼不同於 dev，`seed-admin.js` 用 `AdminPass123`（或其他指定的密碼）創建 admin 帳號。

**Seed 方法（適用於有 VPC 的 ECS 環境）：**
1. 用 `aws ecs run-task` 在 Fargate 環境執行 seed script
2. 需要有 VPC config（subnet + security group）
3. Task definition 必須能訪問 RDS（同一 VPC subnet）
4. Command 範例：
```bash
aws ecs run-task \
  --cluster <cluster> \
  --task-definition <task-def> \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[<subnet-ids>],securityGroups=[<sg-id>],assignPublicIp=DISABLED}" \
  --cli-input-json '{
    "overrides": {
      "containerOverrides": [{
        "name": "<container-name>",
        "command": ["sh", "-c", "cd /app && node prisma/seed-admin.js"]
      }]
    }
  }'
```

**注意：** seed script 裡的密碼是 build time 固定的，不應把 source 推送到 public repo。

**解決方案：** 在 CodeBuild post_build 加 ECS run-task seed 步驟，或在 CDK 部署的最後階段執行。

### 14. S3 Bucket Policy 封鎖 CodeBuild — Exit Status 255

**問題：** CodeBuild 的 S3 sync 失敗，exit status 255，但 IAM role 已有 `AmazonS3FullAccess`。

**根因：** S3 bucket policy 只允許特定 principal（如 CloudFront OAI）訪問，CodeBuild 的 IAM role 不在允許名單內，即使 role 有 S3 full access 也被 bucket policy 攔截。

**診斷：**
```bash
# 檢查 S3 bucket policy
aws s3api get-bucket-policy --bucket <bucket> --region ap-east-1

# CodeBuild 具體錯誤看 CloudWatch logs
aws logs get-log-events \
  --log-group-name /aws/codebuild/umac-ai-deploy \
  --log-stream-name <build-id> \
  --region ap-east-1 --limit 200
```

**修復：** 把 CodeBuild role ARN 加入 S3 bucket policy：
```bash
CODEBUILD_ROLE_ARN="arn:aws:iam::631807311787:role/<role-name>"
aws s3api put-bucket-policy --bucket <bucket> --region ap-east-1 --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Principal\": { \"AWS\": \"$CODEBUILD_ROLE_ARN\" },
      \"Action\": [\"s3:PutObject\", \"s3:PutObjectAcl\", \"s3:DeleteObject\", \"s3:ListBucket\"],
      \"Resource\": [\"arn:aws:s3:::<bucket>\", \"arn:aws:s3:::<bucket>/*\"]
    }
  ]
}"
```

**長遠方案：** 在 CDK 裡面用 `bucket.policy` construct 管理 bucket policy，而不是在 AWS Console 裡面改。

### 15. buildspec.yml runtime-versions 放置位置

**錯誤：**
```yaml
env:
  variables:
    AWS_REGION: ap-east-1
  runtime-versions:        # ❌ 不支持，YAML 解析報 warning
    nodejs: '20'
```

**正確：**
```yaml
env:
  variables:
    AWS_REGION: ap-east-1
phases:
  install:
    runtime-versions:
      nodejs: '20'
    commands:
      - cd $CODEBUILD_SRC_DIR/backend && npm install
```

`runtime-versions` 必須放在 `phases.<phase>.runtime-versions`，不支援放在 `env` 下面。

### 16. CodeBuild S3 Sync Exit Status 故障排查速查

| Exit Code | 原因 | 解決 |
|-----------|------|------|
| 255 | IAM/S3 bucket policy 權限不足 | 檢查 bucket policy 是否允許 CodeBuild role |
| 1 | 本地路徑不存在 | 確認 `$CODEBUILD_SRC_DIR/frontend/dist` 目錄存在 |
| None (空) | 前置步驟（Vite build）失敗 | 檢查 `npm run build` 的輸出日誌 |

```bash
# 在 buildspec 裡加 debug
- pwd && ls $CODEBUILD_SRC_DIR/frontend/dist || true
- aws s3 sync $CODEBUILD_SRC_DIR/frontend/dist s3://<bucket>/ --delete --region ap-east-1
```

### 17. `aws ecs wait services-stable` Timeout in CodeBuild

**問題：** ECS `force-new-deployment` 時，CodeBuild 的 `aws ecs wait services-stable` waiter 超時（預設 max-attempts = 40，每 15s 一次 = 10 分鐘）。ECS滾動部署如果 health check 稍慢，就會超時，build 失敗。

**根因：** ECS deployment controller 的滾動替換策略，舊 task deregistration + 新 task registration + ALB health check 合計可能超過 10 分鐘。

**解決：** 用 polling loop 取代 waiter：
```yaml
# ❌ 會超時
- aws ecs update-service --cluster $CLUSTER --service $BACKEND_SERVICE --force-new-deployment --region $AWS_REGION
- aws ecs wait services-stable --cluster $CLUSTER --services $BACKEND_SERVICE --region $AWS_REGION

# ✅ 用 sleep + describe 代替
- aws ecs update-service --cluster $CLUSTER --service $BACKEND_SERVICE --force-new-deployment --region $AWS_REGION
- sleep 60
- aws ecs describe-services --cluster $CLUSTER --services $BACKEND_SERVICE --region $AWS_REGION \
    --query "services[0].[serviceName,status,runningCount,desiredCount]" --output table
```

**進一步優化（只等必要時間）：**
```bash
# 等到 runningCount == desiredCount 為止（最長 3 分鐘）
for i in $(seq 1 18); do
  RUNNING=$(aws ecs describe-services --cluster $CLUSTER --services $BACKEND_SERVICE \
    --query 'services[0].runningCount' --output text --region $AWS_REGION)
  DESIRED=$(aws ecs describe-services --cluster $CLUSTER --services $BACKEND_SERVICE \
    --query 'services[0].desiredCount' --output text --region $AWS_REGION)
  if [ "$RUNNING" = "$DESIRED" ]; then
    echo "All tasks running: $RUNNING/$DESIRED"
    break
  fi
  echo "Waiting... ($i/18) running=$RUNNING desired=$DESIRED"
  sleep 10
done
```

### 18. Docker Layer Cache in CodeBuild Standard Image

**問題：** buildspec 嘗試用 `docker buildx --cache-from type=local,src=/var/cache/docker`，但 CodeBuild 標準 image 不保留 `/var/cache/docker`，導致：
```
Cache is not defined in the buildspec
Skip cache due to: no paths specified to be cached
```

**解決方案有兩種：**

**方案 A：用 CodeBuild artifacts cache（推薦）**
```yaml
cache:
  type: S3
  bucket: $S3_BUCKET
  prefix: docker-cache/
```
注意：需要 S3 bucket 有足夠權限，且 cache 檔案會上傳下載。

**方案 B：用 ECR Public gallery cache（適用於 public image）**
```bash
docker pull mcr.microsoft.com/dotnet/sdk:8.0 AS base
docker buildx build \
  --cache-from type=registry,ref=public.ecr.aws/your-repo/cache:latest \
  --cache-to type=registry,ref=public.ecr.aws/your-repo/cache:latest \
  -t $ECR_REGISTRY/backend:latest . --push
```

**結論：** 如果 Docker build 時間不是主要瓶頸（通常是 `npm install`），可以先跳過 cache 優化。`npm install --legacy-peer-deps` 才是每次最慢的步驟。

### 19. Smart CloudFront Invalidation — 不要 invalidation `/*`

**問題：** 每次 deploy 都 `create-invalidation --paths "/*"`，會讓 CloudFront 重新快取所有檔案，包括未變更的 large JS/CSS bundles，用戶體驗變差。

**正確做法：** 只 invalidation 有變更的 assets：
```bash
# ✅ 只 invalidation 確定會變的檔案
aws cloudfront create-invalidation \
  --distribution-id $CLOUDFRONT_DIST \
  --paths "/assets/*" "/favicon.svg" "/icons.svg" "/index.html"

# ✅ 如果只有 JS bundle 變了，只 invalidation 那個
aws cloudfront create-invalidation \
  --distribution-id $CLOUDFRONT_DIST \
  --paths "/assets/index-$(git rev-parse --short HEAD).js"
```

**配合 S3 長期 cache：** 在 S3 sync 時加 `Cache-Control`：
```bash
aws s3 sync dist/ s3://$BUCKET/ --delete \
  --cache-control "max-age=31536000, immutable" \
  --exclude "index.html"
# index.html 不要设 immutable，保持短期 cache 以便快速更新
```

### 20. Conditional CDK Deploy — 只在 infra/ 真的改了才 deploy

**問題：** 每次 build 都跑 `cdk deploy`，浪費時間（~30s-2min），而且 CDK diff 沒變化時 CloudFormation stack 也是 no-op。

**解決：** 用 `git diff` 判斷有沒有真的改 infra：
```bash
# 在 buildspec pre_build 或 post_build 階段
if git diff --quiet HEAD~1 -- infra/; then
  echo "No infra changes, skipping CDK deploy"
else
  echo "Infra changed, running CDK deploy"
  cd $CODEBUILD_SRC_DIR/infra && npx cdk deploy $CDK_STACK --region $AWS_REGION --require-approval never
fi
```

**注意：** 這只適用於 `post_build` 階段（因為 `git diff` 在 `pre_build`/`build` 階段已經有 source code）。另外 `HEAD~1` 只比較上一個 commit，如果一次 push 多個 commit 需要改成 `HEAD~N`。

### 21. Git Change Detection for Backend/Frontend in CodeBuild

**pattern：** 在 buildspec 的 `pre_build` 階段偵測哪些部分改變，決定後續 steps 是否執行：
```bash
# 檢測 backend 是否改變
git diff --quiet HEAD~1 -- backend/src/ backend/Dockerfile backend/package.json \
  && echo "BACKEND_CHANGED=false" || echo "BACKEND_CHANGED=true"

# 檢測 frontend 是否改變
git diff --quiet HEAD~1 -- frontend/src/ frontend/package.json frontend/vite.config.ts \
  && echo "FRONTEND_CHANGED=false" || echo "FRONTEND_CHANGED=true"
```

然後在 `build` 階段 conditional 執行：
```bash
# frontend 沒改就不需要重新 build
if [ "$FRONTEND_CHANGED" = "true" ]; then
  cd $CODEBUILD_SRC_DIR/frontend && npm run build
  aws s3 sync ...
fi
```

### 14. CodeBuild post_build 不要用 `|| echo` 吞錯誤

```bash
# ❌ 不好：失敗了也繼續往下
- cd $CODEBUILD_SRC_DIR/infra && npx cdk deploy ... || echo cdk_done

# ✅ 好：讓失敗暴露出來（等流程穩定後再考慮要不要吞）
- cd $CODEBUILD_SRC_DIR/infra && npx cdk deploy ... 
```

`|| echo` 會讓 build 在 migration/CDK deploy 失敗時仍然顯示 SUCCEEDED，很危險。

### 1. Healthcheck 使用 curl — Bun image 沒有
**問題：** CDK Fargate container healthcheck 預設用 `curl -f http://localhost:3000/health`，但 Bun runtime image 沒有 curl，health check 永遠 fail，ECS service 一直無法上線。

**修復：** 後端 Dockerfile 安裝 curl，或者 health check 改用其他方式：
```dockerfile
# 在 backend/Dockerfile 加
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
```
不能用 `wget` 替代（ALB health check 也是用 curl）。

### 2. Security Group 卡在 DELETE_FAILED（AWS bug）
**問題：** CloudFormation 刪除 ECS stack 時，backend SG 有時會卡在 `DELETE_FAILED`，錯誤 `has a dependent object (Service: Ec2, Status Code: 400)`，即使 ENI 已經不存在。

**原因：** AWS ENI cleanup 是非同步的，CloudFormation 在 ENI 完全釋放前就嘗試刪除 SG。

**修復：**
```bash
# 等 2-3 分鐘後重試刪除
aws cloudformation delete-stack --stack-name <name> --region ap-east-1
# 如果還是 DELETE_FAILED，再等 2 分鐘，再 delete一次
# 通常 3-4 次重試後會成功
```

### 3. ECS task 一直停在 ACTIVATING / UNKNOWN
**可能原因：**
- Health check 一直 fail（curl 問題）
- Secrets Manager DATABASE_URL 值錯誤，Prisma 無法連接
- RDS Security Group 沒有允許 ECS SG 流量（TCP 5432 from ECS SG）

**排查順序：**
1. `aws ecs describe-services` 看 service events
2. `aws ecs describe-tasks` 看 container exit code
3. CloudWatch Logs 看實際錯誤日誌

### 4. 舊 stack 刪不掉，deploy 被 block
**原則：** 不管舊 stack 狀態，先等刪乾淨再 deploy。如果一直卡在 `DELETE_IN_PROGRESS`：
- 等 3-5 分鐘
- 再 `aws cloudformation delete-stack` 一次
- 通常反覆 3-4 次後 `DELETE_COMPLETE`
- 真的不行就繼續（AWS 最終會清理）

---

## 清理飄在外面的孤立的 drift（orphan resources）

有時候一個舊 CDK stack 在刪除時會卡住，因為某個 SG 被另一個 SG 的 ingress rule 引用，但雙方都已經不屬於任何 stack 了。

排查方法：
```bash
# 1. 確認卡住的 resource
aws cloudformation describe-stack-events --stack-name <stack> --region ap-east-1 \
  --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`]'

# 2. 找到被卡住的 SG
aws cloudformation describe-stack-resources --stack-name <stack> --region ap-east-1 \
  --query 'StackResources[?ResourceStatus==`DELETE_FAILED`]'

# 3. 查誰在用這個 SG（ENI dependency）
aws ec2 describe-network-interfaces \
  --filters "Name=group-id,Values=<sg-id>" \
  --region ap-east-1 \
  --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]'

# 4. 如果 ENI 列表是空的，檢查 VPC endpoints 或其他 SG 的 ingress rules
aws ec2 describe-security-groups --group-ids <sg-id> --region ap-east-1 \
  --query 'SecurityGroups[0].IpPermissions'

# 5. 找所有引用了問題 SG 的地方
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'SecurityGroups[?IpPermissions[?contains(UserIdGroupPairs[].GroupId, `<sg-id>`)]]'
```

常見原因：RDS SG 或 VPC Endpoint SG 裡面有一條 `UserIdGroupPairs` 允許來自已刪除 stack 的 SG 的 traffic。這個引用讓 AWS 不讓刪除。

**重要原則**：
- 如果 drift resource 在一個 **仍存在的 CDK stack** 管理下 → 回到 CDK 修正
- 如果 drift resource 是 **孤立的**（不在任何 stack 裡）→ 移除它，這不算「建立資源」，是「清理飄在外面的東西」

---

## 驗證 CDK-only 的方法

部署完成後，確認：
1. CloudFormation stack status = `CREATE_COMPLETE`
2. 所有 resources 由該 stack 管理（不要有額外 CLI 建立飄在外面的 resources）
3. Route53 alias 正確解析到 ALB
4. API `/health` 返回正確 response

只要有任何資源是 CLI 手動建立的，就不是成功的 CDK 部署。