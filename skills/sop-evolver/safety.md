# safety.md — RSI 安全規則

> **對應 SKILL.md**：[`SKILL.md`](./SKILL.md) §3 子模組 + §6
> **對應 SOP**：[`docs/sop/handbook/2.8-rsi-evolution.md`](../../../docs/sop/handbook/2.8-rsi-evolution.md) §6

---

## 1. 用途

定義 4 條**不可違反**安全規則 + Reviewer 二審規範。

---

## 2. 規則 1：觀察/改動分離

| 允許 | 禁止 |
|---|---|
| 任何裝了 tree_monstor 的專案都**可寫** observation | 任何裝了 tree_monstor 的專案都**不可改** SOP/AGENTS.md/gates.json/handbook/skill |

**為什麼**：裝在用戶專案裡的 agent 沒有權限動用戶的 SOP 源頭。改 SOP 只能由用戶**在源 repo**明確觸發。

---

## 3. 規則 2：匿名化

| 允許 | 禁止 |
|---|---|
| 存 `project_id` = `SHA256(path)[:8]` | 存**明文路徑**、**明文專案名**、**明文程式碼** |
| 存結構化信號（gate 結果、失敗類型、頻率）| 存 **raw text**、**絕對路徑**、**環境變數值** |

**為什麼**：觀察記錄可能跨多個用戶專案，明文會洩漏隱私。

---

## 4. 規則 3：Reviewer 二審必經（V03 紀律）

所有 SOP / AGENTS.md / gates.json / handbook / skill 修改提案：

1. **必先經** `dev-checker-loop` Reviewer subagent 二審
2. Reviewer 必附風險分級（🟢/🟡/🔴）+ 跨 SOP 一致性檢查 + 修改建議
3. 用戶收到「diff + verdict」兩者並呈
4. 用戶可**明確說「跳過 Reviewer」**直接批准（明示豁免）

### 4.1 Reviewer 三條禁令

Reviewer subagent **不能**：

1. 改 AGENTS.md §1（萬事原則）
2. 改 AGENTS.md §1.5（V01/V02/V03 紀律）
3. 改 AGENTS.md §2.3（Gate 1-4 核心邏輯）

---

## 5. 規則 4：一鍵回滾

每次合併 diff 必自動寫 git tag：

```
rsi-v{YYYYMMDD}-{NN}
```

回滾指令：

```bash
./tools/rsi-rollback.sh rsi-v{YYYYMMDD}-{NN}
```

**特性**：

- 回滾時間 < 5 秒（純 git checkout）
- 觀察記錄**不刪**（保留供未來分析）
- 寫入 `tools/rsi-rollback.sh`（Sprint 10 TD-031 自動寫 git tag）

---

## 6. 安裝旗標

```bash
./install.sh --enable-rsi    # 預設：部署 sop-evolver skill + 建觀察目錄
./install.sh --disable-rsi   # 不部署 sop-evolver，移除觀察目錄
./install.sh --uninstall     # 完全清理
```

### 6.1 `--enable-rsi` 行為

1. 複製 sop-evolver skill 到目標安裝路徑
2. 建 `~/.tree-monstor/observations/` 目錄
3. 驗證 skill 已被讀取（測試 SKILL.md 可讀）

### 6.2 `--disable-rsi` 行為

1. 不複製 sop-evolver skill（**避免空 symlink 循環**）
2. `~/.tree-monstor/` registry 不 init（避免空殼）
3. 移除觀察目錄

### 6.3 `--uninstall` 行為

完全清理 `~/.pi/agent/skills/sop-evolver/` + `~/.tree-monstor/`

---

## 7. 觀察失敗處理

觀察失敗**不阻塞任務**：

| 失敗原因 | 處理 |
|---|---|
| Schema 驗證失敗 | log warning，跳過寫入 |
| 觀察目錄不存在 | `mkdir -p` 後重試 |
| 權限不足 | log warning，不重試 |

---

## 8. 量化紅線

| 指標 | 期望值 | 紅線 |
|---|---|---|
| 觀察失敗率（schema reject） | < 5% | > 20% |
| 違規事件數（incident log） | 0 | > 0 |
| Reviewer 跳過率 | < 10% | > 30% |
| 回滾平均時間 | < 10 秒 | > 60 秒 |

---

## 9. 版本

- v1.0（2025-09-20）— 隨 Sprint 09 US-013 引入
- v1.0-fix（2026-09-20）— Sprint 12 重建，源檔案修復 + 加強 §6 安裝旗標說明
