# Dev-Checker Loop 工作流程

> 本檔係 dev-checker-loop skill 嘅工作流程全文（主檔只留摘要）。四個角色步驟 → 逐表列出。

## Dev Agent 工作流程

| 步驟 | 操作 | 目的 |
|------|------|------|
| **1 領取任務** | 讀 `docs/backlog.md` → 篩選狀態 `PENDING` → 揀一個（按優先級／順序）→ 更新狀態為「進行中」 | 確保每個任務只被一個 dev 處理，避免衝突 |
| **2 開發任務** | 讀對應 Module 嘅 PRD → 按 PRD 開發 → 參照 regression-guard skill 埋入探針 → 自我測試驗證 | 按規格開發，並預留測試覆蓋 |
| **3 標記完成** | 更新狀態為「等待校驗」；如有發現問題則改為「需修復」 | 將任務交給 checker 品質把關 |
| **4 處理修復任務** | 監控 backlog → 領取「需修復」任務 → 修復並更新回「等待校驗」 → 重複直到修復或達循環上限 | 持續修復直到 checker 確認通過 |

## Checker Agent 工作流程

| 步驟 | 操作 | 目的 |
|------|------|------|
| **1 監控 Backlog** | 持續讀 `docs/backlog.md` → 篩選「等待校驗」→ 如有新任務則開始校驗 | 及時發現需要校驗的任務 |
| **1.2a（v2.4）** | 若 `JEV_AVAILABLE=true` 且 Module 檔案數 ≥5，用 `jev_judge` 批次評分可疑點（noul/choice/score 三類混合）聚焦高風險 | 校驗前快篩、節省主動校驗成本 |
| **1.3a（v2.4）** | 若 `JEV_AVAILABLE=true`，校驗後用 `jev_judge`（noul）驗證結論；`escalate: true` 寫進「⚠️ jev escalate 待確認」段 | 避免自我感覺良好 |
| **2 全面校驗** | 功能正確性（對照 PRD）｜代碼品質（風格／安全性／可讀性）｜測試覆蓋｜Regression 探針是否正確運行 | 確保功能正確、品質合格、測試完整、有自我測試機制 |
| **3 記錄問題** | 在 backlog 新增 Defect 條目 → 原任務狀態改為「需修復」→ 循環次數遞增 | 清晰記錄問題，讓 dev 知道要修什麼 |
| **4 通過驗收** | 所有檢查通過 → 狀態改為「已完成」→ 記錄完成時間 | 確認任務符合品質標準 |

---

## 循環控制

| 計數器值 | 意義 |
|---------|------|
| 0 | 問題剛被記錄 |
| 1-19 | 正常修復循環中 |
| 20 | 達到上限 |

**達到 20 時**：在 backlog 標記「達到循環上限」→ 通知用戶需人工介入 → 停止自動修復（該問題不再自動處理）。

## Backlog 狀態機

```
PENDING → 進行中 → 等待校驗 → 需修復 →（循環）→ 等待校驗
              ↓                      ↓
            已完成 ←─────────────────┘
              ↓
          已放棄（循環達上限）
```

| 狀態 | 意義 | 下一個狀態 |
|------|------|-----------|
| `PENDING` | 未領取 | 進行中 |
| 進行中 | dev 處理中 | 等待校驗 |
| 等待校驗 | 等 checker | 需修復 / 已完成 |
| 需修復 | checker 發現問題 | 等待校驗（修復後） |
| 已完成 | 通過驗收 | — |
| 已放棄 | 循環達上限 | — |

## 協作默契

| 原則 | 說明 |
|------|------|
| **Dev 不干擾 Dev** | 同一時間只有一個 dev 處理同一任務 |
| **Checker 客觀公正** | 嚴格按照標準檢查，不妥協 |
| **循環有上限** | 避免無限修復，20 次上限保護 |
| **記錄清晰** | 每個問題都有明確的描述和追蹤 |

---

## jev 整合細節（v2.4 新增）

本節係 SKILL.md Step 0 / Step 3 / 規則表嘅「jev 整合」全文。主檔為咗行數控制只留摘要、完整規則在此展開。

### 可用性偵測（Step 0）

```bash
if which jev-use > /dev/null 2>&1; then
  JEV_AVAILABLE=true
else
  JEV_AVAILABLE=false
  echo "⚠️ jev-use 未安裝；本 skill 將跳過 jev 步驟、降級為純 LLM 工作流程。建議安裝：見 jev-use 安裝指南"
fi
```

**為什麼**：避免 agent 在沒裝 jev 的機器上 fail-fast 卡住；保持 skill 向下相容。
**內部失敗 fallback（S3）**：jev 內部失敗（API key 缺失 / 網路錯誤 / `jev_judge` 拋例外）→ 視同 `JEV_AVAILABLE=false`、走軟性降級、不 fail-fast。

### 校驗前 jev 快篩（Step 3）

**觸發條件**：限 `JEV_AVAILABLE=true` 且 Module 檔案數 ≥ 5（輕量路徑 S2：< 5 跳過以節省 jev API call 成本）。
**動作**：校驗前用 `jev_judge` 對 Module 內可疑點批次評分（`noul / choice / score` 三類混合批次），找出高風險點優先查。
**這只是輔助，不取代主動校驗**。

### 校驗後 jev 驗證（Step 3）

**觸發條件**：限 `JEV_AVAILABLE=true`。
**動作**：校驗報告出來後用 `jev_judge`（`noul` 類型）驗證「這個校驗結論有沒有遺漏風險」。

### escalate 處理（兩個 skill 共用）

`escalate: true`（信心不足）時：
① 標記為 ⚠️ 待確認
② 寫進校驗報告「⚠️ jev escalate 待確認」段（dev-checker-loop 落點）／ deliverable.md `## 反思` 段（dav-reflection 落點）
③ 不在對話中自己猜答案、等用戶最終確認。

### 術語說明（B2）

本 skill 用 `noul / choice / score` 三類混合（聚焦不同風險類型）；dav-reflection 只用 `score`（6 維度單類打分）。兩者屬設計選擇、不是錯。

### v2.4 6 條規則（主檔規則表完整版）

| 規則 | 例外 | 限制 |
|------|------|------|
| **jev 軟性降級** | N/A | jev-use 未安裝時跳過 jev 步驟、繼續原本工作、不中斷流程 |
| **jev escalate 降級為人類決策** | N/A | jev 信心不足時標 ⚠️ 待確認、寫進校驗報告「⚠️ jev escalate 待確認」段、不自己猜 |
| **jev 不取代主動校驗** | N/A | jev 只能輔助；主動校驗仍必跑、不可省略 |
| **小 Module 跳過校驗前 jev 快篩**（輕量路徑 S2）| 大 Module（≥5 檔）才觸發 | 避免小任務過度 jev API call 成本 |
| **jev 內部失敗 fallback**（S3）| N/A | jev 內部錯誤（API key / 網路 / 拋例外）視同不可用、走軟性降級、不 fail-fast |
| **M-Step 3 必跑探針**（B3）| 純錯字修正例外 | 改檔後必跑 `bats tests/` 全綠 |
