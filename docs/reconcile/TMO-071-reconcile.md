# TMO-071 需求對帳表

> 對帳者: `evidence-auditor` subagent（Gate 4.5 獨立對帳者，**未參與實作**）| 對帳時間: 2026-10-26
> 錨點: docs/req/TMO-071-requirement.md
> 覆蓋率: **3/3**
> 對帳輪次: 第 6 輪（Round 6）；第 5 輪殘餘（「端到端證據待以可執行證據確認」）本輪以**真實檔案對抗測試**閉合
> 對帳者獨立性: 非降級路徑（未參與本次實作）；對帳者環境**無 shell 執行能力** → 其「指令實際輸出」欄位由
> supervisor 補跑並附於各列「證據」欄（已標明誰取得）

## 對帳表

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | 交付成果與用戶原始需求之間不得有未說明落差；造成落差的「文件間翻譯」落差必須被機制化處理，可見、可驗、不可藏 | ✅ 已實作 | `skills/dav-reconciler/scripts/check-doc-drift.py`（`Checker.check_deliverable_reconcile()` D8 gaps 分支 / `Checker.check_deliverables()` D4 / `load_whitelist()` fail-closed）；`skills/dav-submitter/SKILL.md` Step 4.5 + 規則表「需求對帳硬門檻」；`skills/dav-submitter/template.md` §3.1；`docs/sop/handbook/2.3-execution.md`「Gate 4.5 需求對帳」節；`docs/sop/handbook/2.5-submission.md` 模板 + self-check 第 9 項；`skills/dav-reconciler/reconcile-format.md` §7 | 可見＝`DRIFT <類> <鍵>: <說明>` / `WHITELIST <類> <鍵>: <理由>` 逐行輸出（DOC-DRIFT-020）｜可驗＝`tests/doc-drift.bats` 37 支（DOC-DRIFT-001..037；該 US 交付當時值，第 6 輪後為 47 支）｜不可藏＝DOC-DRIFT-028/029/031 + `scripts/ci/mutants.tsv` DD-M3｜**端到端（本輪閉合殘餘，supervisor 實跑）**：`bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26` → rc=0、14 項檢查、6 項豁免（該 US 交付當時值）；**對抗測試**：把真實交付摘要狀態改成「✅ 完成」（權威表仍有 2 個 gap）→ rc=1 且報 `DRIFT D8 …: 對帳有未對上的項目（TMO-071 R1=⚠️ 部分實作, TMO-073 R2=⚠️ 部分實作）但交付狀態標為「✅ 完成」` → **硬門檻在真實路徑上確實攔得住假綠**（不只在 fixture 上成立）｜**mutant 守護（supervisor 實跑）**：`python3 scripts/ci/mutant-must-die.py --only DD-M1,DD-M2,DD-M3,DR-M1` → 4 baseline 全綠 + 4 支全死 | 機制三層（錨點＝根節點／對帳＝語意層／探針＝字面層）齊備並接 CI。**第 5 輪殘餘已閉合**：端到端證據由本輪「真實檔案 + 對抗測試」取得（原殘餘＝端到端證據待對帳者以可執行證據確認）。**本輪另修掉一個使「不可藏」失效的真實缺口**：`--from-date` 未驗證格式（比對用**字串**比較 → 傳入 `"bad-date"` 會讓**所有**交付摘要被跳過 → D8 硬門檻被一個 typo 靜默關掉 → 假綠）→ 已改 `datetime.strptime` 驗證 + **rc=2 fail-closed**，並補 DOC-DRIFT-036/037。**殘餘（已揭露的設計邊界，非本句條件缺口）**：①「用戶原話」唯讀靠**約定**無機械鎖（PRD-05 風險表已自陳）；②D8 的內嵌表 vs 權威表比對**只比 (R-ID, 狀態)**，不比「實作位置」「證據」欄 → 證據欄字面漂移**結構上不可見**（本輪實際發生：交付摘要 §3.1 漏列 DOC-DRIFT-034/035 → 已修，見 changelog v2.12） |
| R2 | 機制須以框架級能力設計（其他專案安裝後即可用），並先在 tree_monstor 本 repo 落地驗證，驗證有效後再推廣 | ✅ 已實作 | 實作放在 skill 內：`skills/dav-reconciler/scripts/check-doc-drift.py`；wrapper `scripts/ci/check-doc-drift.sh`（`exec python3 …`）；`lib/install/symlink.sh` `ensure_merged_skills_into()`（**per-skill 目錄層 symlink** → `scripts/` 子樹隨 skill 到位）；`skills/dav-reconciler/SKILL.md`「工具：文件漂移檢查」節（目標專案用法 + 白名單準備 + CI 範例）；本 repo 落地：`docs/req/`（3 份）、`docs/reconcile/`（3 份）、`docs/ci/drift-whitelist.txt`、`.github/workflows/ci.yml`「Verify no document drift (D1-D8)」 | DOC-DRIFT-008（腳本存在且可執行）、009（乾淨 fixture rc=0）、021（本 repo rc=0，**supervisor 實測 rc=0**）、022（CI 真的呼叫且無 `continue-on-error` / `\|\| true`）、034（CI 假綠守護反向自測）｜CI 步驟實讀：`run: bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26`（`--from-date` 顯式外露＝門檻放寬可見）｜CI 有 python3：`.github/workflows/ci.yml` `actions/setup-python@v5`（3.12，matrix 內、非條件式 → ubuntu + macos 兩腿都有）｜`--from-date` 非法值 fail-closed：**supervisor 實測** `--from-date bad-date` → rc=2、`2026-13-45` → rc=2（格式對但日期不存在亦擋）、`2026-01-01` → 正常運作 | 「框架級」條件由**安裝面原始碼**確認：`ensure_merged_skills_into()` 以 `ensure_merged_skill` 對**整個 skill 目錄**建 symlink → `scripts/check-doc-drift.py` 隨 skill 到目標專案，不需二次安裝。**殘餘（不屬本句驗收條件，已揭露）**：尚未在第二個專案實跑（交付摘要 §5 待辦 #4） |
| R3 | 需求錨點以 `docs/req/<US-ID>-requirement.md` 保存；「用戶原話」段為唯讀，後續階段只讀不改（澄清只能寫進「澄清後驗收句」並留變更歷史） | ✅ 已實作 | `docs/req/TMO-071-requirement.md`、`TMO-072-requirement.md`、`TMO-073-requirement.md`（4 段結構齊全、各含「## 用戶原話（唯讀）」/「## 澄清後驗收句」/「## 變更歷史」）；`skills/dav-planner/backlog-rules.md` §4.7（檔案契約 + R-ID 規則表「唯讀」「不可刪」「澄清只能寫進『澄清後驗收句』並在『變更歷史』留痕」＋ 5 項自我檢查清單）；`skills/dav-planner/SKILL.md` v2.7；`skills/dav-reconciler/reconcile-format.md` §5 | DOC-DRIFT-001（`docs/req/` 非空）、002（4 段齊全＋標題格式）、003（R-ID 連續唯一）、004（驗收句 R-ID 集合＝原話 R-ID 集合）｜三份錨點實讀：069=R1/R2/R3、070=R1/R2、071=R1/R2，且「用戶原話」與「澄清後驗收句」逐條一對一 | 「唯讀」**靠約定、無機械鎖**（PRD-05 風險表與交付摘要 §5 待辦 #5 已自陳）：D 系列無任何一條探針能偵測下游改寫「用戶原話」段。此為**已揭露的設計取捨**，非本句條件缺口；但 R-ID 化使「有沒有被改過」可被第三方比對，是目前的替代手段 |

## 結論

- 3 項已實作、0 項部分實作、0 項未實作。覆蓋率 **3/3**（100%）。
- **第 5 輪殘餘已閉合**（「端到端證據待對帳者以可執行證據確認」）：本輪取得**真實檔案**上的可執行證據 ——
  真實 repo `check-doc-drift.sh` rc=0；且**對抗測試**（假「✅ 完成」宣告）被 D8 以 rc=1 攔下並點名 2 個 R-ID。
- 對帳者備註: 本輪對帳者**沒有 shell 執行能力**，其判定以實作原始碼 + 探針斷言 + 真實資料檔逐項比對為據；
  上述「指令實際輸出」由 supervisor 補跑，兩者一致。另本輪對帳者與 supervisor 各抓到**不同**的既存漂移
  （前者：`docs/ac/TMO-073.html` 5 類 vs 8 類；後者：交付摘要 31 vs 35 條、漏列 DOC-DRIFT-034/035、
  待辦 #3 宣稱「二審 verdict 缺席」但 changelog 已有第 2 輪）→ 全部已修，紀錄見 changelog v2.12。
  **本輪機制本身也抓出兩個真實缺陷並已修**：RECON-007 解析器在 BSD grep 上壞掉（導致 5 支 mutant 守護長期失效）、
  `--from-date` 非法值會靜默關掉 D8 硬門檻（假綠）。
- 依 `reconcile-format.md` §7 硬門檻：本 US 全部 ✅ → 本 US 無阻擋項。
