# TMO-091 需求對帳表

> 對帳者: 獨立 Reviewer subagent（V03 二審，**未參與實作**）| 對帳時間: 2026-10-27
> 錨點: docs/req/TMO-091-requirement.md
> 覆蓋率: **6/6**
> 對帳者獨立性: 非降級路徑（未參與本次實作）

## 對帳表

| 需求 ID | 需求句（摘要）| 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | `backlog.md` 只保留未完成；完成嘅 row 移出 ＋ 規範寫入會改 backlog 嘅 skill | ✅ 已實作 | `docs/backlog.md`（88 → 3 列：TMO-054 ⏸️／TMO-089 doing／TMO-091 doing）；`skills/dav-planner/backlog-rules.md` §4.5；`skills/dav-submitter/SKILL.md` Step 5 ＋ 規則表 | 兩邊都有「只留未完成」規範（＋ 記錄去交付摘要／需求錨點／git history 嘅去處）| ⚠️ 欄位解析要小心：row 內含豎線字元 → 狀態欄用 cells[-3]（唔係第 5 欄）|
| R2 | `docs/` 要有「保留 vs 歸檔」判斷並實際執行 | ✅ 已實作 | 保留：`docs/sop/`（SOP）、`docs/ci/`、`docs/cleanup/`、`docs/glossary_list.md`、`docs/DESIGN.md`、`docs/system-design.md`、`docs/install-reference.md`、`docs/need-you-help.md`、`docs/trust-log.md`、`docs/ac/README.md`（範本）｜歸檔：完成 US 嘅 ac／req／reconcile、`docs/prd/`、`docs/deliverable/` 只留最近一次 | 現況：ac 2 ＋README、req 5、reconcile 5、deliverable 1、prd 0（原本 19／15／14／3／2）→ **約減 60%**；doc-drift 仍然 OK（D1/D6/D7/D8 一致 ＋ D4 白名單補已歸檔檔案）| ⚠️ **保留最近一次交付嘅完整引用鏈**（TMO-071/072/073 錨點 ＋ 對帳表）：D8 硬門檻要求窗內有交付摘要可對帳，唔保留 = fail-closed 紅 |
| R3 | PoC 依賴嘅 AC fixture 搬入 skill 內（skill 自足）| ✅ 已實作 | `skills/dav-jev-oracle/PoC/fixtures/ac/`（US-101／M62／M63／M71／M81 5 個；2026-10-28 TMO-092 拆分後路徑，拆分前為 `skills/dav-developer/PoC/fixtures/ac/`）；journey `source:` ＋ PoC 程式 ＋ 探針 ＋ cache fixture 改名 | skill 內 `docs/ac/US-` **0 命中**（自足）；cache fixture 改名（cache key 含 source 路徑 → 改名即命中）→ 離線探針 133 條全綠 | ⚠️ 目標專案裝咗 `dav-jev-oracle` 都跑得 PoC（之前靠 repo 層 `docs/ac/` → 唔自足）|
| R6 | 開發 loop 用 `--changed`（快 6-10 倍）、push 前跑全量；呢個分工要寫入 repo 規則 | ✅ 已實作 | `CONTRIBUTING.md`「完成條件（閘）」段 ＋ `docs/sop/handbook/2.3-execution.md`「本機閘點跑」段 ＋ `scripts/check-all.sh` 頭註解 | 三處都寫明「開發 loop 用 --changed／push 前全量」＋「`--changed` 唔等於全量閘通過，交付要講明驗過範圍」| |
| R5 | 「交付摘要只留最近一次」嘅做法要**寫入 skill**（唔可以只做一次）| ✅ 已實作 | `skills/dav-submitter/retention.md`（新子檔）＋ `SKILL.md` Step 3／Step 5／規則表；`dav-planner` §4.5 | retention.md 收錄：交付摘要只留最近一次（舊嘅靠 git history，刪之前先 commit）＋嗰次交付引用鏈要留低（D8 硬門檻靠佢）＋ `docs/` 保留 vs 歸檔清單 ＋ 執行次序 | 主檔 `dav-submitter/SKILL.md` 壓到 **144 行**（≤150 硬上限：v2.2 Module 級交付段壓成 6 行，詳細內容留 `./module-delivery.md`）|
| R4 | `check-all.sh` 加 `--changed`：只跑受改動影響嘅探針 ＋ 收窄 mutant | ✅ 已實作 | `scripts/check-all.sh`（`--changed`／`--changed=<base>`）| 判定：skill 內改動 → 跑嗰個 skill 嘅 tests/；`tests/*.bats` 改動 → 跑嗰支；`scripts/ lib/ install.sh` 改動 → 跑晒 repo 級（保守）；mdlint／drift 按 .md 改動觸發；mutant 只跑**目標檔被改過**嘅列 | ⚠️ fail-closed 已補：base 唔存在 → rc=2；改動清單空 → rc=1（唔准靜靜哋全 SKIP → 假綠）|

## 結論

- **6 項已實作、0 項部分實作、0 項未實作。覆蓋率 6/6（100%）。**
- 本票屬**規範改動**（backlog 保留規則 ＋ docs 結構 ＋ 閘行為）→ 已依 `AGENTS.md` §1.5 V03 走獨立二審
  （第 1 輪 `request-changes` 3 P1 → 全修 → 覆核 `approve`）。
- 閘：`bash scripts/check-all.sh` → 11 步全綠；`--changed` 實測：改動範圍小時 ~20-40 秒（全量 4 分 10 秒）。
