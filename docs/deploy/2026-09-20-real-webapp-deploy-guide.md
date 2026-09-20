# Sprint 11 US-019 真實小型 web app 部署指南（2026-09-20）

> **任務**：US-019
> **SP**：3
> **對應 FR**：FR-4.16
> **觀察期**：14 天（2026-09-20 ~ 2026-10-04）

---

## 1. 部署目標

把 RSI 觀察模式部署到 1 個輕量小型 web app，觀察 14 天，產生真實跨專案訊號。

## 2. 部署對象（小型 web app）

### 2.1 候選小型 web app

| App | 類型 | 大小 | 推薦 |
|---|---|---|---|
| express-hello-world | Express.js 1 endpoint | 1 檔 + package.json | ✅ |
| flask-hello | Flask 1 endpoint | 2 檔 | ✅ |
| sinatra-hello | Sinatra 1 endpoint | 1 檔 | ✅ |

### 2.2 為什麼小型 web app

- 真實 web app 但極簡（單 endpoint）
- 不破壞（觀察/改動分離）
- 觀察週期內可預期產生 SOP 使用
- 易於驗證 deploy + uninstall

## 3. 部署步驟

### 3.1 準備 web app

```bash
mkdir -p ~/test-projects/express-hello-world/src
cd ~/test-projects/express-hello-world

cat > package.json <<'EOF'
{"name": "hello", "version": "1.0.0", "main": "src/server.js"}
EOF

cat > src/server.js <<'EOF'
const http = require('http');
http.createServer((req, res) => {
    res.writeHead(200, {'Content-Type': 'text/plain'});
    res.end('OK');
}).listen(3000);
console.log('listening on :3000');
EOF
```

### 3.2 部署 RSI 觀察模式

```bash
bash /path/to/tree_monstor/install.sh --enable-rsi --target ~/test-projects/express-hello-world
```

預期結果：

- `~/test-projects/express-hello-world/.pi/sop/` 建立
- `~/test-projects/express-hello-world/.pi/skills/sop-evolver/` 建立
- `~/.tree-monstor/observations/` 初始化
- web app 原始檔（`src/server.js`、`package.json`）**完全沒被改**

### 3.3 驗證部署成功

```bash
ls ~/test-projects/express-hello-world/.pi/sop/
# 預期：gates.json, gates.schema.json, handbook/

ls ~/test-projects/express-hello-world/.pi/skills/
# 預期：sop-evolver/

md5 ~/test-projects/express-hello-world/src/server.js
# 預期：與部署前 hash 一致（沒被破壞）
```

### 3.4 每日 cron（自動觀察）

```bash
# 加入 crontab
crontab -e
# 加這行：
0 0 * * * cd /path/to/tree_monstor && bash tools/rsi-metrics.sh --days 1 >> ~/.tree-monstor/cron.log 2>&1
```

每天 0 點跑 metrics，cron.log 累計 14 天。

### 3.5 啟動 web app（如需）

```bash
cd ~/test-projects/express-hello-world
node src/server.js
```

## 4. 觀察期運作

### 4.1 觀察記錄位置

```
~/.tree-monstor/observations/{sha256(path)[:8]}/YYYY-MM-DD.json
```

### 4.2 觀察期每日動作

- 每天 0 點 cron 跑 `rsi-metrics.sh`
- 每日寫當天 observation（如 agent 在該專案執行任務）
- 第 7 天中間點跑 `rsi-metrics.sh trend_history` 看趨勢
- 第 14 天跑 `rsi-metrics.sh trend_history --days 14` 結束觀察

### 4.3 觀察結束後動作

1. 跑 `rsi-metrics.sh trend_history --days 14`
2. 跑 `rsi-aggregate.sh` 聚合觀察
3. 跑 `rsi-propose.sh --confidence 0.5 --min-freq 2` 看提案
4. 寫 `docs/review/2026-10-04-rsi-real-deploy-result.md` 報告

## 5. 安全邊界（觀察/改動分離）

| 動作 | 是否允許 |
|---|---|
| 讀 web app 檔案 | ✅ |
| 寫 `~/.tree-monstor/observations/` | ✅ |
| 寫 web app 的 `.pi/sop/`（symlink） | ✅ |
| 改 web app 原始碼 | ❌ |
| 改 web app 的 `package.json` | ❌ |
| 刪除 web app 任何檔案 | ❌ |

## 6. 一鍵回滾

```bash
# 解除部署
bash /path/to/tree_monstor/install.sh --uninstall --target ~/test-projects/express-hello-world
```

或手動：

```bash
rm -rf ~/test-projects/express-hello-world/.pi
rm -rf ~/.tree-monstor/observations/{sha256(path)[:8]}
rm -rf ~/.tree-monstor/projects/{project-id}
```

## 7. 驗收標準

| AC | 驗證方式 |
|---|---|
| 選 1 個輕量小型 web app | ✅ |
| `install.sh --enable-rsi` 裝 RSI | ✅ |
| 每日 cron 跑 `rsi-metrics.sh` | ✅ crontab + cron.log |
| 觀察 14 天 | ✅ 14 天後趨勢報告 |
| 結束後跑 `trend_history` | ✅ |
| 觀察/改動分離守住 | ✅ hash 比對 |
| ≥ 8 個 bats 測試 | ✅ us019-real-deploy.bats |

## 8. 預期效益

| 指標 | 預期 |
|---|---|
| 真實觀察專案 | 1 個 web app |
| 觀察天數 | 14 天 |
| observation 數 | ≥ 14 個 / 專案 |
| 跨專案訊號 | 真實非 mock |
| 規則庫候選 | 提供 US-020 反推 |

## 9. 相關 Sprint 11 設計文件

- `docs/plan/2026-09-20-sprint-11-rsi-real-deploy.md`
- `docs/prd/04-self-evolution.md` §11
- `docs/system-design.md` ADR-015/016/017
- `docs/sop/rsi-reviewer-verdict-2026-09-20-sprint11.md`

## 10. 待批准

請用戶批准 US-019 部署文件，進 US-020 從真實觀察反推補規則。
