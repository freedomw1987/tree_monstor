---
name: route53-nginx-https
description: 使用 AWS Route53 + nginx + Let's Encrypt 為測試網域建立穩定 HTTPS URL。適用於需要在 AWS 管理的網域上對外暴露測試服務，取代 Cloudflare Tunnel。
tags: ["devops", "aws", "route53", "nginx", "https", "cloudflare-tunnel"]
---


Last-verified: 2026-07-28
# Route53 + nginx + Let's Encrypt 穩定 HTTPS URL 架設

## 適用場景
- 網域由 AWS Route53 管理（如 david-developer.com）
- 需要對外提供穩定的 HTTPS URL 給用戶測試
- 不想依賴 Cloudflare Tunnel 或其 2 秒 SSE timeout 限制

## 核心優勢
- DNS 在 Route53 直接管理，URL 永久穩定不變
- Let's Encrypt 免費自動 SSL，自動 renew
- 完全繞過 Cloudflare Tunnel 的 SSE timeout 問題
- 日後新專案只需加 nginx 設定檔 + Route53 A 紀錄

## 子網域命名約定
`[project].david-developer.com`
例：`chatbot.david-developer.com`

---

## 標準流程

### 前置條件
使用者在 Route53 已經有 A 紀錄指向伺服器公網 IP。

### Step 1：確認 port 80 可用
```bash
sudo lsof -i :80
```
如果有東西佔用，先停掉（通常是 Docker）：
```bash
sudo docker ps  # 找 PORTS 含 80/tcp 的
sudo docker stop <container-name>
# 或
sudo fuser -k 80/tcp
```

### Step 2：安裝 nginx + certbot
```bash
sudo apt-get update -qq
sudo apt-get install -y nginx certbot python3-certbot-nginx
```

### Step 3：申請 SSL（自動設定 nginx）
```bash
sudo certbot --nginx -d <subdomain.david-developer.com> \
  --non-interactive --agree-tos \
  --email david@david-developer.com --redirect
```
成功後 nginx 會自動重啟，SSL 憑證也會自動設定好。

### Step 4：驗證
```bash
curl -s -o /dev/null -w "%{http_code}" https://<subdomain.david-developer.com>
# 應返回 200
```

---

## 日後新專案流程

1. **使用者在 Route53** 新增 A 紀錄：`新專案名.david-developer.com` → `54.169.93.94`
2. **等待 DNS 生效**（通常幾分鐘）
3. **執行 certbot**：
   ```bash
   sudo certbot --nginx -d <new-subdomain.david-developer.com> \
     --non-interactive --agree-tos --email david@david-developer.com --redirect
   ```
4. **交付 URL** 給用戶

不需要重新安裝 nginx 或 certbot。

---

## 單一 Nginx 設定檔 + 重新申請 SSL（推薦）

適用：nginx config 已存在但 SSL 失效或從未申請。

1. **建立 nginx 設定**（不含 SSL）：
   ```nginx
   server {
       listen 80;
       listen [::]:80;
       server_name <subdomain.david-developer.com>;

       root /var/www/<subdomain.david-developer.com>;
       index index.html;

       location / {
           try_files $uri $uri/ /index.html;
       }
   }
   ```
2. **寫入設定**：`sudo cp <config> /etc/nginx/sites-available/<subdomain.david-developer.com>`
3. **連結並測試**：`sudo ln -sf ... && sudo nginx -t`
4. **用 certonly --webroot 申請 SSL**（繞過 nginx SSL 設定）：
   ```bash
   sudo certbot certonly --webroot \
     -w /var/www/<subdomain.david-developer.com> \
     -d <subdomain.david-developer.com> \
     --non-interactive --agree-tos -m david@<domain>
   ```
5. **更新 nginx 設定加入 SSL**（見下方完整 template）
6. **重載 nginx**：`sudo nginx -s reload`

### 完整 Nginx Template（含 SSL + /api/ proxy）
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name <subdomain.david-developer.com>;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name <subdomain.david-developer.com>;

    ssl_certificate /etc/letsencrypt/live/<subdomain.david-developer.com>-0001/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/<subdomain.david-developer.com>-0001/privkey.pem;

    root /var/www/<subdomain.david-developer.com>;
    index index.html;

    client_max_body_size 50M;
    proxy_read_timeout 300s;

    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
        chunked_transfer_encoding on;
        proxy_request_buffering off;
        tcp_nodelay on;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

---

## 常見錯誤

| 錯誤 | 原因 | 處理 |
|------|------|------|
| `Address already in use` on port 80 | Docker 或其他進程佔用 | 先停掉該進程 |
| `DNS problem: NXDOMAIN` | Route53 A 紀錄未生效或本地 DNS 未刷新 | 等 2-5 分鐘或換用 `dig` 確認；Route53 可能已設定但本地 resolver 未更新 |
| `nginx: [emerg] cannot load certificate` on restart | 之前 certbot 申請失敗但 nginx config 已有 SSL 路徑 | 用 `certonly --webroot` 而非 `--nginx`，或先移除 SSL 行再用 `--nginx` |
| certbot fails after failed `--nginx` attempt | nginx -t 失敗，certbot 會拒絕操作 | 先清除 `/etc/letsencrypt/live/<subdomain>/`，用 `certonly --webroot` 完成 |
| nginx 命中 default site 而非新設定 | 安裝時預設 site 未移除 | `sudo rm -f /etc/nginx/sites-enabled/default` 後 reload |
| `sudo certbot --dns-route53` 讀不到 AWS credentials | sudo 不繼承 user 的 `~/.aws/` | 複製 credentials 到 `/etc/letsencrypt/.aws/`，用 `AWS_SHARED_CREDENTIALS_FILE=... sudo certbot certonly --dns-route53 ...` 指定 |

---

## Alternatives: Cloudflare Tunnel（伺服器不可直連時的後備方案）

本 skill（nginx + Let's Encrypt）是首選，但**前提是 port 80/443 可從外部直連**。伺服器在 NAT / 共享公網 IP 後面時（AWS NAT Gateway、EC2 shared IP 等），只能用 Cloudflare Tunnel。

### 先判斷可達性（選型的第一步）

```bash
curl -s --connect-timeout 5 http://<公網IP>/
# timeout            → NAT / port 被擋 → 只能用 Cloudflare Tunnel
# connection refused → port 閒置可用   → 用本 skill（nginx + certbot）
# 200                → 完全可達        → 用本 skill
```

注意：AWS EC2 的「公網 IP 有回應」不代表 port 可連入；`ifconfig.me` 看到的 IP 與實際可路由 IP 在 NAT 下不同。

### Tunnel 兩種模式

| 模式 | 認證 | URL | 穩定性 |
|------|------|-----|--------|
| Quick Tunnel（`cloudflared tunnel --url http://localhost:PORT`） | 免登入 | 隨機 `.trycloudflare.com` | 每次重啟變；如配 Route53 CNAME 須每次更新 |
| Named Tunnel（`cloudflared login` → `tunnel create` → `tunnel route dns`） | 一次性 OAuth | 自己的子網域 | 永久穩定 |

**Gotcha**：Quick Tunnel 加 `--hostname` 未登入時會被**靜默忽略** — 仍然拿到 trycloudflare.com URL，自訂網域永遠不生效。要自訂子網域就用 Named Tunnel，或 Quick Tunnel + Route53 CNAME（每次重啟更新）。

### Tunnel 關鍵 gotchas（用 tunnel 時必讀）

1. **啟動順序**：先 backend → 再前端 static/proxy server（curl 確認 200）→ 最後才啟 cloudflared。順序錯會 connection refused / EADDRINUSE / zombie process。
2. **先清舊進程**：`pkill -9 -f cloudflared; sleep 1` — 舊 tunnel 殘留會造成「stale URL」（讀到舊 log 的死鏈接）、port 指錯。
3. **輸出必須 redirect 到 log**：`sh -c 'cloudflared tunnel --url http://localhost:PORT > /tmp/cf.log 2>&1' &`，等約 10 秒後 `grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cf.log | head -1`。不包 `sh -c` 輸出會被丟棄，URL 永遠拿不到。
4. **進程活著 ≠ URL 可達**：一律 `curl -s -o /dev/null -w "%{http_code}"` 驗證 200 後才交付 URL。
5. **Vite dev server 過 tunnel 會 403**：HMR WebSocket 被擋 + Vite host check。解法二選一：(a) `npm run dev` 配 `server.allowedHosts: true`；(b) `npm run build` 後用 static+proxy server 服 `dist/`（單 port 兼代理 `/api` 到 backend，避 CORS）。
6. **`vite --port X` 不讀 `vite.config.js`**：proxy / allowedHosts 全部失效，只有 `npm run dev` 會正確載入 config。
7. **SSE 長串流**：tunnel 有 timeout 限制（本 skill 取代 tunnel 的主因）；長 SSE / AI streaming 服務優先用 nginx 方案。

---

## DNS 傳播注意
Route53 設定完成後，線上 dig/nslookup 可能立即回應，但本地 `host`/`nslookup` 可能持續回 NXDOMAIN（因為本地 resolver 快取）。以 `curl` 實際能訪問為準。

---

## 參數參考

- 伺服器公網 IP：`54.169.93.94`
- Domain：`david-developer.com`
- nginx 設定檔目錄：`/etc/nginx/sites-available/` + `sites-enabled/`
- Let's Encrypt 憑證：`/etc/letsencrypt/live/<subdomain>/`
- Certbot log：`/var/log/letsencrypt/letsencrypt.log`
