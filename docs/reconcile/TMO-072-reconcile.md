# TMO-072 需求對帳表

> 對帳者: `evidence-auditor` subagent（Gate 4.5 獨立對帳者，**未參與實作**）| 對帳時間: 2026-10-26
> 錨點: docs/req/TMO-072-requirement.md
> 覆蓋率: **2/2**
> 對帳輪次: 第 6 輪（Round 6）；第 5 輪無殘餘，本輪複核機制「有沒有真的攔住」而非只看規則存在
> 對帳者獨立性: 非降級路徑（未參與本次實作）；對帳者環境**無 shell 執行能力** → 其「指令實際輸出」欄位由
> supervisor 補跑並附於各列「證據」欄（已標明誰取得）

## 對帳表

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | 成果與需求的落差必須由**獨立第三方**判定，不能由執行任務的同一個 Agent 自評自證 | ✅ 已實作 | `skills/dav-reconciler/SKILL.md`（Step 2 + 規則表第 1 列「對帳者必須獨立 subagent（未參與實作）」）、`reconcile-format.md` §5（降級標註列）；`docs/sop/handbook/2.3-execution.md`「Gate 4.5 需求對帳」節（通過條件 2）；`AGENTS.md` §2.3 Gate 4.5 列（2026-10-26 起改由 `skills/dav-reconciler/SKILL.md` 承載） | RECON-009（SKILL.md 必登錄「獨立 subagent」＋「降級」）、011（handbook §2.3 必含 Gate 4.5 ＋ 需求對帳）、012（Gate 4.5 必登記在承載它的 skill；2026-10-26 前為「AGENTS.md §2.3 速查表必列 Gate 4.5」）、015（skill 不得讀跨目錄 `docs/`）；DOC-DRIFT-031（對帳降級卻宣告 ✅ → 紅）｜**本輪實例（非退化證明）**：本輪對帳由未參與實作的 `evidence-auditor` 執行，且其判定與執行者交付摘要的「⚠️ 部分完成」**方向不同**（對帳者初判 7/7 ✅，但同時抓出 5 處既存漂移並點名）→ 機制確實非自評 | 「獨立性」屬**流程性約束**，機制面只有「規則存在性」探針（RECON-009/011/012）與「降級不得宣告通過」的機械攔截（DOC-DRIFT-031），**無法機械驗證「某人真的沒參與實作」**。此為**已揭露的設計限制**，非本句落差 |
| R2 | 對帳由未參與實作的獨立 subagent 執行；對帳結果有「未實作／偏離」時**不得**宣告「✅ 完成」，只能標「⚠️ 部分完成」並列出待補項 | ✅ 已實作 | 規則面：`skills/dav-submitter/SKILL.md` v2.5（TL;DR 第 5 條 + Step 4.5「帶入需求對帳結論」+ 規則表「需求對帳硬門檻」）；`skills/dav-submitter/template.md` §3.1（含硬門檻說明與狀態值列舉）；`docs/sop/handbook/2.5-submission.md`（模板「## 3.1 需求對帳」段 + 提交前 Self-Check 第 9 項）；`skills/dav-reconciler/reconcile-format.md` §7 交付狀態對應表。機械面：`skills/dav-reconciler/scripts/check-doc-drift.py` `Checker.check_deliverable_reconcile()`（gaps 分支、內嵌 vs 權威表多重集比對、降級分支） | RECON-010（dav-submitter 必含「需求對帳」＋「部分完成」）；DOC-DRIFT-028（gaps 卻宣告 ✅ → 紅）、029（舊欄位名 `**狀態**` 同樣被抓）、030（內嵌 vs 權威表矛盾 → 紅，且只產生 1 條 DRIFT D8）、031（降級卻宣告 ✅ → 紅）；`scripts/ci/mutants.tsv` **DD-M3**（D8 gaps 分支 `if gaps and declared.startswith("✅")` → `if False:` 必紅，baseline 必須先綠）｜**supervisor 實跑**：①真實 repo `check-doc-drift.sh --from-date 2026-10-26` → rc=0；②**對抗測試**：把真實交付摘要的 `**交付狀態**` 改成「✅ 完成」（權威表仍有 069 R1 / 071 R2 兩個 gap）→ rc=1 且報 `DRIFT D8 …: 對帳有未對上的項目（TMO-071 R1=⚠️ 部分實作, TMO-073 R2=⚠️ 部分實作）但交付狀態標為「✅ 完成」`；③`mutant-must-die.py --only DD-M1,DD-M2,DD-M3,DR-M1` → 4 baseline 全綠 + 4 支全死（**DD-M3 即本句的機械保險**） | 「gaps → 不得宣告 ✅」有**雙重證據**：規則面 4 處 + 機械面 D8 gaps 分支（DD-M3 mutant 鎖）。**實機行為證據**：本次交付摘要的狀態欄就是「⚠️ 部分完成」且 §5 列了待補 → 硬門檻在**自己的交付上生效**，未出現「自己寫自己完成」。「列出待補項」由交付摘要 §5 待辦表落實。**殘餘（設計邊界，已揭露）**：D8 的內嵌 vs 權威表比對**只比 (R-ID, 狀態)**，不比「實作位置」「證據」欄 → 證據欄字面漂移不可見（見 TMO-071 R1 備註）。**本輪另修掉一個使本句失效的真實缺口**：`--from-date` 傳入非法值會讓**所有**交付摘要被跳過 → D8 硬門檻被一個 typo 靜默關掉 → 假綠 → 已改 fail-closed（rc=2）+ DOC-DRIFT-036/037 |

## 結論

- 2 項已實作、0 項部分實作、0 項未實作。覆蓋率 **2/2**（100%）。
- 核心命題「gaps → 不得宣告 ✅」有 DD-M3 突變鎖 + DOC-DRIFT-028/029/031 三支探針 + 規則面 4 處條文，四重證據；
  且在**真實交付檔案**上經對抗測試實際生效（假「✅ 完成」宣告被 rc=1 攔下）。
- 對帳者備註: 本輪對帳者沒有 shell 執行能力，改以實作原始碼 + 探針斷言 + 真實資料檔逐項比對判定；
  指令實際輸出由 supervisor 補跑並與其推演一致。本輪另發現並修掉 `--from-date` 的 fail-open 缺口 ——
  該缺口一旦被觸發，本句的硬門檻會**整個失效**，屬本句條件的實質風險，已閉合。
- 依 `reconcile-format.md` §7 硬門檻：本 US 全部 ✅ → 本 US 無阻擋項。
