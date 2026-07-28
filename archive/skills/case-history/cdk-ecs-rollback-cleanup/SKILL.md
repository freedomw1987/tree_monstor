---
name: cdk-ecs-rollback-cleanup
description: CDK ECS Fargate stack rollback cleanup when BackendSg deletion fails with DependencyViolation
tags: [aws, cdk, ecs, rollback, security-group]
retired: 2026-07-28 archived:case-history
---
Last-verified: 2026-07-28
# CDK ECS Fargate Rollback Cleanup

## Trigger Condition
CDK deploy `UMacAiEcsAllInOneStack` 遇到 `ROLLBACK_COMPLETE` 或 `DELETE_FAILED`，特別是 `BackendSg` 無法刪除，出現：
```
DependencyViolation: resource sg-0c8d9db23e3180ad2 has a dependent object
```

## Root Cause
手動在 RDS Security Group 加入了来自 Backend SG 的 ingress rule（例如允許 5432 from backend SG），造成 RDS SG 依賴 Backend SG，Backend SG 無法刪除，stack 無法完成 rollback。

## Cleanup Sequence

### Step 1: 找到 blocking dependency
```bash
aws cloudformation describe-stack-resources \
  --stack-name UMacAiEcsAllInOneStack \
  --region ap-east-1 \
  --query "StackResources[?ResourceStatus=='DELETE_FAILED']"
```

### Step 2: 移除造成循環的 SG ingress rule
```bash
# 如果 RDS SG 允許了 backend SG 的 5432，revoke 掉
aws ec2 revoke-security-group-ingress \
  --group-id sg-0c293e8c5b30d839f \
  --protocol tcp \
  --port 5432 \
  --source-group sg-0c8d9db23e3180ad2 \
  --region ap-east-1
```

### Step 3: 等待並重試刪除 stack
```bash
aws cloudformation delete-stack --stack-name UMacAiEcsAllInOneStack --region ap-east-1
# 等待
aws cloudformation wait stack-delete-complete --stack-name UMacAiEcsAllInOneStack --region ap-east-1
```

### Step 4: 檢查並清理殘留 ALB
Rollback 成功後 ALB 通常已刪除，但 Route53 A record 可能仍在：
```bash
aws elbv2 describe-load-balancers --region ap-east-1
```
Route53 stale alias 會在下次 CDK deploy 時自動更新。

## 預防措施
- **不要**在 RDS SG 內手動加入來自 CDK 管理的 SG 的 ingress rule
- CDK 會自己創建 SG 間的依賴，優先使用 CDK SecurityGroup egress/ingress rules
- Route53 A record 應由 CDK 管理，減少手動 drift
