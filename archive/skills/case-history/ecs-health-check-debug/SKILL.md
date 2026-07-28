---
name: ecs-health-check-debug
description: Debug ECS Fargate CDK deployment failures due to health check curl not found in Docker image
retired: 2026-07-28 archived:case-history
---
Last-verified: 2026-07-28
# ECS Health Check Debug in CDK Deployments

## Problem
ECS Fargate CDK deployment fails with `ROLLBACK_IN_PROGRESS` and error: "Resource handler returned message: Exceeded attempts to wait (HandlerErrorCode: NotStabilized)"

## Root Cause
ECS container health check configured as:
```typescript
healthCheck: {
  command: ['CMD-SHELL', 'curl -f http://localhost:3000/health || exit 1'],
  ...
}
```
But the Docker image does NOT contain `curl`. Health check fails → container restarts → ECS service never stabilizes → CDK times out.

## Solution

### Option 1: Add curl to Dockerfile (RECOMMENDED for Bun/Node images)
```dockerfile
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
```

### Option 2: Change health check to not require curl
```typescript
healthCheck: {
  command: ['CMD-SHELL', 'bun curl -f http://localhost:3000/health || exit 1'],
  // OR use wget if available
}
```

### Option 3: Use ECS exec to verify inside container
```bash
aws ecs execute-command --cluster <cluster> --task <task> --container <name> --command "curl -f http://localhost:3000/health"
```

## Verification
After deploying, check:
```bash
# 1. Verify curl exists in running container
aws ecs execute-command --cluster <cluster> --task <task> --container <name> --command "which curl"

# 2. Check target health
aws elbv2 describe-target-health --target-group-arn <tg-arn> --region ap-east-1

# 3. Check ECS service events
aws ecs describe-services --cluster <cluster> --services <service> --query 'services[0].events[0:5]'
```

## Key Lesson
**Always include the health check command's dependencies in your Docker image**, or use a health check command that uses tools already in your image.
