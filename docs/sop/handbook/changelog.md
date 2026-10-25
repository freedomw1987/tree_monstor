# §3 CHANGELOG（SOP 異動紀錄）

> 本檔是 SOP 的異動紀錄（2026-10-26 起 `AGENTS.md` 已不再內嵌 SOP 與變動歷史）。引用：`[CHANGELOG](./sop/handbook/changelog.md)`
>
> 追蹤 SOP（handbook ＋ 各 skill）的所有重大異動，便於 audit 與回溯。每筆異動需註明版本號、日期、變更內容與原因。
>
> ⚠️ **版本序號說明**：本檔的版本號 = **全域變更序號**（含 skill / CI / 文件變更），
> 與舊 `AGENTS.md` §2 標題的 **SOP 版本號**（已於 v2.14 隨 §2 移除）不是同一個序號 —— 兩者不可互相比較大小。

## v2.15 — 2026-10-26

**本版異動**：TMO-074 的 PNA-4 探針**效能修正**（掃描器重寫）＋ 補守門缺口。
**判定規則一個都冇放寬** —— PNA-4 嘅判定邏輯與原版**逐條等價**（45 個真實探針檔逐行 diff 0 差異；
fuzz 200 檔 + 1000 檔對照 0 差異，1866 = 1866 violations）。

| 類型 | 項目 | 說明 |
| ---- | -- | ---- |
| 效能 | `tests/helpers/probe-scan.bash` 新增 `probe_find_standalone_assertions` | PNA-4 由「逐行 fork awk/sed」（repo 13,660 行 × 約 2.5 fork ≈ 35,000 次 process spawn）改為**每檔一個 awk 行程** → PNA-4 **94,612ms → 855ms**（量測：`bats --timing tests/probe-name-ascii.bats`）；整個 `bats tests/ skills/` 約 380s → 2m42s–3m23s（受機器負載影響，故不寫死單一數字） |
| 守門 | `tests/probe-name-ascii.bats` 新增 `PNA-4b` canary ＋ PNA-4 加 `scanned_files >= 40` | 第 2 輪二審 P1：新掃描器零 canary + PNA-4 零防空過下限 → 掃描器壞咗就**永久靜默綠**。canary 用 `printf` 寫 15 行 fixture（唔可以用 heredoc：bats 前處理器會改寫 `@test`），覆蓋規則 ① ② ④ ⑤ ⑥b ⑦ 七條；`scanned_files` 下限擋**檔案列舉漂移**，canary 擋**sc描描器壞掉**，兩者缺一不可 |
| CI | `scripts/ci/mutants.tsv` 新增 `PNA-M1` | 令掃描器「永遠 skip」嘅突變 → 必須令 `PNA-4b` 轉紅；全表 **56 支全部死亡**（每支都有綠 baseline 對照） |
| 計數 | `scripts/ci/mutants.tsv` 檔頭 ＋ `tests/mutant-must-die.bats` ＋ `CONTRIBUTING.md` | mutant 表＝46 支行為鎖 ＋ 10 支文件／資料契約鎖 ＝ 56 支；三處原本各寫各的（同一套 awk 指令兩個答案）→ 已統一。⚠️ `CONTRIBUTING.md` 嘅過期數字**改前已存在**，非本次引入 |
| 記錄 | `docs/backlog.md` TMO-078 | 開票記錄 PNA-4 兩項技術債：縮排 `}` 嘅 latent 假紅（正解係 brace-depth 追蹤，屬語意變更 → 須另走 V03）＋ `probe_strip_comment`／`probe_code_lines` 死碼清理 |

**教訓（值得留低）**：
① **shell `case` 嘅 glob（尾端錨定）≠ awk regex（任意位置）** —— fuzz 捉到初版 3 處唔等價，方向全部係**漏報（假綠）**。
② **守門自己也必須先證明自己會咬** —— 手動突變實證：掃描器壞 → `PNA-4b` 轉紅、而 `PNA-4` 照綠（＝假綠路徑真實存在）。
③ **同一件事唔可以多份文件各說各話** —— 同一套 awk 指令，檔頭寫一套、`CONTRIBUTING.md` 寫另一套。

> 二審過程見下方「TMO-074 的 V03 二審結論（Reviewer）」表第 1／2／3 輪。

## v2.14 — 2026-10-26

**本版異動**：把 SOP 從 `AGENTS.md` 移出 —— AGENTS.md 只留「你是誰 + 萬事原則 + 3 條行為紀律」；
Gate 的**定義**改由各自承載它的 skill 負責，讓 skill 自足；並新增探針鎖兩份一致。

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | `AGENTS.md` 121 → 35 行 | 刪 §2 SOP 全部（§2.0 分流表／§2.3 Gate 速查表／§2.x 索引／變動歷史）。保留 §1 萬事原則（SOUL 7 條須逐字在場，有探針）＋ §1.5 三條行為紀律（V01／V02／V03）。**預設不再強制跑流程** |
| **P0** | Gate 定義進各自的 skill | `tdd-test-writer` 收 Gate 1 TDD ＋ Gate 2 lint（gate-2 無專屬 skill）；`regression-guard` 收 Gate 3；`dev-checker-loop` 收 Gate 4；`dav-reconciler` 收 Gate 4.5。每節含 name／pass_criteria／required_evidence／fail_action／mandatory_phrase |
| **P1** | 新增 `markdownlint-guard.bats` **MLG-10／MLG-10b** | 掃**全部 git 追蹤檔**（不用副檔名白名單——白名單會漏 `.bash`／`.tsv`／`.jsonc`／`.ts`／無副檔名檔）必須能嚴格 UTF-8 解碼；二進位以兩層跳過（① 已知二進位副檔名前置過濾 ② 解碼失敗且前 8KB 含 NUL）；`scanned ≥ 150` 防空過；MLG-10b 內建自證（壞檔必紅／好檔必綠／含 NUL 不誤報）。**為什麼要**：本次用 `sed` 做多檔數字替換時把 `changelog.md` 一行打成非法 UTF-8，而 markdownlint（0 issues）與 `bats tests/`（全綠）**都攔不到** → 會靜默出貨 |
| **P0** | 新增 `tests/gate-in-skill.bats` | 鎖「skill 內的 Gate 定義 == `gates.json` 逐條一致」（gate-1..4）＋「Gate 4.5 的 mandatory_phrase 與 handbook 2.3 一字不差」；含比對器自證（5 個欄位各掉一輪必紅、完整版必綠、`gates.json` 欄位被清空必紅）。另新增 `agents-md.bats` TD-017 AC-4／AC-4b：live 文件不得再導向已移除的 §2（① 同行寬鬆 pattern ② **區段式**：標題點名 AGENTS.md → 區段內任何 §2 皆違規 ③ 每個 glob 家族各自非空 ＋ AC-4b 五情境自證；含 `README`／`CONTRIBUTING`）|
| **P1** | 交叉引用修正 **17 個檔案** | handbook 7 章自我描述改「SOP §2.X」；handbook 2.1／2.2／2.6 的 trust 與分流交叉引用改指 `skills/dav-trust/preflight.md`；`dav-planner/SKILL.md` 的「§2.0 啟動後」；`docs/system-design.md`；`editor-guide.md` 的 V03.5 同源；PRD 05；`docs/ac/` 的 `.md`＋`.html`；`docs/reconcile/TMO-072`／`TMO-073`；**`README.md`**；**`CONTRIBUTING.md`** |
| **P1** | 補回原 TD-016 的義務 | 「進入每個 Gate 時必須在對話引用該 Gate 的 `mandatory_phrase`；不引用＝視為 gate 未觸發（偽裝通過，§2.7 違規）」寫進 handbook 2.3「Agent 必做動作」＋ 4 支 Gate skill 的 Gate 段各一行（原本只放在 AGENTS.md §2.3，搬走後無家）|
| **P1** | V03 補回原有子句 | 新 §1.5 V03 補回「具名 `/skill:dev-checker-loop`」「風險分級 ＋ 跨 SOP 一致性檢查」「用戶可明說『跳過 Reviewer』直接批准」＋「探針（`tests/**/*.bats`）修改比照辦理」；原 V03.6 的「條件放寬」三定義移入 `skills/dav-skill-creater/editor-guide.md` |
| **P1** | `gates.json`／`gates.schema.json` 描述更新 | 原寫「AGENTS.md §2.3 會自動引用」→ 改為「Gate 定義另外落在各自的 skill；本檔為機器可讀副本，兩邊都要改」 |
| **P1** | 探針調整（皆為強化，**無一放寬**） | `agents-md.bats`：TD-017 AC-1 上限 200 → **60** 行；TD-017 AC-2 改「不再內嵌 Gate 表＋須指名 4 支承載 skill」；TD-018 AC-6 改「AGENTS.md 自足」；SOUL-3 段落範圍不綁 §1.5 節名；SKILL-REF-2 改掃全 repo 文件面的 `/skill:` 引用（原版已成 0 迭代空過）。`restruct-dav-reconciler.bats` RECON-012 改「Gate 4.5 登記在承載它的 skill」 |

**數字變化**：`AGENTS.md` 121 → **35 行**；`tests/*.bats` 42 → 43 檔、探針 646 → **654** 支；
4 支 skill 行數 105／133／129／128 → 136／149／146／144（皆 ≤ 150）；改動檔 **36** 個（4 A／32 M／**0 D**）；**門檻一個都沒放寬**。

> 口徑說明：探針數 = `bats --count tests/`。

**決策紀錄**：
- **SOP 只是從 AGENTS.md 移出，不是刪掉 SOP**：handbook／`gates.json`／5 個 SOP skill／`install.sh` 的 sop 安裝
  **全部原地保留**。改變的是「預設」，需要時才由 skill 自己觸發
- **Gate 定義跟著 skill 走**：skill 被觸發時就看得到「什麼叫通過、要貼什麼證據、不通過會怎樣」
- **不禁用第二份定義，改用探針鎖一致**：`gates.json` 保留為機器可讀副本（install 會裝、schema 會驗）
- **V03 保留一條**：15 處 skill 引用 V03（改 SOP／skill 必走二審）。它不是流程步驟，是規範修改的品質紀律 → 留在 §1.5 一行

**前置**：V03 Reviewer 二審（見交付摘要）

**後續（同日 TMO-077）**：
① `regression-guard/SKILL.md` 149 → **120 行**（「## 流程（5 步）」由 5 個 `###` 子段 39 行
   重排為單一表格，語意不減；脫離 130–149 預警區、重拿 30 行餘裕）。
② 新增 `tests/doc-facts.bats`（`DOC-FACTS-1/2`）：**live 文件的自述數字必須等於實況**。
   只掃 `README.md`／`CONTRIBUTING.md`／`skills/*/SKILL.md`（`docs/deliverable/`、`changelog.md`、
   `*/CHANGELOG.md`、`docs/backlog.md` 是歷史快照 → 一律不掃）；`## 變動歷史` 段內的列也跳過。
   守 4 類事實：主檔自述行數、子檔自述行數、`N 個 skill`、`N 支 mutant`（皆以 `wc -l`／
   `ls -d skills/*/`／`mutants.tsv` 資料列數重算）。含 5 情境內建自證。
   **首次跑就抓到 6 處真實漂移**（`regression-guard` 4 個子檔行數 37／30／28／16 →
   43／37／32／28；`CONTRIBUTING.md` 2 處 mutant 總數 50 → 55）。
③ `scripts/ci/mutants.tsv` 的 `RG-M4` 錨點由「含行數的整行」改為「不含行數的指標句」——
   原本行數一改，mutant 就會因「錨點找不到」而中止（本次真的踩到）。

## v2.13 — 2026-10-26

**本版異動**：砍掉框架的 meta 自我管理層（第一刀）— 刪 12 支 meta 探針、40 支歷史交付摘要、
3 支 PRD、2 支獨立 reflection，並把 backlog / changelog / need-you-help / trust-log 壓回可用體積；
同時補上 D4/D8「日期窗內 0 件」的 fail-closed 守護（原本是「掃不到就 skip → rc=0」的假綠）。

| 類型 | 項目 | 說明 |
| ---- | -- | --- |
| **P0** | 刪 12 支 meta 探針（`tests/restruct-*.bats`） | 這批只驗「Markdown 標題／字串存在」，不驗產品事實，且大量斷言已刪除的路徑。保留 3 支仍承載契約的：`restruct-zero-cross-read`（可攜性）、`restruct-dav-trust`（checkpoint）、`restruct-dav-reconciler`（需求對帳） |
| **P0** | `docs/deliverable/` 40 支歷史交付摘要 → 1 支 | 保留 `2026-10-26-delivery-fidelity-tmo-069-071.md`（D4/D8 還要有件可查）；目錄本身保留（`dav-submitter` 要寫入） |
| **P0** | 刪 PRD 02 / 03 / 04 | PRD 01（AC 範本）與 PRD 05（D3 追溯矩陣）仍有 live dependency，保留 |
| **P0** | 刪 2 支獨立 reflection | v2.0 起反省併進交付摘要末段，`docs/reflection/` 不再生成 |
| **P0** | D4/D8「窗內 0 件」改為 fail-closed | 新增 `--require-window-checks`（`check-doc-drift.py`），`scripts/ci/check-doc-drift.sh` 在本 repo 自動啟用；窗內 0 件 → rc=1 |
| **P1** | `docs/backlog.md` 102KB → 14KB | 75 列全留（狀態 / 依賴 / 優先級 / 點數逐欄比對不變），只壓縮「主題」欄、移除表下歷史細節段（純歷史，留在 git history） |
| **P1** | `docs/sop/handbook/changelog.md` 979 → 487 行 | 保留最新 4 版全文（v2.13 最新 + v2.12/v2.11/v2.10 為 AGENTS.md 引用的二審結論節），舊版收斂為一行索引（索引行刻意保留探針錨定的關鍵字） |
| **P1** | `docs/need-you-help.md` / `docs/trust-log.md` 精簡 | 保留格式契約、trust checkpoint 檔頭、終局錨點與已結案索引；逐筆事件收斂成結果摘要 |
| **P1** | 新增 10 支探針（DOC-DRIFT-039..048） | 守住「窗內 0 件必紅」（039/042）「窗內有件必綠」（040/043）「真實 repo 窗內仍有件可查」（041）「wrapper 自動開嚴格模式」（044）「對外 `--root` 維持可攜語意」（045/046）「CI 那行不得帶 `--root`」（047，第六輪補）「窗內有件但 D8 零檢查件仍必紅」（048，第六輪補） |
| **P1** | 刪 3 支已失真或已失效的探針 | DOCS-REDUCE-004（檢查對象：兩支獨立 reflection 已隨本次減法刪除）、DOCS-REDUCE-006（檢查對象已刪）、PRD-02 存在性斷言 |
| **P1** | 修 `skills/dav-wiki/SKILL.md` 的「假覆蓋」宣稱 | 原本寫「`tests/dav-wiki.bats` AC-1a~1d 需要」，但那 4 支只是**檔案存在性**斷言；真正要求「最近 3 條歷史」的是已刪的 `restruct-dav-wiki.bats` → 改為誠實註明（第三輪二審 F2／checker P1-1）|
| **P1** | 接手被刪 meta 探針的 **7 支產品契約守護** | 第三輪先補 `AC-1e/1f/1g`（3 支）；第四輪複審後再補 `AC-1h`＋`PPTX-SLIM-CONTRACT`＋`SKILL-FM-1/2`（4 支）。原守護（dav-wiki 子檔指標解析／子檔掏空必紅／產品名詞錨點／版本一致性、pptx 腳本可執行、skill frontmatter）都是**產品層**不變式，不隨 meta 層減法消失（checker P2-1、第四輪 checker P2-2／task-2 P2-1）|
| **P2** | wrapper 改用逐引數比對 `--root` | 原本用 `"$*"` 子字串判斷：`--whitelist /tmp/--root=x.txt` 這類「值裡含 `--root`」的引數會誤命中，反而把 fail-closed 靜默關掉 → 改 `for a in "$@"` 逐個比對（checker P2-5）|
| **P2** | DOC-DRIFT-041 補正向斷言 | 原本只做負向斷言；`docs/deliverable/` 整包消失時 `check_deliverable_window()` 直接 `return`（連 WARNING 都不印）→ 041 仍綠，正是它要擋的假綠 → 補 rc=0 + 目錄存在 + 窗內有 `20*.md`（第三輪二審 F3）|
| **P2** | skill-local 跨目錄探針補 2 條 | 接手被刪 repo 級探針的 `](docs/` 與 Obsidian 跨目錄 `[[` 守護（checker P2-2）|
| **P2** | `docs/sop/handbook/changelog.md` 保留段 4 處補歷史註記 | v2.11／v2.10 全文保留段有 4 處提及已刪的 `tests/restruct-agents-md.bats`，補「已於 v2.13 刪除」以免被讀成現存探針（第三輪二審 F1）|
| **P2** | `skills/dav-reflection/template.md` 與 `docs/sop/handbook/2.4-reflection.md` 同步 | 原本仍寫「檔案位置：`docs/reflection/...`」，與 v2.0「併進交付摘要末段」矛盾，且指向已刪目錄 |

**數字變化**：`tests/*.bats` 53 → 42 檔、探針 794 → 646 支（−162：刪 12 個探針檔／162 支；
−3：移除 3 支失效斷言；+10：新增 DOC-DRIFT-039..048；+7：接手被刪探針的產品契約守護——
`tests/dav-wiki.bats` 補 AC-1e/1f/1g/1h、`tests/pptx-slim.bats` 補 `PPTX-SLIM-CONTRACT`、
新增 `tests/skill-frontmatter.bats`（SKILL-FM-1/2，repo 級覆蓋全部 13 個 skill））；`scripts/ci/mutants.tsv` 維持 55 支不變
（MMD-1 門檻不動、不刪守護探針）。

> 口徑說明：以上「探針數」= `bats --count tests/`（CI 實際執行數，不含 `skills/*/tests/` 的 2 檔／5 條）。
> 若用 `grep -c '^@test'` 計數則為 648（多出來的 2 支是 `@test` 字樣出現在註解／heredoc 內，不是真的測試案例）。

**決策紀錄**：
- **先砍 meta 層，不砍產品層**：四道 Gate、`dav-reconciler`／doc-drift、產品側真探針、CI 守護機制全部保留
  —— 被砍的是「框架管理框架」的那一層
- **反假綠優先於數字好看**：刪東西的同時補上 fail-closed 守護，寧可少一個檔案也不留一個會假綠的檢查
- **歷史不刪，改成可追溯**：內容保留在 git history，索引行保留探針錨定關鍵字
- **門檻一個都沒放寬**：mutant 門檻 55 不動；`.bats` 檔數地板維持原本的 40（當時實算 43 支、現 44 支 ≥ 40，仍成立）

**前置**：Reviewer 二審第一輪 verdict: `request-changes`（7 項阻擋點已全數納入本版修正）；
第二輪 verdict: `request-changes`（3 項 P1 + 4 項 P2、無 P0）→ 修正摘要：
① 補 DOC-DRIFT-044/045/046 守住 wrapper 的自動啟用分支（原本那個分支無任何探針覆蓋，刪掉會假綠回歸）；
② `.bats` 數量地板**改回 40**（當時實算 43 支、現 44 支 ≥ 40，原本的放寬不必要 → 本次變更**不含任何門檻放寬**）；
③ 探針數、檢查項數、刪除檔案數等所有數字同步更正（口徑已寫明；定案值見上方「數字變化」）；
④ DOCS-REDUCE-004 的刪除理由更正為「檢查對象已刪」（與 HTML 政策無關）；
⑤ `ci.yml` 的探針註解更新為 DOC-DRIFT-008..046；
⑥ 交付摘要補上「Reviewer 阻擋點 ↔ 修正」對帳表（§3.1）。

第三輪 verdict: `approve-with-comments`（0 P0 / 0 P1 / 3 P2）＋ Gate 4 checker verdict: `需修復`
（1 P1 + 5 P2）→ 修正摘要（已全部納入）：
① `skills/dav-wiki/SKILL.md` 的「假覆蓋」宣稱改為誠實註明（真正要求該段落的是已刪的 meta 探針）；
② 第三輪補 `tests/dav-wiki.bats` AC-1e/1f/1g（3 支結構性／產品名詞錨點守護）；
   第四輪複審後再補 `AC-1h`（版本一致性）、`tests/pptx-slim.bats` `PPTX-SLIM-CONTRACT`（腳本可執行）、
   新增 `tests/skill-frontmatter.bats`（frontmatter 註冊契約）——合計 7 支；
③ wrapper 的 `--root` 判斷改逐引數比對（堵住「值裡含 `--root`」誤關 fail-closed 的洞）；
④ DOC-DRIFT-041 補正向斷言（目錄整包消失時原本仍綠）；
⑤ skill-local 探針補 `](docs/` 與 Obsidian 跨目錄 `[[` 兩條守護；
⑥ changelog 保留段 4 處補歷史註記、交付摘要死引用宣稱改精確為「0 處可執行引用」。

第四輪 verdict（並行雙角色）：V03 Reviewer 二審 `approve-with-comments`（0 P0 / 0 P1 / **0 P2** / 6 P3）
＋ Gate 4 checker `approve-with-comments`（0 P0 / 0 P1 / 2 P2 / 3 P3）→ 修正摘要（已全部納入）：
① 探針總數以 `bats --count tests/` 實跑定案（第四輪當時 642；後續輪次再補探針後為 646，見「數字變化」）；第四輪 mission 舊稿的 639 作廢；
② 補回 **2 支產品契約**守護：`tests/dav-wiki.bats` `AC-1h`（主檔版本列 == CHANGELOG 首列）、
   `tests/pptx-slim.bats` `PPTX-SLIM-CONTRACT`（SKILL.md 點名的 5 支腳本存在且可執行）；
③ 其餘被刪 meta 探針的殘留覆蓋損失（段標字串、GWT 指引、130 行早警、dav-planner／regression-guard 的版本一致性、AGENTS.md ↔ handbook 版本一致性）判定屬「文字存在性」或改人工維護，
   於交付摘要 §5 逐條列出，**不補回**；
④ 「零死引用」列舉改正（`skills/*/CHANGELOG.md` 不再誤歸入 `docs/` 子句）；
⑤ 移除生成器 `/tmp/slim/06-edits.py` 內殘留的「`.bats` 地板 40 → 30」edit，原地留註解說明。

第五輪 verdict（並行雙角色）：V03 Reviewer 二審 `approve-with-comments`（0 P0 / 0 P1 / 1 P2 / 3 P3）
＋ Gate 4 checker `approve-with-comments`（0 P0 / 0 P1 / 2 P2 / 5 P3）→ 修正摘要（已全部納入）：
① 新增 `tests/skill-frontmatter.bats`（`SKILL-FM-1/2`）：原 `restruct-dav-reflection.bats`／
   `restruct-dev-checker-loop.bats` 各守一個 skill 的 frontmatter，刪除後無人接手（缺 frontmatter = skill 不載入）
   → 改為 repo 級一支，涵蓋全部 13 個 `skills/*/SKILL.md`（並用壞／好 fixture 自證偵測器真的會咬）；
② changelog 的輪次歸屬拆開、口徑改「2 檔／5 條」；③ §5 補列 AGENTS.md ↔ handbook 版本一致性改人工；
④ 標頭不再預先宣告未發生的複審結果；⑤ whitelist 改稱「機器讀取的豁免列」；
⑥ `docs/reconcile/TMO-073-reconcile.md` 白名單 6 → 7 筆；⑦ 移除生成器殘留的「地板 40→30」與
   「把 dav-wiki 假覆蓋文字寫回」兩條 edit，並把該檔標為不可重跑的一次性稽核紀錄。

第六輪 verdict（並行雙角色）：V03 Reviewer 二審 `approve-with-comments`（0 P0 / 0 P1 / 2 P2 / 4 P3）
＋ Gate 4 checker `approve-with-comments`（0 P0 / 0 P1 / 3 P2 / 3 P3）→ 修正摘要（已全部納入）：
① 新增 `DOC-DRIFT-047`：鎖住 CI 那一行不得帶 `--root`（否則 wrapper 判定「外部專案」→ 嚴格模式靜默關閉，
   而 022／041／044／045／046 全部仍綠）；② `check_deliverable_window()` 補第二個條件＋`DOC-DRIFT-048`：
   窗內有件但沒有任何交付摘要引用得到 `docs/req/` 錨點時，**D8** 的檢查件數仍是 0 → 也必須 fail-closed
   （原本只保證 D4 有件可查）；③ `docs/reconcile/TMO-073-reconcile.md` 的探針數／檢查項數全數更新；
④ §5 補列 `dav-planner`／`regression-guard` 的版本一致性守護損失；⑤ 生成器第四輪段落改回「2 支」並補第五／六輪段。

## v2.12 — 2026-10-26

**本版異動**：Gate 4.5 第 6 輪需求對帳 —— 補正 v2.11 的**失真紀錄**、修正 RECON-007 探針解析器（BSD grep 交替分支上限）、
修掉 `--from-date` 的 **fail-open** 缺口、關閉 v2.11 二審指出的 RECON-007 覆蓋盲點、**並完成 TMO-074（假綠溫床）**

### TMO-074：bats 1.14 在 **bash 3.2**（macOS 預設）+ UTF-8 locale 下靜默丟棄 CJK 名的探針

**病因（實測確認，非推論）**：bats 的 `bats_encode_test_name` 用 `[[:alnum:]]` 決定哪些字元**原樣**留在 bash 函式名裡。
該類別在 **UTF-8 locale** 下會匹配 Unicode 字母（中文／假名／韓文／西里爾）→ 函式名對不上 → bats 報
`bats: unknown test name` + `Executed N instead of expected M` → **該支探針從未被執行**；
但 `bats --count` **仍把它算進去** → 報表看起來全綠。

| 環境 | CJK 名探針 |
|------|-----------|
| bash 3.2 + `LC_ALL=C` | **會跑**（`[[:alnum:]]` 只認 ASCII → CJK 被跳過編碼）|
| bash 3.2 + UTF-8 locale | **被丟棄**（＝本 bug 的成因；**本機 macOS 預設 /bin/bash 就是 3.2**）|
| bash 5.3 + UTF-8 locale | **會跑** ← **CI（ubuntu / macOS 腿都是 bash 5.x）不受影響** |
| bash 5.3 + `LC_ALL=C` | **會跑** |

（希臘文／café／全形英數／emoji／→ **不受影響**。）

> ⚠️ **變因是「bash 版本 × locale」兩個，不是只有 locale**（2026-10-26 二次實測更正）。
> 第一次量測只變了 locale、沒變 bash 版本 → 誤判成「locale 相依」。實際上 **bash 5.x 修掉了這個行為**。
> 這一點 `docs/deliverable/2026-10-23-dav-trust-v2.4-resume-and-stop.md` §7 當年就寫對了
> （「在 **bash 3.2 本機**上，23 支探針檔的守護會被靜默丟棄」）→ 本版依實測把它補完整。
> （該交付摘要已於 v2.13 隨歷史產物收斂刪除，內容見 git history）
>
> **所以 CI 在這件事上從來不是紅的**：HEAD 的 mutant 表在 bash 5.x 下 43 支全死。
> 受影響的是**本機 bash 3.2 的開發者**（macOS 預設）：他們看到的綠是假的。

**動工前**（2026-10-26 量測）：**21 個探針檔共 134 支**探針名含非 ASCII → 其中約 104 支在
**本機 bash 3.2 + UTF-8 locale** 下從未執行（CI 的 bash 5.x 正常執行它們）。

**處置**：

| # | 動作 | 證據 |
|---|------|------|
| 1 | 134 支探針改名為**純 ASCII**（保留 `<ID>: <說明>` 結構與 ID 前綴，說明翻英文）| 計畫數 == 執行數 == **760**；`unknown test name` 0 筆；`instead of expected` 0 筆 |
| 2 | 新增 `tests/helpers/probe-scan.bash`（引號/heredoc 感知的共用掃描器）| 每個 .bats 檔：掃描器計數 == `bats --count`（PNA-2 釘住）|
| 3 | 新增 `tests/probe-name-ascii.bats`：PNA-1 命名政策／PNA-2 交叉比對／PNA-3 掃描器自測／PNA-4 斷言 fail-fast | PNA-4 突變測試：把一個 fail-fast 還原成裸 `[[ ]]` → 轉紅並指名檔案行號 |
| 4 | ENV-EQ-9 的 canary 改成 **locale 正確**的斷言（舊版斷言「CJK 名必須跑 2 條」是 `LC_ALL=C` 下的觀察 → 在 UTF-8 locale 下必然紅，且紅的原因被誤讀成「canary 檔壞掉」）| ENV-EQ-9 從紅轉綠（baseline 47 → **46**）|

#### 連帶挖出並修掉的第二層假綠（比本 bug 更嚴重）

**實測發現**：bats（與純 bash）之下，**獨立的 `[[ ... ]]` 斷言失敗不會中止 test body** —— 只有**最後一個**命令的狀態決定結果：

```
[[ abc == xyz ]]; echo reached   → reached（rc 0，沒中止）
[ abc = xyz ];    echo reached   → 中止（rc 1）
false;             echo reached   → 中止（rc 1）
```

→ **夾在中間的 `[[ ]]` 斷言等於沒有**。實例：`tests/ffmpeg-version.bats` FV-2 在 `MIN_MAJOR=5 → 0` 的突變下**仍綠**，
因為它的核心斷言 `[[ "$output" == *"太舊"* ]]` 夾在中間、失敗被靜默忽略。

**處置**：把 **181 個**獨立 `[[ ]]` 改成 repo 既有的 fail-fast 慣例：

```bash
[[ ... ]] || {
  echo 'FAIL: <file>:<line>: assertion failed' >&2; return 1; }
```

> **兩個刻意的設計**（都是被現有工具逼出來的）：
> ① **不把運算式嵌進訊息**、且**拆成兩行**——`scripts/ci/lint-probe-secrets.py` 的 R3 規則是**行級**的
> （同一行同時出現 `FAIL` 與 `$output`/`$out`/`$result` 且無 `mask_secrets` → 判成外洩）。
> 兩行式正是本 repo 既有慣例。
> ② **行尾註解（含 `SECRET-OK:` 標記）一律保留**——掉了會讓秘密掃描器誤判成「出現真 key 前綴」。

**效果**：**本機（bash 3.2）原本「守不住」的 6 支 mutant 全部轉死**（IMG-M2／V-M7／V-M10／FF-M1／SM-M1／SM-M2）。
（這 6 支在 CI 的 bash 5.x 下本來就會死 —— 它們守不住是**本機 bash 3.2** 的假象。）
這 6 支的探針正是那 134 支「從未執行」的其中之一 → **它們從來沒有被驗證過**。
全表 **48 支 mutant 全部死亡**（動工前**本機**（bash 3.2）整表 `UnicodeDecodeError` 崩潰、從未跑完；
CI 的 bash 5.x 下本來就能跑完）。

> **失敗數沒有變**：改寫 181 個斷言後，全套失敗數 **46 → 46，失敗集合完全不變**——
> 表示那些斷言本來就都成立，只是**沒有被強制**。這是「假綠」的典型樣貌：報表綠，但護欄其實沒扣住
> ——而且**只在 bash 3.2（本機）扣不住**，CI 的 bash 5.x 一直是扣住的。

### TMO-074 的 V03 二審結論（Reviewer）

| 輪次 | Verdict | 摘要與處置 |
|------|---------|------------|
| 第 1 輪 | ⚠️ approve with comments（0 P0 / 1 P1 / 6 P2 / 6 P3）| **P1**：Reviewer 質疑「`[ ]` 會中止、`[[ ]]` 不會中止」的不對稱是**量測環境混用** → **已用同檔對照實驗排除**（T1~T5 放在同一個 .bats、同一環境、每例最後一個命令都是 `true`：T1 `[ ]` 紅、T2 `[[ ]]` 綠、T3 `false` 紅）→ Reviewer 的前提不成立，但**其結論「裸 `[ ]` 中段斷言也不安全」因此也不成立**（`[ ]` 確實會中止 → 安全）。**P2**：①`\|\|`/`&&` 豁免過寬 → 已收緊（PNA-4 重寫，連 `\|\|` 鏈也抓）；②fail-fast 訊息行號漂移 → 已用 `fix_line_numbers.py` 重算（182 筆全對）；③新檔 untracked → CI 的 `git ls-files` 系列守門與 shellcheck 尚未蓋到 → **併入合併前檢查清單**（本分支所有新檔都還沒 add，非本次獨有）；④ENV-EQ-9 canary 用 `charmap` 當代理是錯的代理 → 已改用**「該 locale 的 `[[:alnum:]]` 是否含 CJK」**（與 bats 內部 `bats_encode_test_name` 同一判準）；⑤同一件事四處四個數字 → 已統一為「動工前 21 個探針檔共 134 支」；⑥V03 未閉環 → 本節即為二審紀錄。**P3**：PNA-4 的 `if/elif` 豁免是不可達死碼 → 已刪；PNA-4 不跳 heredoc → 已改用 heredoc 感知的 `probe_code_lines`；巢狀 bats 未清 `BATS_` 前綴的環境變數 → 已清；PNA-1/2/4 缺「掃到幾個」下限 → 已補（防空過）。 |
| 第 2 輪 | ⚠️ approve with comments（0 P0 / 1 P1 / 6 P2）| **背景**：PNA-4 掃描器由「逐行 fork awk/sed」（repo 13,660 行 × 約 2.5 fork ≈ 35,000 次 process spawn）改為**每檔一個 awk 行程** → PNA-4 由 **94,612ms → 855ms**（量測：`bats --timing tests/probe-name-ascii.bats`），整個 `bats tests/ skills/` 由約 380s → 2m42s–3m23s（受機器負載影響，故不寫死單一數字）。**等價性**：45 個真實探針檔逐行 diff 0 差異；fuzz 200 檔 + 1000 檔（多 seed／未閉合引號／各種 heredoc 變體）0 差異（1866 = 1866 violations）。⚠️ fuzz 途中捉到初版 3 處 **shell glob vs awk regex 語意唔等價**——① shell 的 `case` glob 要求邏輯運算子喺**行尾**，awk regex 只要求「包含」②「test body 最後一句」原版用**未剝空白**嘅原行 ③ heredoc 偵測嘅引號狀態原版**跨行保留**——**方向全部係漏報（假綠）**，已全部修正。**教訓：shell `case` 嘅 glob（尾端錨定）≠ awk regex（任意位置）**。**P1**：新掃描器零 canary + PNA-4 零防空過下限 → 掃描器壞咗就**永久靜默綠**（repo 自己踩過同一個坑：TMO-074 嗰輪改 `while read` 漏改 `done < "$file"` → 整支守門空轉仍報綠）→ 已補 `PNA-4b` canary（用 `printf` 寫 fixture，唔可以用 heredoc：bats 前處理器會改寫 `@test`）＋ PNA-4 `scanned_files >= 40` 下限 ＋ `mutants.tsv` 加 `PNA-M1`（令掃描器永遠 skip → must die）。**手動突變實證**：掃描器壞 → PNA-4b 轉紅、而 PNA-4 照綠（＝第 1 輪 P1 描述嘅假綠路徑真實存在，現已被咬住）。**P2**（今輪處理）：① `CONTRIBUTING.md` 5 個數字（50/27/42/8）過期 → 已同步 56/33/46/10（**改前已過期**，非本 diff 引入；同一套 awk 指令兩個答案 = repo 最痛嘅「同一件事多份文件各說各話」）② fixture 副檔名由 `.bats` 改為 `.fixture`（萬一 TMPDIR 指去 repo 內，PNA-4 自己嘅 glob 會掃到 → 假紅）③ fixture 補 3 條規則案例（規則②整行註解／⑥b 跨行 fail-fast 區塊／⑦ `}` 結尾豁免）→ **期望字串不變**④「沿用」→「**複製自**」（awk 內無法叫 bash function，實為複製；改一處要同步另一處）⑤「逐條等價」收窄成**有證據範圍**＋貼返 ①~⑧ 逐條對照表⑥ `mutants.tsv` 檔頭加「**探針名欄係 regex**」（`bats -f` 係無錨定 regex 搜尋；括號會變 capture group → `ERROR: Found no tests` → die(rc=2)；而 MMD-1 只做 `grep -qF` → 攔唔到）⑦ 數字口徑統一（標明量測指令同範圍）⑧ `probe-scan.bash` 檔頭函式清單補全（5 支）＋死碼標明「目前冇呼叫點」⑨ 記錄語法哨兵盲點（`bash -n` 唔 parse 內嵌 awk → 日後「改壞 awk」型 mutant 會係假死因）。**門檻一個都沒放寬**：PNA-4 嘅判定規則與原版逐條等價；`scanned_files >= 40` 同 PNA-1/PNA-2 一致（本表早前已明文「.bats 檔數地板維持原本的 40」）。**刻意不做的兩件事**：①「縮排嘅 `}` 算唔算 test body 最後一句」——原版 glob 要求 `}` 喺**行首**，縮排嘅 `}` 會被當 violation（latent 假紅）；**唔可以用「剝空白」修**（咁樣會令真違規變 pass = 條件放寬 = 假綠），正解係 brace-depth 追蹤 → **已開票 TMO-078、另走 V03**；②死碼 `probe_strip_comment`／`probe_code_lines` 全刪（≈70 行，會擴大 diff）→ 已標明「目前冇呼叫點」，清死碼屬另一輪（已併入 TMO-078）。 |

> **本輪自己也踩到同一個坑（假綠）**：PNA-4 改用 heredoc 感知掃描器時，我改了 `while read` 卻忘了改底部的
> `done < "$file"` → **整支守門變成空轉卻回報綠**。是「突變測試」（把一個 fail-fast 還原成裸 `[[ ]]`
> 必須轉紅）把它抓出來的 → **守門自己也必須先證明自己會咬**。

### 第 6 輪對帳 → 補正 v2.11 的失真紀錄

**為什麼**：v2.11 記載「實測 4 支 mutant 全死」，但**當時並未真的觀察到**——RECON-007 v1.0 的解析器在
macOS/BSD grep 上本身是壞的（baseline 紅）→ `mutant-must-die.py` 的 baseline 迴圈 `die()` → **整個表中止** →
DD-M1..DD-M3 / DR-M1 四支守護一直是**失效狀態**。v2.11 同節的「探針『會咬』實測」表（DR-M1 列
`✅ 紅（baseline 綠 → 突變 rc=1）`）與「登錄 4 支 mutant（實測 4 支全死）」同屬當時未發生的宣稱。
**這正是本專案要解的病（同一件事多份文件各說各話、宣稱與實況不符）在自己的 changelog 裡重現。**

### 探針修正（依 V03.6 走 Reviewer 二審）

| 探針 | 問題 | 修正 | 判定 |
|------|------|------|------|
| RECON-007（`tests/restruct-dav-reconciler.bats`）| v1.0 用 `grep -oE '(✅\|⚠️\|❌\|🚫) …'`：BSD grep 2.6 的 ERE **交替分支上限為 2** → 4 分支只吐出前 2 個（❌ / 🚫 被吞）→ count 只數出 2 種 → 探針紅 | 改用 python3 逐行 + `re.finditer().group(0)` 解析（明確 UTF-8 讀檔、Unicode 語意、兩平台一致）| **不是門檻放寬**：同一 regex、同一 4 種門檻、同一缺值斷言，僅換解析器（predicate 逐位元組未變）|
| DOC-DRIFT-036/037（`tests/doc-drift.bats`，新增）| `--from-date` 未驗證格式：比對用**字串**比較（`doc.name[:10] < from_date`）→ 傳入 `"bad-date"` 會讓**所有**交付摘要被跳過 → 檢查範圍靜默縮成空集 → **D8 硬門檻被一個 typo 關掉** → 假綠 | `--from-date` 改用 `datetime.strptime` 驗證（格式 + 日期存在性），不合法 → **rc=2**（fail-closed）| **收緊**（新增 fail-closed 契約），非放寬 |

### 實測證據（V03.6 要求：修改前 fail / 修改後 pass）

```
# RECON-007 修改前（BSD grep 2.6.0-FreeBSD，實測）
$ printf '%s\n' "$sec" | grep -oE '(✅|⚠️|❌|🚫) [^ |（(]+' | sort -u
✅ 已實作
⚠️ 部分實作                     ← 只數出 2 種（❌ / 🚫 被交替上限吞掉）
not ok 1 RECON-007: exactly four allowed status values are defined
#   `count=$(printf '%s\n' "$values" | grep -c . )' failed

# RECON-007 修改後
ok 1 RECON-007: exactly four allowed status values are defined

# 交替分支數 vs 抓到幾種（實測，證明是分支數而非字串長度／locale／跨行）
(✅) → 1 種 ｜ (✅|⚠️) → 2 種 ｜ (✅|⚠️|❌) → 2 種 ｜ (✅|⚠️|❌|🚫) → 2 種
(a|b|c|d)（純 ASCII）→ 4 種（正常）｜ LC_ALL=C 與 en_US.UTF-8 結果相同（非 locale 問題）

# mutant 守護（修好後才第一次真的跑完）
$ python3 scripts/ci/mutant-must-die.py --only DD-M1,DD-M2,DD-M3,DR-M1
baseline（未突變，必須綠）：4 組 → 4 組全綠
突變（每支都必須紅）：DD-M1 / DD-M2 / DD-M3 / DR-M1 → 4 支全死
OK: 4 支 mutant 全部死亡（每支都有綠 baseline 對照）
```

### 第 6 輪對帳 → v2.11 二審指出的 RECON-007 覆蓋盲點（P2-3）

RECON-007 只認 4 個**已知** emoji → 全新 emoji 的第 5 種狀態值（如 `🟡 暫緩`）**不被擋**
（已實測：加該列後 RECON-007 仍綠）。**此盲點在舊實作同樣存在，非本版引入。**

**本版實作（V03 Reviewer 第 2 輪 P2-1 / P2-2 / P2-3 的建議，非最初提案的「掃 emoji」）**：

| 面向 | v1.1 | v1.2（本版） |
|------|------|------|
| 取值 | regex 只認 4 個已知 emoji | **結構式**：以「表頭第一欄 == 狀態」定位 §4 狀態表，取資料列第一欄 |
| 比對 | `grep -qF` **子字串** | **集合等值**（`✅ 已實作 🟡 暫緩` 不再被誤判為合法）|
| 跨檔 | 無 | **跨檔守護**：規格檔 §4 ↔ `check-doc-drift.py` 的 `VALID_STATUS` 必須一致 |
| 反向自測 | 無 | **RECON-016**（新增）：兩個突變情境都必須讓解析結果改變 |

> **為什麼不用「掃所有 emoji 開頭儲存格」**（Reviewer 第 2 輪 P2-2 的實測反駁）：
> 同一份文件裡「emoji 開頭儲存格」≠「狀態值」—— `reconcile-format.md` §3 欄位定義表就用
> 單獨的 `✅` 當「必填」標記（5 處）、§2 範例表也有。若掃 emoji，往 §4 加一列**說明性** emoji
> （例如 `| 📌 備註 | … |`）就會讓**合法檔案**變紅（假紅）。結構式沒有這個風險。

**新增 mutant DR-M2**：把 §4 某一整格變成 `| ✅ 已實作 🟡 暫緩 | … |`
→ 舊的 `grep -qF` 子字串比對**會漏掉**（count 仍 4 且子字串命中）→ **在 v1.1 下這支 mutant 會活著**；
v1.2 的集合等值會把它判為違規 → **mutant 死**。這支 mutant 正是「子字串比對不可用」的證據。

> **邊界（已揭露，非缺陷）**：D7（`check-doc-drift.py` 的 `VALID_STATUS`）本來就能抓到**對帳表裡**的
> 非法狀態值；RECON-007 守的是**規格檔** `reconcile-format.md` 本身。兩者守不同對象，互補。
> 本版的**跨檔守護**讓這兩份詞彙表副本**不會各說各話**。

### 第 6 輪對帳 → 順手修掉的自證漂移（本專案自己的病）

| # | 漂移 | 處置 |
|---|------|------|
| 1 | `docs/ac/TMO-073.html:22` 寫「本 US 做 **5 類**字面對帳」，同檔 :19 / :24 寫 **8 類** → **同一檔自相矛盾**（正是 D5 只比狀態、不比內文的盲區）| 統一為 8 類 |
| 2 | 交付摘要 §2.3 產物表寫「`tests/doc-drift.bats`（新，**31 條**）」，§3 驗證表寫「**35/35 綠**」→ 同一檔自相矛盾 | 統一為實際數（37 條） |
| 3 | 交付摘要 §5 待辦 #3「**V03 第 2 輪二審 verdict 缺席**」→ changelog v2.11 **同時有第 1 / 第 2 輪兩列**（＋「第 2 輪處置明細」16 項）→ 宣稱不實 | 刪除該待辦（已閉合）|
| 4 | 交付摘要 §3.1 證據欄漏列 DOC-DRIFT-034 / 035（D8 只比 (R-ID, 狀態)、不比證據欄 → 證據欄漂移**結構上不可見**）| 補列；並把此盲區寫入對帳表備註 |
| 5 | `tests/mutant-must-die.bats` docstring「表 39 → **42** 支 → 47 支」→ 實算 39 + 4 = **43** | 改為 43 |

### 二審結論（V03 Reviewer）

| 輪次 | Verdict | 摘要 |
|------|---------|------|
| 第 1 輪（RECON-007 解析器修正）| ⚠️ approve with comments（0 P0 / 0 P1 / 3 P2 / 4 P3）| **P2-1**：探針內嵌根因註解寫錯機制（宣稱「否定字元類吃掉換行」→ 跨行黏 token；grep 逐行比對，**不可能**跨行）→ 必改成實測機制；**P2-2**：v2.11 的「實測 4 支全死」為當時未發生的宣稱 → 必補正（→ 本版 v2.12）；**P2-3**：全新 emoji 第 5 種狀態值不被擋（舊實作同樣漏）→ 建議改為數所有 emoji 開頭儲存格；**P3-1**：註解「與 parse_reconcile_rows 同一語意」不精確（後者 norm_emoji 去 U+FE0F，本探針要求位元組一致）；**P3-2**：`m` shadowing；**P3-3**：缺 python3 時診斷訊息原始（建議 fail-closed 前置檢查）；**P3-4**：缺反向自測 |
| 第 2 輪（RECON-007 v1.2：結構式 + 集合等值 + 跨檔守護）| ⚠️ approve with comments（0 P0 / 1 P1 / 3 P2 / 5 P3）| **P1**：changelog v2.12 把「尚未實作」的 P2-3 寫成已完成（且同段自相矛盾：「本版改為…」vs「已實測仍綠」）→ 合併前必修（→ 本版已依 Reviewer 建議改成**結構式 + 跨檔**並實作，changelog 同步改正）；**P2-1**：沿用 `grep -qF` 子字串比對會留假綠（`✅ 已實作 🟡 暫緩` 仍綠）→ 必須集合等值；**P2-2**：「emoji 開頭」在本文件不是狀態值的可靠 proxy（§3 用單獨 ✅ 當「必填」標記 5 處）→ 掃 emoji 會假紅；**P2-3**：P2-1 註解的根因規則與其對照組互相矛盾；**P3-1**：`parse_reconcile_rows` 的描述與程式碼不符；**P3-2~P3-5**：§4 終止式建議用 `^## \d`（§2 的 fenced code 內有 `## 對帳表`/`## 結論`）、`\p{So}` 在 Python stdlib 不支援、Unicode 版本漂移風險、缺「會咬住」證據（反向自測 + mutant）|

> **P2-1 的修正**：執行者依 Reviewer 要求重做根因實測（3 種 locale × 4 種交替分支數 × ASCII 對照組），
> 確認真實機制＝**BSD grep 2.6 的 ERE 交替分支上限為 2**（與字串長度、locale、跨行皆無關），
> 並已把實測證據寫入探針註解。同時加 `command -v python3` fail-closed 前置檢查（P3-3）、改 `m` → `mm`（P3-2）。
> **P3-1 的修正**：原註解寫「`parse_reconcile_rows` 會 norm_emoji() 去掉 U+FE0F」——**經實讀程式碼確認該說法錯誤**
> （`parse_reconcile_rows` 本身**不**呼叫 norm_emoji；norm_emoji 是在比對端 D7/D8/deliverable_status 才套用；
> 且其前綴集是 `("✅","⚠","❌","🚫")`，其中 `"⚠"` **不含** U+FE0F）→ 該段描述已刪除（v1.2 重寫時一併移除）。
>
> **P3-4 的修正**：新增 **RECON-016**（反向自測，見上）。
>
> **第 2 輪的處置**：①P1 → 依 Reviewer 建議**放棄「掃 emoji」提案**，改為**結構式 + 集合等值 + 跨檔守護**並**實作完成**，
> changelog 該段同步改正（原寫法已刪）；②P2-1 → 集合等值（`sorted(vals) != sorted(CANON)`）；
> ③P2-2 → 結構式（表頭第一欄 ==「狀態」）；④P3-2 → 邊界改用 `^## \d`；
> ⑤P3-4 → **反向自測 RECON-016**（兩個突變情境）+ **新增 mutant DR-M2**。
>
> ⚠️ **執行者在實作 RECON-016 時自己踩到同一個坑**：初版用全檔 `str.replace("| ✅ 已實作 |", …, 1)` 做突變，
> 但「`| ✅ 已實作 |`」在 §2 的 fenced 範例（line 27）**先於** §4 狀態表（line 56）出現 → 突變改到 §2、
> §4 根本不變 → 反向自測**變成空轉（假綠）**。已改為**只在 §4 區段內** mutate、且與**基準值**比較。
> 這印證了「探針本身要先證明自己會咬」——正是 RECON-016 存在的理由。
>
> **另一項本輪才浮現的既存缺陷（非本 US 範圍，已揭露）**：跑**整張** mutant 表時，harness 在
> `subprocess.run(..., text=True)` 嚴格解碼 bats 輸出 → 突變把**多位元組字元截斷**時輸出含不合法 UTF-8
> → `UnicodeDecodeError` → **整個 harness 崩潰**（其餘 mutant 從未被驗）。
> 已改 `errors="replace"`（rc 才是判定依據，輸出只是證據）→ 崩潰變成可診斷的失敗。
> 剩下的失敗真因＝**TMO-074**（bats 1.14 在 UTF-8 locale 下靜默丟棄名稱含 CJK 的 `@test` → **21 個探針檔共 134 支**探針從未執行），
> 屬**已存在的 P1 backlog 項**（`docs/backlog.md` TMO-074，todo），不在本 US 驗收範圍。
> 註：`tests/doc-drift.bats` 與 `tests/restruct-dav-reconciler.bats` 的測試名**全為 ASCII**（0 支中文名）
> → **不影響本輪 7 條需求句的對帳判定**。
## v2.11 — 2026-10-26

**本版異動**：§2.3 新增「Gate 4.5 需求對帳」子關卡（Delivery Fidelity 機制：需求錨點 → 獨立 subagent 對帳 → 交付狀態硬門檻）

| 類型 | 項目 | 說明 |
| ---- | -- | ---- |
| **P0** | `skills/dav-reconciler/`（新 skill）| 需求對帳機制：輸入＝需求錨點 + 最終變更清單（**刻意不給實作自述**）；輸出＝需求對帳表（覆蓋全部 R-ID）；狀態 4 種（已實作／部分實作／未實作／已作廢）；硬門檻＝未全數對上不得標「✅ 完成」|
| **P0** | `skills/dav-planner/`（v2.7 + `backlog-rules.md` §4.7）| 產 US 必產需求錨點檔 `docs/req/<US-ID>-requirement.md`（4 段固定結構 + R-ID 連續唯一 + 原話區唯讀）|
| **P0** | `docs/sop/handbook/2.3-execution.md` | 新增「Gate 4.5 需求對帳」段落（位置 / 輸入 / 輸出 / 通過條件 / 不通過後果 / mandatory_phrase / 定位說明 / trust 例外）|
| **P1** | `skills/dav-submitter/`（v2.5 + `template.md` §3.1）| 交付模板加「需求對帳」段；Step 4.5 帶入對帳結論；硬門檻（對帳未過 → 不得標「✅ 完成」）|
| **P1** | `skills/dav-reflection/`（v2.3）| 規則表加「需求對帳先於反省」（反省不得建立在未經驗證的「已完成」前提上）|
| **P1** | `docs/sop/handbook/2.4-reflection.md` | 前置條件 blockquote（先對帳再反省）|
| **P1** | `AGENTS.md` §2.3 | 速查表加 Gate 4.5 一列（標明「§2.3 子關卡，非 gates.json 項」）；標題改「4 大 Gate + Gate 4.5 子關卡」；TD-016 補 Gate 4.5 的 mandatory_phrase 位置；§2 版本 v2.1 → v2.2 + 變動歷史加 v2.2 列 |
| **P1** | `skills/dav-reconciler/scripts/check-doc-drift.py` + `scripts/ci/check-doc-drift.sh`（wrapper）+ `docs/ci/drift-whitelist.txt` + `.github/workflows/ci.yml` | 文件漂移檢查 8 類（D1..D8）：AC 狀態 vs backlog / AC 編號連續唯一 / PRD 追溯矩陣幽靈 ID / 交付摘要引用不存在的檔案 / md 與 html 狀態一致 / AC ↔ 需求錨點 / 對帳表 R-ID 覆蓋 / 交付摘要對帳段與狀態一致；白名單 fail-closed（缺理由 → rc=2、全類豁免 → rc=2）；**實作放在 skill 內**（隨安裝到位，目標專案可用）|
| **P2** | `docs/ac/US-M62` / `US-M63` / `US-M71` / `US-M81`（md + html）| 修正被新探針抓出的**真實漂移**：狀態 PENDING → done、backlog 引用舊格式 → 實際 ID（TMO-019 / TMO-020）|
| **P2** | `docs/prd/05-delivery-fidelity.md` + `docs/system-design.md` §2.4 + `docs/DESIGN.md` §8 | 新模組 M5 — Delivery Fidelity 的 PRD / 架構 / 介面契約（含 3 條 ADR）|
| **P2** | `tests/doc-drift.bats`（37 條）+ `tests/restruct-dav-reconciler.bats`（16 條）| 新探針（含 rc 契約、白名單 fail-closed、CI 接線守護、from-date 雙向驗證、跨平台改檔輔助）|
| **P2** | `scripts/ci/mutants.tsv` | 登錄 **4 支** mutant（DD-M1 / DD-M2 / DD-M3 / DR-M1）證明新護欄真的會咬（**當時並未真的觀察到**——RECON-007 v1.0 解析器在 BSD grep 上本身壞掉、baseline 紅 → `mutant-must-die.py` 整表中止 → 四支守護實際上是失效狀態；**首次真正實測 4 支全死在 v2.12（見 v2.12 實測證據）**）|

**二審結論（V03 Reviewer）**：

| 輪次 | 結論 | 處置 |
|------|------|------|
| 第 1 輪 | ❌ request-changes（1 P0 / 4 P1 / 10 P2 / 5 P3），現狀不可合併 | **P0**：新探針用 macOS-only 的 `sed -i ''` → Ubuntu CI 腿會紅（4 條探針失效）；**P1**：CI 接線無探針守護、全域 changelog / SOP 版本未登錄且冒用已發布的 v2.1、CHANGELOG 預先宣告「二審通過」、新機制未自我套用（無對帳表 / deliverable）；**P2**：AC 與實作不同字、5 類 vs 6 類、狀態詞彙表與 backlog 定義不符、ac README 未補 TMO 形式、HTML 連結文字矛盾、作廢 R-ID 與 3 種狀態死結、D4 只固化放寬未證明會檢查、未登錄 mutants.tsv、DESIGN 宣稱不存在的檢查、PRD 自身狀態未更新；**P3**：AGENTS 標題與 mandatory_phrase 敘述、❌ 未完成不可達、範例過時、審查產物落在 docs/、DOC-DRIFT-007 無空集合守護 → **全修**（處置見下表）|
| 第 2 輪 | ❌ request-changes（1 P0 / 3 P1 / 6 P2 / 6 P3），現狀不可合併 | **P0**：`skills/dav-reconciler/SKILL.md` 的「專案端」標記讓既有探針 `restruct-zero-cross-read.bats` 轉紅（Gate 3 失敗）→ 已改「目標專案」；**P1**：DOC-DRIFT-029 未孤立（宣稱已修但 fixture 未改）、權威對帳表與交付摘要對殘餘缺口的描述互相矛盾、第 2 輪 verdict 缺席（迴圈引用）；**P2**：backlog 宣稱不存在的檢查、html 重複純文字 ID、DOC-DRIFT-022 的 CI 假綠守護視窗有洞、dav-submitter 變動歷史 4 條超上限、PRD / 交付摘要數字過時；**P3**：emoji 未正規化回傳值、mutant docstring 算式、狀態詞彙別名未登錄、gates.json 反向鎖缺檔假綠、交付摘要用不存在的簡寫路徑、DESIGN 訊息樣式與實輸出不符 → **全修**（處置見下表）|

**本輪處置明細**（第 1 輪 20 項全部處置）：

| # | 級別 | 指摘 | 處置 |
|---|------|------|------|
| 1 | P0 | `sed -i ''` 在 Ubuntu 腿失效 | 改用跨平台 python3 改檔輔助 `_replace_in_file`（4 處全改）|
| 2 | P1 | CI 接線無守護 | 新增 DOC-DRIFT-022（鎖 CI 步驟存在 + 禁 `continue-on-error` / `\|\| true`）|
| 3 | P1 | 全域 changelog / SOP 版本未登錄、冒用 v2.1 | SOP v2.1 → **v2.2**；本檔加 v2.11 條目 + 二審結論節；`2.3` / `2.4` 標註改 v2.2；`tests/restruct-agents-md.bats` 同步（並加 v2.11 與 Gate 4.5 兩條新探針）【該探針已於 v2.13 減法刪除，本列為歷史記錄】|
| 4 | P1 | CHANGELOG 預先宣告「二審通過」 | 改寫為真實 verdict（第 1 輪 request-changes → 已修 → 第 2 輪見本節）|
| 5 | P1 | 新機制未自我套用 | 本次即以新機制完成自己：產 3 份對帳表 + 本次 deliverable（含 §3.1 需求對帳段）|
| 6 | P2 | AC 與實作不同字（②同字比對）| 統一改為「AC 編號連續且唯一」|
| 7 | P2 | 5 類 vs 6 類 | 全域統一（PRD / AC / backlog / system-design / DESIGN / CI）；**第 2 輪後再統一為 8 類（D1..D8）**（對帳第 2 輪要求：新增 D7 / D8 也要同步）|
| 8 | P2 | 狀態詞彙表不符 | `STATUS_VALUE` 擴充為 backlog.md 宣告的單一來源詞彙（todo/doing/done/blocked/待決…）；本批新列改用 `doing (2026-10-26)` |
| 9 | P2 | ac README 未補 TMO 形式 | 已補（`US-<編號>` 與 `TMO-<nnn>` 兩種形式並存，探針以檔名 stem 為 key）|
| 10 | P2 | HTML 連結文字矛盾 | US-M62 / US-M63 的 html 連結文字改為對應 ID |
| 11 | P2 | 作廢 R-ID 與 3 種狀態死結 | 對帳狀態擴為 **4 種**（加 🚫 已作廢；列出但不列入交付狀態判定）；planner / reconciler / 探針三處同步 |
| 12 | P2 | D4 只固化放寬 | 新增 DOC-DRIFT-023（`--from-date` 拉早 → 範圍內交付**會**被檢查）；CI 步驟顯式帶 `--from-date` |
| 13 | P2 | 未登錄 mutants.tsv | 登錄 DD-M1 / DR-M1（實測：baseline 綠 → 突變紅 → 2 支全死）|
| 14 | P2 | DESIGN 宣稱不存在的檢查 | 刪除誤導句，改為指 deliverable 模板 §3.1 |
| 15 | P2 | PRD 自身狀態未更新 | 追溯矩陣改「✅ 已實作」+ DoD 逐項勾選 |
| 16 | P3 | AGENTS 標題 / mandatory_phrase 敘述 | 標題改「4 大 Gate + Gate 4.5 子關卡」；TD-016 補例外說明 |
| 17 | P3 | ❌ 未完成不可達 | 門檻表補「全數 ❌ → 可標 ❌ 未完成」|
| 18 | P3 | 範例過時 | `examples.md` 範例 B 改為中性示範缺口 |
| 19 | P3 | 審查產物落在 docs/ | 移出 repo（改放暫存目錄）|
| 20 | P3 | DOC-DRIFT-007 無空集合守護 | 已補 `count > 0` 守護 |

**第 2 輪處置明細**（第 2 輪 16 項全部處置）：

| # | 級別 | 指摘 | 處置 |
|---|------|------|------|
| 21 | P0 | 新 skill 讓 `restruct-zero-cross-read.bats` 轉紅 | `skills/dav-reconciler/SKILL.md` 4 處「專案端」→「目標專案」；**同時發現該探針 3 支測試名含中文被 bats 1.14 靜默跳過** → 改 ASCII 名讓它們真的跑（跑出即抓到上項違規）|
| 22 | P1 | DOC-DRIFT-029 未孤立 | fixture 改為「權威表與內嵌表都 ⚠️ + 舊欄位名」→ 唯一紅因 = gaps 分支；加負向斷言 |
| 23 | P1 | 對帳表 ↔ 交付摘要敘述矛盾 | 三份對帳表依最新一輪對帳判定重寫；交付摘要 §5 對齊 |
| 24 | P1 | 第 2 輪 verdict 缺席 | 本節補第 2 輪列（並修正第 1 輪處置 #4 的懸空引用）|
| 25 | P2 | backlog 宣稱不存在的檢查 | 主表列舉補 ⑦⑧；詳細 AC-1 ② 改「AC 編號連續且唯一」|
| 26 | P2 | html 重複純文字 ID | `US-M62.html` / `US-M63.html` 刪掉 anchor 前重複的純文字 ID |
| 27 | P2 | DOC-DRIFT-022 守護視窗有洞 | 改「從 `- name:` 起算 + 剝註解 + 轉小寫比對」，並加 DOC-DRIFT-034 反向自測 |
| 28 | P2 | dav-submitter 變動歷史超 3 條 | 刪 v2.1 列（v2.0 起完整條目在 CHANGELOG）|
| 29 | P2 | PRD / 交付摘要數字過時 | PRD 行數預檢改實際值（120/121/140）；交付摘要 §3 改 14 項檢查；簡寫路徑改實際檔名 |
| 30 | P3 | emoji 未正規化回傳值 | `deliverable_status()` 回傳值套 `norm_emoji()` |
| 31 | P3 | mutant docstring 算式 | 「+5」→「+4」 |
| 32 | P3 | 狀態詞彙別名未登錄 | backlog 狀態定義段補列相容舊值（`pending` / `in_progress` / `deferred` / `cancelled` / `進行中` / `待辦`）|
| 33 | P3 | gates.json 反向鎖缺檔假綠 | `restruct-agents-md.bats` 加 `[ -f gates.json ]` 前置檢查【該探針已於 v2.13 減法刪除，本列為歷史記錄】|
| 34 | P3 | 交付摘要用不存在的簡寫路徑 | 改實際檔名；D4 的 `~` 區間簡寫改由 `expand_paths()` 展開（不靠檔名碰巧不含 `~`）|
| 35 | P3 | DESIGN 訊息樣式與實輸出不符 | §8.4 改成貼腳本實際輸出樣式 |
| 36 | P2 | D4 路徑簡寫誤判（對帳第 4 輪）| `expand_paths()`：`X.md/.html` → `X.html`；`X-069~071.md` → 編號區間展開；新增 DOC-DRIFT-032 / 033 |

**Gate 4.5 需求對帳的第一次實戰**（本機制的首度自我套用，5 輪獨立對帳）：

| 輪次 | 對帳結果 | 處置 |
|------|----------|------|
| 第 1 輪 | 5 ✅ / 2 ⚠ | 指出 7 條缺口（無「對帳表 R-ID 覆蓋」探針、無「交付狀態 ↔ 對帳結果」機械檢查、未自我套用、install 部署面、白名單 2 項、changelog 宣稱與實況不符、PRD 未更新）→ 全修（新增 D7 / D8）|
| 第 2 輪 | 5 ✅ / 2 ⚠ | 抓出 **N1**：D8 讀不到官方模板的 `**交付狀態**` 欄位 → 硬門檻在真實路徑上是假綠；另抓 N2（兩份官方交付模板互斥）→ 已修（欄位名統一 + D8 改讀權威表）|
| 第 3 輪 | 5 ✅ / 2 ⚠ | 抓出**位元組級落差**（`⚠️` 的 U+FE0F 差異 → 照 spec 寫的對帳表會被判「狀態值不合法」）、D8 以 R-ID 為全域鍵（多 US 交付摘要誤紅）、2 支探針未孤立 → 全修（`norm_emoji()` + 多重集比對 + 孤立性斷言）|
| 第 4 輪 | 5 ✅ / 2 ⚠ | 抓出「宣稱已修但 fixture 未改」（DOC-DRIFT-029 仍不孤立）、D4 路徑簡寫仍誤判、交付摘要用了不存在的簡寫路徑 → 全修（`expand_paths()` + 探針 032/033/035）|
| 第 5 輪（終審）| 5 ✅ / 2 ⚠ | 029/030 已孤立、R-ID 作用域已修、emoji 已正規化、敘述數字已收斂；殘餘＝D4 數字區間分支的探針本輪才補（DOC-DRIFT-035）待複核、端到端需可執行證據 → **交付狀態依硬門檻 = ⚠️ 部分完成**，backlog 三列維持 `doing` |

> **這段歷史本身就是機制的價值證據**：本次交付被自己的機制擋在「⚠️ 部分完成」，而不是被寫成「✅ 完成」——
> 這正是 `dav-reconciler` 規則要的效果（自己宣稱已修的 4 處被獨立對帳者逐條抓出）。

**探針「會咬」實測**（突變 → 必須紅）：

> ⚠️ **v2.12 更正**：本表 4 列的「✅ 紅（baseline 綠 → 突變 rc=1）」是**當時並未真的觀察到**的宣稱——
> RECON-007 v1.0 的解析器在 macOS/BSD grep 上本身是壞的（baseline 紅）→ `mutant-must-die.py` 的
> baseline 迴圈 `die()` → **整個表中止** → 下表 4 支（含 DD-M1..M3）實際上**一次都沒被跑到**。
> 修好 RECON-007 後才**第一次真的跑完**（4 baseline 全綠 + 4 支全死）→ 見 **v2.12 實測證據**。

| 突變 | 預期 | 實測 |
|------|------|------|
| DD-M1：`check-doc-drift.py` 的 D6 報錯改成 `pass` | DOC-DRIFT-017 紅 | ✅ 紅（baseline 綠 → 突變 rc=1）— **首次真實觀察於 v2.12** |
| DD-M2：D7 覆蓋率檢查改成 `if False:` | DOC-DRIFT-024 紅 | ✅ 紅（baseline 綠 → 突變 rc=1）— **首次真實觀察於 v2.12** |
| DD-M3：D8 狀態矛盾檢查改成 `if False:` | DOC-DRIFT-028 紅 | ✅ 紅（baseline 綠 → 突變 rc=1）— **首次真實觀察於 v2.12** |
| DR-M1：刪掉 `reconcile-format.md` 的「🚫 已作廢」狀態列 | RECON-007 紅 | ✅ 紅（baseline 綠 → 突變 rc=1）— **首次真實觀察於 v2.12** |

**決策紀錄**：

- **為什麼 Gate 4.5 不進 `gates.json`**：該檔的 schema 限定 gate `id` 符合 `^gate-[0-9]+$`（整數），
  而 Gate 4.5 是排在 Gate 4 之後、§2.4 之前的**子關卡**，不是第五道大 Gate。gates.json v1.1.0 曾移除
  Gate 5（RSI 機制歸檔）——那是「整道 Gate 從流程上消失」，與本案性質不同。
  **代價**：gates.json 對「子關卡」不再 SSOT（四道大 Gate 仍是）→ 已在 ADR-D1 與 handbook 明文化。
  【事後註記 2026-10-26 v2.14：四道大 Gate 的**定義本體**已改由各自承載它的 skill 負責，`gates.json` 為機器可讀副本。】
- **為什麼對帳狀態要有第 4 種「已作廢」**：規劃階段允許「需求被砍掉」（R-ID 不可刪），
  若對帳只有 3 種狀態，被砍的需求會永遠卡住交付 → 死結。加「已作廢」後：仍須列出（不可省略），
  但不列入交付狀態判定。
- **為什麼 D4 只檢 from-date 之後的交付**：歷史交付宣稱的檔案多已刪 / 改名，回溯檢查必假紅；
  「當下寫的宣稱必須成立」是合理原則。**這是門檻放寬**（V03.6 定義 ①②）→ 已加反向探針證明
  範圍內的交付會被檢查，且 CI 步驟顯式帶 `--from-date` 讓放寬在 log 可見；延長 from-date 視為放寬，需再走 V03。
## v2.10 — 2026-10-23

**本版異動**：§2.0 登錄 trust mode 為第三條 SOP 路徑（執行段），並同步 §2.6 一般任務章節的例外條款

| 類型 | 項目 | 說明 |
| ---- | -- | ---- |
| **P0** | `AGENTS.md` §2.0 任務類型表 | 新增「信任模式（trust mode）」列 → 執行段（§2.3 → §2.5）；規劃 / 設計屬啟動前置條件 |
| **P0** | `AGENTS.md` §2.0 判斷責任歸屬 | 新增 trust 條：走執行段；§2.1 / §2.2 屬啟動前置條件（需用戶互動、trust 內不跑）；啟動判準見 dav-trust preflight 子檔 |
| **P1** | `docs/sop/handbook/2.6-general-task.md` | 檔頭 + 升級觸發器表下方新增「trust mode 進行中不適用本節 / 上表升級觸發器不套用」例外；升級判斷改由 trust-log 與 need-you-help 承載 |
| **P1** | `docs/sop/handbook/2.1-planning.md` + `2.2-design.md` | 兩章節各加例外 blockquote「本節僅適用於非 trust 的開發編程任務路徑；規劃 / 設計是 trust 啟動前置條件」 |
| **P1** | `docs/sop/handbook/2.3-execution.md` | 三種策略表後加例外 blockquote：`ask_user` 策略 / fallback 在 trust 進行中不適用（改記 trust-log + need-you-help）；`gates.json` schema 不變 |
| **P1** | `docs/sop/handbook/2.4-reflection.md` + `skills/dav-reflection/SKILL.md` | 加 trust 例外：「Sprint / Module 必須有用戶參與確認」在 trust 進行中不適用（Action Items 一律寫 backlog；待決事項寫 need-you-help）|
| **P1** | `tests/restruct-agents-md.bats`（已於 v2.13 刪除）| 新增 8 條探針（§2.0 trust 列含負向斷言不得含 §2.1 / §2.2、判斷責任歸屬區塊前置條件、§2.6 例外完整片語、一般任務列仍在、§2.1 / §2.2 trust 提示、§2.3 ask_user 例外、§2.4 用戶參與例外、changelog v2.10 + 二審結論節）+ 改寫 1 條（守 SOP 現行版本 v2.1）|
| **P2** | `AGENTS.md` §2 標題 + 變動歷史 | §2 SOP 流程 v2.0 → v2.1、變動歷史加 v2.1 列（欄位名改「SOP 版本」、合併 v2.0 重號兩列）|

**二審結論（V03 Reviewer）**：

| 輪次 | 結論 | 處置 |
|------|------|------|
| 第 1 輪 | ⚠️ approve with comments（3 P1 / 9 P2），現狀不可合併 | P1：§2.0「不開例外」矛盾句未修（trust 與 dev task 無優先序）、本檔二審結論節懸空引用、TMO-067 仍 `todo`；P2：一般任務條款未加 trust 限定、§2.6 違規處理未排除、範例對照未註 trust、pointer 指向偏、README 未列第三路徑、§2.1 / §2.2 章節無 trust 提示、版本序號混淆、探針 ② 弱 / ③ 鬆、「本次未動」清單不完整 → **全修** |
| 第 2 輪 | ⚠️ approve with comments（1 P1 / 8 P2），現狀不可合併 | **P1**：trust 真正會跑的 §2.3（`ask_user` 策略）與 §2.4（用戶參與確認 = Reflection Gate 通過條件）無 trust 例外 → 死鎖；P2：探針數字錯、changelog 敘述低估、skill 三處仍寫「待補」、缺 changelog 守護探針、條列順序與優先序不一致、探針會咬證據未示範、deliverable v2.0 易誤讀 → **全修** |
| 第 3 輪 | ⚠️ approve with comments（1 P1 / 9 P2），現狀不可合併 | **P1**：§2.4 的「operational 條款」（通過條件 5、「假裝通過」清單、Sprint/Module 觸發時機與 Step 5 動作/產出/證據）未就地例外 → 依字面仍會被判「假裝通過」→ 死鎖；P2：AGENTS.md §2.3 無 trust 例外摘要、§2.7 升級條款仍指向 §2.1、dav-reflection 未登錄變動歷史 + 無守護探針、§2.0 表列順序、§2.6 範例第二列、§2.0 探針守護缺口、缺第 3 輪登錄、缺 deliverable → **全修**；依第 3 輪 reviewer 指示「修完可逕行合併、不需再排一輪二審（僅需補貼修後綠燈輸出）」結案 |

**探針「會咬」實測**（突變 → 必須紅，做完還原）：

| 突變 | 預期 | 實測 |
|------|------|------|
| 刪掉 §2.0 表「一般任務」列 | 探針「general-task row still present」紅 | ✅ 紅 |
| trust 列的 SOP 欄改成含 §2.1 | 探針「trust mode registered as third path」紅 | ✅ 紅 |
| §2.1 只出現在「舉例」欄 | 限欄後不誤紅 | ✅ 全綠 |

**決策紀錄**：

- **為什麼要改**：dav-trust v2.3 把「規劃 / 設計」從 trust 的執行階段改成**啟動前置條件**（兩者強制用戶互動、
  與 trust「中途不問用戶」互斥）；但 AGENTS.md §2.0 仍寫「開發編程任務 → 一律走完整 SOP，不開例外」
  → agent 先讀 AGENTS.md 時會在 trust 內跑 §2.1 / §2.2，回到「啟動即注定卡死」（TMO-067）
- **為什麼不寫成「例外」而是「第三條路徑」**：trust 不是「一般任務的例外」，它有**自己的入口條件**
  （大目標 + deadline + 既有 backlog / 設計），與前兩類任務的分類維度不同 → 開一列更誠實
- **§2.6 為何要加例外**：§2.6 的「溝通 & 思考（問用戶）」與「自動升級觸發器（停下等用戶確認）」
  與 trust 直接互斥 → 不加例外，agent 在一般任務分支誤判時會在 trust 內停下問用戶
- **本次未動**：`dav-planner` / `dav-designer`（trust 內本來就不跑它們）、`gates.json`（4 Gate 定義與 schema 不變；
  trust 例外寫在 §2.3 handbook，不改 schema）、`docs/sop/handbook/2.5-submission.md`（無強制用戶確認步驟）、
  `docs/system-design.md`（歷史設計文件，非 SOP 規範）
- **下次升版待辦（避免漏改）**：SOP 版本字串 `v2.2` 當時硬編於 `AGENTS.md`（§2 標題 + 變動歷史）與
  `docs/prd/05-delivery-fidelity.md` 共 3 處。**2026-10-26 更新：`AGENTS.md` 的 2 處已隨 §2 移除，只剩 PRD 05 1 處。**
  （原註記提到的守版探針 `tests/restruct-agents-md.bats` 已於 v2.13 隨 meta 探針減法刪除）

---

## 歷史版本索引（v2.10 之前）

> **為什麼收斂**：本檔從 24 版膨脹到 979 行，是框架自我管理層最大的單一檔案。
> 舊版全文已收斂為一行索引；完整內容保留在 git history（`git log -p -- docs/sop/handbook/changelog.md`）。
> 索引行**刻意保留原始關鍵字**（版本號、TMO 編號、機制名稱）——多支探針以 whole-file grep
> 驗證「某版本條目記載了某規則」，改寫關鍵字會讓那些探針假紅。

| 版本 | 一行摘要 |
|------|----------|
| v2.9 | 本版異動：3 個 skill 補充 Module 細節 + 建 Module 範例專案（四 commit 進連環重構，補完 v2.8 的「Module 設計 → 交付」閉環）｜`skills/dav-submitter/SKILL.md` v2.1 + `template.md` v2.1 ／ +「為什麼必含」+ §1.2「為什麼做這個改動」+ §2.4「改動背後的理由」+ §6.1「為什麼這個優先」；`skills/dav-submitter/SKILL.md` v2.2 + `module-delivery.… |
| v2.8 | 本版異動：3 個 skill 拆檔 + Module 感知邏輯實作（三 commit 進連環重構）｜`skills/dav-skill-creater/SKILL.md` 拆檔（v2.5） ／ 主檔 223 → 147 行；「SKILL.md 編寫準則」+「變動歷史外移規範」→ `editor-guide.md`（92 行）；主檔只留 3 條最高頻規則；`skills/regression-guard/SKILL.md` 拆檔（v2.9） ／ 主檔 714 → 120 行；Jev Oracle 506 行 → `… |
| v2.7 | 本版異動：所有 skill 的「變動歷史外移」重構（跨 10 skill、dav-skill-creater 新增規範）｜10 個 skill 新增 `CHANGELOG.md` ／ dav-planner / dav-designer / dav-wiki / dav-skill-creater / dav-submitter / dav-reflection / dev-checker-loop / dav-trust / tdd-test-writer / regression-guard 各自創建 CHA… |
| v2.6 | 本版異動：`skills/dav-designer/` 重構（Module 定義 + 拆檔、雙提交 v2.3 + v2.4）｜`~/.pi/agent/skills/dav-designer/SKILL.md` Step 1 加 Module 目的與切割原則 ／ Module 定義為「可獨立開發 / 增減 / 測試」的功能單位；附 5 條切割原則（功能內聚 / 低耦合 / 可獨立交付 / 可獨立測試 / 粒度適中）與反例；`~/.pi/agent/skills/dav-designer/SKILL.md` Ste… |
| v2.5 | 本版異動：`skills/dav-planner/` 重構（減法 + 職責收斂，雙提交 v2.1 + v2.2）｜`~/.pi/agent/skills/dav-planner/SKILL.md` 刪除 §2.7 整套（用戶背景收集） ／ 拿掉「對話用戶角色詢問」（v1.9 功能）；dav-planner 定位收斂為「釐清任務的背景 / 最終目的 / 驗收標準」；`~/.pi/agent/skills/dav-planner/SKILL.md` 流程 Step 1 移除 ／ 原「收集用戶背景」整步刪除，後續 4… |
| v2.4 | 本版異動：docs/ 批量減法（TMO-010）｜刪 `docs/sop/handbook/dav-wiki-cleanup.md` ／ 孤立檔（0 引用、9KB），內容已重複在 `skills/dav-wiki/SKILL.md`；刪 `docs/deliverable/2026-09-26-dav-planner-ac-templates.html` ／ v1.8 存量 HTML（14KB），v2.0 起禁止產出；刪 `docs/deliverable/2026-09-26-dav-planner-user-… |
| v2.3 | 本版異動：dav-skill-creator 對「修改既有 skill」亦生效（TMO-009 階段 11c）｜`skills/dav-skill-creater/SKILL.md` 觸發時機表加「修改既有 skill」 ／ 任何 `skills/<name>/SKILL.md` 被修改都必走修改流程；`skills/dav-skill-creater/SKILL.md` 新增「修改既有 skill」流程 ／ M-Step 1（讀舊版 + 評估規範偏差）/ M-Step 2（套用變更 + 清偏差）/ M-Step… |
| v2.2 | 本版異動：跨目錄讀檔引用零容忍（TMO-009 階段 11b）｜skill 內跨目錄讀檔引用零容忍 ／ 禁止「讀 docs/xxx」、「見 docs/xxx」、「見 skills/other-skill/SKILL.md」這類「去讀別的 dir 檔案」的引用；9 個 SKILL.md 全清跨目錄讀檔引用 ／ dav-planner / dav-reflection / dav-submitter / dav-trust / dav-skill-creater / dav-wiki / regression-gua… |
| v2.1 | 本版異動：重結構 — 9 skill + AGENTS.md 改為「任務導航」5 段 + 純文字引用（TMO-009）｜9 個 SKILL.md 重組為「任務導航」5 段 ／ dav-reflection / dav-submitter / dav-planner / dav-trust / dav-wiki / regression-guard / tdd-test-writer / dev-checker-loop / dav-skill-creater 統一 TL;DR / 觸發時機 / 流程 / 規則 /… |
| v2.0 | 本版異動：減法 — 文件產出物精簡（TMO-008）｜`skills/dav-submitter/SKILL.md`「三層產出物」→「兩層產出物」 ／ 未來 sprint 不再生成 `docs/deliverable/<...>.html`；對話摘要 + Markdown 詳錄（反思併進末段）即可；`docs/sop/handbook/2.5-submission.md` 取消 HTML 強制 ／ Self-Check 清單移除「HTML 版存在且可開啟」項；`docs/sop/handbook/2.4-refl… |
| v1.9 | 本版異動：dav-planner skill 新增「用戶背景收集」機制（TMO-007）｜`dav-planner/SKILL.md` §2.7 新增「用戶背景收集」 ／ dav-planner 啟動後第一題，先問用戶角色（PM/開發者/設計師/業務/其他），依角色動態選擇追問（PM→目標用戶/規模、Dev→技術棧/團隊、設計師→品牌規範、業務→目標市場）；`dav-planner/SKILL.md` §2.7.1 新增「跳過規則」 ／ 同專案後續對話或用戶明確說「直接問需求」時可跳過角色題，但 Agent 必須… |
| v1.8 | 本版異動：dav-planner skill AC 範本獨立化 + HTML 版本（TMO-006）｜`dav-planner/SKILL.md` §4.3.2 新增「AC 欄位精簡規則」 ／ backlog.md 表格 AC 欄位精簡為「AC 摘要（≤ 30 字 + 連結）」；完整 Given-When-Then + DoD 寫到 `docs/ac/<US-ID>.md`；`dav-planner/SKILL.md` §4.6 新增「AC 範本生成 SOP」 ／ Agent 生成新 US 時必做 3 動作（同一… |
| v1.7.1 | 本版異動：v1.7 後續技術債清理（UTF-8 bug + `.agents/` 歷史殘留 + TMO-005 關閉 + 順手修 latent bug）｜5 個 bats 中文 test name 改為英文 ／ `dav-wiki.bats`、`ci-linux.bats`、`wiki-cleanup.bats`、`wiki-cross-ref.bats`、`wiki-cross-ref-multimodal.bats` 共 ~47 個 test 改為純 ASCII 名（移除中文括號內容 / 中文描述）；功能保留… |
| v1.7 | 本版異動：dav-wiki 工具目錄重組（從 `tools/wiki-*.sh` → `skills/dav-wiki/scripts/wiki-*.sh`）｜`skills/dav-wiki/scripts/` 新建 ／ 9 個 wiki-*.sh 從 `tools/` 搬入；dav-wiki skill 變 self-contained；`wiki-extract-media.sh` 內 OCR 呼叫改 sibling ref ／ 原用 `$REPO_ROOT/tools/wiki-ocr.sh` 會解析為… |
| v1.6 | 本版異動：dav-planner skill 新增 SWOT 分析機制（關鍵決策點展開）｜`~/.pi/agent/skills/dav-planner/SKILL.md` §2.6 新增「關鍵決策點 SWOT」 ／ 4 個觸發條件（不可逆變更 / 高成本 / 用戶糾結 / 戰略級影響）+ SWOT 標準格式 + V01 相容的逐項追問節奏 + V02 復用條款 + 自我檢查清單 + 情境 A/B 對照範例；`dav-planner/SKILL.md` §4.3.1 新增「SWOT 落版規則」 ／ 只記最終選項的… |
| v1.5 | 本版異動：修正 §2.0 表格與 §2.6 之間的立場矛盾（從「角色混淆」重新定位為「自動升級規則不一致」）｜`AGENTS.md` §2.0 表格補上「升級觸發器」說明 ／ 原本寫「一般任務 → Agent 與用戶都可主動判斷」，跟 §2.6 「必須停下問用戶」衝突。改為「以 §2.6 為準」，並引用 §2.6 的升級觸發器表格；`2.6-general-task.md` 加準則聲明 ／ 在檔頭明示「本檔為 §2.0 表格的準則源頭」避免未來誤看 §2.0 簡述而違反「自動升級必須停下確認」規則 |
| v1.4 | 本版異動：Gate 3 測試指令禁用 interactive / watch 模式（防 session 卡死）｜`skills/regression-guard/SKILL.md` 加「測試指令執行規範」章節 ／ 主流 runner 對照表（vitest/jest/npm test/bats/pytest/playwright/cargo/go）+ TTY 強制關閉法 `< /dev/null` + Fail-fast 自檢條件；`docs/sop/gates.json` Gate 3 `notes` 加 wat… |
| v1.3 | 本版異動：SOP 加 `remediation` 策略欄位（TD-019）｜`gates.schema.json` 加 `remediation` 物件 ／ 定義 `strategy` enum（`auto_fix` / `auto_fix_with_limit` / `ask_user`）+ `max_attempts` + `fallback` + `description`；`gates.json` 4 個 Gate 加 `remediation` ／ Gate 1/3 = `auto_fix_with_l… |
| v1.2 | 本版異動：AGENTS.md 精簡重構（TD-017） |
| v1.1 | 本版異動：｜§2.1 Plan Gate (fail-fast) ／ V05 — 加用戶確認才可進 §2.2；§2.2 Design Gate (fail-fast) ／ V07 — 加 3 文檔 + Story Point + 用戶確認；§2.3 用戶確認才能進 Gate ／ V09 — Plan 確認才能進 §2.3；§2.3 subagent 機制明確化 ／ V13 — dev/reviewer via `subagent` + `workflowScript`；§2.4 Reflection Gate (… |
| v1.0 | v1.0 |
