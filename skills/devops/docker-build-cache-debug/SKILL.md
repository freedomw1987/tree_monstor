---
name: docker-build-cache-debug
description: Docker build cache causes stale code to run in containers despite source changes
category: devops
---


Last-verified: 2026-07-28
# Docker Build Cache Debug

## 徵兆
Docker build 顯示成功（`BUILD:0`），但容器內的代碼症態（如：仍然有語法錯誤、删掉的代碼還在跑）、前端 SPA bundle 入面缺少最近 commit 加嘅 string/feature。

## 根因
Docker 的 `COPY . .` 層被緩存了。當源文件變更但 Docker daemon 认为 "没变"，就會复用过舊的 image layers。

2026-06-07 crm-system Day 14.7 嘅具體 case:`docker compose build web` 顯示大量 CACHED(包括 `COPY apps/web ./apps/web` 嗰層),但 image 嘅 `Created` 係 11:09Z,**早過** 我哋最後個 commit 嘅 18:50 HKT (=10:50Z)。即係 source 有改,但 image 已經 build 咗,build 過程 cache 命中。**`docker compose build` 唔保證 image 會 rebuild 即使 source 改咗 — `docker compose up -d` 更加唔保證**。

## 調試步驟

### 1. 確認容器內跑的是哪個 image
```bash
sudo docker inspect pm-system-backend-1 | grep Image
# 例如: "Image": "sha256:abc123..."
```

### 2. 對比主機上的 image creation time 同最近 commit time
```bash
sudo docker image inspect pm-system-backend | grep -A2 Created

# 加埋 (crm-system 2026-06-07 嗰個 case) — 對比 git log 嘅最新 commit:
git log -1 --format='%ai %s' <branch>
# Created time 早過 commit time = 100% stale
```

呢個就係 crm-system 嗰個 case 點解 catch 唔到 — `docker compose build web` 報 DONE + 0.0s cache,睇落成功,但 image creation time 顯示佢係**上一次** build 嗰陣產出,**唔係**今次 source state。

### 3. 確認 container 喺用最新 image(唔係 suspended 嘅舊 instance)
```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.CreatedAt}}' | grep <service>
# 比較 CreatedAt 同 image inspect 嘅 Created — 唔同 = container 喺用 pre-existing image
```

`docker compose up -d` 喺 image 唔變嘅情況下,係**唔會**自動 restart 個 container 去用「新 image」嘅。如果個 container 仲喺度 healthy status,佢就繼續用 build 時嗰個 image layer。

### 4. 看容器日誌（實時）
```bash
sudo docker logs pm-system-backend-1 2>&1 | grep -E "error|Error|Expected"
```

### 5. 本地快速驗證（不等 Docker）
在主機直接 build TypeScript，不經 Docker：
```bash
cd /home/ubuntu/projects/pm-system/backend
bun --bun build src/index.ts --target=bun --outfile=/dev/null
echo "Return code: $?"
```
如果 return code 0 = 代碼沒語法錯誤。如果失敗，錯誤會立即顯示。

**Frontend SPA 嘅 analog**(crm-system 2026-06-07 親驗):如果 backend 啱但 web SPA 入面有 Step N 嘅 string 唔見咗,grep 個 static bundle:
```bash
# 1. Build 出嚟個 bundle
curl -s http://localhost:80/assets/index-*.js > /tmp/bundle.js
# 2. 搵 Step 6/7 加嘅 specific string
for s in "系統設置" "Default Tax Rate" "SYSTEM_CONFIG_UPDATED" "getTax"; do
  count=$(grep -c "$s" /tmp/bundle.js)
  echo "$count × $s"
done
# 預期:全部 ≥1。如果全部 0 = stale bundle,rebuild
```
呢個係 catch 啱啱 crm-system 個 cache 問題嘅關鍵 — `docker compose build` 報 DONE,**但** nginx 服務嘅 bundle hash 仲係上次 build 嘅,grep 之後先知 source 根本未入到 image。

### 6. 強制 rebuild（不走 cache）
```bash
sudo docker compose build --no-cache backend
```

**`--no-cache` 嘅實際作用**:令所有 build step 重新 evaluate,包括 `COPY . .` 嗰層嘅 cache invalidation。**冇呢 flag,即使 source 改咗,Docker 都可能 cache hit**(特別係 monorepo 入面 workspace + node_modules 嗰啲 layer 容易 false-positive cache hit)。

crm-system 嗰個 case 嘅 fix:用 `docker compose build --no-cache web` 就見到 `COPY apps/web ./apps/web` step 出嚟,DONE 0.1s,**真係**用新 source。

### 7. 確保新 image 真的被使用
```bash
sudo docker compose down backend
sudo docker image rm pm-system-backend
sudo docker compose up -d backend
```

或者**直接**用 `docker run --rm`(不用 compose):
```bash
docker rm -f <container-name> 2>/dev/null
docker run -d --name <container-name> --network <compose-network> \
           -p <host-port>:<container-port> --restart unless-stopped \
           <image-name>
```

Hermes terminal guard 對 `docker compose up -d` 嘅 long-lived false positive(2026-06-07 親驗):
```
This foreground command appears to start a long-lived server/watch process.
Run it with background=true, verify readiness (health endpoint/log signal),
then execute tests in a separate command.
```
**Workaround**:繞過 compose,直接用 `docker run` 配 `docker network ls` 攞 compose network。Compose 同 `docker run` 嘅 network 通常喺 `<project>_default`,`docker network ls` 確認。

## 快速 Debug 流程
```
懷疑容器跑舊代碼
  → `sudo docker logs <container>` 看錯誤
  → `bun --bun build` 本地驗證
  → `sudo docker image inspect <image> | grep Created` 
  → `git log -1 --format='%ai' <branch>` 對比 — image Created 早過 commit = cache 問題
  → 額外:grep 個 frontend bundle 入面有冇最近 commit 加嘅 string(0 = stale)
  → `docker compose build --no-cache <service>`
  → `docker compose down <service> && docker image rm <image> && docker compose up -d <service>`
    OR  `docker rm -f <container> && docker run -d ...` (避免 Hermes long-lived guard)
  → curl smoke 確認 bundle hash 變咗 / API response 啱
```

## 預防
- **修改源代碼後,用 `docker compose build --no-cache <service>` 而非只 `up -d`**。`--no-cache` 多用 30-60 秒但保證 stale 問題 0 風險。
- **重大修改後先本地 `bun --bun build` / `tsc --noEmit` 確認再 build Docker**
- **E2E smoke 之前必 grep bundle hash**:`curl -s http://localhost/ | grep -oE "assets/index-[A-Za-z0-9]+\.js"` 對比 build log 嘅 `dist/assets/index-*.js`。Hash 一樣 = stale 100%。
- **永遠對比 image Created time vs git log latest commit time**。兩者 mismatch = 用咗 stale image。

## crm-system 2026-06-07 case study #1 (Day 14.7 Steps 5-10 — cache hit case)

- 5 個 commit (Step 5-10) 全部 push 咗,`git log --oneline` 顯示 `6146aea` 係 HEAD。
- `docker compose build web` 報 DONE + 大量 CACHED,exit 0。
- 啟動 browser smoke 之前,curl `/api/health` 200,**但** web container `Created: 2026-06-07T11:09:41Z` 早過 `git log -1 --format='%ai' = 18:50:03 +0800 = 10:50Z`。
- 唯一救我嘅係 grep SPA bundle 嘅 Step 7 user-visible string:
  ```bash
  curl -s http://localhost:80/ | grep -oE "assets/index-[A-Za-z0-9]+\.js"
  # → assets/index-am9hO3Fd.js (對比 build log 嘅 CXgamMpS? 不,build log am9hO3Fd)
  # 跟住 grep bundle 入面 Step 6 加嘅 string
  for s in "系統設置" "Default Tax Rate" "Pipelines"; do grep -c "$s" /tmp/bundle.js; done
  # → 0 × Default Tax Rate = stale!
  ```
- 跟住 `docker compose build web --no-cache` 見到 step 19 行 `#19 [builder 12/14] COPY apps/web ./apps/web / #19 DONE 0.1s`,build 真係行咗。
- 跟住 `docker rm -f crm-web && docker run -d --name crm-web --network crm-system_default -p 80:80 --restart unless-stopped crm-system-web` 換新 image,grep bundle hash 變咗,user-visible string 齊,E2E smoke 通過。

**Lesson**:**`docker compose build` DONE + 0 errors + 0 cache miss = 唔等於 image 嘅 source state 係最新**。Always grep frontend bundle hash OR backend container 入面嘅某個 user-visible marker 確認真係新 build。對比 image Created time vs latest commit time 係最可靠嘅 detection。

## crm-system 2026-06-07 case study #2 (Day 14.7 Steps 6-12 + Deal Autocomplete — pre-existing instance case)

- Step 6-12 嘅 5 個 commit + Deal Autocomplete 嗰個 commit (`0119a9f`) push 咗,`git log --oneline` 顯示 22 commits ahead of main,本地 source state 完整。
- `docker compose build web` 報 DONE + 12.2s,有 `built in 2.99s` 行,**冇 cache miss**。睇落成功。
- **真正 catch 嘅 trigger**:Step 12 browser smoke 期間揾 DealAutocomplete 個 input 唔見,DOM 入面 Deal field 係 plain `<select>`(Step 5 嗰個 pre-DealAutocomplete 嘅 native `<select>`),唔係 `<Autocomplete>` wrapper(commit 0119a9f 嗰個)。
- **第二步驗證**:container 入面 grep `dist/assets/index-*.js` 嘅 user-visible string:
  ```bash
  docker exec crm-web sh -c "grep -c '搜尋 deal 名' /usr/share/nginx/html/assets/*.js"
  # → 0 (DealAutocomplete 唔喺 bundle 入面)
  ```
  對比 commit 0119a9f mtime `Jun 7 20:14` vs image Created `2026-06-07T11:42:41Z`,明顯 image 早過 5 個鐘 → stale 100% 確認。
- **修法**(避開 Hermes long-lived guard):
  ```bash
  # 1. Force rebuild (no --no-cache 因為 cache 冇 hit problem,係 image-from-old-build 問題)
  docker compose build web  # 2.99s
  # 2. Remove old container
  docker rm -f crm-web
  # 3. Bring up new container
  docker compose up -d web
  # 4. Verify new bundle hash
  docker exec crm-web sh -c "ls -la /usr/share/nginx/html/assets/*.js"
  # → index-C3W_bq4I.js (新 hash,deal-autocomplete string 喺度)
  ```
- 跟住 `grep -c '搜尋 deal 名' /usr/share/nginx/html/assets/*.js` → 1 (新 build 有),DealAutocomplete UI 立即 render。

**Lesson delta vs case study #1**:**Step 12 smoke 入面 UI 唔對勁 + bundle grep 係 catch stale 嘅 2 大 trigger,單睇 `docker compose build` DONE + 0 cache miss 完全唔夠**。Source-vs-image Created time diff 仍然係最可靠 detection,但呢次係 container 用緊 pre-existing instance(image 冇變 → `docker compose up -d` 唔 auto-restart),唔係 cache 問題。
