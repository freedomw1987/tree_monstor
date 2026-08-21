# Suggester 設計 — 第三者視角的協助者

**日期**：2025-08-21
**作者**：Agent（依 SOP §2.8）
**狀態**：✅ 已實作並整合到 tree_monstor install.sh
**對應 Backlog**：—

---

## 1. 動機

主 Agent 在執行任務時容易陷入自己的邏輯盲點，特別是：

- 過度自信、忽略風險
- 給多方案但沒標明最推薦
- 沒看見用戶的隱性需求
- 對話中出現矛盾 / 不一致
- 累積技術債

**「三人行必有我師」** — 需要一個獨立的 subagent 從第三者視角旁聽對話，主動補盲點。

---

## 2. 角色定位

| 項目 | 設定 |
|------|------|
| **角色名** | `suggester` |
| **類型** | advisory agent（advisory review） |
| **Tools** | `read, grep, find, ls, bash`（唯讀，不允許 edit/write） |
| **Acceptance role** | `read-only` |
| **Model** | inherit parent default |
| **Thinking** | medium |
| **inheritsProjectContext** | false（不需要專案上下文，只需要對話上下文） |
| **inheritsSkills** | false（不需要專案 skill） |

---

## 3. 觸發條件（條件觸發 + 用戶可召喚）

### 自動觸發（任一發生就跑）

| 觸發點 | 為什麼要觸發 |
|--------|------------|
| 主 Agent 完成 **Plan Gate**（§2.1） | 規劃結果對用戶影響大 |
| 主 Agent 完成 **Design Gate**（§2.2） | 計劃涉及長期技術債 |
| 主 Agent 完成 **Gate 4 Reviewer**（§2.3） | reviewer gate 通過是「完成聲明」 |
| 主 Agent 完成 **Reflection Gate**（§2.4） | 反省報告影響未來 sprint |
| 主 Agent 完成 **Submit**（§2.5） | 交付物是用戶最後驗收 |
| 對話出現**風險信號**（用戶說「不確定」「會不會」「擔心」） | 用戶已有疑慮，需第三方確認 |
| 主 Agent 提議**重大改動**（修改 SOP / 重構模組 / 刪檔案） | 改動風險大 |

### 用戶主動召喚

- 用戶輸入 `/suggester` 即可隨時召喚
- 適合場景：覺得需要另一個視角、對主 Agent 建議有疑慮

---

## 4. 發言紀律

### ✅ 必須做

1. 永遠以 `> Suggester say: ...` quote 形式發言
2. 標明嚴重程度：⚠️（風險）/ 💡（機會）/ 🤔（疑問）/ ✅（肯定）
3. 給選項時標明「最推薦 X，因為...」
4. 簡短有洞見（≤ 3 行）

### ❌ 絕對不做

1. 不下指令給主 Agent（只給用戶建議）
2. 不修改任何檔案
3. 不批評主 Agent（角色是「補盲點」不是「找錯處」）
4. 不發言除非有實質價值（沉默也是貢獻）

---

## 5. 與 §2.7 的關係

- §2.7：防止 Agent 違規 SOP（執行層）
- §2.8：補充 Agent 看不見的盲點（協作層）
- 兩者互補：suggester 發現違規可在發言中標明 `⚠️ SOP 違規`，但實際處理仍按 §2.7 流程

---

## 6. 整合方式

### 檔案位置

| 用途 | 路徑 |
|------|------|
| Agent 定義（來源） | `tree_monstor/agents/suggester.md` |
| 安裝目標（user-scope） | `~/.agents/suggester.md`（install.sh 自動 symlink） |
| SOP 規範 | `tree_monstor/AGENTS.md` §2.8 |

### install.sh 整合

`install.sh` 新增 `install_subagents()` function：

- 從 `tree_monstor/agents/*.md` 自動 symlink 到 `~/.agents/<name>.md`
- 對應 `uninstall_subagents()` 處理解除安裝
- 在 `install_pi()` / `uninstall_pi()` 內呼叫（subagent 是 pi-subagents 套件功能，目前只 pi 支援）
- 在 `print_plan()` 加 subagent 安裝計畫輸出

**整合優勢**：
- 用戶裝一次 tree_monstor 就自動有 suggester
- 升級 tree_monstor 時 suggester 自動更新（symlink）
- 解除安裝時乾淨移除

---

## 7. 已知限制

- ⚠️ 目前 subagent 主要給 pi 用（pi-subagents 套件）；claude / 其他 agent 暫不支援
- ⚠️ 觸發邏輯目前是「Agent 自己判斷」，可能漏觸發；長期可考慮做 watchdog hook
- ⚠️ suggester 用 inherit default model，若用戶想用更便宜/更強的模型需 override（`subagents.agentOverrides.suggester.model`）

---

## 8. 驗證方式

| 驗證 | 做法 |
|------|------|
| suggester 被列出 | `subagent({ action: "list" })` 應看到 `suggester (user)` |
| suggester 可 dispatch | 主 Agent 在關鍵 gate 切換時主動召喚 |
| 用戶可手動召喚 | 輸入 `/suggester` 看是否有回應 |
| suggester 發言形式 | 必須是 `> Suggester say: ...` quote |

---

**心法**：

> 「主 Agent 是工程師，suggester 是旁觀的智者 — 兩者各有所長，互補共贏。」
