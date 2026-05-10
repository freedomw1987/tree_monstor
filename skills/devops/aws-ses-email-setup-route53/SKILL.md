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
- `aws route53` IAM permissions
- `ses` IAM permissions

## 1. Verify Domain with SES

```bash
# Add domain to SES
aws ses verify-domain-identity --domain yourdomain.com --region us-east-1

# Get verification token for TXT record
aws ses get-identity-verification-attributes --identities yourdomain.com --region us-east-1

# Get DKIM tokens (3 CNAME records)
aws ses verify-domain-dkim --domain yourdomain.com --region us-east-1
```

## 2. Add Route53 DNS Records

Get hosted zone ID:
```bash
aws route53 list-hosted-zones --output json
# Zone ID is in "Id": "/hostedzone/Z0XXXXX"
```

Add TXT record for domain verification:
```bash
ZONE_ID="Z0XXXXX"
TOKEN="<VerificationToken from step 1>"

aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch "{
  \"Changes\": [{
    \"Action\": \"UPSERT\",
    \"ResourceRecordSet\": {
      \"Name\": \"_amazonses.yourdomain.com\",
      \"Type\": \"TXT\",
      \"TTL\": 300,
      \"ResourceRecords\": [{\"Value\": \"\\\"$TOKEN\\\"\"}]
    }
  }]
}" --region us-east-1
```

Add 3 DKIM CNAME records (use tokens from step 1):
```bash
ZONE_ID="Z0XXXXX"

aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch "{
  \"Changes\": [
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"<Token1>._domainkey.yourdomain.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"<Token1>.dkim.amazonses.com\"}]
      }
    },
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"<Token2>._domainkey.yourdomain.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"<Token2>.dkim.amazonses.com\"}]
      }
    },
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"<Token3>._domainkey.yourdomain.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"<Token3>.dkim.amazonses.com\"}]
      }
    }
  ]
}" --region us-east-1
```

## 3. Verify Setup

```bash
# Check domain verification status
aws ses get-identity-verification-attributes --identities yourdomain.com --region us-east-1
# Should show "VerificationStatus": "Success"

# Check DKIM
aws ses get-identity-dkim-attributes --identities yourdomain.com --region us-east-1
# Should show "DkimVerificationStatus": "Success", "DkimEnabled": true
```

## 4. Verify Recipient Emails (Sandbox Mode)

By default SES is in sandbox mode — **all recipient emails must be verified**:
```bash
aws ses verify-email-identity --email-address recipient@gmail.com --region us-east-1
```
Recipient must click the verification email from AWS before you can send to them.

To request production access (removes recipient verification requirement):
```bash
aws ses put-account-sending-attributes --enabled true --region us-east-1
# Or via AWS Console: AWS SES → Account dashboard → Request production access
```

## 5. Configure Backend .env

```env
AWS_REGION=us-east-1
SES_FROM_EMAIL=noreply@yourdomain.com
```
AWS SDK automatically reads credentials from `~/.aws/credentials`.

## 6. Test Send

```bash
aws ses send-email \
  --from "noreply@yourdomain.com" \
  --to "verified@recipient.com" \
  --subject "Test" \
  --text "Body" \
  --region us-east-1
```

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Email address is not verified` | Sandbox mode, recipient not verified | Verify recipient email or request production access |
| `Could not connect to endpoint` | Wrong region | SES available regions: us-east-1, us-west-2, eu-west-1 |
| `Domain not verified` | DNS not propagated | Wait 2-5 min or check Route53 records |
