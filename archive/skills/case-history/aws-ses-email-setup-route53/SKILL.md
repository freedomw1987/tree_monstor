---
name: aws-ses-email-setup-route53
description: Set up AWS SES for transactional email — verify domain with DKIM, add Route53 DNS records, configure credentials for SDK use
tags: [aws, ses, route53, email, devops]
retired: 2026-07-28 archived:case-history
---
Last-verified: 2026-07-28
# AWS SES + Route53 Domain Setup

## Prerequisites
- AWS CLI configured (`aws configure`)
- Domain registered in Route53
- `ses:CreateEmailIdentity`, `ses:GetEmailIdentity` IAM permissions
- `route53:ChangeResourceRecordSets` IAM permissions
## Critical: SES Region Identity Isolation

**SES identities (domain/email) are REGION-SPECIFIC.** Creating a domain identity in `us-east-1` does NOT make it available in `ap-southeast-2` or any other region. Each AWS region operates its own independent SES service.

**Practical implication**: If you set up SES in `us-east-1` but your backend uses `SES_REGION=ap-southeast-2`, the domain will not be verified in `ap-southeast-2`. You must either:
- Use the **same region** everywhere (recommended: `us-east-1`)
- Or set up SES identities separately in each region you use

**For Elysia.js/Bun backends**: The env var in `.env` must match what the code reads. Code typically uses `SES_REGION` (not `AWS_REGION`).

## Prerequisites
- AWS CLI configured (`aws configure`)
- Domain registered in Route53
- `ses:CreateEmailIdentity`, `ses:GetEmailIdentity` IAM permissions
- `route53:ChangeResourceRecordSets` IAM permissions
- **SES region: use `--region us-east-1`** for all setup commands

## 1. Verify Domain with SES (SESv2 API)

```bash
# Create domain identity + get DKIM tokens in one call
aws sesv2 create-email-identity \
  --email-identity yourdomain.com \
  --region us-east-1
```

Response includes 3 DKIM tokens:
```json
{
  "DkimAttributes": {
    "Tokens": [
      "kzvhheahaevapu752va5dodlxconelgx",
      "2ejiojj3nmhh6xrxak45vp6fnzzkj7da",
      "u3yminhz5lbjcw6bsikq22dlwi4zalqi"
    ]
  }
}
```

Also verify a sending email address:
```bash
aws sesv2 create-email-identity \
  --email-identity noreply@yourdomain.com \
  --region us-east-1
```

## 2. Add Route53 DNS Records

Get hosted zone ID:
```bash
aws route53 list-hosted-zones --output json
# Zone ID is in "Id": "/hostedzone/Z0XXXXX"
```

DKIM token format: `selectorN._domainkey.yourdomain.com CNAME selectorN.<token>.dkim.amazonses.com`

```bash
ZONE_ID="Z0XXXXX"

aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch "{
  \"Changes\": [
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"selector1._domainkey.yourdomain.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 1800,
        \"ResourceRecords\": [{\"Value\": \"selector1.<Token1>.dkim.amazonses.com\"}]
      }
    },
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"selector2._domainkey.yourdomain.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 1800,
        \"ResourceRecords\": [{\"Value\": \"selector2.<Token2>.dkim.amazonses.com\"}]
      }
    },
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"selector3._domainkey.yourdomain.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 1800,
        \"ResourceRecords\": [{\"Value\": \"selector3.<Token3>.dkim.amazonses.com\"}]
      }
    },
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"yourdomain.com\",
        \"Type\": \"TXT\",
        \"TTL\": 3600,
        \"ResourceRecords\": [{\"Value\": \"\\\"v=spf1 include:amazonses.com ~all\\\"\"}]
      }
    },
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"_dmarc.yourdomain.com\",
        \"Type\": \"TXT\",
        \"TTL\": 3600,
        \"ResourceRecords\": [{\"Value\": \"\\\"v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com; pct=100\\\"\"}]
      }
    }
  ]
}" --region us-east-1
```

**Domain ownership verification**: After creating the domain identity, AWS assigns a verification token. Add this TXT record to prove you own the domain:
```bash
# First get the token (run this after create-email-identity):
aws ses verify-domain-identity --domain yourdomain.com --region us-east-1
# Returns: { "VerificationToken": "TFKJIBNmz..." }

# Then add the TXT record:
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch "{
  \"Changes\": [{
    \"Action\": \"UPSERT\",
    \"ResourceRecordSet\": {
      \"Name\": \"_amazonses.yourdomain.com\",
      \"Type\": \"TXT\",
      \"TTL\": 3600,
      \"ResourceRecords\": [{\"Value\": \"\\\"<VerificationToken>\\\"\"}]
    }
  }]
}" --region us-east-1
```

**Note**: DKIM verification can remain "Pending" for up to 72 hours even after DNS records are set. Domain verification via TXT record is what enables sending — email sending works as soon as domain verification succeeds, even if DKIM is still pending.

## 3. Verify Setup

**SESv2 API** (for identity info):
```bash
aws sesv2 get-email-identity --email-identity yourdomain.com --region us-east-1
# VerifiedForSendingStatus: true when domain is verified
```

**SESv1 API** (for verification/DKIM status — NOT available in sesv2):
```bash
# Domain verification status
aws ses get-identity-verification-attributes --identities yourdomain.com --region us-east-1
# VerificationStatus: "Success" when domain ownership is confirmed

# DKIM verification status
aws ses get-identity-dkim-attributes --identities yourdomain.com --region us-east-1
# DkimVerificationStatus: "Success" when AWS detects DKIM DNS records (can take up to 72h)
```

## 4. Verify Recipient Emails (Sandbox Mode)

By default SES is in sandbox mode — **all recipient emails must be verified**:
```bash
aws sesv2 create-email-identity --email-address recipient@gmail.com --region us-east-1
```
Recipient must click the verification email from AWS before you can send to them.

To request production access (removes recipient verification requirement):
```bash
aws sesv2 put-account-details \
  --production-access-enabled \
  --region us-east-1
# Or via AWS Console: AWS SES → Account dashboard → Request production access
```

## 5. Configure Backend .env

```env
SES_REGION=us-east-1
SES_FROM_EMAIL=noreply@yourdomain.com
AWS_ACCESS_KEY_ID=AKIAZGGVGP6VXXXXXXX
AWS_SECRET_ACCESS_KEY=your_secret_key
```

**Important**: Bun automatically loads `.env` files — do NOT use `dotenv` or `import "dotenv/config"` in Bun projects.

AWS SDK automatically reads credentials from `~/.aws/credentials` or environment variables.

### ⚠️ Credential Provider Pitfall

If `.env` contains `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` but the SDK still fails with credential errors (e.g., "Credentials not found"), the issue may be that `~/.aws/credentials` file has display-truncated keys or formatting issues. **Solution: use `fromIni` credential provider explicitly in code:**

```typescript
import { SESClient } from "@aws-sdk/client-ses";
import { fromIni } from "@aws-sdk/credential-providers";

const sesClient = new SESClient({
  region: process.env.SES_REGION || "us-east-1",
  credentials: fromIni({ profile: "default" }), // ← explicit fromIni, not default chain
});
```

Or set env var before initialization:
```bash
export AWS_SDK_LOAD_CONFIG=1
```
This forces the SDK to use `~/.aws/credentials`/`~/.aws/config` files properly.

## ⚠️ Critical Invariant — "API 返 200 唔等於 email 真係 send 出"

**2026-06-19 umac_ai lesson**: 用戶投訴 forgot-password 冇 email 收到。POST `/api/auth/forgot-password` 返 HTTP 200 + `{"ok":true,"message":"如果該電郵存在，重設連結已發送"}` — 表象完美。但實查 SES `us-east-1` `list-email-identities` → 0 個 identity,`get-account` → `ProductionAccessEnabled: false` 仲喺沙盒。**整個 backend 嘅 email code path 由始至終冇 call SES,或者 call SES 但失敗被 generic success handler 食咗**。

### 5 個 verify commands (10 秒,唔需要 project source code)

```bash
# 1. SES region 有冇 verified identity
aws sesv2 list-email-identities --region us-east-1 --output json | jq '.EmailIdentities'
# 預期: ["yourdomain.com", "noreply@yourdomain.com"] 或同類
# 0 = SES 沙盒空,邊個 email 都 send 唔出

# 2. SES 喺沙盒定 production
aws sesv2 get-account --region us-east-1 --query '{sandbox:ProductionAccessEnabled,quota:SendQuota.Max24HourSend}' --output text
# 預期: False<TAB>50000 = production access
# 0 個 200 = 沙盒 mode + 未申請 production

# 3. Backend 端 health (確認 process 仲在返)
curl -fsS https://api.<your-domain>.site/health
# 200 = backend alive; 5xx = backend crash, fix 嗰個先

# 4. 直接 trigger forgot-password (用你 controlled 嘅 email)
curl -sS -X POST https://api.<your-domain>.site/api/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"email":"your-test@your-domain.com"}' \
  -w "\nHTTP %{http_code} time %{time_total}s\n"
# 200 + generic success message 唔等於 send 成功 — 必須 cross-check 下面 SES send log

# 5. SES send quota usage (確認有冇真係 call 過 SES)
aws sesv2 get-account --region us-east-1 --query 'SendQuota.{SentLast24:SentLast24Hours,Max24:Max24HourSend}' --output text
# SentLast24 = 0.0 + API 返 200 = backend 根本冇 call SES = bug 喺 backend code
# SentLast24 > 0 = backend 試過 send, 但 SES 入面查 send events 拎 detail
```

### SES Send Event Audit (找出邊個 call 失敗)

```bash
# 配 SES Event Destination (CloudWatch / SNS) — 拎最近 24h 嘅 send attempt
aws sesv2 list-configuration-sets --region us-east-1
# 0 個 = 冇 setup event tracking, send log 永遠查唔到

# 用 CloudWatch Logs Insights query SES log group
aws logs start-query \
  --log-group-name /aws/ses/<configuration-set> \
  --start-time $(date -u -v-24H +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, eventType, mail.messageId, mail.source, mail.destination, complaint.feedbackType, bounce.bounceType, reject.reason | filter eventType = "Send" or eventType = "Bounce" or eventType = "Reject"' \
  --region us-east-1
```

**3 個 pitfall**(almost 100% 撞):

1. **Generic 200 success handler 食咗 exception** — backend catch SES `MessageRejected` 但 `return { ok: true }` 冇 log。Fix: `console.error('SES send failed', err)` + alerting。
2. **Wrong SES region** — backend `.env` 寫 `SES_REGION=ap-east-1` 但 SES identity 只喺 `us-east-1` verified。Fix: `aws sesv2 get-email-identity --region <code-region>` 確認。
3. **Sandbox + unverified recipient** — production mode 未申請 OR 申請咗但個 recipient email 唔喺 verified list。Fix: 申請 production access, 或 `aws sesv2 create-email-identity --email-identity <recipient>` verify 佢。

**心法**: **報 email 唔 work 嘅 bug,**第一步唔係睇 code,**係跑呢 5 個 verify command**。If 1/2/5 三個入面有 1+ 個 fail,**code path 一定有問題**(根本冇 call SES / region 錯 / recipient unverified),**唔需要讀 source code 都知 root cause 喺邊**。

## 6. Test Send (SESv2)

```bash
aws sesv2 send-email \
  --from-email-address noreply@yourdomain.com \
  --destination '{"ToAddresses":["verified@recipient.com"]}' \
  --content '{"Simple":{"Subject":{"Data":"Test","Charset":"UTF-8"},"Body":{"Text":{"Data":"Body","Charset":"UTF-8"}}}}' \
  --region us-east-1
```

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Email address is not verified` | Sandbox mode, recipient not verified | Verify recipient email or request production access |
| `Could not connect to endpoint` | Wrong region | SESv2 only available in us-east-1, us-west-2, eu-west-1 — always use `--region us-east-1` |
| `Domain not verified` | DNS not propagated | Wait 2-5 min or check Route53 records |
| `Found invalid choice 'get-domain-verification-attributes'` | Used wrong subcommand | Use SESv2: `aws sesv2 get-email-identity --email-identity domain.com` |
| `Found invalid choice 'get-domain-dkim-attributes'` | Used sesv2 instead of ses | Use SESv1: `aws ses get-identity-dkim-attributes --identities domain.com` |
| `--domain not valid` for `create-email-identity` | Wrong flag name | Use `--email-identity yourdomain.com` (even for domains) |
| `--from` ambiguous for `send-email` | Wrong flag name | Use `--from-email-address` (SESv2) |
| `Email address is not verified in region` | Identity created in different region | Use `us-east-1` everywhere, or set up identity in the correct region |
