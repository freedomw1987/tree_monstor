---
name: umac-ai-deploy-prod
description: UMAC AI 生產部署 SOP — backend + frontend + CDK + ECS 全流程
---

# UMAC AI 生產部署流程

## 概述
UMAC AI 項目（澳門大學 AI 大賽活動網站）的生產環境部署 SOP。

## 環境
- Region: `ap-east-1`
- SES Region: `us-east-1`
- 生產 API: `https://api.board-ai.site`
- 生產 Frontend: `https://board-ai.site`
- ECS Cluster: `umac-ai-cluster`
- Services: `umac-ai-backend`, `umac-ai-frontend`

## 部署流程（完整代碼發布）

### 1. 確認代碼已 commit
```bash
cd ~/projects/umac_ai
git add -A && git commit -m "description"
git push origin main
```

### 2. Prisma Migration（如 schema 有變更）
```bash
# 先確認有哪些 pending migrations
aws ecs run-task \
  --cluster umac-ai-cluster \
  --task-definition UMacAiEcsStackBackendTaskDefEF56D88D \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-01255018d4a3a1b1f,subnet-0c5ce99b7d83c693b],securityGroups=[sg-01d213a5c6e416f40]}" \
  --overrides '{"containerOverrides":[{"name":"umac-ai-backend","command":["sh","-c","cd /app && ./node_modules/.bin/prisma migrate deploy --schema prisma/schema.prisma"],"environment":[{"name":"DATABASE_URL","value":"postgresql://umacai:PASSWORD@umacaidatabasestack-ummaaidbinstancecd68fce1-pxp9c9hn2dv6.cd8ge4mwq7jq.ap-east-1.rds.amazonaws.com:5432/umac_ai"}]}]}' \
  --region ap-east-1
# 等待約 45 秒後 describe-tasks 確認 ExitCode: 0
```

**注意：`npx prisma` 在 Fargate 內會失敗（ExitCode: 127），必須用 `./node_modules/.bin/prisma` 並先 `cd /app`。**

### 3. Build + Push Backend Image
```bash
cd ~/projects/umac_ai/backend
sudo docker build --no-cache -t umac-ai-backend .
sudo docker tag umac-ai-backend:latest 631807311787.dkr.ecr.ap-east-1.amazonaws.com/umac-ai-backend:latest
aws ecr get-login-password --region ap-east-1 | sudo docker login --username AWS --password-stdin 631807311787.dkr.ecr.ap-east-1.amazonaws.com
sudo docker push 631807311787.dkr.ecr.ap-east-1.amazonaws.com/umac-ai-backend:latest
```

### 4. Build + Push Frontend Image
```bash
cd ~/projects/umac_ai/frontend
# .env.production 已有 VITE_API_BASE_URL=https://api.board-ai.site/api
sudo docker build -t umac-ai-frontend .
sudo docker tag umac-ai-frontend:latest 631807311787.dkr.ecr.ap-east-1.amazonaws.com/umac-ai-frontend:latest
sudo docker push 631807311787.dkr.ecr.ap-east-1.amazonaws.com/umac-ai-frontend:latest
```

### 5. CDK Deploy（如有 Infra 變更）
```bash
cd ~/projects/umac_ai/infra
npx cdk deploy UMacAiEcsStack --region ap-east-1 --require-approval never
# CDK deploy 會 timeout（300s），但 CloudFormation 會繼續在後台執行
# 確認：aws cloudformation describe-stacks --stack-name UMacAiEcsStack --region ap-east-1
```
## 部署方式：有兩種

### 方式 A：CodeBuild（全自動，推送後自動執行）
```bash
cd ~/projects/umac_ai
git add -A && git commit -m "description" && git push origin main
# CodeBuild 會自動：
# 1. Build backend Docker image + push to ECR
# 2. Build frontend + sync to S3 + CloudFront invalidation
# 3. 如果 infra/ 有變更 → CDK deploy
# 4. Prisma migrate + seed
# 5. ECS service update（拉新 image）
```

**手動觸發 CodeBuild（如需立即部署）：**
```bash
aws codebuild start-build --project-name umac-ai-deploy --region ap-east-1 --query 'build.id' --output text
# 查狀態：
aws codebuild batch-get-builds --ids umac-ai-deploy:<build-id> --region ap-east-1 --query 'builds[0].[status,currentPhase]' --output text
```

**CodeBuild 包含完整的檢測邏輯：**
- `git diff` 檢測哪些模組有變更
- 只有 infra/ 變更才 CDK deploy
- 只有 backend/ 變更才 rebuild Docker image
- post_build phase 包含 migration + seed + ECS update

### 方式 B：手動部署（僅 CDK 變更或緊急修復）

### 6. Force ECS Deploy（拉新 Image）

```bash
# Backend
aws ecs update-service --cluster umac-ai-cluster --service umac-ai-backend --force-new-deployment --region ap-east-1

# Frontend
aws ecs update-service --cluster umac-ai-cluster --service umac-ai-frontend --force-new-deployment --region ap-east-1
```

### 7. S3 + CloudFront 靜態部署（frontend 有變更時必做）

```bash
# 前端靜態資源需同步到 S3，ECS frontend 容器更新的只是 container 本身
cd ~/projects/umac_ai/frontend
npm run build

aws s3 sync dist/ s3://umac-ai-frontend-631807311787-ap-east-1/ --region ap-east-1

aws cloudfront create-invalidation --distribution-id E2KORZ2WAC4CZS --paths "/*"
```

**前端有 UI 改動時，否則用戶看到的是 CloudFront 緩存的舊版。**

### 8. 驗證
```bash
# Basic health
curl -s https://api.board-ai.site/health

# 測試登入
curl -s -X POST "https://api.board-ai.site/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@umac.ai","password":"AdminPass123"}'

# 測試 presign 上傳（需要新 token）
LOGIN_RESP=$(curl -s -X POST "https://api.board-ai.site/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@umac.ai","password":"AdminPass123"}')
TOKEN=$(echo $LOGIN_RESP | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
curl -s -X POST "https://api.board-ai.site/api/upload/presign" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"filename":"test.pdf","contentType":"application/pdf","size":1234}'

# CloudFront 測試（等同瀏覽器訪問）
curl -s -I "https://d25s1d60o4mvcq.cloudfront.net/api/courses"
```

## 重要教訓

### CDK ≠ 代碼部署
CDK 只負責更新 AWS infrastructure（建立 S3 bucket、更新 task definition env、加 IAM policy）。**CDK 不會 build 或 push Docker image**。

每次代碼變更後，必須手動：
1. Build 新 Docker image
2. Push 到 ECR
3. Force ECS deploy

如果忘記這步，ECS 會繼續跑舊 image。

### Dev Backend 啟動方式
```bash
cd ~/projects/umac_ai/backend
bun --env-file=.env src/index.ts
```

### Dev Forgot Password 需要的 env
`.env` 必須包含：
```
SES_REGION=us-east-1
SES_FROM_EMAIL=noreply@board-ai.site
JWT_SECRET=...
DATABASE_URL=...
```

### SES DMARC 問題
email From 為 `noreply@board-ai.site`，envelope sender 預設是 `010001...@amazonses.com`，導致 DMARC FAIL。

解決：在 Route53 加 DKIM CNAME 記錄 + DMARC TXT 記錄。

## 常見問題

### Q: Production API 回 503、ECS backend `desired=2` 但 `running=0`？
先查 ECS stopped tasks + CloudWatch logs。曾發生 root cause：backend Dockerfile 用 `bun build --target=node --format=cjs`，但 runtime 是 `CMD ["bun", "dist/index.js"]`，導致 Elysia/Bun app 啟動後 crash：

```text
TypeError: Bun.serve() needs either routes object or fetch handler
```

修復：Dockerfile 必須用 Bun target：

```dockerfile
RUN bun build src/index.ts --target=bun --outfile=dist/index.js
CMD ["bun", "dist/index.js"]
```

驗證：
```bash
cd ~/projects/umac_ai/backend
bun build src/index.ts --target=bun --outfile=dist/index.js
PORT=3999 timeout 5s bun dist/index.js
# 看到 startup log 並保持運行直到 timeout，不能出現 Bun.serve TypeError
```

修好後 rebuild/push backend image + force ECS deploy，確認：
```bash
aws ecs describe-services --cluster umac-ai-cluster --services umac-ai-backend --region ap-east-1 \
  --query 'services[0].{desired:desiredCount,running:runningCount,pending:pendingCount,deployments:deployments[*].rolloutState}'
curl -fsS https://api.board-ai.site/health
```

### Q: Admin 登入失敗？
先分辨是 API 掛了還是密碼錯：
1. `curl -fsS https://api.board-ai.site/health` — 如果 503，先修 backend。
2. Production admin 已驗證帳密：`admin@umac.ai / AdminPass123`；`admin123` 會回 `Invalid email or password`。

### Q: CloudFront 全部返回 502？
根因：CloudFront origin 使用 ALB DNS name（如 `UMacAi-UmmaA-...elb.amazonaws.com`），但 ALB ACM 證書是 `api.board-ai.site`，TLS CN 不匹配導致 CloudFront 無法完成 TLS 握手。

修復（CDK 或 AWS CLI）：
1. 將 CloudFront origin domain 從 ALB DNS name 改為 `api.board-ai.site`
2. 將 originProtocolPolicy 從 `https-only` 改為 `match-viewer`

AWS CLI 直接修復（立即生效）：
```bash
# 取得目前 config
aws cloudfront get-distribution --id E2KORZ2WAC4CZS --region ap-east-1 > /tmp/cf-config.json
# 修改 Origin items[0].DomainName = "api.board-ai.site"
# 修改 Origin items[0].CustomOriginConfig.OriginProtocolPolicy = "match-viewer"
aws cloudfront update-distribution --id E2KORZ2WAC4CZS --distribution-config file:///tmp/cf-config.json
```

CDK 修復（同步到代碼）：
```typescript
// infra/lib/frontend.ts
const albDomain = 'api.board-ai.site';  // 不要用 ALB DNS name
// origin: { domainName: albDomain, originProtocolPolicy: 'match-viewer' }
```

### Q: API 返回 401 Unauthorized？
**測試 API 時一定要用「立即取得的新 token」，不要重複使用舊 token。**
```bash
# 正確方式：登入後立即用同一個 shell session 測試
LOGIN_RESP=$(curl -s -X POST "https://api.board-ai.site/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@umac.ai","password":"AdminPass123"}')
TOKEN=$(echo $LOGIN_RESP | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
curl -s -X POST "https://api.board-ai.site/api/upload/presign" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"filename":"test.pdf","contentType":"application/pdf","size":1234}'
```

### Q: ECS 顯示 ACTIVE 但 API 還是舊版？
檢查是否忘記 force new deployment。CDK deploy 只更新 task definition，現有 ECS tasks 不會自動重啟。

### Q: SES email 進垃圾郵件？
檢查 DKIM 是否 Pending → 需要在 Route53 加 DKIM CNAME 記錄。

### Q: CDK deploy timeout？
正常，CloudFormation 在後台繼續執行。等 2-3 分鐘後確認 `UPDATE_COMPLETE`。

## 文件位置
- Backend: `~/projects/umac_ai/backend/`
- Frontend: `~/projects/umac_ai/frontend/`
- Infra: `~/projects/umac_ai/infra/`
- ECR Repos: `631807311787.dkr.ecr.ap-east-1.amazonaws.com/umac-ai-backend` 和 `.../umac-ai-frontend`
