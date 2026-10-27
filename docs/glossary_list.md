# tree_monstor Glossary（術語表）

> **A-Z 排序** ｜ 統一用英文術語做 key（中文對照放喺術語欄括號）→ 排序零歧義
> **用途**：本專案各階段（規劃／設計／執行／驗收／交付）同用戶用**同一套詞語** → 減少理解落差
> **來源**：規劃階段提問整理 ｜ **規格**：`skills/dav-planner/backlog-rules.md` §4.9
> **點用**：新寫嘅文件／對話用**「術語」欄**（英文＋中文對照）；**「別名」欄係唔應該再用嘅其他講法**
> **維護**：新增／改名要 **A-Z 插入**（唔好 append 喺尾）；已存在就**合併更新**，唔好覆蓋重寫

| 術語 | 定義（一句，≤ 40 字）| 別名（唔應該再用嘅其他講法）|
|------|----------------------|------------------------|
| AC（驗收條件）| 一條 US 嘅可驗收行為描述（Given-When-Then）| 驗收標準 |
| Backlog（待辦清單）| 本專案所有 US／DE／TECH／Spike 嘅總表 | 待辦、任務清單 |
| DE（Defect，缺陷）| Backlog 一類：已存在嘅錯誤行為要修 | Bug、錯誤 |
| Deliverable（交付摘要）| §2.5 產出嘅交付文件（含對話摘要＋對帳段）| 交付文件、deliverable.md |
| DoD（完成定義）| 一條 US 嘅技術視角完成清單（checklist）| 完成條件 |
| Drift（文件漂移）| 同一件事喺多份文件各說各話（漂移檢查 D1..D8）| 漂移、文件不一致 |
| Fail-closed（失敗即閉）| 檢查件數為 0／工具壞咗都當紅，唔准靜靜哋放行 | — |
| False green（假綠）| 檢查報綠但其實冇驗到嘢（守門失效嘅假象）| 假覆蓋、假通過 |
| FR（功能需求）| PRD 入面嘅功能需求條目（FR-xx）| — |
| Frontmatter（前置元資料）| SKILL.md 開頭嘅 `---` 區塊（name＋description）| YAML 頭、文件頭 |
| Gate（閘）| SOP 每階段嘅 fail-fast 屏障；唔通過唔准入下一階段 | — |
| INVEST（US 品質準則）| US 應滿足：獨立／可協商／有價值／可估／細／可測 | — |
| Local gate（本機等價閘）| 本機一次跑齊 CI 檢查步驟嘅閘（CI 已降級為偵測器）| — |
| Module（模組）| 開發切割單位；一個 Module 一個 sprint | — |
| Mutant（突變）| 故意改壞程式碼，用嚟證明探針真係咬得住 | — |
| Mutant table（突變表）| 逐支記錄「改邊個檔／改成乜／邊支探針要紅」嘅表（mutants.tsv）| — |
| Plain-text reference（純文字引用）| 唔用跨目錄連結或路徑引用，改用抽象詞講明出處 | — |
| PRD（產品需求文檔）| dav-designer 產出嘅模組級需求＋追溯矩陣＋原型 | 需求文檔 |
| Probe（探針）| 開發期埋入嘅自動化驗證；紅就帶修復建議 | unit test、test case |
| Ratchet（棘輪上限）| 只可下唔可上嘅上限（baseline ＋ tolerance）| 棘輪、只減不增 |
| Reconcile（對帳）| 逐條需求句對住實作比對，產出對帳表 | 對帳表、reconciliation |
| Requirement anchor（需求錨點）| 存用戶原話＋R-ID 驗收句嘅檔，全鏈路嘅根節點 | 錨點、錨點檔 |
| Requirement maturity（需求成熟度）| 寫 US 前按涵蓋率／清晰度／可行性評分 | 成熟度 |
| Second review（二審）| 規範改動必走獨立 Reviewer subagent 覆核（V03）| Reviewer 二審 |
| Skill（技能）| 一個可獨立安裝嘅能力包（SKILL.md ＋ 支援檔）| — |
| SOP（標準作業流程）| 本 repo 定義嘅多階段流程（規劃→設計→執行→反省→交付）| 流程規範 |
| Spike（研究項）| Backlog 一類：先研究／驗證，唔直接交功能 | 技術研究 |
| Sprint（迭代批次）| 一個 Module 整體交付嘅批次 | sprint、批次 |
| Story Point（故事點）| 相對工作量單位（唔係工時）| SP |
| Support file（支援子檔）| SKILL.md 以外嘅 skill 內 .md（主檔連結指向佢）| 子檔、支援檔 |
| Task navigation（任務導航）| SKILL.md 嘅 4 段結構（TL;DR／觸發時機／流程／規則）| 導航結構 |
| TECH（技術債）| Backlog 一類：唔係新功能亦唔係 bug 嘅技術工作 | tech debt |
| Trust mode（信任模式）| 用戶俾大目標＋deadline 後 Agent 自主跑執行段，中途唔問 | trust |
| US（User Story）| Backlog 一類：一個用戶可驗證嘅價值單位 | 用戶故事 |
| Whitelist（白名單）| 漂移檢查嘅逐筆豁免清單（每筆要有理由；drift-whitelist.txt）| — |
