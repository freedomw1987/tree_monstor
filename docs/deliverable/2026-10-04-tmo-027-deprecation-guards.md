# TMO-027 dav-planner §2.7「廢棄守門」探針（5 紅 → 0 紅）

**日期**：2026-10-04
**Backlog ID**：TMO-027
**作者**：Agent
**狀態**：✅ 完成

## 摘要

v1.9 的「用戶背景收集」（dav-planner §2.7：先問對話用戶角色 PM/開發者/設計師/業務，再依角色動態追問）已由**用戶決策**於 v2.1
廢除（理由：對話用戶角色對後續開發無實質幫助，反引導用戶進入「搞不清自己要什麼」的狀態）。但 5 條回歸探針仍斷言「§2.7 必須存在」→ 從 TMO-026 之後就一直恆紅。

本輪依用戶在 §2.7 處置題的選擇（**⭐ 轉「廢棄守門」探針**）把 5 條**存在型**探針改寫成 4 條**守門型**探針：**負向斷言**（廢除功能不得回流）+ **「為什麼廢除」的定位句必須留著** +
**廢除紀錄必須留著**（本地 CHANGELOG 列級錨定 + 全域 changelog）。新增 helper `refute_file_contains()`。

關鍵判斷：**沒有**走「把 §2.7 內容搬回 SKILL.md 迎合探針」這條路（那等於用探針否決用戶決策），也**沒有**走「直接刪掉 5 條探針」（那等於把守門人偷偷解僱）。結果：`bats tests/` 由 6 紅 →
**1 紅**（僅剩 TMO-028 的 dav-wiki 151 行），**已修 5 / 新增 0**。

## 變更清單

| 檔 | 改動 |
| --- | --- |
| `tests/helpers/test-env.bash` | +`refute_file_contains <path> <substring>`（負向斷言，與 `assert_file_contains` 同構）|
| `tests/dav-planner-user-background.bats` | 4 條「§2.7 存在」探針 → 3 條守門（檔內 7 tests → 6 tests）|
| `tests/restruct-dav-planner.bats` | 1 條「§2.7 preserved」探針 → 「retired (not re-introduced)」（13 tests 不變）|
| `docs/backlog.md` | TMO-027 → `done`；新增/修正 TMO-028~032 與「狀態定義」註 |

守門三件套（每條守門必含）：
1. **功能不得回流**：`refute_file_contains` × `用戶背景收集` / `角色詢問` / `PM/PO` / `業務`（掃
   `SKILL.md`、`reference.md`、`backlog-rules.md`）
2. **定位句必須留著**：`assert_file_contains "$skill" "不問對話用戶的個人角色"` + `"§3 Persona"`（防後人「看到缺章節就善意補回」）
3. **廢除紀錄必須留著**：本地 `CHANGELOG.md` **列級錨定**（`| v1.9 |` 必須帶 `已廢棄`、`| v2.1 |` 必須帶 `-§2.7 用戶背景收集整套`）+ 全域 changelog
   `刪除 §2.7 整套`

## 測試 / 驗收證據

### Gate 1（TDD 紅→綠）— 原始輸出（V03.6 要求「改前 fail / 改後 pass 兩次必貼」）

依 gates.json 規範，Gate 1 (TDD) 需要：測試先紅後綠，並在對話貼出 測試執行指令 + 失敗輸出 + 通過輸出。

```
$ bats tests/dav-planner-user-background.bats          # 改前（對應 HEAD 3639d00 的檔案）
1..7
not ok 1 SKILL: dav-planner documents user background collection (section 2.7)
# (from function `assert_file_contains' in file tests/helpers/test-env.bash, line 92,
#  in test file tests/dav-planner-user-background.bats, line 20)
#   `assert_file_contains "$skill" "§2.7"' failed
# FAIL: file .../skills/dav-planner/SKILL.md does not contain: §2.7
not ok 2 SKILL: dav-planner section 2.7 has a role-to-followup mapping table
#   `assert_file_contains "$skill" "PM/PO"' failed
not ok 3 SKILL: dav-planner section 2.7 documents the skip rule (2.7.1)
#   `assert_file_contains "$skill" "§2.7.1"' failed
not ok 4 SKILL: dav-planner section 2.7.2 distinguishes from §3 Persona
#   `assert_file_contains "$skill" "§2.7.2"' failed
ok 5 CHANGELOG: v1.9 entry documents user background collection rule
ok 6 BACKLOG: TMO-007 dav-planner user background entry exists
ok 7 PRD: docs/prd/02-dav-planner-user-background.md exists

$ bats tests/dav-planner-user-background.bats          # 改後
1..6
ok 1 DEPRECATED: dav-planner must not re-introduce section 2.7 user background
ok 2 DEPRECATED: role-to-followup mapping must not return (PM/PO)
ok 3 DEPRECATED: retirement of v1.9 section 2.7 is recorded (local + global)
ok 4 CHANGELOG: v1.9 entry documents user background collection rule
ok 5 BACKLOG: TMO-007 dav-planner user background entry exists
ok 6 PRD: docs/prd/02-dav-planner-user-background.md exists

$ bats tests/restruct-dav-planner.bats                  # 改前
1..13
... ok 1-7 ...
not ok 8 RESTRUCT-DAV-PLANNER: v1.9 §2.7 user background collection rule preserved
# (in test file tests/restruct-dav-planner.bats, line 76)  # `return 1' failed
# FAIL: skill should reference §2.7
ok 9-13 ...

$ bats tests/restruct-dav-planner.bats                  # 改後
1..13（0 not ok，全綠，含改名的 ok 8 "…v1.9 section 2.7 retired (not re-introduced)"）
```

### Gate 2（lint / syntax）

```
bash -n tests/helpers/test-env.bash        → rc=0
shellcheck tests/helpers/test-env.bash     → rc=0（0 issue）
bats <兩個改動檔>                           → 0 parse warning

bash -c 'if grep -F -q x /nonexistent; then echo MATCH; fi; echo rc=$?'
grep: /nonexistent: No such file or directory
rc=0
```

（最後一條是**刻意驗證假綠機制**：`grep` 對不存在檔案 rc=2 → `if` 不成立 → 函式無條件落到尾端回 0＝PASS。此模型經實跑確認，也是本輪 P2-1 的成因。）
測試名全 ASCII → 不踩 bats 1.14「CJK `@test` 靜默不執行」的坑（TMO-026 教訓）。

### Gate 3（regression）

```
$ bats tests/
not ok 42 AC-2: SKILL.md is at most 150 lines
ok=496  not_ok=1        # 宣告 497、實跑 497
```

- 對比 TMO-026 後 baseline（6 not ok / 492 ok / 實跑 498）：**已修 5、新增 0**（集合差比對）
- executed 498 → 497 = 該檔 7 → 6 tests；ok 492 → 496 = +3（該檔）+1（`restruct-dav-planner`）
- 剩下唯一 1 紅 = `skills/dav-wiki/SKILL.md` 151 行 > 150，屬 **TMO-028**

### Gate 4（reviewer，V03.6 二審 2 輪）

依 gates.json 規範，Gate 4 需要 reviewer 原文回傳（agent 不自動修、由用戶裁定）。實跑 dev-checker-loop **兩輪**：

| 輪次 | 範圍 | 判定 | 風險 | P0/P1 | 主要發現 |
| --- | --- | --- | --- | --- | --- |
| 1 | 主體（5 探針 → 4 守門） | approve-with-comments | low | **0 P0 / 1 P1** | P1-1 = V03.6 原始 bats 輸出未貼；P2-1 = `refute` 對不存在檔案假綠；P2-2 = whole-file 負向 `§2.7` 未來會誤紅；P2-3/P2-4 = PRD/backlog 麵包屑、`SKILL.md:73` 舊步驟名 |
| 2 | delta（採納 P2-1/P2-2） | approve-with-comments | low | **0 P0 / 0 P1** | 新增 P2-a（helper 假綠未根除）、P2-b（`SKILL.md` 變動歷史段會誤紅）、P2-c（本檔帳目小誤）→ 全 report-only |

- 第 1 輪判定原文關鍵句：「**放寬要件不成立**；唯一觸及定義①字面的是『舊斷言標的已被用戶決策廢除』——這是**規格變更**後的探針重定位，不是為了變綠而放寬」；覆蓋率判定「**非淨損**（新探針擴大了覆蓋面：多查
  `reference.md`、`backlog-rules.md`、本地 CHANGELOG 列、全域 changelog）」。
- 第 2 輪判定原文關鍵句：「P2-2 **關閉，且新標的比舊標的覆蓋更廣**」＋「**不建議第四輪**」。
- 第 2 輪實跑定案（reviewer 無 shell，指定 supervisor 執行）：**M10（原 §2.7 內容換編號 `§3.5` 貼回）→ 2 紅**，證明「用主題不用編號」確實覆蓋更廣（舊標的 `§2.7`
  對換編號回流是零覆蓋）；**M11（同義詞改詞回流）→ 0 紅**，記錄為已知缺口 → TMO-032。

**可證偽性（11 次突變，全部還原後回綠）**：

```
M1' SKILL.md +「## §2.7 用戶背景收集」                     → 2 紅
M7  reference.md +「角色詢問」                            → 2 紅
M8  reference.md 被刪/改名（mv 走）                        → 1 紅   ← P2-1 堵漏（修前此情境 0 紅）
M9  reference.md +「### §2.7 未定義編號占位」（主題無關）    → 0 紅   ← P2-2（修前會誤紅）
M10 SKILL.md +原 §2.7 內容但編號改 §3.5（換編號回流）       → 2 紅   ← 覆蓋更廣之證
M11 SKILL.md +同義詞改寫（使用者角色盤點／產品經理）         → 0 紅   ← 已知缺口，進 TMO-032
M2  reference.md +「PM/PO 對照」                          → 1 紅
M3' SKILL.md 兩處（:3 frontmatter + :37）皆移除定位句       → 2 紅
M4  移除 CHANGELOG v1.9 列「已廢棄」註記（列級錨定）         → 1 紅
M5  移除全域 changelog「刪除 §2.7 整套」                    → 1 紅
M6  刪除 skill CHANGELOG v2.1 廢除列                       → 1 紅
```

## 已知問題

- `bats tests/` 仍有 **1 紅** = TMO-028（`skills/dav-wiki/SKILL.md` 151 行 > 150）
- **第 2 輪 P2 全數折入 TMO-032**（本輪刻意不採納，理由見反思 4）：① helper 內加 `[[ -f "$p" ]]` 可一行根除整類假綠（本輪只在 d1 補正向錨定）；② `SKILL.md`
  變動歷史段（`:119-138`）會被「撤銷的章節不抹去」政策誤紅 → 負向斷言應改掃 body；③ `dav-planner-user-background.bats` v1.9 條目仍 whole-file grep；④
  `BACKLOG-005` regex 只禁小寫 `pending`（大寫 `PENDING` 漏抓，pre-existing）；⑤ M11 同義詞回流缺口
- TMO-030（麵包屑）：`docs/prd/02-dav-planner-user-background.md`、`docs/prd/03-reduce-deliverables.md:104`、`docs/backlog.md`
  TMO-007 詳細段仍把 §2.7 寫成現行規格（PRD 是 sprint 快照體例，但這份是唯一還被探針「保活」的現行規格描述）
- TMO-031：`skills/dav-planner/SKILL.md:73`「Step 1（背景收集）之後、Step 2（最終目的）之前」用舊步驟名（pre-existing，v2.6 引入 Step 1.5
  時即如此；位置資訊仍正確）
- **自首 1（跨票）**：TMO-026 的 commit `3639d00` 我在 backlog 加票時用了 `pending`，引入 `BACKLOG-005` 新紅（該紅不在 TMO-026 的 Gate 3
  證據內）。本輪發現並修掉：**不改探針**，改用 `todo` + 表下明列狀態定義（第 1 輪 reviewer 判定為「合法狀態語意（approved）」，條件是「有定義 + 有揭露」，並指出「若改為縮小探針範圍反而是真放寬」）
- **自首 2（我的標籤錯誤）**：第 2 輪 reviewer 抓到我 backlog 寫「二審 3 輪」卻只有第 1/3 輪紀錄——實情是**共 2 輪**，是我在給第 2 輪 reviewer 的 brief 裡誤寫成「第三輪
  delta」。已修正 backlog 為「2 輪（主體 + delta）」，並記錄此為本輪第 2 輪 P2-c

## 下一步建議（V20）

1. **驗收方式**：
   - `bats tests/` → 期望 **1 not ok / 496 ok（497 executed）**，唯一紅 = `AC-2: SKILL.md is at most 150 lines`
   - `bats tests/dav-planner-user-background.bats` → 6 ok；`bats tests/restruct-dav-planner.bats` → 13 ok
   - `bash -n tests/helpers/test-env.bash && shellcheck tests/helpers/test-env.bash` → rc=0
2. **預估時間**：驗收 1.5 分鐘（全套約 90 秒）
3. **風險提示**：守門是**意圖型**（主題字串），不是**編號型**。若未來要合法使用 `§2.7` 編號（`reference.md` 的 `§2.1–§2.6`
   序列自然延伸）不會誤紅；但若有人**只改詞**（例：「使用者角色盤點」）把功能貼回來，目前抓不到（M11 缺口）→ TMO-032
4. 接著的優先順序（推薦）：**TMO-028**（1 紅、需 V03 + 行數預檢）→ **TMO-029**（venv bootstrap，P1；乾淨 clone 目前 39 紅，CI trigger 一修就會炸）→
   TMO-032（探針精準化，消掉本輪已知缺口）→ TMO-030/TMO-031（麵包屑 + 1 行文案）
5. **commit 建議**：本輪單獨 1 個 commit（探針層 + helper + backlog）

## 反思

1. **「廢棄功能的探針」是光譜上最容易被誤殺的一種**。它紅了，但紅的理由不是回歸、而是「規格被用戶決策改掉了」。此時最容易的兩條錯路：①把內容搬回去讓它綠（用探針否決用戶決策）；②刪掉探針（解僱守門人）。正解是第三條：把守門
   人**換崗位**——從「證明功能在」改成「證明功能沒偷偷回來」。這一輪的價值不在 −5 紅，而在把「用戶決策」變成**機器可強制執行**的事實。
2. **負向斷言天生比正向斷言脆弱**。`grep` 對「檔案不存在」rc=2，`refute` 就回 PASS——守門人會因為「守的門被拆了」而**安靜通過**。這是本輪最貴的一課：**任何負向斷言都必須配一個正向錨定**（同檔、同
   test 內）。第 1 輪 reviewer 抓到這個洞、第 2 輪 reviewer 又指出我的修法只在 helper 層「局部繞過」而沒根除——兩次都在教我同一件事。
3. **守門標的要綁「主題」不綁「編號」**。用 `§2.7` 當禁字，會在 `§2.1–§2.6` 序列自然延伸時誤紅（誤殺好人），而且對「換個編號貼回來」零覆蓋（放過壞人）。M10/M11
   這一對突變把這件事講清楚：主題字串抓到了換編號的壞人（M10 紅），代價是抓不到改詞的壞人（M11 綠）——**這是把「零覆蓋」換成「部分覆蓋」的交換，值得，但必須把殘留缺口誠實寫下來**，而不是宣稱已完全防住。
4. **我刻意不採納第 2 輪的 P2-a，是遵守協定而不是偷懶**。P2-a 的一行修法（helper 加 `[[ -f ]]`）明顯更好，但改 `tests/**` 就要重開一輪 V03.6；reviewer
   已明確說「不建議第四輪、P2-a/b 折入 TMO-032」。**把「明知更好但超範圍」的修法切票、並在 deliverable 寫清楚它更好且已知**，比在本輪硬塞進去（造成審閱鏈斷裂）更負責。這是紀律與品質的取捨，不是妥協。
5. **我又一次被自己的行政動作咬到**（TMO-026 用 `pending` 撞 BACKLOG-005）。值得記下的不是「小心點」，而是：**修法是「定義 + 揭露」而不是「放寬探針」**。reviewer 的判準（資訊未被隱藏 /
   未違反探針意圖 / 未降低守護強度 / 有文件化 + 揭露）可以直接複用到未來所有「我的動作撞到自家探針」的場景。
6. **我的標籤錯誤被抓到，而且是我自己該抓的**。我在第 2 輪 brief 把「delta 二審」誤標成「第三輪」，寫進 backlog 後成了自相矛盾的帳目（有第 3 輪沒有第 2
   輪）。這種錯誤很小、但性質是**自欺**：輪次不是形式，它決定「這一輪審了哪些 delta、上輪意見有沒有被涵蓋」。誠實帳目是 V03 的地基——**記錯一輪，就等於有一段 delta 沒有可追溯的審閱紀錄**。
7. **不足**：① 我沒有為「廢棄守門」建立通用機制（每廢一個功能都要手寫三件套），未來應在 skill 廢除流程裡加一步「廢棄守門探針產生器/範本」；② M11
   缺口我選擇只記錄不修（修法需關鍵詞庫或語意比對，超出本輪），這是一個**已知會被同義詞繞過的守門人**——已明確進 TMO-032，不假裝它不存在。
