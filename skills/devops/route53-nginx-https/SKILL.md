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

## 常見錯誤

| 錯誤 | 原因 | 處理 |
|------|------|------|
| `Address already in use` on port 80 | Docker 或其他進程佔用 | 先停掉該進程 |
| `DNS problem: NXDOMAIN` | Route53 A 紀錄未設定 | 先讓使用者在 Route53 加 A 紀錄再繼續 |
| `nginx: [emerg] bind() to 0.0.0.0:80 failed` | 舊 nginx 進程未清除 | `sudo systemctl restart nginx` |

---

## 參數參考

- 伺服器公網 IP：`54.169.93.94`
- Domain：`david-developer.com`
- nginx 設定檔目錄：`/etc/nginx/sites-available/` + `sites-enabled/`
- Let's Encrypt 憑證：`/etc/letsencrypt/live/<subdomain>/`
- Certbot log：`/var/log/letsencrypt/letsencrypt.log`
