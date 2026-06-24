# DevOps 規範

> **Status:** Runbook. DevOps process management, zombie handling, and operational safeguards.

## 進程生命週期鐵律

**每個啟動的進程都必須明確回答三個問題：**
1. **誰啟動的？** — 記錄 PID 和啟動命令
2. **誰是家長？** — 記錄 parent PID，確保 parent 會 wait() 它
3. **如何終結？** — 明確知道如何 kill 它

任何無法回答這三個問題的進程，就是潛在僵尸。

---

## 啟動服務前必須檢查 Port

```bash
# 檢查 port 是否已被占用
lsof -i :3001 || netstat -tlnp | grep 3001

# 如果占用，先 kill 舊進程
pkill -f "node.*server.js"
```

---

## Background Process 管理

### 正確做法
```bash
nohup npm run dev > /tmp/vite.log 2>&1 &
echo "PID: $!"
sleep 5
curl -s http://localhost:5173 | head -5 || echo "FAILED"
```

### 每次啟動後必須驗證
1. Process 存在：`ps aux | grep vite | grep -v grep`
2. Port 監聽中：`lsof -i :5173`
3. HTTP 可訪問：`curl -s -o /dev/null -w "%{http_code}" http://localhost:5173`

---

## Cloudflare Tunnel

```bash
cloudflared tunnel --url http://localhost:5173 2>&1 | tee /tmp/cloudflared.log &
sleep 10
grep -o "https://[a-z0-9-]*\.trycloudflare\.com" /tmp/cloudflared.log | head -1
```

---

## 必須防止的 Zombie 場景

| 場景 | 徵兆 | 處理 |
|------|------|------|
| Zombie | `ps` 顯示 `<defunct>` | 確認 parent 正常，kill -CHLD |
| Orphan | PPID=1 | 確認是否正常，必要时终止 |
| Fork Bomb | 大量同名進程 | `pkill -9 -f <name>` |
| Memory Leak | `free -m` 持續下降 | 重啟進程 |
| Disk Full | `df -h` 100% | `du -sh /*` 找大文件 |
| FD Exhaustion | `too many open files` | `ulimit -n 65535` |

---

## 診斷流程

```bash
# Step 1: 系統整體狀態
uptime; free -m; df -h; ps aux | wc -l

# Step 2: 找出問題進程
ps aux | grep -E "node|vite|claude|cloudflared" | grep -v grep

# Step 3: 網絡連接
lsof -i :3001; netstat -tlnp | grep 3001

# Step 4: 進程樹
pstree -p $(pgrep -f vite)

# Step 5: 日誌
tail -100 /tmp/vite.log
```

找到問題後才行動，不要盲目重啟。

---

## Related docs

- [Documentation index](00-index.md)
- [Environment isolation](environment-isolation.md)
- [Failure policy](failure-policy.md)
- [macOS setup runbook](../setup-macos.md)
