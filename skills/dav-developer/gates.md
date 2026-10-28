# Dav Developer — Gate 1–4 定義

> 本檔為 `dav-developer` 嘅「Gate 定義」子檔（2026-10-28 v2.11 減法版由主檔搬出，主檔只留指標）。
> 本檔係 single source 之一；機器可讀副本 `docs/sop/gates.json`（`notes` 與 `remediation` 仍在嗰度）。
> **進本 Gate 時必須在對話引用對應嘅 `mandatory_phrase`；不引用＝視為 gate 未觸發**（屬「偽裝通過」）。
> 2026-10-26 起 Gate 定義改由**承載它的 skill** 負責；鎖兩份一致嘅探針已於 2026-10-27 減法刪走 → 兩份要人手同步。

## Gate 1 TDD gate

- **pass_criteria**：① 測試可運行　② 看到「先紅後綠」（失敗 → 通過）
- **required_evidence**：① 測試執行指令（如 pytest／bats／npm test）② 失敗輸出（改實作前嘅失敗訊息截錄）
  ③ 通過輸出（改實作後嘅通過訊息截錄）
- **fail_action**：不可寫實作 code
- **mandatory_phrase**：依 gates.json 規範，Gate 1 (TDD) 需要：測試先紅後綠，
  並在對話貼出「測試執行指令 + 失敗輸出 + 通過輸出」。
- **豁免**：純文件／配置改動可豁免，但須在交付摘要註明「無 TDD 需求」。

## Gate 2 lint / syntax gate

- **pass_criteria**：對應語言的 linter 0 error / 0 warning
- **required_evidence**：linter 完整 output（不可只說「過了」）
- **fail_action**：不可繼續寫更多 code
- **mandatory_phrase**：依 gates.json 規範，Gate 2 (lint / syntax) 需要：對應語言的 linter 0 error / 0 warning，
  並在對話貼出 linter 完整 output。
- **對應工具**：bash/sh → shellcheck；python → ruff check 或 `python -m py_compile`；其他語言用對應工具。

## Gate 3 regression gate

- **pass_criteria**：① 探針埋好（記錄關鍵 state／行為／boundary）② **改動範圍內**測試套件跑過
- **required_evidence**：① 修改前 baseline（範圍內測試 output，含 pass/fail 計數）② 修改後 output
  ③ Diff 對比（既有測試結果一致 + 新探針如預期觸發）
- **fail_action**：不可聲稱「做完了」
- **mandatory_phrase**：依 gates.json 規範，Gate 3 (regression) 需要：探針埋好 + 改動範圍內測試套件跑過，
  並在對話貼出「修改前 baseline + 修改後 output + Diff 對比」。
- **機器可讀副本**：`docs/sop/gates.json`（鎖兩邊一致嘅探針已刪 → 兩邊要人手同步）。
- **測試指令必須禁用 interactive / watch 模式**（詳見同套 `./runner-cheatsheet.md`）。

## Gate 4 reviewer gate

- **pass_criteria**：① checker subagent 回傳「沒找到更多問題」② playwright-cli E2E 全綠（含截圖證據，UI 任務必跑）
- **required_evidence**：① checker subagent 原文回傳 ② playwright test 報告路徑 + 截圖路徑（若有 UI）
- **fail_action**：不可進入 §2.4 反省
- **mandatory_phrase**：依 gates.json 規範，Gate 4 (reviewer) 需要：checker 回傳「沒找到更多問題」
  - playwright-cli E2E 全綠（含截圖），並在對話貼出 checker subagent 原文回傳。
- **豁免**：純後端／CLI／腳本任務可跳過 playwright-cli，但要在對話明示「無 UI 故不適用」及理由。

## Gate 定義點解搬出主檔

- 主檔 ≤ 50 行係硬門檻（v2.11 減法版）→ Gate 定義內容留喺子檔，主檔只留指標
- Gate 定義屬**規則語意**：搬位唔可以改字；`pass_criteria`／`required_evidence`／`fail_action`／`mandatory_phrase` 四欄一個都唔准刪
- 改動呢一檔＝改規範 → 依 `AGENTS.md` §1.5 V03 走獨立 Reviewer 二審
