---
name: subagent-timeout-recovery
description: Subagent 執行超時後的接管流程。當 delegation 任務超時，檢查 partial outputs、驗證配置、啟動並完成測試，而不是重新 delegation。
version: 1.0.0
author: Hermes Agent
metadata:
  tags: [delegation, subagent, timeout, recovery]
  related_skills: [development-watchdog]
---

# subagent-timeout-recovery

Subagent 執行超時後的接管流程。

## 問題

當 subagent timeout 時，它的產出可能已經部分完成（如這個案例：frontend 和 backend 的多個文件都已經建立），只是 subagent 本身未能匯報結果。

## 搶救流程

### Step 1 — 檢查 Subagent 實際產出

```bash
# 列出 subagent 建的目錄結構
find ~/projects/wynn_seat/src -type f

# 檢查關鍵文件是否已存在
cat ~/projects/wynn_seat/src/api/index.ts
cat ~/projects/wynn_seat/src/frontend/package.json
```

### Step 2 — 驗證配置文件

Subagent 常會建好以下文件，需人工確認內容正確：
- `package.json` — scripts、dependencies
- `vite.config.ts` — proxy、port
- `tailwind.config.js` — custom colors、fonts
- `tsconfig.json`

### Step 3 — 啟動並測試

```bash
# 後端
cd ~/projects/wynn_seat && bun run src/api/index.ts &
sleep 2 && curl http://localhost:3001/health

# 前端
cd ~/projects/wynn_seat/src/frontend && bun run dev &
sleep 5 && curl -s -o /dev/null -w "%{http_code}" http://localhost:5174
```

### Step 4 — 快速代碼抽查

不要假設 subagent 的代碼是對的，隨機抽樣關鍵文件：
- API routes 是否完整
- TypeScript types 是否匹配
- 前端 API call 的 URL 是否正確

### Step 5 — 讀取並修正

如果發現問題，用 `read_file` + `patch` 修正，不重寫。

## 關鍵教訓

- **Subagent timeout ≠ 0 產出**。多數會 partial complete
- **不要重新 delegation**，浪費時間且結果相同
- **直接接管**，檢查 → 修補 → 啟動 → 測試
- 複雜任務（full-stack app generation）不適合丟給 subagent，超過 10 分鐘幾乎一定 timeout
