# tree_monstor Glossary（術語表）

> **A-Z 排序** ｜ 統一用英文術語做 key（中文對照放喺術語欄括號）→ 排序零歧義
> **用途**：本專案各階段（規劃／設計／執行／驗收／交付）同用戶用**同一套詞語** → 減少理解落差
> **來源**：規劃階段提問整理 ｜ **規格**：`skills/dav-planner/backlog-rules.md` §4.9
> **點用**：新寫嘅文件／對話用**「術語」欄**（英文＋中文對照）；**「同義寫法」欄 = 同一件事嘅其他講法**
> （可以咁理解，但**唔會另立新詞**）；真正會指錯嘢嘅寫法見下面「勿用寫法」
> ⚠️ **兩欄互斥**：任何字串**只出現喺其中一欄**（出現喺「勿用寫法」就唔准再列做同義寫法）
> **維護**：新增／改名要 **A-Z 插入**（唔好 append 喺尾）；已存在就**合併更新**，唔好覆蓋重寫

| 術語 | 定義（一句，≤ 40 字）| 同義寫法（同一件事嘅其他講法）|
|------|----------------------|------------------------|
| AC（驗收條件）| 一條 US 嘅可驗收行為描述（Given-When-Then）| — |
| Backlog（待辦清單）| 本專案所有 US／DE／TECH／Spike 嘅總表 | 待辦、任務清單 |
| DE（Defect，缺陷）| Backlog 一類：已存在嘅錯誤行為要修 | Bug |
| Deliverable（交付摘要）| §2.5 產出嘅交付文件（含對話摘要＋對帳段）；檔名 deliverable.md | 交付文件 |
| DoD（完成定義）| 一條 US 嘅技術視角完成清單（checklist）| — |
| Drift（文件漂移）| 同一件事喺多份文件各說各話（漂移檢查 D1..D8）| 漂移、文件不一致 |
| Fail-closed（失敗即閉）| 檢查件數為 0／工具壞咗都當紅，唔准靜靜哋放行 | — |
| False green（假綠）| 檢查報綠但其實冇驗到嘢（守門失效嘅假象）| 假覆蓋、假通過 |
| FR（功能需求）| PRD 入面嘅功能需求條目（FR-xx）| — |
| Frontmatter（前置元資料）| SKILL.md 開頭嘅 `---` 區塊（name＋description）| YAML 頭、文件頭 |
| Gate（閘）| SOP 每階段嘅 fail-fast 屏障；唔通過唔准入下一階段 | — |
| INVEST（US 品質準則）| US 應滿足：獨立／可協商／有價值／可估／細／可測 | — |
| Line cap（行數上限）| skill 主檔 ≤50 行／子檔 ≤150 行／context ≤400 行（硬門檻）| 行數上限 |
| Local gate（本機等價閘）| 本機一次跑齊 CI 檢查步驟嘅閘（CI 已降級為偵測器）| — |
| Module（模組）| 開發切割單位；一個 Module 一個 sprint | — |
| Mutant（突變）| 故意改壞程式碼，用嚟證明探針真係咬得住 | — |
| Mutant table（突變表）| 逐支記錄「改邊個檔／改成乜／邊支探針要紅」嘅表（mutants.tsv）| — |
| Plain-text reference（純文字引用）| 唔用跨目錄連結或路徑引用，改用抽象詞講明出處 | — |
| PRD（產品需求文檔）| dav-designer 產出嘅模組級需求＋追溯矩陣＋原型 | 需求文檔 |
| Probe（探針）| 開發期埋入嘅自動化驗證；紅就帶修復建議 | — |
| Reconcile（對帳）| 逐條需求句對住實作比對；產出檔＝對帳表 | reconciliation |
| Requirement anchor（需求錨點）| 存用戶原話＋R-ID 驗收句嘅檔（全鏈路嘅根節點）；產出檔＝錨點檔 | 錨點 |
| Requirement maturity（需求成熟度）| 寫 US 前按涵蓋率／清晰度／可行性評分 | — |
| Second review（二審）| 規範改動涉代碼／契約／探針時必走獨立 Reviewer subagent 覆核（V03）；純 markdown 改動只自查行數上限 | Reviewer 二審 |
| Skill（技能）| 一個可獨立安裝嘅能力包（SKILL.md ＋ 支援檔）| — |
| SOP（標準作業流程）| 本 repo 定義嘅多階段流程（規劃→設計→執行→反省→交付）| 流程規範 |
| Spike（研究項）| Backlog 一類：先研究／驗證，唔直接交功能 | 技術研究 |
| Sprint（迭代批次）| 一個 Module 整體交付嘅批次 | sprint、批次 |
| Story Point（故事點）| 相對工作量單位（唔係工時）| SP |
| Support file（支援子檔）| SKILL.md 以外嘅 skill 內 .md（主檔連結指向佢）| 子檔、支援檔 |
| Task navigation（任務導航）| SKILL.md 嘅 4 段結構（TL;DR／觸發時機／流程／規則）| — |
| TECH（技術債）| Backlog 一類：唔係新功能亦唔係 bug 嘅技術工作 | tech debt |
| Trust mode（信任模式）| 用戶俾大目標＋deadline 後 Agent 自主跑執行段，中途唔問 | trust |
| US（User Story）| Backlog 一類：一個用戶可驗證嘅價值單位 | 用戶故事 |
| Whitelist（白名單）| 漂移檢查嘅逐筆豁免清單（每筆要有理由；drift-whitelist.txt）| — |

## 勿用寫法（會指錯嘢嘅，唔好喺新文件用）

| 概念 | 唔好用 | 點解會指錯 |
|------|--------|-----------|
| DE（Defect）| 錯誤 | 「錯誤」泛指任何唔對（連 exception 錯誤都係），唔等於一個要修嘅 Defect |
| DoD（完成定義）| 完成條件 | 會同 Gate 嘅「完成條件（閘）」撞 —— 一個係逐條 US 嘅清單，一個係階段門檻 |
| Gate（閘）| 關卡 | 「關卡」係通用嘅關卡／級別，唔係 fail-fast 屏障 |
| AC（驗收條件）| 驗收標準 | 同一個概念兩個正式名 → 一律用「驗收條件」 |
| Probe（探針）| 測試案例 / unit test | 探針要 fail-loud ＋ 帶修復建議；一般測試唔呢個要求 |
| Mutant（突變）| mutation | mutation 係「突變行為」，mutant 係「被改壞嗰個」—— 唔係同一樣嘢 |
| Local gate（本機等價閘）| 本機閘 / 等價閘 | 兩者都指唔到「同 CI 步驟等價」呢層意思 |
| Requirement maturity（需求成熟度）| 成熟度 | 「成熟度」泛指任何成熟度（產品、團隊⋯⋯）|
| Task navigation（任務導航）| 導航結構 | 冇講明係 SKILL.md 嘅結構 |

> 存量文件仲有以上寫法 → 屬「術語統一」嘅待辦（逐份改寫）；新文件唔可以用。
