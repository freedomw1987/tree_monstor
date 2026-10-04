# TMO-026 A 類探針 retarget（12 紅）+ 修 3 條 CJK 靜默假綠探針

**日期**：2026-10-04
**Backlog ID**：TMO-026
**作者**：Agent
**狀態**：✅ 完成

## 摘要

承 TMO-025 的餘下 **18 紅**，本輪清掉 **A 類 12 紅**（探針落後於 skill 拆檔），並附帶修掉 **3 條「從未被執行」的假綠探針**。

A 類的病因很單純、也很危險：v2.1–v2.9 期間各 skill 依「任務導航 + 子檔拆分」重構，把內文從 `SKILL.md` 搬進同 skill 子檔（`backlog-rules.md` / `runner-cheatsheet.md` / `jev-oracle.md` / `CHANGELOG.md`），但 regression 探針仍盯著舊位置找舊字串 → 一片紅。**這批紅不是回歸，是「探針與文件不同步」**；處理原則刻意定為「**retarget（把探針指向事實的新家）**」而不是「把內容搬回舊址（迎合探針）」——後者等於用探針鎖死重構自由，是更糟的債。

附帶挖到的第二個病：`bats` 1.14.0 對「`@test` 名稱含 CJK」**靜默不執行**（宣告 498 / 實跑 495，3 條消失），它們是**假綠**——永遠不出現在報告裡的「守門人」。本輪把 3 條改名為 ASCII 使其真的執行（且真的通過）。

全套由 18 紅 / 477 綠（宣告 498 / 實跑 495）→ **6 紅 / 492 綠（宣告 498 / 實跑 498）**，**0 新增失敗**，修好的正好是這 12 個 + 3 條復活的假綠。

## 變更清單

### 探針（6 檔，retarget 主體）

| 檔 | 改動 | 新家（事實所在） |
| --- | --- | --- |
| `tests/dav-planner-ac-templates.bats` | `AC 範本生成 SOP` 斷言移到子檔；補「主檔留有 `backlog-rules.md` 指標」 | `skills/dav-planner/backlog-rules.md:116` |
| `tests/regression-guard-watch-mode.bats` | `vitest run` / `jest --ci` / `< /dev/null` / `Watch Usage` 移到子檔；CROSS 測試改為**段落級**指標斷言 + 加 `gates.json` 的 `< /dev/null` 斷言 | `skills/regression-guard/runner-cheatsheet.md` |
| `tests/restruct-dav-planner.bats` | 變動歷史的 `v2.0` 斷言改讀 `CHANGELOG.md`；改為**版本漂移鎖**（主檔最新版 == CHANGELOG 最新版） | `skills/dav-planner/CHANGELOG.md:15` |
| `tests/restruct-regression-guard.bats` | 同上（漂移鎖）；TTY 測試：主檔斷 `watch|interactive`、子檔斷 `/dev/null` | `skills/regression-guard/CHANGELOG.md:21` |
| `tests/v2.1-jev-poc.bats` | SKILL-b → `jev-oracle.md`（+ 主檔指標斷言）；SKILL-d → `CHANGELOG.md`；M6-e / M6.1-e → `jev-oracle.md`（內文）+ `CHANGELOG.md`（TMO-016/017 紀錄） | `jev-oracle.md`、`CHANGELOG.md` |
| `tests/restruct-agents-md.bats` | **2 條 CJK 測試名改 ASCII**（`萬事原則 (soul) preserved` → `core principles (soul) preserved`、`變動歷史 section exists` → `change history section exists`）——改前根本沒被執行 | — |
| `tests/restruct-dav-planner.bats` | **1 條 CJK 測試名改 ASCII**（`V01/V02/V03 紀律 referenced` → `... discipline referenced`） | — |

### Skill 文案（1 檔 1 行）

- `skills/dev-checker-loop/SKILL.md:41`：`從 \`docs/backlog.md\` 領 PENDING 任務、讀 \`docs/system-design.md\` 拿 Module 綁定` → `從目標專案的 backlog（\`docs/backlog.md\`）領任務、取 system-design 拿 Module 綁定`
  - 為什麼：該行**命中自家 `restruct-zero-cross-read.bats` 的零跨目錄讀規則**（`(見|詳見|詳閱|參考|讀) \`?docs/`）。修法是**精確化語意**（明示這兩個路徑屬「目標專案」，不是 skill 自己去讀 monorepo），不是放寬探針。行長 174 → **120 字元**，順帶清掉 1 個 MD013。
- `skills/dev-checker-loop/SKILL.md` 變動歷史表刷新為 **v2.5 / v2.4 / v2.3**（原為 v2.3 / v2.2 / v2.1，與 CHANGELOG 最新 v2.4 脫節 → 二審 P2 抓到的「主檔陳舊」）。
- `skills/dev-checker-loop/CHANGELOG.md`：新增 **v2.5** 列（稽核鏈）。

## 測試 / 驗收證據

### Gate 1（TDD 紅→綠）

依 gates.json 規範，Gate 1 (TDD) 需要：測試先紅後綠，並在對話貼出 測試執行指令 + 失敗輸出 + 通過輸出。

改前（`git stash` 取原狀，逐檔）：

```
tests/dav-planner-ac-templates.bats        not_ok=1  ok=9
tests/regression-guard-watch-mode.bats     not_ok=3  ok=2
tests/restruct-dav-planner.bats            not_ok=2  ok=10   (Executed 12 instead of expected 13)
tests/restruct-regression-guard.bats       not_ok=2  ok=11
tests/restruct-zero-cross-read.bats        not_ok=1  ok=5
tests/v2.1-jev-poc.bats                    not_ok=4  ok=94
tests/restruct-agents-md.bats              not_ok=0  ok=8    (Executed 8 instead of expected 10)
```

改後（最終態）：

```
tests/dav-planner-ac-templates.bats        not_ok=0  ok=10
tests/regression-guard-watch-mode.bats     not_ok=0  ok=5
tests/restruct-agents-md.bats              not_ok=0  ok=10   (宣告 10 = 實跑 10 → 2 條假綠復活)
tests/restruct-dav-planner.bats            not_ok=1  ok=12   (剩 1 紅屬 TMO-027)
tests/restruct-regression-guard.bats       not_ok=0  ok=13
tests/restruct-zero-cross-read.bats        not_ok=0  ok=6
tests/v2.1-jev-poc.bats                    not_ok=0  ok=98
tests/restruct-dev-checker-loop.bats       not_ok=0  ok=22
```

**可證偽性（5 次突變，證明 retarget 與新斷言真的會咬人）**：

```
突變 1：搬走 skills/regression-guard/runner-cheatsheet.md      → watch-mode 3 紅（還原後 0）
突變 2：搬走 skills/dav-planner/backlog-rules.md               → ac-templates 1 紅（還原後 0）
突變 3：搬走 skills/regression-guard/jev-oracle.md             → v2.1-jev-poc 3 紅（還原後 0）
突變 4：搬走 skills/regression-guard/CHANGELOG.md              → v2.1-jev-poc 3 紅（還原後 0）
突變 5：把 SKILL.md 的指標行移出「TTY fail-fast」段落（仍在檔內）→ CROSS 1 紅
        `FAIL: SKILL.md TTY fail-fast section should point at runner-cheatsheet.md`（還原後 0）
突變 6：把主檔最新版改成與 CHANGELOG 不一致（v2.6→v2.5）        → restruct-dav-planner 2 紅（還原後 1）
突變 7：拿掉 docs/sop/gates.json 的 `< /dev/null`              → CROSS 1 紅（還原後 0）
```

### Gate 2（lint / syntax）

```
$ bats <each file>            → 0 parse warning（.bats 非 bash 語法，`bash -n` 不適用；以執行即解析驗證）
$ npx markdownlint-cli2@0.13.0 skills/dev-checker-loop/SKILL.md CHANGELOG.md
Summary: 1 error(s)
skills/dev-checker-loop/SKILL.md:51:121 MD013/line-length (Expected: 120; Actual: 193)
```

- 本輪無 `.sh` 改動 → shellcheck N/A
- `SKILL.md` 的 MD013 由 **2 → 1**（`:41` 那條是本輪修掉的）；剩下 `:51` 是**未觸碰的既有問題**（改前就存在，193 字元）

### Gate 3（regression）

```
$ bats tests/
1..498
not ok 31   SKILL: dav-planner documents user background collection (section 2.7)
not ok 32   SKILL: dav-planner section 2.7 has a role-to-followup mapping table
not ok 33   SKILL: dav-planner section 2.7 documents the skip rule (2.7.1)
not ok 34   SKILL: dav-planner section 2.7.2 distinguishes from §3 Persona
not ok 43   AC-2: SKILL.md is at most 150 lines
not ok 127  RESTRUCT-DAV-PLANNER: v1.9 §2.7 user background collection rule preserved
ok=492  not_ok=6           # 宣告 498、實跑 498（本輪前是 495）
```

- 對比 TMO-025 後 baseline（18 紅 / 477 綠 / 實跑 495）：**已修 12、新增 0**（腳本集合差 `comm -23/comm -13` 驗證）
- 剩下 6 紅分佈：**5 條 = TMO-027**（dav-planner §2.7 廢棄條款）、**1 條 = TMO-028**（`dav-wiki/SKILL.md` 151 行 > 150）
- 實跑數 +3 = 3 條 CJK 假綠探針復活（**宣告 498 == 實跑 498**，這條「帳目對齊」本身就是一個可持續的守門指標）

### Gate 4（reviewer）

依 gates.json 規範，Gate 4 需要 reviewer 原文回傳（agent 不自動修、由用戶裁定）。實跑 dev-checker-loop **兩輪**：

| 輪次 | 判定 | 風險 | P0/P1 | 主要意見 |
| --- | --- | --- | --- | --- |
| 1（主體 12 retarget） | approve-with-comments | low | **0 P0 / 0 P1** | 逐條驗證 11 個新家字串確實存在（附行號）；判定全屬「搬家追蹤」非「覆蓋率淨損」；3 條 CJK 改名安全（無名稱耦合）；7 條 P2 |
| 2（採納 P2 的 delta） | approve-with-comments | low | **0 P0 / 0 P1** | ①段落級斷言「真強化、非化妝」；⑥ skill 改寫「**實質修正、非字面規避**」（明列拆字規避判準並掃過全 repo）；明示 V03.6 **無任何放寬** |

二審原文關鍵句（第 2 輪）：「The round-2 delta strengthens the suite rather than weakening it: no loosened regex, no dropped guarantee without a successor-side assertion, and the four round-1 P2 suggestions that were acted on are genuinely hardened, not cosmetic.」

**Reviewer 逼出的自踩 bug（自身，已修）**：第 2 輪前我把 CHANGELOG 說明寫成「移除「讀 `docs/…`」語法」——這行**自己命中** zero-cross-read 正則而轉紅。修法是不引述該字面（「改寫為非跨目錄讀取式語法」），並在二審第 2 輪請 reviewer **專門判定此改寫是實質修正還是字面規避**（結論：實質，因為動詞被移除、路徑改以「目標專案的」限定語承載、且路徑資訊未消失）。

**採納的 3 條 P2 強化**（由 reviewer 提出、我實作、再加突變驗證）：① CROSS 改段落級（＋`gates.json` 一併斷言）；② 版本漂移鎖（主檔最新版 == CHANGELOG 最新版，正是二審抓到的陳舊型態）；④ `sed` range 改 `awk`＋`---` 終止符（避免範圍外誤綠）。

## 已知問題

- `bats tests/` 仍有 **6 紅**（5 條 TMO-027 dav-planner §2.7 廢棄條款 + 1 條 TMO-028 `dav-wiki/SKILL.md` 151 行）
- **未採納的 P2（進 backlog）**：
  1. `restruct-zero-cross-read.bats` 的 `SKILLS` 陣列漏掉 `skills/ask-me/SKILL.md`（其 `:10`/`:36` 真的寫了 `讀 \`docs/need-you-help.md\``）；`dev-checker-loop/module-rules.md:23,39` 同型。**刻意不動**：現在加進去會製造新的紅（違反本輪「0 新增」），應與「reword ask-me + module-rules」同批做
  2. `regression-guard/CHANGELOG.md:11,12` 有兩列同為 `v2.10`（重複版本號；無探針看守 monotonic）
  3. ③ 的「主檔→子檔指標」斷言仍是 whole-file grep（與 ① 同類「任何出現都算」）
  4. `dev-checker-loop` 的變動歷史探針（`restruct-dev-checker-loop.bats:44-56`）用 OR 分支（v2.x 列 **或** `CHANGELOG.md` 指標），**不會**抓到二審抓到的「主檔陳舊」型態；建議把本輪的漂移鎖移植過去
  5. `docs/sop/gates.json:62` / `docs/sop/handbook/2.3-execution.md:43` 仍指向 TMO-009 階段 7 已改名的「測試指令執行規範」章節
- **本輪改變了測試帳目**：宣告 498 = 實跑 498（前一輪是 495）；README badge 的 `209/209` 早已陳舊（另一票）

## 下一步建議（V20）

1. **驗收方式**：`bats tests/`（應 **6 not ok / 492 ok / 498 executed**）；`bats tests/regression-guard-watch-mode.bats tests/restruct-dav-planner.bats tests/restruct-regression-guard.bats tests/dav-planner-ac-templates.bats tests/v2.1-jev-poc.bats tests/restruct-agents-md.bats`（應 1 紅，即 TMO-027 那條）
2. **預估時間**：驗收 1.5 分鐘（全套 `bats tests/` 約 90 秒）
3. **風險提示**：本輪**沒有**恢復任何 skill 內文；`SKILL.md` 與子檔的「哪邊是事實家」由探針明文綁定（含主檔指標斷言），若未來再把內容搬第三次，探針會紅——這是刻意設計，請走 V03.6 更新探針而不是把內容搬回
4. 接著的 3 條路（推薦順序）：
   - **TMO-027**（5 紅）：dav-planner §2.7 已由用戶決策廢除 → 轉「廢棄守門」負向斷言（`refute_file_contains` helper 需先加）
   - **TMO-028**（1 紅）：`dav-wiki/SKILL.md` 151 → ≤150（走 V03 + 行數預檢）
   - **TMO-029**：venv bootstrap（`requirements.txt` + setup 腳本 + CI + 探針改「缺 venv 就大聲紅」）—— 目前乾淨 clone 會 **39 紅**，CI 一修 trigger 就會炸
5. **commit 建議**：本輪單獨 1 個 commit（探針層 + 1 行 skill 文案 + CHANGELOG）

## 反思

1. **「探針紅了」有三種完全不同的病，混在一起處理就會治錯**。這 18 紅表面同型（都紅），實際是三類：①探針落後重構（本輪 12，改探針）；②探針守著**已廢棄的功能**（TMO-027 的 5，該改成「廢棄守門」）；③產品/文件本身的缺陷（TMO-028 的 1，該改文件）。**如果把 ① 和 ② 一起「讓它變綠」，就會把「廢棄功能的守門人」偷偷刪掉**；所以我刻意把它們拆成不同票、不同決策（② 需要用戶選擇「刪除 or 轉負向斷言」）。這是本輪最重要的方法論收穫。
2. **retarget 是「追蹤事實」，不是「放寬門檻」——但這條界線只有加上「主檔指標斷言」才守得住**。如果只把斷言從 `SKILL.md` 移到子檔，會產生一個洞：未來有人把子檔刪掉/改名，主檔仍漂漂亮亮。所以每一條 retarget 都配了「主檔必須留有進子檔的指標」，並用突變測試（把子檔搬走 → 紅）證明。**「搬家」與「放寬」的差別，就在有沒有把指標也一起鎖住。**
3. **最安靜的債是「沒在跑的探針」**。3 條 CJK 測試名讓 bats 靜默跳過：報告上不紅也不綠，**宣告 498 / 實跑 495 的落差**才是唯一的線索。這比紅燈危險得多——紅燈會叫人，假綠不會。本輪把它救回來並讓「宣告 == 實跑」成為可稽核的指標。
4. **二審的價值第二次被證明是「咬到作者自己」**（上次是 `${var}` 全角地雷，這次是我引述自己的規則字串而踩線）。而且二審對我的「改寫」提出「這是修正還是字面規避？」的質疑，逼我建立判準（動詞是否移除、資訊是否隱藏、有無不可見字元）——**這條判準比這次的修法本身更值錢**，因為它能被套用到未來所有「被探針抓到才改」的場景。
5. **不足**：① 我把「主檔→子檔指標」斷言的 whole-file 弱點（P2-3）留著沒收緊，因為再加就會把 diff 從「探針 retarget」擴成「探針體系重寫」——這是一個自覺的取捨，代價是留了一個同型的小洞。② `ask-me` 的零跨目錄讀違規我**選擇不修**（修了要多改 2 個檔並可能引入新紅），等於用「本輪不擴大」換「一條已知違規繼續存在」——已明文進 backlog，下一輪必須償還。③ 這批紅燈是「別人重構留下的屍體」，我全程沒有質問「為什麼當初重構時沒同步改探針」——真正的根因是**改 skill 的流程裡沒有『探針同步』這一步**，本輪只在事後補。這應該是下一層的改善（可考慮在 V03 檢查清單加入「本次是否搬動了被探針斷言的內文」）。