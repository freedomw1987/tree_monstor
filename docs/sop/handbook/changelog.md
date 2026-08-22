# §3 CHANGELOG（SOP 異動紀錄）

> 本檔是 AGENTS.md §3 的詳細內容。引用：`[§3 CHANGELOG](./sop/handbook/changelog.md)`
>
> 追蹤 AGENTS.md §2 SOP 的所有重大異動，便於 audit 與回溯。每筆異動需註明版本號、日期、變更內容與原因。

## v1.2 — 2025-08-22

**本版異動**：AGENTS.md 精簡重構（TD-017）

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| 重構 | §2.1-§2.8 + §3 抽出去 `docs/sop/handbook/*.md` | 一章一檔，AGENTS.md 從 524 行 → ~150 行 |
| 重構 | AGENTS.md 引用方式 | Markdown 相對路徑 `[§2.1](./sop/handbook/2.1-planning.md)` |

**目的**：讓大模型可穩記 AGENTS.md 的核心內容（萬事原則、提問紀律、SOP 範圍判斷、4 Gate 表格、引用索引）。

## v1.1 — 2025-08-21

**本版異動**：

| 類型 | 項目 | 說明 |
| ---- | -- | -- |
| **P0** | §2.1 Plan Gate (fail-fast) | V05 — 加用戶確認才可進 §2.2 |
| **P0** | §2.2 Design Gate (fail-fast) | V07 — 加 3 文檔 + Story Point + 用戶確認 |
| **P0** | §2.3 用戶確認才能進 Gate | V09 — Plan 確認才能進 §2.3 |
| **P0** | §2.3 subagent 機制明確化 | V13 — dev/reviewer via `subagent` + `workflowScript` |
| **P0** | §2.4 Reflection Gate (fail-fast) | V17 — 加 6 維度報告 + backlog 更新 + 用戶確認 |
| **P0** | §2.0/§2.6 灰色地帶表 + 升級條款 | V21 — 強化任務分類 + 自動升級 |
| **P0** | §2.7 SOP 違規回報（**新章節**） | V23 — 違規自檢 + 用戶回應 + 記錄 |
| **P1** | §1.5 提問紀律（**新子章節**） | V01/V02 — 一次一個問題 + 方案必標推薦 |
| **P1** | §2.1 Plan Gate 通過聲明格式 | V06 — 必貼 checklist |
| **P1** | §2.2 Story Point 規模表 | V08 — Fibonacci 1/2/3/5/8/13 對照表 |
| **P1** | §2.3 Gate 1/2/3 必留證據 | V10/V11/V12 — 紅綠 output / lint output / baseline diff |
| **P1** | §2.4 反省模板 + Action Items 格式 | V15/V16 — 6 維度表 + 4 欄位（動作/類型/驗收/預估） |
| **P1** | §2.5 Markdown 模板 + 下一步建議規範 | V18/V20 — 必含欄位 + 三項必填 |
| **P1** | §2.5 Self-Check 清單 | V19 — 8 項 ✅ 才能提交 |
| **新增** | §2.8 Suggester 協作機制 | — — 第三者視角 advisory agent |
| **新增** | §3 CHANGELOG（本節） | V24 — SOP 版本控制 |

**修補來源**：AGENTS.md 完整 audit 識別 27 個 vulnerabilities（P0:7 / P1:13 / P2:7），本次處理 P0+P1 共 20 項；P2 待處理。

## v1.0 — 之前版本

未保留詳細記錄（CHANGELOG 機制為 v1.1 新增）。
