---
name: prisma-migrate-private-rds
description: Run Prisma migrations on private RDS via ECS one-off task when CodeBuild can't reach the database
category: devops
---

# Prisma Migration on Private RDS via ECS One-Off Task

## Problem
CodeBuild (no VPC) cannot reach RDS in private subnet. `prisma migrate deploy` in buildspec fails with:
```
Can't reach database server at `xxx.rds.amazonaws.com`
```

## Solution
Use ECS run-task to run migration inside the VPC, since the backend container IS in the private subnet and has access to RDS.

## Step-by-Step

1. Find the latest active task definition for the backend service:
```bash
aws ecs describe-services --cluster umac-ai-cluster --services umac-ai-backend --region ap-east-1
# Note: taskDefinition arn like UMacAiEcsStackBackendTaskDefEF56D88D:4
```

2. Run one-off ECS task with migration command:
```bash
aws ecs run-task \
  --cluster umac-ai-cluster \
  --task-definition UMacAiEcsStackBackendTaskDefEF56D88D:4 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-01255018d4a3a1b1f,subnet-0c5ce99b7d83c693b],securityGroups=[sg-01d213a5c6e416f40],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"umac-ai-backend","command":["sh","-c","cd /app && bunx prisma migrate deploy --schema prisma/schema.prisma"]}]}' \
  --region ap-east-1 \
  --query 'tasks[0].taskArn' \
  --output text
```

3. Wait for task to complete (~30-40s):
```bash
sleep 30 && aws ecs describe-tasks --cluster umac-ai-cluster --tasks <task-arn> --region ap-east-1
# Look for lastStatus=STOPPED and exitCode=0
```

## Key Insight
- CodeBuild builds Docker image and pushes to ECR — no VPC needed
- Migration MUST run from within VPC — use ECS task container
- `npx` doesn't work inside Bun container — use `bunx` instead
- Working directory in ECS task is `/app` (matches Dockerfile WORKDIR)
- ECS task needs ~30-40s to start + run Prisma

## Gotchas
- Exit code 127 = command not found (use `bunx` not `npx`)
- Exit code 2 = wrong path (try `cd /app &&` prefix)
- Exit code 1 = migration error (check logs)
- `assignPublicIp=DISABLED` required for private subnet tasks