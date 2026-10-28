# Dav Reviewer — Gate 4 ＋ Gate 4.5 定義

> 本檔為 `dav-reviewer` skill 嘅 Gate 定義子檔（**人手觸發**嘅審核段）。
> 本檔係 Gate 4 ＋ Gate 4.5 嘅**單一真相**（2026-10-28 起：`docs/sop/gates.json` 副本已刪 → 唔再兩份要人手同步）。
> Gate 定義屬**規則語意**：搬位唔可以改字；`pass_criteria`／`required_evidence`／`fail_action`／`mandatory_phrase` 四欄一個都唔准刪。
> 反省 ＋ 提交嘅規則本體 → 同套 `./deliver.md`。

## Gate 4 reviewer gate

- **pass_criteria**：① checker subagent 回傳「沒找到更多問題」② playwright-cli E2E 全綠（含截圖證據，UI 任務必跑）
- **required_evidence**：① checker subagent 原文回傳 ② playwright test 報告路徑 + 截圖路徑（若有 UI）
- **fail_action**：不可進入反省段
- **mandatory_phrase**：依 Gate 規範，Gate 4 (reviewer) 需要：checker 回傳「沒找到更多問題」
  - playwright-cli E2E 全綠（含截圖），並在對話貼出 checker subagent 原文回傳。
- **豁免**：純後端／CLI／腳本任務可跳過 playwright-cli，但要在對話明示「無 UI 故不適用」及理由。
- **remediation**：`ask_user`（最終決策——接受／退回／改架構——由用戶決定，agent 不自動修）。
- **觸發方式**：**人手觸發**（用戶叫先做；唔喺執行段（自動段）內 → 執行段只有 Gate 1/2/3）。

## Gate 4.5 需求對帳

> **進本 Gate 時必須在對話引用下表嘅 `mandatory_phrase`；不引用＝視為 gate 未觸發**（屬「偽裝通過」，依同套 `dav-router` skill 嘅違規回報規則處理）。

- **pass_criteria**
  - 內容：① 對帳表覆蓋錨點的全部 R-ID（覆蓋率 100%）② 由未參與實作的獨立 subagent 執行（降級須標註）③ 對帳結果帶入交付摘要，且交付狀態與對帳結果一致
- **required_evidence**
  - 內容：① 需求對帳表（落在目標專案的 reconcile 目錄）② 未參與實作的 subagent 對帳原文回傳 ③ 交付摘要的「需求對帳」段與覆蓋率
- **fail_action**
  - 內容：不可進入反省段
- **mandatory_phrase**
  - 內容：依 Gate 規範，Gate 4.5 (需求對帳) 需要：對帳表覆蓋全部 R-ID + 獨立 subagent 對帳原文 + 交付狀態與對帳結果一致，並在對話貼出對帳表與覆蓋率。
- **定位說明**：Gate 4.5 係 **執行段內嵌嘅子閘** → 只喺本檔定義（唔另立機器可讀副本檔）。
  原因：Gate id 嘅命名規則（`gate-<整數>`）容唔落小數號；對帳表格式 → 同套 `./reconcile-format.md`。
- **觸發方式**：同 Gate 4 一樣 **人手觸發**（一次 review pass 一併做）→ 用戶叫「review／對帳」時，
  品質審核（Gate 4）同需求對帳（Gate 4.5）喺**同一個 skill** 內完成。
- **例外**：存量任務（無需求錨點）唔觸發；trust mode 進行中唔中途停下問用戶，
  對帳結果照常產出、缺口記入 trust-log 代答 ＋ need-you-help 檔待回覆。

## 兩道 Gate 點解喺同一個 skill ＋ 點解唔再喺執行段（自動段）

- 用戶要嘅係**一次 review 得出兩樣嘢**：品質 verdict（做得好唔好）＋ 需求對帳表（做緊嘅係咪用戶要的）；
  分兩個 skill → 用戶要叫兩次、agent 要開兩個 session、對帳嘅輸入要再準備一次 → 浪費
- 合併後：一次 review pass 內，checker 做品質審核、對帳者做需求比對，兩份結果一併交返用戶
- 執行段（自動）只剩 Gate 1/2/3（TDD／lint／回歸）→ 執行完就交返用戶，**唔使等 2-5 分鐘嘅審核**
- Gate 4 係最貴嘅校驗而對「行得唔行」影響最少 → 交由用戶按需要觸發；但做 review 時一樣會跑，
  fail_action 仍然係「不可進入反省段」（當用戶觸發咗就要認真做）
