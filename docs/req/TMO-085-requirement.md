# TMO-085 需求錨點

> US: TMO-085 | 建立: 2026-10-27 | 來源: 用戶決策（測試體系減法 ＋ 探針 skill-local 化 ＋ 唔記歷史）

## 用戶原話（唯讀）

- R1: 「我想刪除這個項目中的大部分的test，只保留真的對python / shellscript 的測試」
- R2: 「也把文檔行數限制寫入 dav-skill-creater 規範中」
- R3: 「為了減上下文，所有Changelog 都不要了，相關的引用也要刪除」
- R4: 「skills 中的歷史變動都不用記，這個也要改dav-skill-creater」
- R5: 「我想把tests 中的測試有部份是因為skills 去做的，請把skill 相關的測試，放入skills自身的目錄下，
  例如與regression-guard skill 相關的測試就放在skills/regression-guard/tests 中；
  這樣我整個項目，改動指定skill時，才對個別skill 去做測試，不會浪費我時間等」

> ⚠️ 本票嘅用戶原話係**逐字引錄**（2026-10-27 對話）。

## 澄清後驗收句

- R1: 探針嘅「對象」係**可執行碼**（python 模組／shell 腳本）→ 保留；對象係**文件／規格內容**
  （markdown、AGENTS.md、backlog、skill 結構、gates.json、探針檔自身嘅命名）→ 刪。
  刪走嘅探針必須**連帶清埋**佢哋守嘅機械工具、mutant 列、CI／本機閘步驟（唔留死引用）。
- R2: 「文檔行數限制」必須寫入 `dav-skill-creater` 規範（`editor-guide.md` 章節 ＋ `SKILL.md` 規則行），
  並**取代**原本嘅機械守門（`check-framework-weight.py`／`check-skill-size.sh` ＋ 對應探針）。
- R3: 所有 `CHANGELOG.md`（13 個 skill ＋ `docs/sop/handbook/changelog.md`）必須刪除，
  **所有引用**（`SKILL.md` 指標、探針斷言、交叉引用「見 changelog」）一併刪。
- R4: skill 主檔**唔寫變動歷史**（冇 `## 變動歷史` 段、冇版本表）；`dav-skill-creater` 嘅
  「任務導航」由 5 段改 4 段，規範同 SKILL.md 一齊改。
- R5: skill 相關嘅探針必須搬到 `skills/<name>/tests/`；必須有**一條指令淨跑單一 skill**；
  搬完之後 repo 級同 skill 級兩條 CI 執行路徑都要仲喺度（唔准出現冇人跑嘅 orphan 探針）。

## 執行約束（repo 既有規則，唔屬驗收句）

- 刪／改 `tests/**/*.bats` 屬**條件放寬** → 依 `AGENTS.md` §1.5 **V03 走獨立 Reviewer 二審**。
- 新增守門機制必補 mutant；mutant 表只可增不減（刪探針 → 跟住刪對應列，數字要同步）。
- 探針名全 ASCII；fail-fast 慣例。
- `bash scripts/check-all.sh`（本機閘）必須全綠。

## 變更歷史

| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-10-27 | 初版 | 用戶 5 條決策逐字整理成錨點 |
