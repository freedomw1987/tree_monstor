---
name: docker-build-cache-debug
description: Docker build cache causes stale code to run in containers despite source changes
---

# Docker Build Cache Debug

## 徵兆
Docker build 顯示成功（`BUILD:0`），但容器內的代碼症態（如：仍然有語法錯誤、删掉的代碼還在跑）。

## 根因
Docker 的 `COPY . .` 層被緩存了。當源文件變更但 Docker daemon 认为 "没变"，就會复用过舊的 image layers。

## 調試步驟

### 1. 確認容器內跑的是哪個 image
```bash
sudo docker inspect pm-system-backend-1 | grep Image
# 例如: "Image": "sha256:abc123..."
```

### 2. 對比主機上的 image creation time
```bash
sudo docker image inspect pm-system-backend | grep -A2 Created
```

### 3. 看容器日誌（實時）
```bash
sudo docker logs pm-system-backend-1 2>&1 | grep -E "error|Error|Expected"
```

### 4. 本地快速驗證（不等 Docker）
在主機直接 build TypeScript，不經 Docker：
```bash
cd /home/ubuntu/projects/pm-system/backend
bun --bun build src/index.ts --target=bun --outfile=/dev/null
echo "Return code: $?"
```
如果 return code 0 = 代碼沒語法錯誤。如果失敗，錯誤會立即顯示。

### 5. 強制 rebuild（不走 cache）
```bash
sudo docker compose build --no-cache backend
```

### 6. 確保新 image 真的被使用
```bash
sudo docker compose down backend
sudo docker image rm pm-system-backend
sudo docker compose up -d backend
```

## 快速 Debug 流程
```
懷疑容器跑舊代碼
  → `sudo docker logs <container>` 看錯誤
  → `bun --bun build` 本地驗證
  → `sudo docker image inspect <image> | grep Created`
  → 如果 image creation 比代碼修改時間舊 = 確認 cache 問題
  → `docker compose build --no-cache <service>`
  → `docker compose up -d <service>`
```

## 預防
- 修改源代碼後，用 `docker compose build <service>` 而非只 `up -d`
- 重大修改後先本地 `bun --bun build` 確認再 build Docker
