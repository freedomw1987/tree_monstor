# TMO-028 dav-wiki SKILL.md 主檔瘦身（151 → 129 行；bats 全綠 498/498）

- **日期**：2026-10-04
- **Backlog ID**：TMO-028
- **作者**：pi agent（user 核准的 4 里程碑計畫第 3 站）
- **狀態**：完成（Gate 1–4 全過；V03 二審 2 輪皆 approve-with-comments / risk low / 0 P0 / 0 P1）

## 摘要

`skills/dav-wiki/SKILL.md` 151 行超過硬上限 150 → `tests/dav-wiki.bats` AC-2 恆紅（TMO-027 後全套唯一 1 紅）。
本輪不是「砍 1 行到 150」，而是照 `skills/dav-skill-creater/editor-guide.md:102`「主檔行數預檢規範」
（V03.5：**主檔 ≥150 → 必先瘦身至 ≤130 行**）做**內容無損外移**：細節進同 skill 子檔、主檔留導航與指針。

結果：**151 → 129 行**、**零內容損失**（樹狀圖 15 行逐字搬移，diff 為空）、**淨 +1 條新探針**、
`bats tests/` **0 not ok / 498 ok**（本工作線首次全綠）。

## 變更清單

| 檔 | 改動 |
| --- | --- |
| `skills/dav-wiki/SKILL.md` | 151 → **129 行**；`## 輸出結構` 15 行樹狀圖 → 1 行指針；`## Trust 整合` 表格 → 1 條 bullet（同義）；`## 軟刪除規則` 6 行 → 1 行摘要（保留 `deprecated` / `superseded_by`）+ 指針；檔案尾重複 `---\n---` 收斂為單一；`## 變動歷史` 新增 v2.2 列；`:107` 由 122 → 118 字元（去除「靠 MD013 無空白豁免」的債） |
| `skills/dav-wiki/output-structure.md` | **新增**（41 行）：樹狀圖（逐字搬移）+ 各節點用途表 |
| `skills/dav-wiki/soft-delete.md` | **新增**（35 行）：軟刪除規則（重組 + 補充；`wiki-cleanup.sh` CLI 參數逐項對照腳本 `usage` 驗證，含 `--target` / `--older-than`（預設 90）/ `--dry-run` / `--yes` / `--purge`、日期來源 `deprecated_at`（無則 mtime））|
| `skills/dav-wiki/CHANGELOG.md` | 補 v2.2 列（該檔原註「從 SKILL.md v2.2 起變動歷史外移」過去卻無 v2.2 列，現補齊） |
| `tests/restruct-dav-wiki.bats` | **+1 條探針**：主檔所有 `./xxx.md` 指標目標必須存在（防空過 `found >= 4`）；既有「變動歷史」測試內**追加**版本漂移鎖（主檔首列版本 == CHANGELOG 首列版本），未新增測試條數 |

## 測試 / 驗收證據

### Gate 1（TDD 紅→綠）

依 gates.json 規範，Gate 1 (TDD) 需要：測試先紅後綠，並在對話貼出 測試執行指令 + 失敗輸出 + 通過輸出。

```
改前：bats tests/  → not ok 42 AC-2: SKILL.md is at most 150 lines（wc -l = 151）
改後：bats tests/dav-wiki.bats → ok 6 AC-2: SKILL.md is at most 150 lines（129 行）
新增探針：ok 13 RESTRUCT-DAV-WIKI: subfile pointers in SKILL.md resolve (no silent loss)
```

#### 突變證明（新增探針可證偽，全部還原後回綠）

```
M-a  mv skills/dav-wiki/output-structure.md 走 → 1 紅
     # FAIL: pointer target missing: skills/dav-wiki/output-structure.md
M-b  把主檔 5 個指標改成非 `./xxx.md` 格式（模擬指標擷取失效）→ 1 紅
     # FAIL: expected >=4 subfile pointers, found 3        ← 防空過非永真
M-c  主檔 v2.2 → v2.3（bats 級原始輸出）
     not ok 6 RESTRUCT-DAV-WIKI: change history with v2.0 reference
     # (in test file tests/restruct-dav-wiki.bats, line 58)
     #   `return 1' failed
     # FAIL: 主檔最新版本(v2.3) 與 CHANGELOG(v2.2) 不一致
M-d  CHANGELOG v2.2 → v2.4（bats 級原始輸出）
     not ok 6 RESTRUCT-DAV-WIKI: change history with v2.0 reference
     # (in test file tests/restruct-dav-wiki.bats, line 58)
     #   `return 1' failed
     # FAIL: 主檔最新版本(v2.2) 與 CHANGELOG(v2.4) 不一致
還原後：bats tests/restruct-dav-wiki.bats tests/dav-wiki.bats → 34 ok / 0 not ok
```

#### 內容無損證明

```
git show HEAD:skills/dav-wiki/SKILL.md 抽出樹狀圖 15 行  vs  output-structure.md fence 15 行
→ diff 為空（逐字一致：順序、縮排皆同）
```

### Gate 2（lint / syntax）

```
npx markdownlint-cli2@0.13.0 "skills/dav-wiki/*.md" → Summary: 2 error(s)
  SKILL.md:10:121 MD013 (Actual 149) / SKILL.md:18:121 MD013 (Actual 155)
  → 與 HEAD 版本逐字相同（baseline 也是同 2 條）＝ 零新增 lint 債
  → 我原本寫出的 2 條新超長行（240 / 177 字元）已在送審前收短
bats 跑動 0 parse warning；`@test` 名稱全 ASCII（bats 1.14 CJK 靜默丟棄）
```

### Gate 3（regression）

```
bats tests/ → 宣告 1..498、實跑 498、0 not ok、498 ok
集合差 vs TMO-027 baseline（1 not ok / 496 ok）：
  已修 1（AC-2: SKILL.md is at most 150 lines）、新增 0
（TMO-027 後測試數 497 → 本輪 +1 條新探針＝498）
```

### Gate 4（reviewer，V03 + V03.6 二審 2 輪）

- **第 1 輪（主體）**：**approve-with-comments / risk low / 0 P0 / 0 P1 / 6 P2**。判定「真瘦身非字面規避」
  （資訊未隱藏 / 探針意圖未違反 / 守護強度未降且淨 +1）；判「新增探針屬加嚴非放寬」；
  P2 清單：①版本漂移鎖缺席 ②子檔只有 existence 鎖 ③`:107` 實測 122 字（靠 MD013 豁免過關）
  ④同源死引用 4 處（pre-existing）⑤`SKILL.md:95` 降級條款 vs `require_tool` 硬 `exit` 矛盾（**無票**）
  ⑥本檔/backlog 記帳未做。Reviewer 明示 **Q3 建議本輪就補漂移鎖**。
- **第 2 輪（delta，fresh reviewer）**：**approve-with-comments / risk low / 0 P0 / 0 P1 / 4 P2**，**明示不需第三輪**。
  判定 A（漂移鎖）= 純新增、加嚴、fail-closed，`[ -n "$v_skill" ]` 足以防「兩側抽空 → `"" = ""` 靜默假綠」；
  B（122 → 118 字元）= 零語意損失（四個關鍵字與指針全在）。本輪唯一要求：TMO-035 的 exit code 要寫 **4**（非 5），
  並引用既有紀錄 `docs/backlog.md:771`。

## 已知問題（本輪未處理，已切票）

- **TMO-033**：子檔只有 existence 鎖、無內容錨點（子檔被掏空仍全綠）。最小鎖：`output-structure.md` 需含
  `_index.json` / `_tags.json` / `_concepts.json` / `transcript.md`；`soft-delete.md` 需含 `deprecated_at` /
  `--older-than` / `--purge`。
- **TMO-034**：同源死引用 4 處 —— `skills/dav-wiki/scripts/wiki-cleanup.sh:3`（檔頭註解）、`:39`（usage「對應手冊」）、
  `.github/workflows/ci.yml:50`、`CONTRIBUTING.md:48` 仍指名**已由 DOCS-REDUCE-002 移除**的
  `docs/sop/handbook/dav-wiki-cleanup.md`（`tests/docs-reduction.bats:23` 正在守「它不存在」）。
- **TMO-035**：`skills/dav-wiki/SKILL.md:94-95` 寫「OCR / 字幕為擴充模組」「未裝時降級為純文字模式 / 降級時必警告」，
  但 `wiki-extract-media.sh`（`require_tool()` → **`exit 4` = `EXIT_TOOLMISSING`**，六處呼叫 `:114/124/135/153/164/204`）、
  `wiki-extract-audio.sh:174-175`、`wiki-extract-video.sh` 對缺工具**一律硬失敗、無降級路徑** → 文實矛盾。
  此觀察已存在於 `docs/backlog.md:771`（P1 清單第 2 項），但一直**無票**；本篇首次立票。
- **TMO-036**：`skills/dav-planner/SKILL.md:80`「先 grep `docs/concepts/` + `docs/wiki/_index.json`」實質是跨目錄讀取，
  但 `tests/restruct-zero-cross-read.bats` 的動詞表只有 `讀|見|詳見|詳閱|參考`、不含 `grep` → 探針覆蓋缺口（與 TMO-026 P2-1 同型）。
- **P2-2（折入 TMO-032）**：漂移鎖在「主檔改非 `| vX.Y |` 表格列」時會紅且訊息不可診斷
  （顯示「主檔最新版本() 與 CHANGELOG(v2.2) 不一致」）。屬刻意 fail-closed（判定為加嚴非缺陷），
  但訊息可讀性有債；dav-planner / regression-guard 同構同病 → 三檔一起改，折入既有 TMO-032。
- **out-of-scope（未立票，僅記錄）**：`ci.yml` trigger `branches: [main]` vs 預設 `master`（CI 從未執行）、
  README badge `209/209` 陳舊 → 將由 TMO-029（CI/測試環境）處理。

## 下一步建議（驗收方式）

1. **驗收方式**（約 3 分鐘）：

   ```
   bats tests/                                        # 期望 498 ok / 0 not ok
   wc -l skills/dav-wiki/SKILL.md                     # 期望 129
   ls skills/dav-wiki/{output-structure,soft-delete}.md
   git diff --stat                                    # 期望 3 改 + 2 新
   ```

2. **風險提示**：主檔已完全不提 `scripts/wiki-cleanup.sh`（清理 CLI 變 1 hop）；主檔單獨不再自足，
   依賴同目錄子檔 —— 這是 repo「子檔 + 顯式指針」既有哲學，可接受，但若未來 skill 要被單檔複製使用需重新評估。
3. **後續**：TMO-029（venv bootstrap；clean clone 實測 **35 紅**全在 `tests/v2.1-jev-poc.bats`，缺少依賴僅
   `httpx` + `PyYAML` 兩個 —— 已用乾淨 venv 實證：只裝這兩者 → 該檔 98 ok / 0 not ok）。

## 反思

- **「行數上限」不是要你砍字，是要你分層**。真正的觸發點是 V03.5 那句「≥150 → 必先瘦身至 ≤130」：
  規則早就寫好要主動出擊，我原本卻只想「151 → 150 剛好過關」。若只砍 1 行（重複的 `---`），
  下一個小改動又會撞牆；把細節外移成子檔，才是把注意力成本結構性降下來。
- **搬移要能被證明是搬移**。光說「內容無損」不算證據；`git show HEAD:...` 抽舊樹狀圖 vs 新子檔 fence
  做 `diff` 得到空輸出，才算。這招（對「搬動」類變更做逐字 diff）值得寫進 V03 checklist。
- **負向與空值都有假綠**。新探針的 `found >= 4` 是為了擋「指標擷取失效 → 0 筆 → 全綠」；
  漂移鎖的 `[ -n "$v_skill" ]` 是為了擋「兩側都抽不到 → `"" = ""` 成立」。兩個洞都不會自己現形，
  是靠「先想它怎麼假綠」補的。
- **最吵的債是 151 撞 150，最安靜的債是缺鎖**。這條線一路（TMO-026/027/028）反覆證明：
  探針不紅不代表守得住 —— dav-wiki 是三個「拆檔家族」中最後一個沒上版本漂移鎖的 skill。
- **自傷要當場說**：本輪我跑突變時 `git checkout skills/dav-wiki/SKILL.md`，把整份瘦身連未 commit 的編輯
  一起還原；發現後重做全部編輯。另一次是把既有 `grep -qE "v2\.0"` 誤打成 `"v\.0"`（會把守護放寬成 `vX.0`），
  立刻修回並主動寫在送審說明裡。兩次都未進入最終 diff，但**檢查者若有心，這種事最該被知道**。
- **reviewer 的「不用第三輪」也是產出**：第 2 輪明示觸發條件（再動探針／版本列變動／現在就做 TMO-033／
  §2.5 記帳後出現新紅），把「何時必須再審」變成可稽核的規則，而不是我的自由心證。
