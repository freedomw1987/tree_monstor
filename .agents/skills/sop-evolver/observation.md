# observation.md — 觀察模式規範

> **對應 SKILL.md**：[`SKILL.md`](./SKILL.md) §3 子模組
> **對應 SOP**：[`docs/sop/handbook/2.8-rsi-evolution.md`](../../../docs/sop/handbook/2.8-rsi-evolution.md) §5

---

## 1. 用途

定義「觀察模式」的完整規範：如何、何時、寫什麼 observation。

觀察模式**只寫不改**：

- 寫 observation JSON 到 `~/.tree-monstor/observations/`
- 不能改 SOP / AGENTS.md / gates.json / handbook

---

## 2. 觀察記錄存放位置

```
~/.tree-monstor/observations/{project-id}/{YYYY-MM-DD}.json
```

| 元素 | 規則 |
|---|---|
| `project-id` | `SHA256(安裝路徑).substring(0,8)`（**絕不存明文路徑**）|
| `YYYY-MM-DD` | ISO 8601 日期 |
| 每個 task | 寫一個 JSON 檔（多 task 同日 → 同檔 + 陣列） |

---

## 3. Observation JSON Schema（白名單 + 黑名單雙重保護）

### 3.1 白名單欄位（多餘欄位 → ajv reject）

| 欄位 | 型別 | 說明 |
|---|---|---|
| `task_id` | UUID | 任務 ID |
| `project_id` | string | `SHA256(path).substring(0,8)` |
| `timestamp` | ISO-8601 | 觀察時間 |
| `gate_results` | object | 5 Gate 的 pass/fail（Gate 1-5）|
| `skills_used` | array | 使用的 skill 名 |
| `failure_signals` | array | 失敗信號 `{gate, type, count}` |
| `duration_seconds` | integer | 任務耗時 |

### 3.2 黑名單欄位（被拒絕）

- ❌ `raw_conversation`（raw 對話內容）
- ❌ `code_snippets`（程式碼片段）
- ❌ `file_paths`（檔案絕對路徑明文）
- ❌ `env_values`（環境變數值）
- ❌ `git_messages`（git commit message 內容）

### 3.3 範例 observation

```json
{
  "task_id": "550e8400-e29b-41d4-a716-446655440000",
  "project_id": "a3b4c5d6",
  "timestamp": "2026-09-20T12:34:56Z",
  "gate_results": {
    "gate1_tdd": "pass",
    "gate2_lint": "pass",
    "gate3_regression": "pass",
    "gate4_reviewer": "pass",
    "gate5_rsi": "pass"
  },
  "skills_used": ["dav-planner", "dav-designer", "tdd-test-writer"],
  "failure_signals": [],
  "duration_seconds": 3600
}
```

---

## 4. 寫入規則

### 4.1 時機

任務完成時（Gate 5 觸發）。觀察失敗**不阻塞任務**（log warning，跳過寫入）。

### 4.2 觀察目錄權限

```bash
chmod 700 ~/.tree-monstor/observations/
```

### 4.3 失敗處理

| 失敗原因 | 處理 |
|---|---|
| Schema 驗證失敗 | log warning，跳過寫入 |
| 目錄不存在 | `mkdir -p` 後重試 |
| 權限不足 | log warning，不重試 |
| 寫入空間不足 | log warning，不重試 |

---

## 5. 故障排除

| 症狀 | 檢查 |
|---|---|
| 觀察記錄沒寫 | 看 `~/.tree-monstor/logs/observation-{date}.log` |
| Schema 錯誤 | 對照 §3 白名單欄位 |
| 觀察目錄不存在 | `mkdir -p ~/.tree-monstor/observations/` |

---

## 6. 版本

- v1.0（2025-09-20）— 隨 Sprint 09 US-013 引入
- v1.0-fix（2026-09-20）— Sprint 12 重建，源檔案修復
