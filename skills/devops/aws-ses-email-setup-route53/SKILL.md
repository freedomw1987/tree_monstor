---
name: aws-ses-email-setup-route53
description: Set up AWS SES for transactional email — verify domain with DKIM, add Route53 DNS records, configure credentials for SDK use
version: 1.0.0
tags: [aws, ses, route53, email, devops]
metadata:
  hermes:
    tags: [aws, ses, route53, email, devops]
---

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
