---
name: cdk-route53-apigateway-alias
description: CDK v2 Route53 ARecord alias to API Gateway custom domain — workaround for missing IAliasRecordTarget bind() method
retired: 2026-07-28 archived:case-history
---
Last-verified: 2026-07-28
# CDK Route53 ARecord Alias to API Gateway Custom Domain

## Problem
CDK v2 fails when trying to use `aws_route53.ARecord` with `RecordTarget.fromAlias()` targeting an `aws_apigateway.DomainName` custom domain.

**Error:**
```
TypeError: props.target.aliasTarget.bind is not a function
```

**Root cause:** `aws_apigateway.DomainName` in CDK v2 does NOT implement the `IAliasRecordTarget` interface with a `bind()` method (unlike CDK v1). There is no `.target` property on DomainName that provides `dnsName` and `hostedZoneId`.

## Solution: Use CfnRecordSet Directly

Use `aws_route53.CfnRecordSet` instead of `aws_route53.ARecord`, and reference the domain's CloudFormation attributes via `Fn::GetAtt`:

```javascript
const { Stack, aws_route53, aws_apigateway } = require('aws-cdk-lib')

// Domain must be created before CfnRecordSet
const apiDomain = new aws_apigateway.DomainName(this, 'ApiDomain', {
  domainName: props.domainName,
  certificate: cert,
  endpointType: aws_apigateway.EndpointType.REGIONAL,
  securityPolicy: aws_apigateway.SecurityPolicy.TLS_1_2,
})

// Use CfnRecordSet for the A alias record
new aws_route53.CfnRecordSet(this, 'ApiDnsRecord', {
  name: props.domainName,
  type: 'A',
  hostedZoneId: zone.hostedZoneId,
  aliasTarget: {
    dnsName: apiDomain.domainNameAliasDomainName,
    hostedZoneId: apiDomain.domainNameAliasHostedZoneId,
    evaluateTargetHealth: false,
  },
})
```

## Other CDK v2 Compatibility Issues Found

1. **NODEJS_20_X does not exist in aws-cdk-lib@2.x** — Only up to `NODEJS_18_X`
2. **aws-cdk-lib@latest (2.253+) has incompatible alias target** — The `RecordTarget.fromAlias({ targetType: 'api-gateway', apigatewayDomain: domain })` pattern fails with `aliasTarget.bind is not a function`. Use aws-cdk-lib@2.100.0 or similar stable v2 release.

## CDK Project Setup (Node.js/commonjs)

```bash
mkdir -p cdk/lib
cd cdk
npm init -y
npm install aws-cdk-lib@2.100.0 constructs
```

`cdk.json`:
```json
{ "app": "node bin.js" }
```

`bin.js`:
```javascript
'use strict'
const { App } = require('aws-cdk-lib')
const { LemontreeApiStack } = require('./lib/stack')

const app = new App()
new LemontreeApiStack(app, 'LemontreeApiStack', {
  env: {
    account: process.env.CDK_ACCOUNT || process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_REGION || process.env.CDK_DEFAULT_REGION,
  },
  domainName: 'api.david-developer.com',
  hostedZoneId: 'ZXXXXXXXXXXXX',
  lambdaBundlePath: '../dist/lambda.zip',
})
```

## Useful Commands

```bash
cdk synth          # Preview CloudFormation
cdk diff           # Show changes
cdk bootstrap      # First time only
cdk deploy         # Deploy stack
```
