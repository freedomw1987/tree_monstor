---
name: cdk-v2-deployment-patterns
description: CDK v2 deployment patterns and common issues encountered when setting up AWS infrastructure with CDK
category: devops
tags: [aws, cdk, infrastructure, deployment]
applicability: generic-pattern
---


Last-verified: 2026-07-28
# CDK v2 Deployment Patterns

## Common Issues & Solutions

### 1. CDK CLI + Library Version Mismatch
```
CLI versions and CDK library versions have diverged
```
**Fix:** Ensure CDK CLI and `aws-cdk-lib` are same major version. Use:
```bash
npm install aws-cdk@2.150.0 --save-dev
```
CLI 2.1000+ no longer matches library versions 1:1.

### 2. Feature Flags from CDK v1
```
Unsupported feature flag '@aws-cdk/core:enableStackNameDuplicates'
```
**Fix:** Remove all v1 feature flags from `cdk.json` context. CDK v2 handles these automatically.
```json
{ "app": "...", "context": {} }
```

### 3. Package Names
- `@aws-cdk/aws-secretsmanager` (NOT `@aws-cdk/aws-secrets-manager`)
- Check with: `npm view @aws-cdk/aws-secretsmanager versions`

### 4. SSLMethod Enum
`SSLMethod.TLS_V1_2_2021` does NOT exist.
```typescript
// Available values:
SSLMethod.SNI   // ✓
SSLMethod.VIP   // ✓
```

### 5. SubnetType Deprecation
```
PRIVATE_WITH_NAT is deprecated, use PRIVATE_WITH_EGRESS
```
```typescript
SubnetType.PRIVATE_WITH_EGRESS  // ✓ not PRIVATE_WITH_NAT
```

### 6. IHostedZone vs HostedZone
When using `HostedZone.fromLookup()`, type is `IHostedZone`, not `HostedZone`.
```typescript
import { HostedZone, IHostedZone } from 'aws-cdk-lib/aws-route53';

let hostedZone: IHostedZone;
hostedZone = HostedZone.fromLookup(this, 'Zone', { domainName: 'example.com' });
```

### 7. Code.fromAsset Path
Path is relative to `cdk.json` location, NOT the entry point.
```
cdk.json at infra/ → Code.fromAsset('../backend') → infra/../backend
```
Use relative path from `cdk.json` directory.

### 8. ts-node via npx
```bash
# Wrong - uses global npx ts-node
"app": "npx ts-node ..."

# Correct - use local node_modules
"app": "./node_modules/.bin/ts-node bin/app.ts"
```

### 9. constructs Package Version
```bash
npm view constructs versions --json | tail -3
# Check available versions, don't hardcode patch version
```

### 10. RDS PostgreSQL Version Mismatch (ap-east-1 / Oracle Linux)
CDK `PostgresEngineVersion` constants often map to engine versions NOT available in the target region. `VER_15_7` failed with "Cannot find version 15.7", `VER_16_3` (highest constant) also not available.

**Diagnosis:**
```bash
aws rds describe-db-engine-versions --engine postgres --region ap-east-1 \
  --query 'DBEngineVersions[?contains(EngineVersion,`16.`)].[EngineVersion,Status]'
```

**Workaround:** Use the highest available CDK constant with `as any` cast, then verify actual version via AWS CLI:
```typescript
// CDK constant may not match actual available version
version: PostgresEngineVersion.VER_16 as any,
// Actual ap-east-1 available: 16.6 (VER_16 maps here via postgresFullVersion)
// Always verify with AWS CLI after deployment
```

### 11. RDS MasterUsername "admin" is Reserved
```
MasterUsername admin cannot be used as it is a reserved word
```
**Fix:** Use a different username like `umacai` or `appuser`.

### 12. CloudFront ACM Certificate Must Be in us-east-1
```
The specified SSL certificate doesn't exist, isn't in us-east-1 region
```
CloudFront certificates MUST be in `us-east-1` regardless of stack region.

**Options:**
- Option A: Create certificate in `us-east-1` via console or cross-region stack, then use `Certificate.fromCertificateArn()`
- Option B: Use `ViewerCertificate.fromCloudFrontDefaultCertificate()` (no custom domain)
- Option C: Bootstrap a separate stack in us-east-1 that creates and exports the cert

```typescript
// In us-east-1 stack:
new Certificate(this, 'SiteCert', { domainName: 'example.com', ... });
// Export ARN

// In main stack (ap-east-1):
const cert = Certificate.fromCertificateArn(this, 'Cert',
  'arn:aws:acm:us-east-1:ACCOUNT:certificate/XXX');
```

### 13. S3 Bucket Already Exists After Failed Stack Rollback
When a CloudFormation stack fails and rolls back, S3 buckets are sometimes NOT deleted, causing subsequent deploys to fail:
```
AWS::EarlyValidation::ResourceExistenceCheck - ResourceExistenceCheck
```
**Fix:** Manually delete the orphaned bucket:
```bash
aws s3 rb s3://bucket-name --force
```

## Deployment Commands
```bash
cdk bootstrap aws://ACCOUNT/REGION
cdk list
cdk synth
cdk diff
cdk deploy --all
cdk destroy --all
```

## Typical package.json Scripts
```json
{
  "scripts": {
    "build": "tsc",
    "cdk": "cdk",
    "cdk:bootstrap": "cdk bootstrap",
    "cdk:list": "cdk list",
    "cdk:synth": "cdk synth",
    "cdk:diff": "cdk diff",
    "cdk:deploy": "cdk deploy --all"
  }
}
```
