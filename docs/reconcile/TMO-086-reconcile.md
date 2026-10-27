# TMO-086 需求對帳表

> 對帳者: 獨立 Reviewer subagent（V03 二審，**未參與實作**）| 對帳時間: 2026-10-27
> 錨點: docs/req/TMO-086-requirement.md
> 覆蓋率: **1/1**
> 對帳者獨立性: 非降級路徑（未參與本次實作）

## 對帳表

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | `dav-planner` 維度展開必須多一個維度「業務邏輯與依賴」，並寫清①何時必問②點樣問（V01/V02）③答案寫落邊 | ✅ 已實作 | `skills/dav-planner/reference.md` §3 補充維度第 6 條；`skills/dav-planner/backlog-rules.md` §4.3 ＋ AC 詳細段範本；`skills/dav-planner/examples/backlog.md`；`skills/dav-planner/SKILL.md` Step 3 | ① §3 第 6 條列 3 個觸發條件（有計算/規則、依賴其他模組或外部系統、US 之間有先後次序）②問法段寫明「一題一輪、2-4 個選項、⭐ 推薦放第 1 個；建議最後問」＋一個完整問法示例 ③答案落點段：業務規則 → AC 的 Given-When-Then ＋ 詳細段「業務規則」行；依賴 → Backlog 表格「依賴」欄 ＋ 詳細段「依賴」行；另加「答唔到 → 列入 Open questions」 | ⚠️ 同步清咗規範偏差：原「7 個維度」名實不符（實際核心 4 ＋ 補充 5 ＝ 9 條）→「維度展開（唔寫總數）」；成熟度「涵蓋率」改按「觸發咗嘅補充維度 ≥ 3 條」計，並寫明觸發由 Agent 逐條判斷、要在對話列出 |

## V03 二審結論（獨立 Reviewer）

```
Verdict: approve（P2 建議項，不阻擋合併）
殘留問題: P2 examples 5 個詳細段只有 2 個有「業務規則」行 → 補 3 行 N/A；
          §5 加一句「觸發由 Agent 逐條判斷並列出已觸發維度」
未驗: bash scripts/check-all.sh 未跑（reviewer 無 shell 權限）
```

**實作者處置**（2026-10-27）：

| 二審 P2 | 處置 | 證據 |
|---|---|---|
| examples 3 個詳細段缺「業務規則」行 | 已補 `N/A（無計算 / 狀態 / 權限 / 冪等規則）` ×3 | `skills/dav-planner/examples/backlog.md`（5 段全部有該行） |
| §5 未寫明「觸發」由邊個判斷 | 已加：Agent 逐條判斷 ＋ **要在對話列出已觸發維度**（用戶可覆核）＋ 觸發咗但冇問唔算已涵蓋 | `reference.md` §3 補充維度引言 ＋ §5 規則段 |

**reviewer 冇驗嘅部分，由實作者實跑補證**：`bash scripts/check-all.sh` → **11 步全綠**
（deps／ffmpeg／shellcheck／bashn／heredoc／drift／mdlint／venv／bats／skill-tests／mutant）；
`bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26` → OK: 30 項檢查完成，40 項豁免；
markdownlint → 0 issues；行數自查：主檔 129／子檔 111·158·133 ≤300／dav-planner context 531 ≤700 ✓。

## 結論

- **1 項已實作、0 項部分實作、0 項未實作。覆蓋率 1/1（100%）。**
- 本票屬**規範改動**（skill 內容 ＋ 產出模板欄位）→ 已依 `AGENTS.md` §1.5 V03 走獨立二審，verdict `approve`。
- 冇放寬任何既有門檻（主檔行數上限、純文字引用、4 段結構、變動歷史「唔記」規則全部維持）。
- ⚠️ 已記錄嘅影響：Backlog 詳細段多咗一個欄位（「業務規則」）→ 新寫嘅 US 必填（冇就寫 N/A）；
  存量 US 不回補（跟「既有 US 不主動遷移」慣例）。
