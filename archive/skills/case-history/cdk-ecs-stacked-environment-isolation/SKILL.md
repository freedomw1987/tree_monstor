---
name: cdk-ecs-stacked-environment-isolation
description: CDK ECS Fargate 部署時保護開發環境的注意事項 — CDK rollback 會把現有服務的 desiredCount 重置為 0，導致服務中斷。
tags: ["cdk", "ecs", "fargate", "aws", "deployment", "environment-isolation"]
related_skills: ["cdk-v2-deployment-patterns", "systematic-debugging"]
retired: 2026-07-28 archived:case-history
---
Last-verified: 2026-07-28
# CDK ECS 部署環境隔離注意事項

## 核心問題

CDK ECS stack deploy 失敗並 rollback 時，CloudFormation 會將 ECS Service 的 `desiredCount` 重置為 0（或其他 CDK 定義的預設值），導致所有 running tasks 被終止，服務變成 `INACTIVE`。

**影響範圍：** 同一個 ECS cluster 內的所有 service（包括不受本次 deploy 影響的開發環境服務）。

## 徵兆

- CDK deploy timeout 或失敗
- CloudFormation stack 變成 `ROLLBACK_COMPLETE`
- ECS service 變成 `INACTIVE`，`desiredCount: 0`，`runningCount: 0`
- 原本正常的服務（例如 `course.david-developer.com`）突然無法訪問
- 本地 `systemd` 服務仍在運行，但 ECS tasks 已全被終止

## 診斷步驟

```bash
# 1. 檢查 ECS services 狀態
aws ecs describe-services \
  --cluster umac-ai-cluster \
  --services umac-ai-backend umac-ai-frontend \
  --region ap-east-1 \
  --query 'services[*].[serviceName,status,desiredCount,runningCount]'

# 2. 檢查 CloudFormation stack 狀態
aws cloudformation describe-stacks \
  --stack-name UMacAiEcsAllInOneStack \
  --region ap-east-1 \
  --query 'stacks[*].[StackName,StackStatus]'

# 3. 檢查是否有 CDK deploy 仍在進行
aws cloudformation list-stacks \
  --stack-status-filter CREATE_IN_PROGRESS UPDATE_IN_PROGRESS \
  --region ap-east-1

# 4. 確認本地 systemd 服務是否正常
sudo systemctl status umac-backend
curl http://localhost:3000/health
```

## 修復方式

```bash
# 將 ECS service desiredCount 恢復並重啟
aws ecs update-service \
  --cluster umac-ai-cluster \
  --service umac-ai-backend \
  --desired-count 2 \
  --region ap-east-1

aws ecs update-service \
  --cluster umac-ai-cluster \
  --service umac-ai-frontend \
  --desired-count 2 \
  --region ap-east-1

# 或使用 CDK 重新部署
cdk deploy UMacAiEcsAllInOneStack --require-approval never
```

## 預防措施

| 措施 | 說明 |
|------|------|
| 部署前記錄 `desiredCount` | `aws ecs describe-services --query 'services[*].desiredCount'` |
| 先 `cdk diff` 預覽變更 | 確認即將變更的內容再執行 deploy |
| 開發/生產用不同 stack | 不要用同一個 CDK app 管理多個環境 |
| 生產 deploy 前通知用戶 | 生產環境 deploy 需要確認停機時間 |
| 使用 ` --no-change-set` 預演 | `cdk deploy --no-execute-changeset` 查看計劃但不執行 |
| CDK timeout 設長一點 | `cdk deploy --timeout=600` 避免 300s timeout |

## 環境隔離最佳實踐

**生產 vs 開發嚴格分開：**
- 開發 stack：`UMacAiEcsDevStack`（dev VPC, dev RDS, dev ECS cluster）
- 生產 stack：`UMacAiEcsProdStack`（prod VPC, prod RDS, prod ECS cluster）
- 絕對不要讓同一個 CDK app 的 deploy 操作影響多個環境的 ECS service

**CDK 架構建議：**
```
infra/
├── bin/
│   ├── umac-ai-dev.ts    # 開發環境
│   └── umac-ai-prod.ts   # 生產環境
└── lib/
    ├── ecs-cluster.ts     # ECS cluster 定義
    ├── ecs-service.ts     # 服務定義（可合成）
    └── database.ts        # RDS（dev 與 prod 分開）
```

每個環境有自己的完整 stack，deploy 時只影響目標環境。
