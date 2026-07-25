# 環境隔離指南

> **Status:** Canonical. Source of truth for Dev / Prod / Agent Config environment isolation.

> 所有功能開發，第一優先一定是開發環境（Dev）。Production 只是最終目的地。

---

## 三層架構

```
┌─────────────────────────────────────────────────────────┐
│  L1: Agent Config（平台配置層）                         │
│  路徑：~/.tree_monstor/ 或 <platform-profile>/         │
│  包含：.env（API key）、config.yaml（模型設定）         │
│  用途：Agent 的工具、模型、平台連接                     │
└─────────────────────────────────────────────────────────┘
                          ↕ 隔離
┌─────────────────────────────────────────────────────────┐
│  L2: 專案開發環境（Project Dev）                         │
│  路徑：~/www/<project>/                                   │
│  包含：.env（dev API key）、dev 資料庫、測試設定          │
│  用途：功能開發、測試、驗證                               │
└─────────────────────────────────────────────────────────┘
                          ↕ 隔離
┌─────────────────────────────────────────────────────────┐
│  L3: Production（部署目標）                              │
│  路徑：cloud / prod server                              │
│  包含：.env.production、生產資料庫、real API key          │
│  用途：正式運行                                          │
│  規則：未通過 Ship 階段，絕對不碰                        │
└─────────────────────────────────────────────────────────┘
```

---

## 變數命名規範

避免不同環境的變數互相覆蓋或混淆：

### 專案內 `.env` 命名
```bash
# Dev 環境（本地）
DATABASE_URL=postgres://dev.local:5432/app_dev
API_KEY=sk-dev-xxxxx
STRIPE_MODE=test

# Production 環境
DATABASE_URL=postgres://prod.xxx.com:5432/app
API_KEY=sk-prod-xxxxx
STRIPE_MODE=live
```

### 在 config.yaml / 程式碼中明確標記
```bash
# 錯誤：不知道是哪個環境
API_KEY=sk-xxx

# 正確：明確標記環境
DEV_API_KEY=sk-dev-xxx
PROD_API_KEY=sk-prod-xxx
```

---

## 每層 CRUD 規範

### L1：Agent Config（平台配置層，通常不需要動）
- **Read**：可讀取用來了解 Agent 設定
- **Write**：除非明確需要改 Agent 行為，否則不修改
- 紅線：不要把專案的 API key 放進來

### L2：專案開發環境（日常使用）
- **Read/Write**：日常開發都在這層
- 確認所有設定都是 `-dev` / `-test` 版本
- 使用 sandbox / test API key

### L3：Production（嚴格管制）
- **Read**：可以看，但不要在 dev 環境操作
- **Write**：只能在 Ship 階段，經過完整 QA Gate 後操作
- 紅線：未通過 QA Gate 的代碼，絕對不部署

---

## 每階段檢查點

### Think / Plan 階段
- [ ] 確認目標是 dev 還是 prod
- [ ] 如果是 prod，確認是否有充分理由繞過 dev
- [ ] 明確即將操作哪一層的設定

### Build 階段
- [ ] 確認當前 working directory 是哪個專案
- [ ] 確認 `.env` 是 dev 版不是 prod 版
- [ ] 任何新變數加入，明確屬於哪個環境

### Review / Test 階段
- [ ] 確認測試是在 dev 資料庫 / sandbox 環境
- [ ] 確認沒有用到 real production key

### Ship 階段
- [ ] 最終確認所有設定切換到 prod 版本
- [ ] 再次確認 `.env.production` 內容正確
- [ ] 部署後驗證 log 確認正常

---

## 測試 / 執行腳本隔離（David 經驗鐵律）

> **任何測試腳本、執行腳本、一次性實驗程式、debug 探針，絕對不寫進 `~/www/<project>/` 的專案目錄。**

**原因（過去的實戰教訓）：**
- 這類腳本會污染專案結構，混進 production build 的風險
- 影響項目代碼質量、code review 信號
- 容易在 `git add .` / `git status` 時被誤提交
- 跟正式 source code 混在一起後，後續維護很難分辨

**規則：**
| 類型 | 寫到哪 | 範例 |
|------|--------|------|
| 一次性測試 / 探針 / debug | `/tmp/` | `/tmp/test_auth_flow.py` |
| 長期保留的測試套件 | 專案內 `tests/` 或 `__tests__/` | 視專案慣例 |
| 實驗性 / scratch 程式 | `/tmp/scratch_<date>_<purpose>.py` | `/tmp/scratch_2026-06-03_explore-prisma.py` |
| CI 跑的測試 | 專案內 `tests/` + 透過 CI runner | — |

**每個 Build 階段開始前，確認：**
1. 我要寫的這支腳本，屬於「專案資產」還是「暫時實驗」？
2. 暫時實驗 → 寫到 `/tmp/`，**不要**寫到 `~/www/<project>/`
3. 如果最終發現值得留下來，再手動搬到專案內 `tests/` 並寫進 git

---

## 常見錯誤案例

### 案例 1：混用 API Key
```
問題：在 dev 環境看到 STRIPE_LIVE_KEY=sk_live_xxx
解決：立即停手，確認這不是 dev 該有的設定
```

### 案例 2：本地指向 Production DB
```
問題：DATABASE_URL 指向 prod.xxx.com
解決：確認這不是 deploy 流程的一部分，立即切回 dev
```

### 案例 3：.env 覆蓋出問題
```
問題：修改了平台配置層的 .env，以为是專案 .env
解決：使用完整的相對路徑，或在 terminal 前先 pwd 確認
```

---

## 快速確認清單

在 terminal 操作前，快速確認：

```bash
# 1. 確認我在哪個目錄
pwd

# 2. 確認這是哪個專案
ls -la | grep -E "package.json|requirements.py|Cargo.toml"

# 3. 確認 .env 是哪個版本
cat .env | grep -E "NODE_ENV|DATABASE_URL|MODE" | head -3

# 4. 確認沒有 production 關鍵字
env | grep -iE "prod|live|production" || echo "CLEAN"
```

---

## 隔離檢查指令

任何時候懷疑環境混用，執行：

```bash
# 檢查當前專案的環境設定
grep -r "production\|prod\|live" --include=".env*" .

# 檢查是否有用到線上資料庫
grep -r "DATABASE_URL" .env* | grep -v "dev\|test\|localhost"

# 確認 Agent Config 的 env 沒有被專案污染
cat ~/.tree_monstor/.env | grep -E "APP_|DB_|STRIPE_" || echo "CLEAN"
```

---

## Related docs

- [Documentation index](00-index.md)
- [DevOps runbook](devops.md)
- [Cross-platform usage](cross-platform-usage.md)
- [Failure policy](failure-policy.md)
