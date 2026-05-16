---
name: cdk-ecs-fargate-deploy
description: CDK v2 ECS Fargate deployment pattern — single consolidated stack to avoid circular dependencies between Route53, ALB, ECS, and RDS
tags:
  - aws
  - cdk
  - ecs
  - fargate
  - docker
  - bun
  - elysia
related_skills:
  - elysia-aws-lambda-deploy
  - docker-caddy-elysia-deploy
---

# CDK v2 ECS Fargate Deployment

## When to Use This

Deploying a containerized app (Bun/Elysia backend + React frontend) on AWS ECS Fargate behind an ALB, with Route53 DNS and RDS PostgreSQL — where all components are interdependent.

## Key Lesson: Use ONE Consolidated Stack

**Never split ECS Fargate + ALB + Route53 + RDS into separate CDK stacks** if they have cross-references. CDK cross-stack references create CFN export/import dependencies that easily become circular when:
- ALB needs target group → ECS service needs target group
- ECS needs security groups → RDS needs security groups  
- Route53 ARecord → ALB alias
- ECS task role needs RDS permissions

**Rule:** Put ALB + ECS + RDS + Route53 + ECR in **ONE stack** (e.g., `UmacAiEcsAllInOneStack`).

## CDK Stack Template

```typescript
// infra/lib/ecs-all-in-one.ts
import { Stack, Duration, aws_ec2, aws_ecs, aws_ecr, aws_rds,
         aws_elasticloadbalancingv2, aws_route53, aws_certificatemanager,
         aws_secretsmanager, aws_cloudwatch_dashboard, CfnOutput } from 'aws-cdk-lib'
import { Effect, PolicyStatement, Role, ServicePrincipal } from 'aws-cdk-lib/aws-iam'
import { RetentionDays } from 'aws-cdk-lib/aws-logs'

export class UMacAiEcsAllInOneStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props)

    // ─── VPC ───────────────────────────────────────────────────────────
    const vpc = new aws_ec2.Vpc(this, 'Vpc', {
      maxAzs: 2,
      natGateways: 1,
      subnetConfiguration: [
        { name: 'Public', subnetType: aws_ec2.SubnetType.PUBLIC, cidrMask: 24 },
        { name: 'Private', subnetType: aws_ec2.SubnetType.PRIVATE_WITH_EGRESS, cidrMask: 24 },
      ],
    })

    // ─── ECR Repos ────────────────────────────────────────────────────
    const backendRepo = new aws_ecr.Repository(this, 'BackendRepo', {
      emptyOnDelete: true,
    })
    const frontendRepo = new aws_ecr.Repository(this, 'FrontendRepo', {
      emptyOnDelete: true,
    })

    // ─── RDS PostgreSQL ────────────────────────────────────────────────
    const dbCredentials = new aws_secretsmanager.Secret(this, 'DBCredentials', {
      generateSecretString: { username: 'admin', excludeCharacters: '"@/\\' },
    })

    const db = new aws_rds.DatabaseCluster(this, 'Database', {
      engine: aws_rds.DatabaseClusterEngine.auroraPostgres({ version: aws_rds.AuroraPostgresEngineVersion.VER_15_4 }),
      instanceProps: { instanceType: new aws_ec2.InstanceType('t3.medium'), vpc, vpcSubnets: { subnetType: aws_ec2.SubnetType.PRIVATE_WITH_EGRESS } },
      credentials: aws_rds.Credentials.fromSecret(dbCredentials),
      defaultDatabaseName: 'umac_ai',
      storageEncrypted: true,
    })

    // ─── ECS Cluster ──────────────────────────────────────────────────
    const cluster = new aws_ecs.Cluster(this, 'Cluster', { vpc })

    // Add CloudWatch log group
    const logGroup = new aws_cloudwatch_dashboard.LogGroup(this, 'LogGroup', {
      logGroupName: '/ecs/umac-ai',
      retention: RetentionDays.TWO_WEEKS,
    })

    // ─── ALB ──────────────────────────────────────────────────────────
    const alb = new aws_elasticloadbalancingv2.ApplicationLoadBalancer(this, 'ALB', {
      vpc,
      internetFacing: true,
    })

    const httpListener = alb.addListener('HttpListener', { port: 80, open: true })
    httpListener.addRedirectResponse({ statusCode: 'HTTP_301', protocol: 'HTTPS', port: '443' })

    const httpsListener = alb.addListener('HttpsListener', {
      port: 443,
      certificates: [{ certificateArn: 'arn:aws:acm:ap-southeast-1:631807311787:certificate/VALIDATE_THIS' }],
      defaultTargetGroups: [backendTargetGroup],
    })

    // ─── Route53 ─────────────────────────────────────────────────────
    const zone = aws_route53.HostedZone.fromLookup(this, 'Zone', { domainName: 'board-ai.site' })

    new aws_route53.ARecord(this, 'DNS', {
      zone,
      recordName: 'course.board-ai.site',
      target: aws_route53.RecordTarget.fromAlias({ targetType: 'alb', apigatewayDomain: { regionalDomainName: alb.regionalDomainName, regionalHostedZoneId: alb.regionalHostedZoneId } }),
    })

    // ─── ECS Task Role & Execution Role ──────────────────────────────
    const executionRole = new Role(this, 'EcsExecutionRole', {
      assumedBy: new ServicePrincipal('ecs-tasks.amazonaws.com'),
    })
    executionRole.addToPolicy(new PolicyStatement({
      effect: Effect.ALLOW,
      resources: ['*'],
      actions: ['ecr:GetAuthorizationToken', 'logs:CreateLogStream', 'logs:PutLogEvents'],
    }))

    const taskRole = new Role(this, 'EcsTaskRole', {
      assumedBy: new ServicePrincipal('ecs-tasks.amazonaws.com'),
    })
    taskRole.addToPolicy(new PolicyStatement({
      effect: Effect.ALLOW,
      resources: [dbCredentials.secretArn],
      actions: ['secretsmanager:GetSecretValue'],
    }))

    // ─── Backend Task Definition ─────────────────────────────────────
    const backendTask = new aws_ecs.FargateTaskDefinition(this, 'BackendTask', {
      cpu: 512,
      memoryLimitMB: 1024,
      executionRole,
      taskRole,
    })

    backendTask.addContainer('Backend', {
      image: aws_ecs.ContainerImage.fromEcrRepository(backendRepo, 'latest'),
      portMappings: [{ containerPort: 3000 }],
      environment: {
        NODE_ENV: 'production',
        DATABASE_URL: `postgresql://\${dbCredentials.secretValueFromJson('username').unsafeUnwrap()}:\${dbCredentials.secretValueFromJson('password').unsafeUnwrap()}@${db.clusterEndpoint.hostname}:${db.clusterEndpoint.port}/\${aws_rds.DatabaseCluster(this, 'DB').clusterEndpoint.port}`,
        FRONTEND_URL: 'https://course.board-ai.site',
        JWT_SECRET: 'CHANGE_ME_in_production',
      },
      logConfiguration: { logDriver: 'awslogs', options: { 'awslogs-group': logGroup.logGroupName, 'awslogs-region': 'ap-southeast-1', 'awslogs-stream-prefix': 'backend' } },
      essential: true,
    })

    const backendService = new aws_ecs.FargateService(this, 'BackendService', {
      cluster,
      taskDefinition: backendTask,
      desiredCount: 2,
      healthCheckGracePeriod: Duration.seconds(30),
    })

    const backendTargetGroup = new aws_elasticloadbalancingv2.ApplicationTargetGroup(this, 'BackendTG', {
      vpc,
      port: 3000,
      targets: [backendService],
      healthCheck: { path: '/health', healthyThresholdCount: 2, unhealthyThresholdCount: 3 },
    })

    httpsListener.addTargetGroups('BackendTG', { targetGroups: [backendTargetGroup], priority: 1 })
    httpListener.addRedirectResponse({ statusCode: 'HTTP_301', protocol: 'HTTPS', port: '443' })

    // ─── Frontend Task Definition ─────────────────────────────────────
    const frontendTask = new aws_ecs.FargateTaskDefinition(this, 'FrontendTask', {
      cpu: 256,
      memoryLimitMB: 512,
      executionRole,
    })

    frontendTask.addContainer('Frontend', {
      image: aws_ecs.ContainerImage.fromEcrRepository(frontendRepo, 'latest'),
      portMappings: [{ containerPort: 80 }],
      essential: true,
    })

    const frontendService = new aws_ecs.FargateService(this, 'FrontendService', {
      cluster,
      taskDefinition: frontendTask,
      desiredCount: 2,
    })

    const frontendTargetGroup = new aws_elasticloadbalancingv2.ApplicationTargetGroup(this, 'FrontendTG', {
      vpc,
      port: 80,
      targets: [frontendService],
      healthCheck: { path: '/', healthyThresholdCount: 2, unhealthyThresholdCount: 3 },
    })

    // Frontend catches /* (lower priority than backend /api/*)
    httpsListener.addAction('Frontend', {
      action: aws_elasticloadbalancingv2.ListenerAction.forward([frontendTargetGroup]),
      priority: 100, // lower number = higher priority, so give backend /api/* priority 1
    })

    // ─── Outputs ──────────────────────────────────────────────────────
    new CfnOutput(this, 'ECRBackendRepo', { value: backendRepo.repositoryUri })
    new CfnOutput(this, 'ECRFrontendRepo', { value: frontendRepo.repositoryUri })
    new CfnOutput(this, 'LoadBalancerDNS', { value: alb.loadBalancerDnsName })
  }
}
```

## Deploy Commands

```bash
cd ~/projects/umac_ai/infra

# Synthesize (verify no CDK errors)
npx cdk synth UMacAiEcsAllInOneStack

# Deploy
CDK_DEFAULT_ACCOUNT=631807311787 \
CDK_DEFAULT_REGION=ap-southeast-1 \
npx cdk deploy UMacAiEcsAllInOneStack \
  --require-approval=never \
  --outputs-file ./cdk-outputs.json

# Get ECR URIs from outputs
cat cdk-outputs.json | jq '.UMacAiEcsAllInOneStack'

# Build & push Docker images
# 1. Login to ECR
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin <ecr-repo-uri>

# 2. Build backend
cd ~/projects/umac_ai/backend
docker build -t umac-ai-backend .
docker tag umac-ai-backend:latest <ecr-backend-uri>:latest
docker push <ecr-backend-uri>:latest

# 3. Build frontend
cd ~/projects/umac_ai/frontend
docker build -t umac-ai-frontend .
docker tag umac-ai-frontend:latest <ecr-frontend-uri>:latest
docker push <ecr-frontend-uri>:latest

# 4. Force ECS new deployment (picks up new images)
aws ecs update-service \
  --cluster umac-ai-cluster \
  --service umac-ai-backend-service \
  --force-new-deployment \
  --region ap-southeast-1
```

## Docker Files Required

### Backend Dockerfile (multi-stage)
```dockerfile
FROM oven/bun:1 AS build
WORKDIR /app
COPY package.json bun.lockb ./
RUN bun install
COPY . .
RUN bun run build

FROM oven/bun:1-slim
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
EXPOSE 3000
CMD ["bun", "dist/index.js"]
```

### Frontend Dockerfile (multi-stage + nginx)
```dockerfile
# Build stage
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
VITE_API_URL=https://course.board-ai.site/api
RUN npm run build

# nginx stage
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### nginx.conf for SPA
```nginx
server {
  listen 80;
  root /usr/share/nginx/html;
  index index.html;

  location / {
    try_files $uri $uri/ /index.html;
  }

  location /api/ {
    proxy_pass http://umac-ai-backend:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
```

## Local Dev with docker-compose

```yaml
version: '3.9'
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: umac_ai
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: changeme
    ports: [5432:5432]
    volumes:
      - postgres_data:/var/lib/postgresql/data

  backend:
    build: ./backend
    ports: [3000:3000]
    environment:
      DATABASE_URL: postgresql://admin:changeme@postgres:5432/umac_ai
      NODE_ENV: development
    depends_on: [postgres]

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    ports: [5173:5173]
    environment:
      VITE_API_URL: http://localhost:3000
    depends_on: [backend]

volumes:
  postgres_data:
```

## Common ECS Errors

### CDK stack stuck in ROLLBACK_FAILED (security group can't be deleted)
**Cause:** CF can't delete a security group that is still referenced by another SG's ingress rule.
**Fix (CLI workaround — CDK stack must be retried after):**
```bash
# Find the blocking reference
aws ec2 describe-security-group-rules \
  --query 'SecurityGroupRules[?ReferencedGroupInfo.GroupId==`sg-STUCK_ID`]'

# Remove the ingress rule on the referencing SG
aws ec2 revoke-security-group-ingress \
  --group-id sg-REFERENCING_SG \
  --ip-permissions '[{"IpProtocol":"tcp","FromPort":5432,"ToPort":5432,"UserIdGroupPairs":[{"GroupId":"sg-STUCK_ID"}]}]'

# Now delete the stuck SG
aws ec2 delete-security-group --group-id sg-STUCK_ID

# Then retry CF stack deletion
aws cloudformation delete-stack --stack-name STACK_NAME --region ap-east-1
```

### ECS task stuck in PROVISIONING
**Cause:** Missing `logConfiguration` or bad `awslogs` permissions.
**Fix:** Ensure execution role has `logs:CreateLogStream` and `logs:PutLogEvents`.

### ECS task dies immediately with exit code 1
**Cause:** Usually missing env vars or bad `DATABASE_URL`.
**Fix:** Check CloudWatch logs for the specific error.

### ALB health check failing (unhealthy)
**Cause:** Backend health endpoint returns non-200 or container port mismatch.
**Fix:** Verify containerPort matches backend server port and `/health` route exists.

### Container cannot connect to RDS (timeout on port 5432)
**Cause:** RDS security group doesn't allow port 5432 from ECS task SG. After CDK rollback cleanup, the RDS SG rule referencing the ECS SG may be gone.
**Fix:** Re-authorize:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-RDS_SG \
  --ip-permissions '[{"IpProtocol":"tcp","FromPort":5432,"ToPort":5432,"UserIdGroupPairs":[{"UserId":"ACCOUNT_ID","GroupId":"sg-ECS_BACKEND_SG"}]}]'
```

### Image tag :latest not updating
**Cause:** ECS doesn't auto-pull on new image push.
**Fix:** Force new deployment: `aws ecs update-service --cluster CLUSTER --service SERVICE --force-new-deployment`

### CDK deploy succeeds but login returns "Invalid email or password" for known-good credentials
**Cause:** The target database (e.g., `umac_ai`) was never created. CDK `DatabaseInstance` creates the PostgreSQL *engine* but does NOT create the database name specified in `defaultDatabaseName`.
**Fix:** Manually create the database and run migrations. Two options:
1. **Lambda one-shot** (recommended for production): Create a Lambda in VPC with `pg` + `bcrypt` + `aws-sdk` packages to run SQL, then delete the Lambda after use.
2. **ECS exec**: Run a temporary task with override command to execute Prisma migrate.
3. **Bastion host**: SSH to a host in the VPC and run `psql` directly.

### Prisma schema field names vs actual DB column names
**Symptom:** Login always fails even with correct password.
**Cause:** Prisma schema uses `camelCase` field names (e.g., `passwordHash`, `mustChangePassword`) but migrations may generate `snake_case` columns OR the User table doesn't exist at all.
**Fix:** Run `bunx prisma migrate deploy` or `bunx prisma db push` from within the ECS task, or use Lambda to create the initial schema:
```sql
CREATE TABLE IF NOT EXISTS "User" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "passwordHash" TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  role TEXT NOT NULL DEFAULT 'STUDENT',
  "mustChangePassword" BOOLEAN DEFAULT false,
  "createdAt" TIMESTAMPTZ DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ DEFAULT NOW()
);
```

## Why Not Lambda?

Lambda is simpler but has cold starts and 15-min timeout limits. ECS Fargate is better for:
- Long-running processes (Bun server is always-on)
- Persistent connections (WebSocket for real-time chat)
- Consistent sub-100ms response times
- No bundle size limits (vs 250MB Lambda)
