---
name: cloudflare-named-tunnel-route53
description: 建立穩定的 HTTPS 測試 URL（子網域 + Cloudflare Named Tunnel + AWS Route53），適用於 AWS NAT/非公網實例
category: devops
---

# Cloudflare Named Tunnel + Route53 穩定 HTTPS URL 架設

## 適用場景

伺服器位於 AWS NAT 內網或使用共享公網 IP，port 80/443 無法直接從外部訪問（curl timeout 而不是 connection refused）。此時 nginx + Let's Encrypt 方案不可行，只能靠 Cloudflare Tunnel。

## 前置條件

- `david-developer.com` 網域在 Route53 管理
- `chatbot.david-developer.com` 已有一條 A 紀錄指向伺服器公網 IP
- AWS CLI 已設定（`~/.aws/credentials`），具備 Route53 修改權限
- `cloudflared` 已安裝
- nginx 已安裝（可選）

## Step-by-Step 架設流程

### Step 1：確認伺服器網路環境

```bash
# 檢查是否有真正的公網 IP（可直接從外部連入）
curl -s --connect-timeout 5 http://<YOUR_PUBLIC_IP>/

# 如果 timeout → NAT/共享 IP，只能用 Cloudflare Tunnel
# 如果 connection refused → port 開放但無服務
# 如果 200 → 有真正公網 IP，可用 nginx + Let's Encrypt
```

### Step 2：啟動本地服務（任何 port）

```bash
# 例如 frontend on 5174, backend on 3002
cd ~/projects/whatsapp-chatbot/backend && node server.js &
cd ~/projects/whatsapp-chatbot/frontend && node server.js &
```

### Step 3：啟動 Cloudflare Quick Tunnel

```bash
# Kill 舊的 cloudflared 進程
pkill -f cloudflared; sleep 1

# 啟動 tunnel（用 sh -c 包裝，確保輸出被捕獲到 log）
sh -c 'cloudflared tunnel --url http://localhost:5174 > /tmp/cf.log 2>&1' &

# 等 10 秒，取出 URL
sleep 10 && grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cf.log | head -1
```

### Step 4：在 Route53 建立 CNAME 指向 tunnel URL

```bash
# 取得 tunnel URL
TUNNEL_URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cf.log | head -1)

# 取出 trycloudflare.com 主機名部分
CF_HOST=$(echo $TUNNEL_URL | sed 's|https://||')

# 在 Route53 建立 CNAME（chatbot.david-developer.com → <hash>.trycloudflare.com）
ZONE_ID=$(aws route53 list-hosted-zones --query 'HostedZones[*].[Id]' --output text | grep david-developer.com | cut -d/ -f3)

aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch "
{
  \"Changes\": [
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"chatbot.david-developer.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$CF_HOST\"}]
      }
    }
  ]
}"
```

### Step 5：驗證

```bash
# 等 DNS propagation（通常 30 秒內）
sleep 30 && curl -s -o /dev/null -w "%{http_code}" https://chatbot.david-developer.com/
# 預期：200
```

---

## 關於 Cloudflare Tunnel 的兩個模式

### Quick Tunnel（適合臨時/每次重啟 URL 會變）
```bash
cloudflared tunnel --url http://localhost:PORT
```
- 不需要登入 Cloudflare
- URL 每次重啟隨機變化
- Route53 CNAME 每次要更新

### Named Tunnel（適合長期穩定 URL）
```bash
# 1. 在有瀏覽器的機器登入
cloudflared login

# 2. 建立命名 tunnel
cloudflared tunnel create my-chatbot

# 3. 設定 DNS
cloudflared tunnel route dns my-chatbot chatbot.david-developer.com

# 4. 啟動（ID 可從 cloudflared tunnel list 取得）
cloudflared tunnel run --token <TOKEN> my-chatbot
```
- URL 永久穩定
- Route53 不用每次更新
- 需要一次性的 `cloudflared login` OAuth 授權

---

## ⚠️ 重要教訓

### 1. AWS EC2 公網 IP 不一定可直接訪問
，並非所有 public IP 都可以從外部連入。AWS 的 NAT Gateway、EC2 Shared IP、EIP 等多種模式都會造成「IP 有回應但 port 被擋」的情況。

**判斷方式：**
```bash
curl -s --connect-timeout 5 http://<公網IP>/
# timeout = 完全進不來（NAT/擋port）→ 只能用 Cloudflare Tunnel
# refused = port 閒置 → 可用 nginx + Let's Encrypt
# 200 = 完全可訪問 → 可用 nginx + Let's Encrypt
```

### 2. certbot --dns-route53 需要特殊 credential 路徑
用 `sudo` 執行 certbot 時，不會繼承 ubuntu user 的 AWS credentials。

**正確做法：**
```bash
# 把 AWS credentials 複製到 certbot 可讀取的位置
sudo mkdir -p /etc/letsencrypt/.aws
sudo cp ~/.aws/credentials /etc/letsencrypt/.aws/credentials
sudo cp ~/.aws/config /etc/letsencrypt/.aws/config

# 用 bash -c 設定環境變數執行（繞過 sudo 環境隔離）
AWS_SHARED_CREDENTIALS_FILE=/etc/letsencrypt/.aws/credentials \
AWS_CONFIG_FILE=/etc/letsencrypt/.aws/config \
  sudo certbot certonly --dns-route53 -d chatbot.david-developer.com \
  --non-interactive --agree-tos --email you@example.com
```

### 3. nginx 安裝時要移除預設 site
```bash
sudo rm -f /etc/nginx/sites-enabled/default
```
否則 nginx 可能優先使用 default site 而非你的設定。

### 4. Docker 可能佔用 port 80
檢查方式：
```bash
sudo lsof -i :80
```
如果有 `docker-proxy` 佔用，需要先停掉 Docker container：
```bash
sudo docker stop <container-name>
```

---

## 日後新增專案 URL 的標準流程

1. 啟動服務（確認 listen port）
2. `pkill -f cloudflared; sleep 1`
3. `cloudflared tunnel --url http://localhost:<PORT> > /tmp/cf.log 2>&1 &`
4. `sleep 10 && grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cf.log | head -1`
5. 在 Route53 建立 CNAME 記錄
6. 驗證 `https://<subdomain>.david-developer.com/`

---

## 常用指令參考

```bash
# 確認服務運作
curl localhost:3002/api/health  # backend
curl localhost:5174             # frontend

# 查看 tunnel URL
grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cf.log | head -1

# 查看 DNS 紀錄
dig +short chatbot.david-developer.com

# 確認 nginx 設定正確
sudo nginx -t

# 重啟 nginx
sudo nginx -s reload
```
