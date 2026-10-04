# Module Rules — Module 定義 + 取得流程 + Fallback

> 本檔為 dev-checker-loop 的「Module 感知邏輯」章節細節（v2.2 新增）。
> 引用：`SKILL.md` 「Module 感知邏輯」章節
>
> 從 SKILL.md v2.2 起，本檔獨立。理由：Module 取得流程 25 行屬於「實作細節」，不在「skill 用法」主流程上。

## Module 定義（什麼是 Module）

Module 定義在 `docs/system-design.md`，由 **dav-designer** skill 產出。dav-designer v2.3 規範定義 Module 為「可獨立開發 / 增減 / 測試」的功能單位，附 5
條切割原則（功能內聚 / 低耦合 / 可獨立交付 / 可獨立測試 / 粒度適中）。

**Module 的 4 個屬性**：

| 屬性 | 來源 | 範例 |
|---|---|---|
| Module 代碼 | system-design.md 的「Module 切割」章節 | `M01` / `M02` |
| Module 名稱 | system-design.md | `user-auth` / `payment-gateway` |
| 包含檔案 | system-design.md 的 Module 邊界 | `src/auth/*.ts` + `src/auth/*.test.ts` |
| Module 職責 | system-design.md | 認證 / 付款 / 訂單 |

## Module 取得流程

1. dev Subagent 讀 `docs/system-design.md` 拿到 Module 列表（每個 Module 有代碼 + 檔案 glob + 職責）
2. dev 領任務時對應到 Module（從 backlog.md 的「Module」欄位）
3. dev 開發時只動該 Module 的檔案（用 grep 過濾）
4. regression-guard 探針跑時用 `REGRESSION_MODULE=M01` 限定

## Module 與 dev-checker-loop 的 4 個互動點（複本，便於子檔獨立讀）

| 互動點 | 規則 |
|---|---|
| **派工** | dev 領任務時必綁 Module；同 Module 多任務可由同一 dev 順序處理、不同 Module 可平行 |
| **改檔** | dev 改檔必在 Module 邊界內；需跨 Module = 結束當前任務、新開跨 Module 任務 |
| **探針** | 探針名稱必含 Module prefix（如 `M01-user-login-returns-correct-data`）；CI 可選只跑某 Module |
| **校驗** | checker 校驗範圍限定 Module 內；跨 Module 的 integration issue 標記為「跨 Module」、升級為新任務 |

## Module 未定義時 Fallback

- 讀 `docs/system-design.md` 找不到 Module 章節 → 整個 repo 視為單一 Module（fallback）
- 視為「Module = 整個 repo」，其他規則照樣適用（只是邊界 = repo 根目錄）
- 建議同時請 dav-designer 補上 Module 定義（下次設計時改）

## 為什麼要 Module 感知

- **平行化加速**：一個 repo 多個 Module 可同時讓多個 dev 派工（每個 dev 負責一個 Module、不互踩）
- **錯誤範圍隔離**：壞了一個 Module 不連累整個 repo
- **測試邊界清楚**：探針只在 Module 邊界內檢查、跨 Module 的 integration test 屬「跨 Module 任務」獨立處理
- **為下游鋪路**（dav-designer v2.6 已鋪）：Module 定義在 system-design.md，本 skill 讓 Module 從「設計紙上」變成「執行單位」
