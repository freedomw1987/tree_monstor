---
name: dav-jev-oracle
description: >-
  開發執行階段用「LLM 判斷」做回歸／修正建議嘅可選加深能力：Jev Oracle 診斷 fail 係真 bug 定 flaky、產 fix proposal、跑 flaky 整合／PR comment／多 story
  矩陣。用於需要語意層面判斷或自動產修正建議時；純機械斷言嘅一般回歸唔用（見同套 `dav-developer` skill）。
---
# Dav Jev Oracle

## TL;DR
1. **做什麼**：用 Jev（LLM 裁判）判斷「呢個 fail 係真 bug、flaky 定 AC 本身寫得唔好」，並提供「診斷 → 產 fix proposal → 套 patch → 重驗 → 自動 rollback」嘅閉環。
2. **何時觸發**：需要**語意層面**判斷（AC 本身含糊、UI 體驗、跨模組一致性），或者要自動產修正建議 → 由同套 `dav-developer` skill 決定要用時調用。
3. **預設 SOP 路徑**：執行段（Gate 3 regression 期間，Gate 4 之前）—— **可選**。
4. **關鍵紀律**：**成本自覺**（只喺語意判斷真係有用時用）｜**只做輔助**（Jev 結果係參考，唔取代 LLM 自評或人工判斷）｜**失敗要降級唔要中斷**（冇 API key／網絡錯 → 純 LLM 評分）。
5. **必產出物**：診斷結果（`overall_health`／`fix_priority`／`flaky_likelihood`／`regression_type`）＋ 需要時嘅 fix proposal ＋ 驗證後嘅報告。

## 觸發時機
- **AC 本身含糊／要判斷「呢個 fail 係咩性質」** → ✅ 建議用
- **要自動產修正建議**（M6／M6.1／M6.2／M6.3）→ ✅ 建議用
- **純功能／純數值斷言，語意判斷冇增值** → ❌ 唔用（成本唔平）
- **Gate 3 嘅一般回歸** → ❌ 唔需要（本 skill 唔做一般回歸，嗰個係同套 `dav-developer` skill 嘅事）

## 流程（5 步；細節 → 同套本 skill 子檔（`./jev-oracle.md`））
- **Step 1 判斷值唔值得用**：對住當前 US 嘅 AC 問「機械斷言夠唔夠用」→ 唔夠先啟動 Jev；對話要明示「jev 模式：on/off」。
- **Step 2 跑 journey ＋ 產診斷**：observe → Jev 判定 → recheck → end-of-run 診斷（JSON ＋ Markdown，4 個維度都有值，要有可重現嘅判定過程，唔係得個結論）。
- **Step 3 修正循環（M6／M6.1／M6.2／M6.3）**：診斷出問題 → 產 fix proposal（v1 自動／v2 LLM Relay）→ 套 patch → 重驗 → 差異就 rollback；proposal
有三段信心度，patch 有 before/after 對比。
- **Step 4 flaky 整合 ＋ PR comment（M7）**：同一 journey 跑多次 → 量 flaky_likelihood → 差異大就標 ⚠️（分唔出真 bug 定 flaky，修正循環會走錯方向）；需要時推
PR comment（4 段格式）。
- **Step 5 本機 CI runner（M8）**：跑多個 story ＋ 匯總 `matrix-summary.md`；**回傳碼語義**：綠 0／黃 2／紅 1／用法錯 3（紅燈要真係擋得住，唔係只印報告）。

## 規則 / 例外 / 限制
- **成本自覺，唔好亂用** — 例外：AC 本身含糊時值得；限制：每個 US 開 Jev 前要講得出「點解機械斷言唔夠」
- **Jev 只係參考，唔取代 LLM 自評／人工判斷** — 例外：JEV 模式 on；限制：兩者唔一致 → 以 LLM 為準，Jev 結果附喺備註
- **失敗要降級唔好中斷**（冇 key／網絡錯 → 純 LLM 評分）— 例外：無；限制：降級要明示
- **禁用 watch／interactive 模式** — 例外：無；限制：會卡住等 stdin
- **本 skill 唔做一般回歸** — 例外：無；限制：一般回歸係同套 `dav-developer` skill 嘅 Gate 3 事
- **Gate 定義**：本 skill **唔新增 Gate**（Gate 1/2/3 → 同套 `dav-developer` skill、Gate 4 → 同套 `dav-reviewer` skill〔人手觸發〕）；本
  skill 係 Gate 3 嘅**可選加深**，用唔用都唔影響 Gate
判定。

## 交叉引用（純文字）
- Jev Oracle 判準／修正循環（M6-M6.3）／flaky 驗證／M7／M8 → 同套本 skill 子檔（`./jev-oracle.md`）
- 探針 API 合約／環境變量／模組 API ＋ safety 規則／本機 CI runner 契約 → 同套本 skill 子檔（`./api-contract.md`）
- 輸出格式（文本／JSON 報告／batch report／PR comment／matrix summary）→ 同套本 skill 子檔（`./output-format.md`）
- 輸出範例 → 同套本 skill 子檔（`./examples.md`）；PoC 用法 → 同套本 skill 子檔（`./PoC/README.md`）；本機 CI runner → 同套本 skill
子檔（`./PoC/run_ci.sh`）；執行段嘅寫測試 → 紅變綠 → 探針 → Reviewer → 同套 `dav-developer` skill
