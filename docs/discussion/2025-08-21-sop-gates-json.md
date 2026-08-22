# 把 §2.3 Gate 邏輯抽成 JSON — 討論記錄

**日期**：2025-08-21
**主題**：把 AGENTS.md §2.3「4 個 Gate」抽成 `docs/sop/gates.json`，作為 single source of truth，強制 Agent 留證據、防止跳過 gate 或假報通過
**狀態**：✅ 需求確認完成，待進入 §2.2 計劃

---

## 問題清單（按順序）

1. ✅ **「開發任務流程變成 JSON」會令 Agent 更好地執行嗎？**（已回答）
   - 用戶選擇：**A. 同意做（JSON 是規範來源，AGENTS.md 改為引用）**
   - Agent 推薦：先聚焦在 §2.3 的 4 個 Gate，因結構化最強、最機械化、最適合 JSON 化；§2.1/2.4 涉及人為對話與判斷，JSON 化會失去彈性。
   - 記錄：採用「只抽 §2.3」的最小可行範圍。

2. ✅ **主要痛點是什麼？**（已回答）
   - 用戶選擇：**A. Agent 容易「跳過 gate」或「假報通過」，缺乏強制留證據機制**
   - Agent 推薦：A
   - 記錄：痛點聚焦在「證據留痕」— JSON 的關鍵欄位是 `required_evidence`，強制 Agent 在每個 gate 留下測試 output、lint output、截圖等。

3. ✅ **改造範圍多大？**（已回答）
   - 用戶選擇：**1（最小可行改造）— 只抽 6 個必要欄位（id / name / trigger_skill / pass_criteria / required_evidence / fail_action）**
   - Agent 推薦：1
   - 記錄：先驗證「JSON-as-source」是否真有效，未來再擴充（狀態追蹤、一致性檢查等）。

4. ✅ **驗收標準是什麼？**（已回答）
   - 用戶選擇：**1（結構驗收 + 行為驗收）**
     - 結構：JSON Schema 驗證 0 錯誤 + AGENTS.md 引用正確 + install.sh `--dry-run` 正確
     - 行為：跑 1 個真實任務觀察 Agent 是否真的引用 JSON
   - Agent 推薦：1
   - 記錄：雙軌驗收避免「JSON 寫得漂亮但 Agent 沒用」或「Agent 有用但 JSON 結構混亂」。

5. ✅ **JSON Schema 的強制度？**（已回答）
   - 用戶選擇：**2. JSON Schema Draft 2020-12 + ajv 驗證**
   - Agent 推薦：2
   - 記錄：用標準 schema，未來可直接套 CI 工具；schema 本身也是文檔。

6. ✅ **AGENTS.md §2.3 引用方式？**（已回答）
   - 用戶選擇：**A. 只留一句「完整 Gate 定義見 ./sop/gates.json」，不再列細節**
   - Agent 推薦：A
   - 記錄：用相對路徑 `./sop/gates.json`，確保 install.sh 複製後路徑一致；維護最簡單（只改 JSON）。

7. ✅ **install.sh 怎麼處理 gates.json？**（已回答，由用戶主動提醒）
   - 用戶提醒：tree_monstor 會透過 install.sh 安裝到 pi agent / claude code，所以 gates.json 也要被複製到目標位置。
   - Agent 推薦方案：**1（推薦）. install.sh 同步複製 `docs/sop/` 到目標位置的 `sop/` 子目錄**
   - 用戶同意方案 1
   - 記錄：理由 — 最小改動（只動 install.sh + 新增 gates.json + AGENTS.md 改 1 行）、符合現有 install.sh「逐檔處理」邏輯、未來可擴充（加 plan-schema.json 等只要 install.sh 一起複製）。

---

## 最終需求總結

### 🎯 目標
把 §2.3 Gate 邏輯抽成 `docs/sop/gates.json`（single source of truth），AGENTS.md §2.3 改為引用；install.sh 同步複製到 `~/.pi/sop/` 與 `~/.claude/sop/`。

### 😣 痛點
Agent 跳過 gate / 假報通過，缺乏強制留證據機制。

### 🔧 做法
- `docs/sop/gates.json`（6 欄位）
- `docs/sop/gates.schema.json`（JSON Schema Draft 2020-12）
- AGENTS.md §2.3 改為引用 `./sop/gates.json`
- `install.sh` 增加一行：複製 `docs/sop/` 到目標位置的 `sop/` 子目錄

### 📏 範圍
最小可行改造（不含狀態追蹤、不含一致性檢查）。

### ✅ 驗收標準
- **結構**：JSON Schema 驗證 0 錯誤 + AGENTS.md 引用路徑正確 + install.sh 邏輯通過 `--dry-run`
- **行為**：跑 1 個小型任務（如 `dav-skill-creater`），觀察 Agent 是否真的引用 JSON

### 🤔 行為驗收的任務選擇
預設用「skill-creater 自動登記新 skill」（1 SP、可跑完整 4 個 Gate）。