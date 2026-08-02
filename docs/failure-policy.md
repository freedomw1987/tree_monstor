# 失敗處理機制
> **When to read:** Reflect

> **Status:** Canonical. Source of truth for L1/L2/L3 failure handling.

## 失敗等級

| 等級 | 定義 | 處理方式 | 嘗試次數 |
|------|------|----------|----------|
| **L1** | 可自動修復（網路波動、port 占用） | 等待 30s 自動重試 | 3 次 |
| **L2** | 需要修復後重試（代碼 bug） | 分析原因、修正後重新派發 | 2 次 |
| **L3** | 需 Developer 介入（架構問題、需要用戶決策） | 記錄失敗報告，升級 | 不限 |

---

## 失敗處理流程

```
Subagent 失敗
    ↓
評估失敗等級
    ↓
┌─ L1? ──自動重試 (30s delay) ──→ 成功？ ─┐
│    ↓ 否                                   ↓ 是
├─ L2? ──分析原因 ──→ 修正 ──→ 重新派發    回到流程
│    ↓ 否                                   ↑
└─ L3? ──寫失敗報告 ──→ 升級給 Developer ──┘
                    ↓
            通知 Developer
```

---

## 失敗報告模板

```markdown
## Subagent Failure Report

### 基本資訊
- Task: [TASK-ID] / [任務名]
- Subagent: [角色]
- Failure Time: [時間]
- Attempt: [第 N 次嘗試]

### 錯誤摘要
[一句話描述]

### 詳細錯誤
```
[錯誤日誌 / Traceback]
```

### 已嘗試的解決方案
1. [方案 1]
2. [方案 2]

### 懷疑根本原因
[分析]

### 建議下一步
[建議]

### 是否阻塞其他任務
- [ ] 否
- [ ] 是 — Blocked Tasks: [列表]
```

---

## ⏱️ 任務進度停滯檢測

### 停滯定義
- 連續 5 次 tool call 全部失敗
- 進入無效循環（反覆讀取相同檔案、重試同一個失敗命令）
- 連續 3 次嘗試失敗但沒有匯報

### 處理流程
```
進度停滯檢測
    ↓
[停止並匯報] → 「我已經卡住了，需要幫忙」：當前嘗試的方案、錯誤日誌
    ↓
等待 Developer / 用戶介入
```

---

## 常見錯誤自動處理

| 錯誤 | 原因 | 處理方式 |
|------|------|---------|
| `EADDRINUSE` | Port 被占用 | `pkill -f <program>; sleep 1; retry` |
| `ENOENT` | 文件不存在 | `mkdir -p <dir>; retry` |
| `EACCES` | 權限不足 | `chmod` 或 `sudo` |
| `ENOSPC` | 磁盤滿 | 清理日誌後重試 |
| `EMFILE` | 文件描述符耗盡 | `ulimit -n 65535` |
| Cloudflare timeout | Tunnel 響應慢 | `pkill -f cloudflared; retry` |
| Subagent 僵死 | 子進程洩漏 | `pkill -9 -f "<agent-process>"` |

---

## Related docs

- [Documentation index](00-index.md)
- [Feedback loop](feedback-loop.md)
- [QA Gate](qa-gate.md)
