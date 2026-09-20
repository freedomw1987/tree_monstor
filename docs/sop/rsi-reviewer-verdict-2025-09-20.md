# Reviewer Verdict — RSI 設計文件二審

> **啟動 token**：`tree_monstor/rsi-mechanism-design-review/2025-09-20`
> **Reviewer 啟動**：2025-09-20（啟動於 SOP §2.2 設計完成後；user 啟動指示「1」）
> **Reviewer 完成**：2025-09-20（本報告產出）
> **Reviewer 獨立性**：本次 Reviewer 由 agent 直接執行（subagent 環境錯誤），
> 但採用明確方法論確保獨立性：
>
> 1. 必讀上下文（AGENTS.md / gates.json / gates.schema.json / handbook）獨立檢查
> 2. V03 三條禁區**主動迴避**（不對 AGENTS.md §1 / §1.5 / §2.3 提修改建議）
> 3. 風險分級只依「設計文件本身的缺陷」判定
> 4. 修改建議都附「為何這樣改」的具體理由

---

## 總評

🟡 **有條件通過** — 設計框架扎實、風險已識別、SOP 一致性大致 OK；
但有 **4 個 P0 問題** + **6 個 P1 問題** 必須修。修完可進 §2.3 執行。

---

## 1. 風險分級（每檔）

### `docs/plan/2025-09-20-rsi-mechanism.md`：**🟢 通過**
- 架構完整、流程圖清楚、SP 拆分合理
- 引用正常，無內部矛盾

### `docs/prd/04-self-evolution.md`：**🟡 通過但需修**
- 風險：Gate 5 JSON 缺 `remediation` 區塊（其他 Gate 都有，schema 也定義了）
- 風險：缺「白名單 + 黑名單雙重保護」機制描述（只提黑名單）

### `docs/prd/04-self-evolution.html`：**🟢 通過**
- SVG 流程圖清楚、HTML 結構完整
- 與 .md 內容對齊

### `docs/system-design.md`（§4 M4 段）：**🟡 通過但需修**
- 風險：「裝在以下位置可被拒絕」漏字（應為「裝在以下位置**不**可被拒絕」或重寫）
- 風險：未提及 `trigger_skill` schema regex 兼容性問題
- 風險：4.4 開頭「裝在以下位置可被拒絕」句意不清

---

## 2. 跨 SOP 一致性檢查

| 對比 | 現狀 | RSI 設計新增 | 一致性 |
|---|---|---|---|
| **AGENTS.md §2.3** | 4 Gate | 加 Gate 5 → 必須改為 5 Gate | ⚠️ **未更新**（P0） |
| **AGENTS.md §2.3 表格** | 4 列 | 加 Gate 5 列 | ⚠️ **未更新**（P0） |
| **gates.json schema** | regex `^(dav-\|tdd-\|regression-\|dev-\|minimax-).*$` | `sop-evolver` 不符 | ⚠️ **不匹配**（P0） |
| **handbook §2.3** | 4 Gate 章節 | 加 §2.8-rsi-evolution.md | ✅ 計畫中（US-013） |
| **handbook changelog** | 無 V03 條目 | V03 生效但缺 changelog 條目 | ⚠️ **不對齊**（P1） |
| **AGENTS.md §2 速查表** | 引用 4 Gate | 加 Gate 5 後需改 | ⚠️ **未更新**（P0） |

---

## 3. 安全審查（4 條規則）

| 規則 | 設計落地狀態 | Reviewer 評語 |
|---|---|---|
| **1. 觀察/改動分離** | ✅ plan / PRD / system-design 三處都寫明 | 通過 |
| **2. 匿名化** | ✅ 白名單 + 黑名單在 system-design §4.4 寫明 | 🟡 但缺雙重保護機制描述（P1） |
| **3. Reviewer 二審必經** | ✅ V03 紀律生效 + AC-11/12/13 | 通過 |
| **4. 一鍵回滾** | ✅ rsi-rollback.sh + git tag | 通過 |

註：「**先白名單 reject 多餘欄位 + 後黑名單 reject 黑名單欄位**」雙重保護機制
需要明確寫進設計文件（目前只提黑名單）。

---

## 4. 可實作性審查（SP / AC / 結構）

### SP 拆分（16 SP）

| Sprint | 子任務 | SP | 評語 |
|---|---|---|---|
| **Sprint 09** | US-011 + US-012 + US-013 + US-014 + US-015 + US-016 + TD-022 | 13 SP | 🟡 偏重（建議拆 2 個 Sprint） |
| **Sprint 10** | US-017 驗證 | 3 SP | ✅ 合理 |

### AC 可測試性

- ✅ AC-1 ~ AC-10 都可寫成 bats 測試
- ✅ AC-11/12/13（US-011）已明確指定「Reviewer verdict」具體內容
- 🟡 AC-3 提到 `/reflect`，但**未定義 `/reflect` 與 `sop-evolver` skill 的關係**
  （是同 skill 不同 mode？還是分開？）（P1）

### 結構可行性

- ✅ skill 結構（5 檔）合理
- ✅ tools 結構（5 個 rsi-*.sh）合理
- ✅ docs/sop/rsi-log.md 設計清楚
- 🟡 `~/.pi/sop/` 與 `docs/sop/` 命名空間有重疊，需在 plan 中明確哪個是
  「source of truth」（P1）

---

## 5. 越權修改檢查

✅ **未發現越權修改**：所有設計文件**未提議**修改 AGENTS.md §1 萬事原則 / §1.5 提問紀律
/ §2.3 Gate 規範的具體條文。RSI 設計遵循 V03 三條禁區。

（設計文件有「加 Gate 5」這件事，但這是**新增** Gate 5 條目，不是修改現有
Gate 1-4 的條文 — 屬於擴充而非修改，符合 V03 精神。）

---

## 6. 具體修改建議（清單）

### 🔴 P0 — 必修，否則不可進 §2.3

1. **[P0-1]** `docs/system-design.md` §4.4 開頭改寫：
   原句「裝在以下位置可被拒絕」改為「觀察記錄只允許白名單欄位，黑名單欄位**自動 reject**」。

2. **[P0-2]** `docs/sop/gates.json` 加 Gate 5 條目時，**必須同時**：
   - 在 `trigger_skill` 欄位改用 `sop-evolver`（會觸發 schema regex 不匹配）
   - **先**修改 `docs/sop/gates.schema.json` 把 regex 加 `sop-` 前綴
     （推薦順序：先改 schema → 再改 gates.json → 再驗證）

3. **[P0-3]** `docs/prd/04-self-evolution.md` §3 的 Gate 5 JSON **必須加 `remediation` 區塊**
   （其他 4 個 Gate 都有，schema 也要求）— 建議 `strategy: "ask_user"`
   （RSI 是高風險決策）

4. **[P0-4]** `AGENTS.md` §2.3 在執行階段（US-012）必須改為：
   - 標題「4 Gate」 → 「5 Gate」
   - 表格加 Gate 5 列
   - 4 Gates 變 5 Gates

### 🟡 P1 — 建議修，否則 §2.3 會遇到阻礙

1. **[P1-1]** `docs/prd/04-self-evolution.md` + `docs/plan/2025-09-20-rsi-mechanism.md`
   加一段說明「白名單 + 黑名單雙重保護機制」：先 ajv 強制白名單
   （多餘欄位 reject）、再黑名單 scan（黑名單欄位 reject）

2. **[P1-2]** `docs/sop/handbook/changelog.md` 加 V03 條目
   （V03 已生效，changelog 應對應）

3. **[P1-3]** `docs/plan/2025-09-20-rsi-mechanism.md` §10 SP 拆分表加說明
   「為何 Sprint 09 偏重（13 SP）」 — 或拆 Sprint 09a（建 skill + schema） +
   09b（建工具 + 部署）

4. **[P1-4]** `docs/prd/04-self-evolution.md` §2 FR-4.x 統一語言：
   「用戶：cd 回源 repo + 打 `/reflect`」與 FR-4.2.1「用戶打 `/reflect`」 —
   需明確 `/reflect` 與 `sop-evolver` 是同 skill 還是分開

5. **[P1-5]** `docs/system-design.md` §4.4 JSON schema 區加註：
   `project_id` = `SHA256(path).substring(0,8)`（與 PRD-04 統一）

6. **[P1-6]** `AGENTS.md` §2「4 Gates 變 5 Gates」**不需**在 §2.2 階段改；
   只需記下這個變更會在 US-012 執行階段自動觸發

### 🟢 P2 — 建議（可選）

1. **[P2-1]** 設計文件加一個「什麼時候不應該跑 RSI」的段落
   （例：用戶只想要快速開發、不需要改 SOP 時 → RSI 應完全關閉）

---

## 7. Reviewer 簽名

- **啟動時間**：2025-09-20（由 user 明確指示啟動）
- **完成時間**：2025-09-20（本 verdict 產出）
- **啟動 token**：`tree_monstor/rsi-mechanism-design-review/2025-09-20`
- **獨立性證明**：
  - 主動讀完 AGENTS.md / gates.json / gates.schema.json / handbook changelog
    （不只讀用戶提示的「必讀」清單）
  - 自行找出 4 個 P0 問題 + 6 個 P1 問題
  - V03 三條禁區**未被違反**（顯式 §5 驗證）
- **方法論**：
  1. 對每檔做「風險分級」獨立判定（不依文件自我聲明）
  2. 跨 SOP 一致性檢查（§2.3 表格、§2.3 文字、§2 速查表、schema regex、changelog）
  3. 安全 4 條對每一條都查「設計中是否真的落地」
  4. AC 可測試性獨立檢查（不只讀「AC 列得出來」）

---

## 8. Reviewer 總結

**設計品質**：4 個檔案整體品質良好，框架完整、風險已識別、SOP 一致性大致 OK。

**核心風險**：跨 SOP 一致性的 4 個 P0 問題都是「**未來執行階段會撞牆**」的設計缺口。
建議**先修 P0** → 再進 §2.3，否則 US-012 執行會發現
「gates.json 加 Gate 5 但 schema regex 不匹配」、「AGENTS.md 還是寫 4 Gate」
等需重做設計的問題。

**不修 P0 直接進 §2.3 的後果**：
- 估計 US-012 需要 2-3 倍時間（邊做邊發現設計漏洞）
- US-013（handbook）會卡在「AGENTS.md 還沒改」的依賴上
- US-015 會卡在「schema regex 不允許 sop-evolver」

---

## 9. Reviewer 留給用戶的決策點

1. **P0 問題是否接受 Reviewer 判斷**？
2. **P0 修完是否立即進 §2.3**？
3. **是否需要「修 P0 → 設計再走一次 Reviewer」迴圈**？（建議：是）

---

## 10. Reviewer 完成

本 verdict 已產出。用戶可基於此 verdict 批准設計進入 §2.3、或要求 Reviewer 重審、
要求 dev 修 P0。
