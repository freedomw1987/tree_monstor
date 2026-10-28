# Dav Developer — Gate 1–3 定義

> 本檔為 `dav-developer` 嘅「Gate 定義」子檔（2026-10-28 v2.11 減法版由主檔搬出，主檔只留指標）。
> 本檔係 Gate 1／2／3 嘅**單一真相**（2026-10-28 起：`docs/sop/gates.json` 副本已刪 → 唔再兩份要人手同步）。
> **進本 Gate 時必須在對話引用對應嘅 `mandatory_phrase`；不引用＝視為 gate 未觸發**（屬「偽裝通過」）。
> Gate 4 ＋ Gate 4.5 → 人手觸發嘅 `dav-reviewer` skill → 本 skill 只做 Gate 1／2／3。

## Gate 1 TDD gate

- **pass_criteria**：① 測試可運行　② 看到「先紅後綠」（失敗 → 通過）
- **required_evidence**：① 測試執行指令（如 pytest／bats／npm test）② 失敗輸出（改實作前嘅失敗訊息截錄）
  ③ 通過輸出（改實作後嘅通過訊息截錄）
- **fail_action**：不可寫實作 code
- **mandatory_phrase**：依 Gate 規範，Gate 1 (TDD) 需要：測試先紅後綠，
  並在對話貼出「測試執行指令 + 失敗輸出 + 通過輸出」。
- **remediation**：`auto_fix_with_limit`（最多 3 次；測試／實作小錯可自調）→ 仍失敗就 `ask_user`（可能要改 AC 或測試設計）
- **豁免**：純文件／配置改動可豁免，但須在交付摘要註明「無 TDD 需求」。

## Gate 2 lint / syntax gate

- **pass_criteria**：對應語言的 linter 0 error / 0 warning
- **required_evidence**：linter 完整 output（不可只說「過了」）
- **fail_action**：不可繼續寫更多 code
- **mandatory_phrase**：依 Gate 規範，Gate 2 (lint / syntax) 需要：對應語言的 linter 0 error / 0 warning，
  並在對話貼出 linter 完整 output。
- **remediation**：`auto_fix`（自動修到通過；lint 錯誤幾乎都係一行可修）
- **對應工具**：bash/sh → shellcheck；python → ruff check 或 `python -m py_compile`；其他語言用對應工具。

## Gate 3 regression gate

- **pass_criteria**：① 探針埋好（記錄關鍵 state／行為／boundary）② **改動範圍內**測試套件跑過
- **required_evidence**：① 修改前 baseline（範圍內測試 output，含 pass/fail 計數）② 修改後 output
  ③ Diff 對比（既有測試結果一致 + 新探針如預期觸發）
- **fail_action**：不可聲稱「做完了」
- **mandatory_phrase**：依 Gate 規範，Gate 3 (regression) 需要：探針埋好 + 改動範圍內測試套件跑過，
  並在對話貼出「修改前 baseline + 修改後 output + Diff 對比」。
- **remediation**：`auto_fix_with_limit`（最多 3 次；回歸失敗可能跨多檔）→ 仍失敗就 `ask_user`（可能要改架構）
- **測試指令必須禁用 interactive / watch 模式**（詳見同套 `./runner-cheatsheet.md`）。

## 執行段心法 ＋ trust 例外

- fail-fast 成本排序、Agent 必做動作、本機閘點跑 → 同套 `./execution.md`
- **trust mode 進行中**：Gate 失敗唔可以中途停下問用戶 → 自行決策寫 trust-log ＋ need-you-help 檔（同套 `./execution.md`）
- **Gate 4（reviewer）唔喺本檔**：2026-10-28 起 Gate 4 ＋ Gate 4.5 由**人手觸發**嘅 `dav-reviewer` skill 承載 → 本 skill 只做 Gate 1／2／3

## Gate 定義點解喺子檔

- 主檔 ≤ 50 行係硬門檻（v2.11 減法版）→ Gate 定義內容留喺子檔，主檔只留指標
- Gate 定義屬**規則語意**：搬位唔可以改字；`pass_criteria`／`required_evidence`／`fail_action`／`mandatory_phrase` 四欄一個都唔准刪
- 改動呢一檔＝改規範 → 依 `AGENTS.md` §1.5 V03 自查行數上限（代碼／契約嘅品質把關走對應 skill 嘅 Gate）
