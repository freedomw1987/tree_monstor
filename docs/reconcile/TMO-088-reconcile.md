# TMO-088 需求對帳表

> 對帳者: 獨立 Reviewer subagent（V03 二審，**未參與實作**）| 對帳時間: 2026-10-27
> 錨點: docs/req/TMO-088-requirement.md
> 覆蓋率: **1/1**
> 對帳者獨立性: 非降級路徑（未參與本次實作）

## 對帳表

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | 本 repo 自己要有一份符合 §4.9 規格嘅 `docs/glossary_list.md`（A-Z／領域專屬／每條一句 ≤40 字／含別名欄），且 `README.md` 同 `CONTRIBUTING.md` 指向它並講明統一用法 | ✅ 已實作 | `docs/glossary_list.md`（**35 條**）；`README.md`；`CONTRIBUTING.md`；規格微調：`skills/dav-planner/backlog-rules.md` §4.9 | ① A-Z：統一用英文術語做 key、中文對照放術語欄括號 → 排序零歧義（覆核逐行核對 ✓）② 領域專屬：只收 tree_monstor 框架術語（探針／mutant／閘／模組／需求錨點／對帳⋯⋯），無通用詞 ③ 簡潔：35 條全部一句、≤40 字（覆核：最長約 30 字）④ 獨立頁：專案層一份、全專案共用；`README.md` ＋ `CONTRIBUTING.md` 各有「用術語欄／唔用別名欄／新術語 A-Z 插入」三條規則 | ⚠️ **套用自己時捉到規格本身一個語意漏洞並已修**（見下） |

## 二審第 1 輪（獨立 Reviewer）→ 修 → 覆核 `approve`

**第 1 輪 verdict：`request-changes`**

| 二審發現 | 處置 | 證據 |
|---|---|---|
| **P1** 別名欄重覆術語欄（18/35 行）→「統一用術語欄」會禁咗 repo 主流叫法（探針／閘／模組／白名單）| **改咗規格語意**：「術語欄 = 應該用嘅（英文 key ＋ 中文對照）」、「別名欄 = 唔應該再用嘅其他講法」，並加註「唔好將術語本身嘅中文對照擺落別名欄」；表內 18 條重覆嘅中文對照移回術語欄 | `skills/dav-planner/backlog-rules.md` §4.9（格式表 ＋ 註 ＋ 排序寫法）＋ `docs/glossary_list.md` 表頭「點用」 |
| **P2** README 缺三項規則 ＋ 自己用咗被禁嘅別名寫法 | README ＋ CONTRIBUTING 統一寫成三條規則，並刪走「（探針、mutant、閘、模組）」呢類括號清單 | `README.md` ＋ `CONTRIBUTING.md` |
| **P2** Support file 用「指標」／Frontmatter 用簡體「区塊」／Mutant table 別名填檔名而 Whitelist 冇 | 改成「連結」／「區塊」；檔名統一入**定義欄**（Mutant table → mutants.tsv、Whitelist → drift-whitelist.txt），別名欄只留同義講法 | `docs/glossary_list.md` |
| **P2（覆核觀察）** Mutant 別名「突變體」、Local gate 別名「本機閘」仍係術語本身變體 | 已清走（Mutant／Local gate／Gate／Whitelist 別名欄改為「—」；Probe 改為 unit test、test case） | `docs/glossary_list.md` |

**第 2 輪覆核 verdict：`approve`**（規格語意已明、別名欄重覆 0 處、兩檔規則齊、用字已修、檔名喺定義欄、主檔 141 行／表 35 條）

## 規格微調（套用自己時發現，已記入 TMO-087 對帳表）

| 問題 | 處置 |
|---|---|
| 「別名（統一用『術語』欄）」語意含糊 → 會禁咗專案最常用嘅中文 | §4.9 改成「術語欄 = 應該用嘅；別名欄 = 唔應該再用嘅其他講法」＋「唔好將術語本身嘅中文對照擺落別名欄」 |
| 「中文術語按拼音（或統一用英文術語為主）」兩種做法混用 → 排序有歧義 | 改成「或統一用**英文術語做 key、中文對照放術語欄括號**」 |

## 實作者實跑補證（reviewer 冇 shell 權限）

`bash scripts/check-all.sh` → **11 步全綠**；`bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26` → OK: 34 項檢查完成，40 項豁免；
markdownlint → 0 issues；自查：A-Z ✓／35 條全部 ≤40 字 ✓／三欄 ✓。

## 結論

- **1 項已實作、0 項部分實作、0 項未實作。覆蓋率 1/1（100%）。**
- 本票屬**規範改動**（產出物 ＋ 規格語意微調 ＋ 跨文件接線）→ 已依 `AGENTS.md` §1.5 V03 走獨立二審
  （第 1 輪 `request-changes` → 全修 → 覆核 `approve`）。
- ⚠️ 已記錄嘅影響：①「術語欄／別名欄」語意改變 → TMO-087 §4.9 規格同步更新（隨本票入帳）
  ②**存量文件嘅舊寫法未逐份改寫**（本票只做「指向 ＋ 規則」）→ 留待後續票，避免一次過大 diff
  ③ 觀察到一個 flaky：`tests/install-qoder.bats` QODER-30 喺某次全套跑入面紅、單跑同其餘 7 次閘都綠
  → 暫記為待觀察（未重現，未當成真 bug 修）
