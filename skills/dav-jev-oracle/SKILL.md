---
name: dav-jev-oracle
description: 在代碼開發執行階段用「LLM 判斷」做回歸／修正建議嘅進階能力。提供 Jev Oracle（用 Jev 對 AC 對唔對、邊個 fail 係真 bug）、M6 修正循環（自動產 fix proposal）、M6.1 LLM Relay、M6.2 patch + re-validate、M6.3 sandbox 自動閉環、M7 flaky 整合 ＋ PR comment、M8 多 story 矩陣 ＋ 本機 CI runner。屬 dav-developer 嘅**可選加深**（Gate 3 唔強制要用）。
---

# Dav Jev Oracle

## TL;DR

1. **做什麼**：用 Jev（LLM 裁判）判斷「呢個 fail 到底係真 bug、flaky 定 AC 本身寫得唔好」，
   並提供由「診斷 → 產 fix proposal → 套 patch → 重驗 → 自動 rollback」嘅閉環。
2. **何時觸發**：需要**語意層面**判斷（AC 本身含糊、UI 體驗、跨模組一致性），
   或者要自動產修正建議 → 由 `dav-developer` 決定要用時調用。
3. **預設 SOP 路徑**：§2.3 執行段（Gate 3 regression 之後、Gate 4 reviewer 之前）—— **可選**。
4. **關鍵紀律**：
   - **成本自覺**：Jev 每次判斷都有 API cost ＋ latency → 只喺「語意判斷真係有用」時用
   - **只做輔助**：Jev 結果係**參考**，唔可以取代 LLM 自評或人工判斷
   - **失敗要降級唔要中斷**：冇 API key／網絡錯 → 走軟性降級（純 LLM 評分）
5. **必產出物**：診斷結果（`overall_health` / `fix_priority` / `flaky_likelihood` / `regression_type`）
   ＋ 需要時嘅 fix proposal ＋ 驗證後嘅報告

## 觸發時機

- **AC 本身含糊／要判斷「呢個 fail 係咩性质」** → ✅ 建議用
- **要自動產修正建議**（M6／M6.1）→ ✅ 建議用
- **純功能／純數值斷言，語意判斷冇增值** → ❌ 唔用（成本唔平）
- **Gate 3 嘅一般回歸** → ❌ 唔需要（本 skill 唔做一般回歸，嗰個係 `dav-developer` 嘅事）

## 流程（5 步）

### Step 1：判斷值唔值得用

- **動作**：對住當前 US 嘅 AC 問「機械斷言夠唔夠用」→ 唔夠先啟動 Jev
- **為什麼**：Jev 每次判斷都有 cost ＋ latency；用唔著就唔好開
- **產出**：對話中明示「用／唔用 Jev（同點解）」
- **證據**：對話有「jev 模式：on/off」

### Step 2：跑 journey ＋ 產診斷

- **動作**：跑 journey（observe → Jev 判定 → recheck）→ 產 end-of-run 診斷
- **為什麼**：要有可重現嘅判定過程，唔係得個結論
- **產出**：run JSON ＋ 診斷報告（JSON ＋ Markdown）
- **證據**：兩份報告都存在 ＋ 4 個維度都有值
- **參考**：同套本 skill 子檔（`./jev-oracle.md`、`./output-format.md`）

### Step 3：修正循環（M6／M6.1／M6.2／M6.3）

- **動作**：診斷出問題 → 產 fix proposal（v1 自動／v2 LLM Relay）→ 套 patch → 重驗 → 差異就 rollback
- **為什麼**：由診斷直接走到修正，先唔使人手逐個試
- **產出**：fix proposal（Markdown）＋ patch（JSON）＋ 重驗報告
- **證據**：proposal 有三段信心度；patch 有 before/after 對比
- **參考**：同套本 skill 子檔（`./jev-oracle.md`）

### Step 4：flaky 整合 ＋ PR comment（M7）

- **動作**：同一 journey 跑多次 → 量 flaky_likelihood → 差異大就標 ⚠️；需要時推 PR comment
- **為什麼**：分唔出真 bug 定 flaky，修正循環會走錯方向
- **產出**：flaky 數據 ＋（可選）PR comment
- **證據**：flaky 欄有值；PR comment 係 4 段格式
- **參考**：同套本 skill 子檔（`./jev-oracle.md`）

### Step 5：本機 CI runner（M8）

- **動作**：跑多個 story ＋ 匯總成 `matrix-summary.md`；**回傳碼語義**：綠 0／黃 2／紅 1／用法錯 3
- **為什麼**：多 US 一次過睇；紅燈要真係擋得住（唔係只印報告）
- **產出**：每個 story 嘅報告 ＋ 矩陣匯總
- **證據**：runner 嘅退出碼符合語義 ＋ 匯總表有「Per-Story Results」
- **參考**：同套本 skill 子檔（`./jev-oracle.md`）

## 規則 / 例外 / 限制

- **成本自覺，唔好亂用**
  - 例外：AC 本身含糊時值得
  - 限制：每個 US 開 Jev 前要講得出「點解機械斷言唔夠」
- **Jev 只係參考，唔取代 LLM 自評／人工判斷**
  - 例外：JEV 模式 on
  - 限制：兩者唔一致 → 以 LLM 為準，Jev 結果附喺備註
- **失敗要降級唔好中斷**（冇 key／網絡錯 → 純 LLM 評分）
  - 例外：無
  - 限制：降級要明示
- **禁用 watch／interactive 模式**
  - 例外：無
  - 限制：會卡住等 stdin
- **本 skill 唔做一般回歸**
  - 例外：無
  - 限制：一般回歸係 `dav-developer` 嘅 Gate 3 事

## Gate 定義（本節是 single source 之一；機器可讀副本 `docs/sop/gates.json`）

> 本 skill **唔新增 Gate** —— Gate 1/2/3/4 仍然由 `dav-developer` 承載（gates.json 唔變）。
> 本 skill 係 Gate 3 嘅**可選加深**：用唔用都唔影響 Gate 判定。

## 交叉引用（純文字）

- 執行段嘅寫測試 → 紅變綠 → 探針 → Reviewer → 同套 `dav-developer` skill
- Jev Oracle 完整設計（各 M6.x／M7／M8 細節、4 種 backend、gating 表）→ 同套本 skill 子檔（`./jev-oracle.md`）
- 輸出範例 → 同套本 skill 子檔（`./examples.md`）
- PoC 用法 ＋ API contract ＋ 環境變量 → 同套本 skill 子檔（`./PoC/README.md`、`./api-contract.md`）
- 本地 CI runner（本機跑：probes／pipeline／matrix／cleanup-scan）→ 同套本 skill 子檔（`./PoC/run_ci.sh`）
