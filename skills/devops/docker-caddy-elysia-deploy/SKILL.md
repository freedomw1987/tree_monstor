---
name: docker-caddy-elysia-deploy
description: Docker + Caddy reverse proxy + Elysia.js (Bun) SPA 部署攻略
triggers:
  - docker compose elysia caddy
  - elysia health route prefix
  - caddy caddyfile syntax error
  - docker sqlite volume persistence
applicability: generic-pattern
---


Last-verified: 2026-07-28
# Docker + Caddy + Elysia.js 部署攻略

## 概述
將 Elysia.js (Bun) + React SPA 項目 Docker 化，使用 Caddy 作為反向代理（自動 HTTPS），替換舊的 nginx + certbot 部署。

## 架構
```
Internet → Caddy (443/80) → docker network
                              ├── chatbot-proxy (Caddy edge, 80/443)
                              ├── chatbot-backend (Bun :3001)
                              └── chatbot-frontend (Caddy SPA :80)
```

## 常見錯誤與修復

### 7. 在現有 Caddy Docker 容器加入新子網域 vhost
**場景**：現有的 Caddy 容器（chatbot-proxy）已經管理著 SSL 和多個網域，需要快速加入新的子網域（如 pos.david-developer.com）指向 host 上的服務

**Caddyfile 位置**：Caddyfile 通過 volume mount 進容器，所以改本地文件就能生效（不需要重 build）：
```
~/projects/whatsapp-chatbot/Caddyfile.proxy → /etc/caddy/Caddyfile (容器內)
```

**熱重載**：不需要重啟容器，直接：
```bash
docker exec chatbot-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

**Caddyfile 格式**（每個 vhost 一個 site block）：
```
pos.david-developer.com {
  handle_path /api/* {
    reverse_proxy 127.0.0.1:3000
  }
  handle /* {
    root * /home/ubuntu/projects/lemontree_aws/frontend/dist
    file_server
  }
}

chatbot.david-developer.com {
  ...
}
```

**⚠️ 重要：千萬不要在 docker-compose ports 加 port mapping 來「映射 backend port」** — Docker 會創建 docker-proxy 監聽 host port，搶佔原本的服務，導致 host 上的 backend 無法綁定。刪掉舊的 `ports: ["3000:3000"]` 就能恢復。

### 8. Docker `host.docker.internal` 在 Linux EC2 環境不可用
**問題**：`host.docker.internal` 在 Debian/Ubuntu 的某些 Docker 安裝版本無法解析，在 AWS EC2 Linux 實例上也無法使用。

**背景**：在 AWS EC2 (Debian) 上測試時，嘗試過 `host.docker.internal`、`172.17.0.1`（默認 bridge gateway）、`172.18.0.1` 都無法從 Caddy 容器訪問 host 服務。

**解法** — 三步確認 host IP：
1. 在 host 上執行 `ip addr` 找到 actual private IP（如 `172.31.19.145`）
2. 確認目標服務確實在 host 上監聽 `0.0.0.0`（不是 `127.0.0.1`）
3. 用這個實際 IP 作為 Caddy `reverse_proxy` 目標

```bash
# 在 host (EC2) 上找到實際 IP
ip addr show eth0 | grep inet
# → inet 172.31.19.145/20

# 在 Caddy 容器內測試（不走容器網路）
curl -s -X POST https://pos.david-developer.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@lemontree.hk","password":"Test123!@#"}'
```

**Caddyfile 配置（使用 host 真實 IP）**：
```
pos.david-developer.com {
  handle_path /api/* {
    reverse_proxy 172.31.19.145:3000
  }
  handle /* {
    reverse_proxy 172.31.19.145:3002
  }
}
```

### 9. Caddy 不能直接 serve host 目錄（容器內路徑不存在）
**問題**：嘗試用 Caddy 的 `file_server` 直接 serve host 上的靜態文件目錄，但容器內該路徑不存在。

**解法**：在 host 上啟動一個靜態文件伺服器（如 Python http.server），Caddy 再反向代理過去：
```bash
# host 上
cd ~/projects/lemontree_aws/frontend/dist
python3 -m http.server 3002

# Caddyfile
handle /* {
  reverse_proxy 172.31.19.145:3002
}
```

### 10. Caddy `handle_path` 會剝離前綴
**行為**：`handle_path /api/*` 會把 `/api` 前綴從 URL 中移除後再轉發給 backend。

例如：`POST https://pos.david-developer.com/api/auth/login`
→ 轉發給 backend 時變成 `POST 172.31.19.145:3000/auth/login`

**對後端路由的影響**：
- 如果 backend 路由是 `/auth/login` → ✅ 能匹配
- 如果 backend 路由是 `/api/auth/login` → ❌ 404（已剝離 `/api`）

**正確做法**：後端不要在路由中加 `/api` 前綴（因為 Caddy 已經剝離了）。如果需要 `/api` 前綴，則用 `handle /api/* { reverse_proxy ... }`（不剝離）。

### 11. Caddy container 是 `network_mode: host`
**發現**：Chatbot 項目的 Caddy 使用 `network_mode: host`，所以 `127.0.0.1` 直接等於 host 網路。

**驗證**：
```bash
docker inspect chatbot-proxy --format '{{.HostConfig.NetworkMode}}'
```

### 1. Caddyfile.spa — `try {path}` 語法無效
**錯誤**：Caddy v2 不支持 `file_server try {path}`  
**修復**：
```
handle { try_files {path} /index.html; file_server }
```

### 2. Caddyfile.proxy — email directive 位置
**錯誤**：email 在 site block 內造成 syntax error  
**修復**：放在 global options block `{}` 內：
```
{
  email admin@example.com
}
chatbot.david-developer.com {
  ...site config...
}
```

### 3. Elysia 健康檢查 — `/api/health` 404
**錯誤**：`.get('/health', ...)` 掛在 root，prefix 對不上 Caddy 的 `/api/*` 轉發  
**修復**：建立獨立的 routes plugin 明確使用 prefix：
```ts
// src/routes/health.ts
import { Elysia } from 'elysia'
export const healthRoutes = new Elysia({ prefix: '/api' })
  .get('/health', () => ({ ok: true, service: 'backend' }))
```
然後在 index.ts 註冊：`app.use(healthRoutes)`

### 4. docker-compose env — 別 hardcode credentials
**錯誤**：直接在 environment 寫 API key，commit 後暴露  
**修復**：用 `env_file: .env` 載入，.env 放 `.gitignore`

### 5. SQLite 資料在 Docker 內消失
**問題**：container 刪除後 DB 不見  
**修復**：用 named volume 持久化：
```yaml
volumes:
  - chatbot-data-sqlite:/data
```
並在第一次啟動前把舊 DB 拷進 volume：
```bash
mkdir -p data/sqlite
cp backend/data/app.db data/sqlite/app.db
```

### 6. Caddy proxy — 路由匹配優先順序
**問題**：`handle /api/*` 和 `handle /*` 順序很重要  
**正確順序**：
```
handle /api/* { reverse_proxy chatbot-backend:3001 }
handle /api/ai/* { reverse_proxy chatbot-backend:3001 }
handle /* { reverse_proxy chatbot-frontend:80 }
```

## docker-compose.yml 關鍵片段
```yaml
services:
  proxy:
    image: caddy:2
    ports: ["80:80", "443:443"]
    volumes:
      - ./Caddyfile.proxy:/etc/caddy/Caddyfile
      - ./data/caddy-data:/data
      - ./data/caddy-config:/config
    env_file: .env
    network_mode: chatbot-network

  backend:
    build: ./backend
    volumes:
      - chatbot-data-sqlite:/data
      - chatbot-data-uploads:/app/uploads
    env_file: .env
    network_mode: chatbot-network
    depends_on: [proxy]

  frontend:
    build: ./frontend
    network_mode: chatbot-network
    depends_on: [backend]

volumes:
  chatbot-data-sqlite:
  chatbot-data-uploads:
  caddy-data:
  caddy-config:
```

## 生產環境遷移檢查清單
- [ ] 停止舊 nginx systemd：`systemctl stop nginx && systemctl disable nginx`
- [ ] 停止舊 backend systemd：`systemctl disable chatbot-backend`
- [ ] 拷貝舊 SQLite DB：`mkdir -p data/sqlite && cp backend/data/app.db data/sqlite/app.db`
- [ ] 確認 `.env` 存在且有所有必要變數（DATABASE_URL, JWT_SECRET, OPENROUTER_API_KEY）
- [ ] 確認 Caddy ACME email 在 global options block
- [ ] 驗證 `/api/health` 返回正確 JSON
- [ ] 驗證前端可以正常登入
