# Dav Reviewer — Gate 4 ＋ Gate 4.5 定義

> 本檔為 `dav-reviewer` skill 嘅 Gate 定義子檔（**人手觸發**嘅審核段）。
> Gate 定義屬**規則語意**：搬位唔可以改字；`pass_criteria`／`required_evidence`／`fail_action`／`mandatory_phrase` 四欄一個都唔准刪。
> 機器可讀副本：`docs/sop/gates.json`（gate-4；Gate 4.5 係內嵌子閘、不入該檔）。

## Gate 4 reviewer gate

- **pass_criteria**：① checker subagent 回傳「沒找到更多問題」② playwright-cli E2E 全綠（含截圖證據，UI 任務必跑）
- **required_evidence**：① checker subagent 原文回傳 ② playwright test 報告路徑 + 截圖路徑（若有 UI）
- **fail_action**：不可進入 §2.4 反省
- **mandatory_phrase**：依 gates.json 規範，Gate 4 (reviewer) 需要：checker 回傳「沒找到更多問題」
  - playwright-cli E2E 全綠（含截圖），並在對話貼出 checker subagent 原文回傳。
- **豁免**：純後端／CLI／腳本任務可跳過 playwright-cli，但要在對話明示「無 UI 故不適用」及理由。
- **觸發方式**：**人手觸發**（用戶叫先做；唔喺 §2.3 自動執行段內 → 執行段只有 Gate 1/2/3）。

## Gate 4.5 需求對帳

> **進本 Gate 時必須在對話引用下表嘅 `mandatory_phrase`；不引用＝視為 gate 未觸發**（屬「偽裝通過」，依 SOP 的違規回報規則處理）。

- **pass_criteria**
  - 內容：① 對帳表覆蓋錨點的全部 R-ID（覆蓋率 100%）② 由未參與實作的獨立 subagent 執行（降級須標註）③ 對帳結果帶入交付摘要，且交付狀態與對帳結果一致
- **required_evidence**
  - 內容：① 需求對帳表（落在目標專案的 reconcile 目錄）② 未參與實作的 subagent 對帳原文回傳 ③ 交付摘要的「需求對帳」段與覆蓋率
- **fail_action**
  - 內容：不可進入 §2.4 反省
- **mandatory_phrase**
  - 內容：依 §2.3 規範，Gate 4.5 (需求對帳) 需要：對帳表覆蓋全部 R-ID + 獨立 subagent 對帳原文 + 交付狀態與對帳結果一致，並在對話貼出對帳表與覆蓋率。
- **定位說明**：Gate 4.5 是 **內嵌子閘**，**不進 `gates.json`**（該檔嘅 gate `id` 受 schema 限制，只允許整數編號嘅四大 Gate）。
  自 2026-10-26 起，四道大 Gate 嘅**定義本體**落在各自承載它的 skill（gate-1/2/3 → `dav-developer`、gate-4 → `dav-reviewer`），
  `gates.json` 為**機器可讀副本**；（2026-10-27 減法：鎖兩邊逐條一致嘅 `tests/gate-in-skill.bats` 已刪 → 兩邊要人手同步。）
- **觸發方式**：同 Gate 4 一樣 **人手觸發**（一次 review pass 一併做）→ 用戶叫「review／對帳」時，
  品質審核（Gate 4）同需求對帳（Gate 4.5）喺**同一個 skill** 內完成。

## 兩道 Gate 點解喺同一個 skill ＋ 點解唔再喺 §2.3 自動執行段

- 用戶要嘅係**一次 review 得出兩樣嘢**：品質 verdict（做得好唔好）＋ 需求對帳表（做緊嘅係咪用戶要的）；
  分兩個 skill → 用戶要叫兩次、agent 要開兩個 session、對帳嘅輸入要再準備一次 → 浪費
- 合併後：一次 review pass 內，checker 做品質審核、對帳者做需求比對，兩份結果一併交返用戶
- §2.3 自動段只剩 Gate 1/2/3（TDD／lint／回歸）→ 執行完就交返用戶，**唔使等 2-5 分鐘嘅審核**
- Gate 4 係最貴嘅校驗而對「行得唔行」影響最少 → 交由用戶按需要觸發；但做 review 時一樣會跑，
  fail_action 仍然係「不可進入 §2.4 反省」（當用戶觸發咗就要認真做）
