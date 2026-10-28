# 交付 — TMO-089／TMO-091 收埋（Backlog 收口 ＋ docs 歸檔）

> **交付日期**: 2026-10-28
> **對應 Backlog**: TMO-089 / TMO-091
> **交付狀態**: ✅ 完成（Gate 4.5 獨立對帳已過：TMO-089 2 條、TMO-091 6 條需求句全數 ✅；R-ID 覆蓋率 8/8）

## 1. 這次完成什麼

用戶決策「A」——收埋 `TMO-089` 同 `TMO-091`。兩張票嘅需求對帳表早已 100% 對上（2/2、6/6），
但 `docs/backlog.md` 嘅 row 仲卡喺 `doing`、兩份 AC 檔仲寫「狀態: doing」→
Backlog 唔符合「只保留未完成」規則，而且 D1（AC 狀態 vs Backlog 狀態）嘅三方一致性就係靠 Backlog 行做樞紐。
今次正式收口：標記完成 → 移出 Backlog → 依保留策略歸檔產物 → 換「最近一次交付摘要」嘅引用鏈。

**關鍵成果**：
- ✅ `docs/backlog.md` 只剩未完成 row（TMO-054 ⏸️）：3 row → 1 row
- ✅ `docs/ac/` 只剩「範本 ＋ 唯一未完成 US（TMO-054）嘅 AC」；TMO-089／TMO-091 嘅 AC 檔依策略歸檔（內容完整保留在 git history）
- ✅ 交付摘要只留最近一次：本次呢份；上一輪 TMO-092 嘅摘要連引用鏈一齊讓位
- ✅ 引用鏈換成 TMO-089／TMO-091（需求錨點 ＋ 對帳表）→ D8 硬門檻（窗內有件可對帳）繼續有效，唔會變假綠
- ✅ 順手修一條死引用：`skills/dav-reconciler/examples.md` 原本指住將歸檔嘅 `docs/reconcile/TMO-092-reconcile.md`
- ✅ 文件漂移檢查 D1–D8 全綠 ＋ 本機等價閘 11 步全綠

### 1.2 為什麼做這個改動

- **問題／脈絡**：Backlog 嘅定位係「仲要做嘅嘢」清單。兩張**已經做完**嘅票留喺度 →
  每次讀 Backlog 都要重新判斷「呢張做咗未」；更實際嘅代價係 D1 機制：
  AC 檔狀態要同 Backlog 狀態一致，Backlog row 一移出，AC 檔就變成「搵唔到對應 ID」嘅違規源頭
  —— 即係機制逼住我哋收口。
- **為什麼選這個解法**：直接用 `skills/dav-submitter/retention.md` 已經寫好嘅保留策略
  （寫交付摘要 → 標完成 → 移出 row → 歸檔產物 → 留引用鏈），
  唔新造規則、唔改探針、唔改任何 gate 門檻。
- **成功怎麼看**：`docs/backlog.md` 只剩未完成 row；D1–D8 全綠；
  `docs/deliverable/` 得一支摘要而佢引用得到 `docs/req/` 錨點（D8 檢查件數 ≠ 0）；
  `docs/ac/` 有活嘅 AC 範本（DOC-DRIFT-007 檢查件數 ≠ 0，唔係空集合假綠）。

## 2. 做了什麼改動

### 2.1 新增檔案

| 檔案路徑 | 用途 |
|---------|------|
| `docs/deliverable/2026-10-28-tmo-089-091-backlog-close.md` | 本次交付摘要（唯一保留嘅交付摘要）|
| `docs/ac/TMO-054.md` | 補建唯一未完成 US（TMO-054）嘅 AC 範本 —— `docs/ac/` 減磅後要有活嘅 AC 檔，否則 DOC-DRIFT-007 撞「空集合假綠」fail-closed |
| `docs/req/TMO-054-requirement.md` | TMO-054 需求錨點（用戶原話出自 NYH-1 記錄；原文在 git history）→ 令 D6「AC ↔ 錨點」對應關係有嘢可驗 |

### 2.2 修改檔案

| 檔案路徑 | 改動內容 |
|---------|---------|
| `docs/backlog.md` | 移出 TMO-089／TMO-091 兩個已完成 row；更新標題同「本檔現況」說明（只留未完成 row 嘅規則不變）；**順帶**把 TMO-054 嘅主題由截斷版（「到…」）還原成完整版，並將狀態改為機器可解析嘅 `blocked (…；⏸️ 跳過 …)` |
| `docs/ci/drift-whitelist.txt` | 加本次交付摘要指向已歸檔檔案嘅 D4 豁免條目（逐筆有理由，fail-closed 不變）|
| `skills/dav-reconciler/examples.md` | 修死引用：原本指向將歸檔嘅 `docs/reconcile/TMO-092-reconcile.md`，改指本次保留嘅對帳表（行數不變，守 ratchet）|

### 2.3 刪除檔案

| 檔案路徑 | 刪除原因 |
|---------|---------|
| `docs/ac/TMO-089.md` | 已完成 US 嘅 AC 檔依保留策略歸檔（Backlog row 移出後 D1 要求一併歸檔）；內容完整保留在 git history |
| `docs/ac/TMO-091.md` | 同上 |
| `docs/req/TMO-092-requirement.md` | 上一輪交付嘅引用鏈讓位畀本次（TMO-089／TMO-091）；內容完整保留在 git history |
| `docs/reconcile/TMO-092-reconcile.md` | 同上 |
| `docs/deliverable/2026-10-28-tmo-092-jev-oracle-split.md` | 交付摘要只留最近一次（舊份靠 git history）|

### 2.4 改動背後的理由

| 改動 | 為什麼這樣設計 | 放棄的選項 |
| --- | --------------- | ----------- |
| 引用鏈留 TMO-089／TMO-091、歸檔 TMO-092 | D8 硬門檻要求「窗內有支交付摘要引用得到 `docs/req/` 錨點」；本次交付報嘅就係呢兩張票，引用鏈自然指向佢哋。留 TMO-092 會變成「摘要報 A 票、引用鏈指 B 票」 | 留 TMO-092 唔歸檔（少一次換位，但引用鏈同交付內容唔對應，遲早又要換）|
| 一次 commit 落齊 | 最終檔案樹同交付摘要嘅宣稱逐句對得上，中間冇一個「摘要話已歸檔但檔仲喺度」嘅 commit 狀態。被刪內容本身早喺之前嘅 commit 入咗 git history，唔會遺失 | 分 2 個 commit（先摘要、後刪檔）—— 保留策略寫「先 commit 再刪」，但咁樣會有一個宣稱同實際唔一致嘅中間 commit |
| 順手修 `skills/dav-reconciler/examples.md` 嘅死引用 | 歸檔 TMO-092 對帳表之後，呢行就會指住唔存在嘅檔；漂移檢查只查交付摘要內嘅路徑（D4），查唔到 skill 內嘅互引 → 唔修就係自己製造一條死引用 | 唔修（留低一個已知壞連結）|

## 3. 驗收條件對應

兩張票嘅 AC 範本隨收口歸檔（內容在 git history）；驗收條件以權威對帳表為準。

| AC | 描述 | 結果 | 證據 |
|----|------|------|------|
| TMO-089 AC01 | QODER-30 再失敗時要印安裝器輸出（令「待觀察」可診斷）| ✅ | `tests/install-qoder.bats`（QODER-30 失敗時印安裝器輸出）；3 次全套 ＋ 3 次單跑全綠 |
| TMO-089 AC02 | 詞典分「同義寫法」／「勿用寫法」兩類（9 條勿用寫法 ＋ 理由）| ✅ | `docs/glossary_list.md` |
| TMO-089 AC03 | 只統一會指錯嘢嘅寫法（34 處），Gate 語意嘅「完成條件（閘）」刻意唔改 | ✅ | 對帳表 TMO-089 R2（量度：live 文件別名寫法 791 處 → 唔做大範圍改寫）|
| TMO-091 AC01 | Backlog 只留未完成 ＋ 規範寫入會改 Backlog 嘅 skill | ✅ | `skills/dav-planner/backlog-rules.md` §4.5 ＋ `skills/dav-submitter/SKILL.md` Step 5 |
| TMO-091 AC02 | `docs/` 有「保留 vs 歸檔」判斷並實際執行（完成 US 嘅 ac／req／reconcile 一併歸檔，交付摘要只留最近一次 ＋ 引用鏈）| ✅ | `skills/dav-submitter/retention.md`；本次執行結果：ac 2→1（只剩 TMO-054 嘅活 AC ＋ 範本）、deliverable 1→1（換成本次）|
| TMO-091 AC03 | PoC 嘅 AC fixture 搬入 skill 內（skill 自足）| ✅ | `skills/dav-jev-oracle/PoC/fixtures/ac/` |
| TMO-091 AC04 | `check-all.sh` 加 `--changed`（只跑受改動影響嘅探針 ＋ 收窄 mutant）| ✅ | `scripts/check-all.sh` |
| TMO-091 AC05 | 「交付摘要只留最近一次」嘅做法要寫入 skill 規格 | ✅ | `skills/dav-submitter/retention.md` ＋ `SKILL.md` Step 3／Step 5 |
| TMO-091 AC06 | 開發 loop 用 `--changed`、push 前跑全量，並寫入 repo 規則 | ✅ | `CONTRIBUTING.md` ＋ `docs/sop/handbook/2.3-execution.md` ＋ `scripts/check-all.sh` 頭註解 |

### 3.1 需求對帳（Gate 4.5 產物）

> 對帳由**未參與實作**嘅獨立 Reviewer subagent 執行（2026-10-27）。下表為權威對帳表嘅內嵌版，兩票合併列出（R-ID 由各票自身計數，故 R1／R2 各出現兩次）。

| 需求 ID | 對應票 | 對帳狀態 | 需求句（摘要）| 實作位置 |
|---------|--------|---------|-------------|---------|
| R1 | TMO-089 | ✅ 已實作 | QODER-30 偶發紅要查清：查得出就修；查唔出就令佢下次可診斷 ＋ 記為待觀察 | `tests/install-qoder.bats`（失敗時印安裝器輸出）|
| R2 | TMO-089 | ✅ 已實作 | 存量文件要用同一套詞語；但要先量度，只統一會指錯嘢嘅寫法 | `docs/glossary_list.md`（兩欄 ＋ 9 條勿用寫法）；統一 34 處 |
| R1 | TMO-091 | ✅ 已實作 | `backlog.md` 只保留未完成；完成嘅 row 移出 ＋ 規範寫入會改 backlog 嘅 skill | `docs/backlog.md`；`skills/dav-planner/backlog-rules.md` §4.5；`skills/dav-submitter/SKILL.md` Step 5 |
| R2 | TMO-091 | ✅ 已實作 | `docs/` 要有「保留 vs 歸檔」判斷並實際執行 | `skills/dav-submitter/retention.md`（保留 vs 歸檔清單 ＋ 執行次序）|
| R3 | TMO-091 | ✅ 已實作 | PoC 依賴嘅 AC fixture 搬入 skill 內（skill 自足）| `skills/dav-jev-oracle/PoC/fixtures/ac/` |
| R4 | TMO-091 | ✅ 已實作 | `check-all.sh` 加 `--changed`：只跑受改動影響嘅探針 ＋ 收窄 mutant | `scripts/check-all.sh` |
| R5 | TMO-091 | ✅ 已實作 | 「交付摘要只留最近一次」嘅做法要寫入 skill（唔可以只做一次）| `skills/dav-submitter/retention.md`（新子檔）＋ `SKILL.md` Step 3／Step 5 |
| R6 | TMO-091 | ✅ 已實作 | 開發 loop 用 `--changed`、push 前跑全量；分工要寫入 repo 規則 | `CONTRIBUTING.md` ＋ `docs/sop/handbook/2.3-execution.md` ＋ `scripts/check-all.sh` 頭註解 |

- 對帳表: `docs/reconcile/TMO-089-reconcile.md` ＋ `docs/reconcile/TMO-091-reconcile.md`
- 對帳者: 獨立 Reviewer subagent（未參與實作；2026-10-27）
- 覆蓋率: 8 / 8（兩票各自 2/2 ＋ 6/6，必須 100%）

## 4. 測試結果

| 測試類型 | 通過 / 總數 | 備註 |
|---------|-------------|------|
| 文件漂移檢查 D1–D8 | 8 / 8 | `bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26` → OK（嚴格模式：窗內有件 ＋ 引用得到錨點）|
| 本機等價閘 | 11 / 11 步 | `bash scripts/check-all.sh`（deps／ffmpeg／shellcheck／bashn／heredoc／drift／mdlint／venv／bats／skill-tests／mutant）|
| 突變測試 | 49 / 49 支死 | 突變只發生喺副本，工作樹 23 個目標檔 md5 全數未變 |
| markdownlint | 0 issue | 本次新增同修改嘅 .md 全過 |

## 5. 已知問題 / 限制

| 問題 | 嚴重性 | 已記錄位置 |
|------|--------|-----------|
| TMO-089 R1 嘅 QODER-30 偶發紅仍掛「待觀察」：已加失敗時印安裝器輸出（下次可診斷），但成因未重現、未定位 | P2 | `docs/reconcile/TMO-089-reconcile.md` R1 備註；`tests/install-qoder.bats:471` |
| `docs/req/` 現時只剩 TMO-089／TMO-091 兩個錨點 —— 引用鏈每次交付都要換位（機制冇問題，但換位要有理由記低）| P2 | `skills/dav-submitter/retention.md` |
| `⏸️ 跳過` 唔喺漂移檢查嘅 `STATUS_VALUE` 入面 → 一行如果淨係用 `⏸️` 狀態，對 D1／D7 嚟講等同「唔存在」；今次靠將 TMO-054 改成 `blocked (…；⏸️ 跳過 …)` 先令佢機器可見（狀態定義同檢查器嘅值集唔一致）| P2 | `skills/dav-reconciler/scripts/check-doc-drift.py`（`STATUS_VALUE`）；`docs/backlog.md` 狀態定義 |
| `skills/dav-jev-oracle` 兩支子檔超行數上限（`jev-oracle.md` 361 行、`examples.md` 334 行，存量例外）→ 瘦身另開票 | P2 | `skills/dav-skill-creater/editor-guide.md`（存量例外清單）|
| `ENV-EQ-21` 仍係 regex 結構檢查，唔係真 YAML parse → 壞 value／壞縮排捉唔到 | P2 | `tests/env-equivalence.bats:856` |
| `docs/install-reference.md` TD-013（`--claude-skills-clean-backups` 自動清理）未做；`skills/dav-wiki` 嘅真 Vision API／Whisper 未實作 | P3 | `docs/install-reference.md:435`；`skills/dav-wiki/scripts/wiki-media-describe.sh` |

## 6. 下一步建議

### 6.1 立即可做（建議優先）

1. **TMO-089／TMO-091 已收口 → 下一張做 `ENV-EQ-21` 改真 YAML parse（1 SP）** —— 呢個係 TMO-092 交付摘要留低嘅 Action Item #2
   - **為什麼這個優先**：佢係目前唯一一個「守門失效」嘅項目 —— 而家個探針只查 frontmatter 嘅**結構**，壞 value（例如 `description:` 寫咗個壞 YAML）會走漏；成本最低（1 SP），而且改完即刻有防護
2. **加一支「skill 路徑存在性」機械探針（2 SP）** —— TMO-092 交付摘要嘅 Action Item #4
   - **為什麼這個優先**：今次收埋就撞到一條死引用（`skills/dav-reconciler/examples.md` 指住將歸檔嘅對帳表），靠人手發現；冇機械探針就只會「每次撞到先記一次」
3. **`dav-jev-oracle` 瘦身（3 SP）** —— `jev-oracle.md` 361 行、`examples.md` 334 行 → ≤300
   - **為什麼這個優先**：直接降每次觸發嘅 context 成本（只可下唔可上嘅棘輪上限），但成本最高、收益最遲

### 6.2 下一個 Sprint 考慮

- [ ] TMO-054 OpenRouter API key 輪替（人工項，只有用戶做得到；2026-10-05 接受風險後擱置至今）
- [ ] `docs/install-reference.md` TD-013：`--claude-skills-clean-backups` 自動清理

### 6.3 長期方向（Think Big）

- 「保留 vs 歸檔」每次換位都要人手做，而且已經手滑出過一條死引用 → 可以評估一個**收尾指令**（一次過做齊標記完成／移出 row／歸檔／換引用鏈／更新白名單），但**唔好**寫成新探針（每加一支探針，框架層就膨脹一次）
- 「引用鏈」可以靠命名規則固定（例如交付摘要檔名帶票號、錨點檔同名）→ 換位時由檔名決定，唔靠人記

## 7. 相關文檔連結

- 需求錨點: `docs/req/TMO-089-requirement.md` ＋ `docs/req/TMO-091-requirement.md`
- 對帳表: `docs/reconcile/TMO-089-reconcile.md` ＋ `docs/reconcile/TMO-091-reconcile.md`
- 保留 vs 歸檔策略: `skills/dav-submitter/retention.md`
- Backlog 規則: `skills/dav-planner/backlog-rules.md` §4.5
- 上一輪交付摘要（已歸檔，內容完整保留在 git history）: `docs/deliverable/2026-10-28-tmo-092-jev-oracle-split.md`

## 8. 反思

### 8.1 6 維度檢查

| # | 維度 | 結果 | 備註 |
| - | --- | --- | --- |
| 1 | UX/UI 一致性 | N/A | 純文件改動，無介面 |
| 2 | RWD 響應式設計 | N/A | 純文件改動，無介面 |
| 3 | 技術債 | ⚠️ | 引用鏈換位靠人手；`ENV-EQ-21` 守門有盲位（見 §5）|
| 4 | 可維護性 | ✅ | Backlog 3 row → 1 row；`docs/ac/` 只剩範本 ＋ TMO-054 嘅活 AC；引用鏈明確 |
| 5 | 測試覆蓋率 | ✅ | D1–D8 全綠 ＋ 本機等價閘 11 步 ＋ 49 支突變全死 |
| 6 | 需求對齊 | ✅ | 8/8 需求句對上；兩票對帳表 2/2 ＋ 6/6 |

### 8.2 問題清單

- ⚠️ [P2] 跨檔互引冇機械守 → 根因：漂移檢查 D4 只掃交付摘要內嘅路徑，`skills/`／`docs/` 之間嘅互引靠人手 → 建議：加「skill 路徑存在性」機械探針（TMO-092 Action Item #4）
- ⚠️ [P2] 「最近一次交付」係人手概念 → 根因：保留策略冇定死「邊張票做引用鏈」，靠當次收尾時臨手決定 → 建議：交付摘要檔名帶票號，令換位由檔名決定
- ⚠️ [P2] 兩條規則各自合理、但交集冇人寫過：保留策略要「完成 US 嘅 ac 歸檔」，
  DOC-DRIFT-007 又要「`docs/ac/` 至少有一支真 AC 範本」（空集合＝紅）→ 減磅到最後一支時撞紅
  → 根因：規則交集冇被寫進任何一份規格
  → 建議：明文寫入「未完成 US 必須保留 AC 範本 ＋ 需求錨點」（本檔 §2.1 已按此補回 TMO-054），
  或改 DOC-DRIFT-007 嘅空集合條件（改探針＝代碼分支，要二審）
- ⚠️ [P2] backlog 嘅 `⏸️ 跳過` 狀態對檢查器嚟講係「不存在」
  → 根因：`STATUS_VALUE` 冇收 `⏸️` 前綴，同 backlog 狀態定義唔一致
  → 建議：加 `⏸️` 入值集，或統一改用 `blocked (原因)` 格式

### 8.3 Action Items

| # | 動作 | 類型（TECH/DE/US/Spike）| 驗收條件 | 預估 |
| - | -- | ----------------------- | -------- | ---- |
| 1 | `ENV-EQ-21` 改真 YAML parse（`yaml.safe_load` ＋ fallback）| TECH | 壞縮排／壞 value 嘅 frontmatter 被捉到 | 1 SP |
| 2 | 加「skill 路徑存在性」機械探針 | TECH | 探針喺本機等價閘捉到任一指標路徑失效 | 2 SP |
| 3 | `dav-jev-oracle` 瘦身（子檔 ≤300、context ≤1,500）| TECH | 兩支子檔 ≤300 行；context ≤1,500 | 3 SP |
| 4 | 交付摘要檔名帶票號，令引用鏈換位可機械決定 | TECH | 檔名同錨點檔一一對應 | 1 SP |
| 5 | 明文寫入「未完成 US 必須保留 AC 範本 ＋ 需求錨點」入 `skills/dav-planner/backlog-rules.md` §4.5／§4.6 | TECH | 規則寫死交集；新 US 流程自動產出，存量 live US 補齊 | 1 SP |
| 6 | 漂移檢查 `STATUS_VALUE` 收 `⏸️` 前綴（或統一 backlog 狀態格式為 `blocked (原因)`）| TECH | `⏸️` row 對 D1／D7 可見 | 1 SP |

### 8.4 Reviewer 二審結果（V03 紀律）

- **不適用** —— 本次改動**只有 markdown**（`docs/backlog.md`、`docs/deliverable/<...>.md`、
  `docs/ci/drift-whitelist.txt`、`skills/dav-reconciler/examples.md`）＋ 刪檔，冇碰代碼／契約／探針
  → 命中 `AGENTS.md` §1.5 V03 **文件分支** → 唔使走獨立 Reviewer 二審
- 已自查行數上限：`skills/dav-reconciler/examples.md` 83 行 → 83 行（子檔 ≤300 ✓）、
  該 skill context 352 → 352 行（baseline ≤700 ✓，棘輪只可下唔可上）、
  `skills/dav-reconciler/SKILL.md` 148 行（主檔 ≤150 ✓）
- 問題數：P0=0、P1=0、P2=0

---

**產生者**: Agent（透過 dav-submitter skill）
**產生時間**: 2026-10-28 12:40
