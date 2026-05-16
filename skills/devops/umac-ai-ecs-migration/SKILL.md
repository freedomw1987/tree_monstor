---
name: umac-ai-ecs-migration
description: 在 UMAC AI production RDS 無法從本地直接訪問時，用 ECS run-task 執行 Prisma migration 的流程
---

# UMAC AI — ECS One-off Prisma Migration

## Trigger
需要在 production RDS 執行 Prisma migration，但本地機器無法直接連接 RDS（security group / VPC 限制）。

## Approach
用 `aws ecs run-task` 在 Fargate 啟動一個一次性的容器，用現有的 backend task definition，override command 執行 `npx prisma migrate deploy`。

## Exact Steps

### 1. 取得 DATABASE_URL
```bash
aws secretsmanager get-secret-value \
  --secret-id umac-ai-db-credentials \
  --region ap-east-1 \
  --query SecretString \
  --output text
```
輸出的 `database_url` 就是 Postgres connection string，密碼在 URL 內。

### 2. 執行 ECS Migration Task
```bash
aws ecs run-task \
  --cluster umac-ai-cluster \
  --task-definition UMacAiEcsStackBackendTaskDefEF56D88D \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-01255018d4a3a1b1f,subnet-0c5ce99b7d83c693b],securityGroups=[sg-01d213a5c6e416f40]}" \
  --overrides '{"containerOverrides":[{"name":"umac-ai-backend","command":["sh","-c","cd /app && ./node_modules/.bin/prisma migrate deploy --schema prisma/schema.prisma 2>&1; echo EXIT:\\$?"],"environment":[{"name":"DATABASE_URL","value":"postgresql://user:password@host:5432/dbname"}]}]}' \
  --region ap-east-1
```

**重要：`npx prisma` 在 Fargate container 內會失敗（ExitCode: 127: command not found）。必須用絕對路徑 `./node_modules/.bin/prisma`，且要先 `cd /app`。**

### 3. 等待並確認 Exit Code
```bash
# 等約30秒
aws ecs describe-tasks \
  --cluster umac-ai-cluster \
  --tasks <task-id> \
  --region ap-east-1 \
  --query 'tasks[0].containers[0].exitCode'
```
確認輸出 `0` 即成功。

## 關鍵參數
| 參數 | 值 |
|------|-----|
| Cluster | `umac-ai-cluster` |
| Task Definition | `UMacAiEcsStackBackendTaskDefEF56D88D` |
| Subnets | `subnet-01255018d4a3a1b1f`, `subnet-0c5ce99b7d83c693b` |
| Security Group | `sg-01d213a5c6e416f40` |
| Region | `ap-east-1` |

## Pitfalls
- **第一個 task 失敗（ExitCode: 1）**：可能原因包括 DATABASE_URL 格式問題、Prisma client 未生成。先確保 `prisma generate` 已做過。
- **不要** 在本地執行 `prisma migrate deploy`，RDS 不接受外部連接。
- Container name 必須與 task definition 內的 actual container name 完全一致，否則 override 不生效。