---
name: route53-nginx-https
description: 使用 AWS Route53 + nginx + Let's Encrypt 為測試網域建立穩定 HTTPS URL。適用於需要在 AWS 管理的網域上對外暴露測試服務，取代 Cloudflare Tunnel。
tags: ["devops", "aws", "route53", "nginx", "https"]
related_skills: ["cloudflare-tunnel-vite-dev", "node-static-proxy-cloudflare"]
---

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
