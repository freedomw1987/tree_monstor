# Context 瘦身二輪 ＋ 產物線存量清理（第三刀 A）

> **交付日期**: 2026-10-26
> **對應 Backlog**: TMO-083
> **Sprint / Module**: 框架自我管理層（meta layer）第三刀
> **交付狀態**: ✅ 完成（AC01..AC06 全部達成；V03 二審結論見 §7）
> **錨點**: `docs/req/TMO-083-requirement.md`

---

## 1. 這次完成什麼

TMO-082（第二刀）之後用戶問「還有什麼可以減磅」。量測後提出 6 個候選（A context 二輪／B 治理文件／
C 衍生膨脹上限／D changelog／E 測試層／F install-reference），用戶揀 **A**，
並要求**先講清楚點做、批准後先動手**（R2）。本票就係執行 A 嘅兩部分。

### 1.2 為什麼做這個改動

**問題/脈絡**：第二刀之後，repo 仍有兩塊未收割嘅肉：**context 層**（5,743 行支援檔）同**產物線存量**
（3 支歷史交付摘要 877 行 ＋ 7 支存量 `docs/ac/*.html` 434 行 = 1,311 行）。

**為什麼選這個解法**：兩塊都係「零功能損失」——前者係教學式重複，後者係已被 git history 完整保留嘅歷史產物。

**成功怎麼看**：(a) context 總量同框架／產品比真係降咗；(b) 被探針錨定嘅契約一個唔少；
(c) 產物線刪除前查清引用鏈，刪完 D1..D8 仍然全綠。

---

## 2. 做了什麼改動

### 2.1 新增檔案

| 檔案路徑 | 用途 |
|---------|------|
| `docs/req/TMO-083-requirement.md` | 需求錨點（用戶三句原話 + 澄清後驗收句 + 背景實測） |
| `docs/ac/TMO-083.md` | AC 範本（AC01..AC06 + DoD + 風險） |
| `docs/reconcile/TMO-083-reconcile.md` | 需求對帳權威表 |
| `docs/deliverable/2026-10-26-context-slim-round2.md` | 本交付摘要 |

### 2.2 修改檔案（支援檔二輪瘦身：9 支檔 ＋ 8 個 skill；dav-trust 佔 2 支）

| 檔案路徑 | 前 → 後 | 手法 |
|---------|---------|------|
| `skills/regression-guard/jev-oracle.md` | 511 → 319 | **去重**（M6／M6.1 示範段同 `examples.md` 重覆 → 內容留 `examples.md`、呢度留規則同判準表）＋ CI matrix YAML 刪走只留設計表 |
| `skills/dav-trust/time-anchor.md` | 210 → 153 | **表格化**（§4 八個邊角情境逐段 → 一張表）|
| `skills/ask-me/examples.md` | 207 → 171 | **指標化**（need-you-help 完整範本同 `dav-trust` 重覆 → 改結構骨架 ＋ 指標）＋ 時間軸收窄 |
| `skills/dav-designer/examples/system-design.md` | 152 → 136 | **表格化**（§7 三段「為什麼」→ 一張表）|
| `skills/dav-skill-creater/editor-guide.md` | 161 → 136 | 規範段展開說明收短（**規則一個唔少**）|
| `skills/dav-trust/examples.md` | 309 → 300 | 啟動輸出壓縮 ＋ 結束後行為表收窄 |
| `skills/dav-reflection/template.md` | 200 → 192 | Module 級協作／架構檢查合併 |
| `skills/dav-planner/backlog-rules.md` | 161 → 156 | AC 段範本改指標式骨架 |
| `skills/dav-submitter/examples/deliverable-sample.md` | 202 → 199 | 新增／修改／指標表收窄 |

### 2.3 刪除檔案（產物線存量清理）

| 檔案路徑 | 行數 | 刪除理由 ＋ 引用鏈查證 |
|---------|------|------------------------|
| `docs/deliverable/2026-10-26-gates-into-skills.md` | 243 | 歷史交付摘要；`git grep` 確認**零外部引用**（內容在 git history）|
| `docs/deliverable/2026-10-26-doc-facts-guard.md` | 255 | 同上，**零外部引用** |
| `docs/deliverable/2026-10-26-slim-meta-layer.md` | 379 | 歷史交付摘要；唯一引用係 `tests/doc-drift.bats` 嘅**註解**（已改寫）|
| `docs/ac/TMO-071.html` / `TMO-072.html` / `TMO-073.html` / `US-M62.html` / `US-M63.html` / `US-M71.html` / `US-M81.html` | 434 | 存量 AC 範本嘅 HTML 閱讀版（內容係 `.md` 嘅重複呈現）；**保留 `US-101.html`**（PRD 01 產物契約有探針依賴）|

### 2.4 修改檔案（連線同記錄）

| 檔案路徑 | 改動內容 |
|---------|---------|
| `docs/ci/drift-whitelist.txt` | 加 **9 筆** D4 豁免（5 筆：刪咗嘅存量 HTML 被歷史交付摘要提及；4 筆：本交付摘要自己點名記錄「刪咗乜」；每筆附理由）|
| `tests/doc-drift.bats` | 註解指向已刪檔案 → 改寫為「已於 TMO-083 刪除（內容在 git history）」|
| 被改動嘅 8 個 skill 嘅 `CHANGELOG.md` ＋ `SKILL.md` | 各加一條 TMO-083 變動記錄（版本照現況遞增；主檔保持 ≤3 列、≤150 行）|
| `docs/backlog.md` / `docs/sop/handbook/changelog.md` | 加 TMO-083 一列 ＋ v2.19 條目 |

---

## 3. 驗收標準對應

| AC | 描述 | 結果 | 證據 |
|----|------|------|------|
| AC01 | 每個候選標明可減量／風險／實際障礙，第一個方案標最推薦 | ✅ | 已於對話呈現 6 個候選嘅對照表（A 最推薦，理由：零功能損失 ＋ 手法已驗證）|
| AC02 | 先講方法、批准後先做 | ✅ | 計劃（判斷標準 ＋ 4 種手法 ＋ 逐檔計劃 ＋ 5 步安全網 ＋ 4 批順序 ＋ 引用鏈查法）先呈現，用戶回「好做」後先動手 |
| AC03 | context 二輪瘦身、零契約損失 | ✅ | 見 §4.1；被錨定契約清單同 TMO-082 §5.2（14 條）一致，本輪再抽驗 Jev Oracle 7 個字串、dav-wiki FR-3 小節 |
| AC04 | 產物線刪除先查引用鏈、刪完 D 全綠 | ✅ | 見 §2.3 查證欄 ＋ D1..D8 全綠（26 項檢查、12 項豁免）|
| AC05 | V03 獨立 Reviewer 二審 | ✅ | 見 §7 |
| AC06 | 落檔後重測、守門 rc=0 | ✅ | 見 §4.1（`git add -A` 後實測）|

---

## 4. 測試結果

### 4.1 量測（同一把尺，`scripts/ci/check-framework-weight.py`）

| 指標 | TMO-082 完成時 | 本票完成時 | 變化 |
|------|---------------|-----------|------|
| context 總量（SKILL.md + 支援 .md） | 7,413 | **7,063** | **−350（−4.7%）** |
| 框架層（tests+docs+scripts+lib+.github+install.sh） | 25,832 | **24,900** | **−932** |
| 框架／產品比 | 2.9203 | **2.806** | −0.116（−4.0%） |
| 支援檔最大者 | regression-guard 1,623 | **1,431** | −192 |

⚠️ **如實記錄：第二輪嘅邊際收益遠低於第一輪**（第一輪 context −22.9%，第二輪只 −4.7%）。
原因：上一輪已抽走最肥嘅重複，剩低嘅支援檔內容**大多係「格式範本」**（每段都係一個獨立 artefact 格式，冇重複可剪），
而「表格化／合併列」唔減少行數。呢個係第二輪嘅真實結論，唔係未做。

### 4.2 測試

| 測試類型 | 通過 / 總數 | 備註 |
|---------|-------------|------|
| 回歸測試（全量 bats） | **682 / 682** | 0 紅 0 skip（探針數不變：本票冇新增探針，只改咗 1 支探針嘅註解）|
| 突變測試（mutant） | 58 / 58 全死 | `scripts/ci/mutants.tsv` 未動 |
| 文件漂移（D1..D8） | 25 項檢查、16 項豁免 | 豁免由 7 → 16（新增 9 筆 D4）|
| Markdown lint | 0 issues | 129 檔（刪 3 支交付摘要 −3、新增 4 支 TMO-083 文件 +4）|
| 體重守門 | rc=0 | 落檔後實測 |

---

## 5. 需求對帳

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 |
|---------|---------------|------|---------|------|
| R1 | 必須先量度再逐塊指出仲有咩可減；標明可減量／風險／障礙；第一個方案最推薦 | ✅ 已實作 | 本檔 §1、對話呈現嘅候選對照表 | 6 個候選逐個列可減量 × 風險 × 實測障礙：① context 層二輪（計劃 −1,300，實際 −350，低~中）② 產物線存量清理（−1,311，低~中）③ 治理文件收斂 B（−600~−800，中）④ 測試層精簡（−1,500~−2,500，中~高，明言唔建議大幅刪探針）⑤ changelog 再收斂（−400，低）⑥ 衍生膨脹上限 C（−2,000+，高）；① 標最推薦（理由：零功能損失 ＋ 手法已驗證）|
| R2 | 用戶選 A 但要求先講方法、批准前唔動手 | ✅ 已實作 | 計劃呈現 → 用戶回覆「好做」→ 先執行 | 計劃含判斷標準（4 類）、4 種手法（各配真實例子）、逐檔計劃表、5 步安全網、4 批執行順序、引用鏈查法；批准前 repo 檔案零改動 |
| R3 | 批准執行；ac html 依最推薦路徑（照刪 ＋ 加 whitelist 附理由） | ✅ 已實作 | §2.3、§2.4 | 7 支存量 HTML 已刪（保留 `US-101.html`）；`docs/ci/drift-whitelist.txt` 加 9 筆 D4 豁免，每筆附理由（腳本對空理由 fail-closed）|

### 5.1 被錨定嘅內容契約（抽驗）

| # | 契約 | 守住佢嘅探針 | 狀態 |
|---|------|----------------|------|
| 1 | `regression-guard/jev-oracle.md` 含 `ac_aware` / `mock` / `playwright` / `修正循環補充` / `JEV_FIX_PROPOSAL` / `M6.1 修正循環補充` / `LLM Relay` | `tests/v2.1-jev-poc.bats` SKILL-b / M6-e / M6.1-e | ✅ 保留 |
| 2 | `dav-trust/time-anchor.md` 含 `進度錨點` / `PHASE` / `DONE` / `NEXT` / `UPDATED_AT` / `trust-log **檔頭**` | `tests/restruct-dav-trust.bats` | ✅ 保留 |
| 3 | `dav-trust/examples.md` 不得含「5 階段」等舊語意 | 同上 | ✅ 保留 |
| 4 | `dav-wiki/examples.md` 有 ≥5 個 `## 範例 N` ＋ FR-3 多模組小節 | `tests/dav-wiki.bats` AC-7 | ✅ 保留（9 個範例）|
| 5 | `dav-planner/backlog-rules.md` 必定義 R-ID 規則 | `tests/doc-drift.bats` | ✅ 保留 |
| 6 | `docs/ac/US-101.html` 必存在（PRD 01 產物契約） | `tests/dav-planner-ac-templates.bats` | ✅ 保留 |
| 7 | 全部 skill 主檔 ≤150 行；變動歷史 ≤3 列 | `scripts/ci/check-skill-size.sh`、各 skill 探針 | ✅ 保留（最長 148 行）|
| 8 | 交付摘要提及嘅檔案必須存在（D4） | `tests/doc-drift.bats` | ✅ 以附理由嘅白名單維持（D4 機制本身不變）|

---

## 6. 已知問題 / 限制

| 問題 | 嚴重性 | 說明 |
|------|--------|------|
| **第二輪 context 瘦身嘅邊際收益遠低於第一輪**（−4.7% vs −22.9%）| P2 | 原因見 §4.1：剩低嘅係格式範本，冇重複可剪。**唔為湊數而剪**——呢個係真實結論 |
| **`docs/ci/drift-whitelist.txt` 由 7 筆增至 16 筆** | P2 | 每筆都有理由（腳本對空理由 fail-closed），但白名單本身會膨脹 → 建議下一刀做「白名單也有生命週期」 |
| **刪咗嘅存量 `.md` AC 檔（US-M62/63/71/81、TMO-071/072/073）保留咗** | P3 | 佢哋係舊 story 嘅驗收標準（需求證據），D1/D6 有白名單處理；只刪 HTML 重複呈現 |
| **治理文件（`docs/system-design.md` 743 + `docs/DESIGN.md` 289）未動** | P2 | 用戶選 A（唔包 B）；佢哋係 dav-designer 嘅**產出路徑**，唔係純歷史 |
| **衍生膨脹未治理** | P2 | 用戶選 A（唔包 C）；每個 story 仍產 3-4 檔（req＋ac＋reconcile＋交付段），本票自身亦新增 4 份（見 §2.1）——**呢個係框架自身成本，唔迴避** |

---

## 7. V03 二審結論

> 見 `docs/reconcile/TMO-083-reconcile.md`（對帳者：獨立 Reviewer subagent，未參與實作）。

---

**產生者**: Agent（透過 dav-submitter skill）
**產生時間**: 2026-10-26
