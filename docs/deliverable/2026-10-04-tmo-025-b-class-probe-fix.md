# TMO-025 B 類 12 紅修復（pptx 靜默假成功 + poppler + 兩支新探針）

**日期**：2026-10-04
**Backlog ID**：TMO-025
**作者**：Agent
**狀態**：✅ 完成

## 摘要

承 TMO-023 的 30 紅，本輪清掉其中 12 紅（B 類，全部在 `tests/wiki-extract-media.bats`）。表面症狀是「11 個 PDF 探針因本機缺 poppler 而紅」，但追下去挖到一個**真產品缺陷**：`wiki-extract-media.sh` 的 `extract_pptx_text()` 用 pandoc 讀 pptx（pandoc 3.8.2 **沒有** pptx reader），pandoc rc=21 被吞掉，腳本卻印「✓ PPTX 文字提取完成」、回傳 0、manifest 還寫了 `text.md` —— 典型的**靜默假成功**，使用者永遠拿不到文字卻以為成功。

因此本輪不只是「裝工具把燈弄綠」，而是：修掉假成功（改用設計文件指定的 python-pptx）+ 新增兩支會咬人的探針（AC-E21 假成功、AC-E22 掃描件）＋ 補 CI 依賴安裝，讓這條路徑在乾淨環境也驗得到。全套由 30 紅 → **18 紅 / 477 綠**，**0 新增失敗**，修好的正好是這 12 個。

## 變更清單

### 產品碼（1 檔）

- `skills/dav-wiki/scripts/wiki-extract-media.sh`（281 行）
  - `extract_pptx_text()` 重寫：pandoc → **python-pptx** 逐頁抽文字（`## Slide N` + 各文字框），與 `docs/system-design.md:100` 設計一致
  - 新增 `verify_artifact <path> <label>`：**檔案不存在 → ERROR + exit 5**；**內容為空 → 只警告**（掃描件是合法情境，建議走圖片 + OCR FR-2.2.3）
  - 新增 `EXIT_EXTRACT=5`（exit code 契約成 0–5）；usage / header 同步
  - `pdfimages` / `pdftotext` / `pandoc`×2 / python heredoc×2 全部補 rc 檢查；python `sys.exit(4)`（缺 python-pptx）正確映射回 `exit 4`
  - 修 2 處死引用（`tools/…`、`docs/prd/03-knowledge-extraction.md`）

### 探針（1 檔）

- `tests/wiki-extract-media.bats`（22 tests，231 行）
  - AC-E6 標題改 implementation-agnostic（**斷言一字未改**）
  - **新增 AC-E21**：壞掉 `.pptx` → `status -eq 5`（釘住 exit code，區分「缺工具 4」vs「提取失敗 5」）+ 不得留 `text.md` + 輸出含「無法讀取」
  - **新增 AC-E22**：掃描件 PDF（無文字層）→ exit 0 + 圖片保留 + 出現「掃描件」警告；探針開頭有 fixture 漂移守衛（缺檔 / fixture 有文字層 → 大聲紅）
  - 新 fixture `tests/fixtures/pdf-scan/scan.pdf`（38 KB，重建指令寫在檔頭）

### 環境 / 文件 / CI

- **本機安裝**（使用者機器，如實揭露）：`brew install poppler`、`brew install shellcheck`
- `docs/install-reference.md`：新增「dav-wiki 媒體提取的測試依賴」表（poppler / pandoc / python-pptx / tesseract），並明確寫**缺工具時探針直接失敗、不 skip**（避免再造假綠）
- `.github/workflows/ci.yml`：加 `actions/setup-python@v5`；bats 步驟前加 Linux / macOS 依賴安裝（poppler、pandoc、tesseract、python-pptx）；`bash -n` 收錄本腳本

## 測試 / 驗收證據

### Gate 1（TDD 紅→綠）

依 gates.json 規範，Gate 1 (TDD) 需要：測試先紅後綠，並在對話貼出 測試執行指令 + 失敗輸出 + 通過輸出。

新探針**先寫、先紅**（紅的原因是產品缺陷，不是斷言錯）：

```
$ bats tests/wiki-extract-media.bats --filter 'AC-E21|AC-E22'
not ok 1 AC-E21: extraction failure must not fake success (non-zero + no text.md)
# (in test file tests/wiki-extract-media.bats, line 250)
#   `[ "$status" -ne 0 ]' failed
not ok 2 AC-E22: scanned PDF (no text layer) → exit 0 + images + empty-text warning
#   `[[ "$output" =~ "掃描件" ]]' failed
2 tests, 2 failures
```

修完產品碼後：

```
$ bats tests/wiki-extract-media.bats          # 1..22
ok 21 AC-E21: extraction failure must not fake success (non-zero + no text.md)
ok 22 AC-E22: scanned PDF (no text layer) → exit 0 + images + empty-text warning
22 tests, 0 failures
```

AC-E6 的 `text.md` 實際內容（真跑 python-pptx）：`## Slide 1` / `Slide 1: Architecture` / `Architecture overview with red diagram`（grep `Architecture` 綠）。

**可證偽性（3 次突變，證明探針會咬人而非空過）**：

```
突變 1：移除 extract_pptx_text() 的 rc 檢查 + verify_artifact（＝還原成原本的假成功行為）
  → not ok 1 AC-E21 / # (line 250) # `[ "$status" -eq 5 ]' failed     [cp 還原後] ok 1 AC-E21
突變 2：移除 verify_artifact() 內的空文字層警告
  → not ok 1 AC-E22 / # (line 273) # `[[ "$output" =~ "掃描件" ]]' failed  [cp 還原後] ok 1 AC-E22
突變 3：把 AC-E22 的 fixture 守衛指向有文字層的 sample.pdf
  → not ok 1 AC-E22 / # (line 263) # `return 1' failed                     [還原後] 22 ok / 0 red
```

### Gate 2（lint / syntax）

```
$ bash -n skills/dav-wiki/scripts/wiki-extract-media.sh   → rc=0
$ shellcheck skills/dav-wiki/scripts/wiki-extract-media.sh → rc=0（0 issue）
```

（修改前版本亦為 0 issue → 本輪沒有新增 lint 債。）

### Gate 3（regression）

```
$ bats tests/
not ok: 18 / ok: 477         # 宣告 498、實跑 495
```

- 對比 TMO-023 後 baseline（`/tmp/after-notok-final.txt`，30 紅）：**新增失敗 = 空集合**
- 修好的正好 12 個：AC-E1、E2、E6、E9、E10、E11、E12、E15、E16、E17、E19、E20
- 剩下的 18 紅全是 A 類（探針落後於 skill 重構，詳見 TMO-023 詳細）

### Gate 4（reviewer）

依 gates.json 規範，Gate 4 需要 reviewer 原文回傳（agent 不自動修、由用戶裁定）。實跑 dev-checker-loop **兩輪**：

| 輪次 | 判定 | 風險 | P0 | 主要意見 |
| --- | --- | --- | --- | --- |
| 1（主體） | approve-with-comments | low | 0 | 假成功機制屬實、rc 傳遞可靠、`tr -d '[:space:]'` 吃得掉換頁符、AC-E6 只改標題＝**無放寬**；建議 5 項補遺 |
| 2（補遺 delta） | approve-with-comments | low | 0 | 五項補遺實作正確、無新風險；V03.6 **合規**（無任何放寬）；**明示不需第三輪**；對 defer 項建議 3 項升 P1 |

二審原文關鍵句：「在本次 5 項補遺 delta 範圍內，除上列 6 條 P2（report-only）外，我沒有找到更多問題；沒有新增 P0/P1、沒有放寬、沒有把第一輪判定變壞。」

**二審意見催生的一個真 bug（自身，已修）**：二審建議「AC-E21 改釘 `status -eq 5`」後探針立刻轉紅，追出根因是 **`${var}` 寫成 `$var` 且緊鄰全角括號** → bash 在 UTF-8 locale 把 `$rc）` 當成變數名 `rc）` → `set -u` 下 `rc: unbound variable`，exit code 變 1。全 repo 掃同型地雷共 **7 處**（本檔 6 + 探針 1），已全數改 `${var}`。這正是「把斷言收緊」抓出來的價值。

## 已知問題

- `bats tests/` 仍有 **18 紅**（A 類探針過期，見 TMO-023 詳細）
- 二審建議以下升 **P1**、另立票（本輪刻意不動，避免 diff 擴大）：
  1. `ci.yml` trigger `branches: [main]` vs repo 預設 `master` → **CI 從未執行**，Gate 2/3 的 CI 強制力為零；修好的當下會立刻紅，建議與 A 類清理、SKILL.md 瘦身同批
  2. `skills/dav-wiki/SKILL.md` **151 行 > 150**（`tests/dav-wiki.bats:38` 已紅）＋ `:95`「未裝工具應降級」與 `require_tool` 硬 `exit 4` 矛盾（需走 V03）
  3. bats 1.14.0 對「`@test` 名含 CJK」**靜默不執行**：實測 3 條（`restruct-agents-md.bats` ×2、`restruct-dav-planner.bats` ×1）＝ 宣告 498 / 實跑 495 的差額；3 條斷言本身若跑會綠
- P2（report-only）：pptx 表格 / 群組文字未抽（只收 `has_text_frame`）、CI badge owner 錯誤、8 個 sibling 腳本死引用 `tools/`、`scan.pdf` 重建指令 macOS-only（CI 是 ubuntu）、「`$var` 緊鄰全角字元」尚未有 repo 級靜態守衛
- 本輪在使用者機器安裝了 `poppler`、`shellcheck`（未安裝無法真驗）
- 尚未 commit：工作區同時含 TMO-023 / TMO-024 / TMO-025 三輪變更

## 下一步建議（V20）

1. **驗收方式**：`bats tests/wiki-extract-media.bats`（應 22 ok）；`bats tests/`（應 18 not ok / 477 ok）；`bash -n` + `shellcheck` 該腳本（應 rc=0）
2. **預估時間**：本輪驗收 1 分鐘
3. **風險提示**：新探針 AC-E21 / E22 **刻意設計成缺工具就紅**（不 skip）→ 未裝 poppler / python-pptx 的機器會看到 12 紅，屬預期行為，`docs/install-reference.md` 已列依賴
4. 建議接著處理的三條路（推薦順序見對話結論）：① A 類 18 紅（含 SKILL.md 瘦身，需 V03）；② CI trigger 修正 + badge 對齊（會讓 CI 立即見紅，需與 ① 同批）；③ CJK 測試名修復（把 3 條沒在跑的探針救回來）
5. **建議分 3 個 commit**：TMO-023（探針層）、TMO-024（README + install-reference）、TMO-025（pptx 修復 + 新探針 + CI）

## 反思

1. **本輪真正價值不在「把紅燈弄綠」，而在挖出「綠燈底下的假成功」**。11 個 PDF 紅是環境缺件（裝 poppler 就綠），但 AC-E6 那 1 紅背後是 pandoc 早已無 pptx reader、錯誤被吞、還印成功訊息 —— 這類缺陷在舊版 CI「從不執行」的情況下可以無限存活。修法中真正貴重的不是 python-pptx，而是 `verify_artifact` 這種「**產物不存在就大聲死**」的契約。
2. **「空 vs 缺」的區分是設計判斷，不是實作細節**。掃描件抽不到文字是合法結果（應警告導向 OCR），檔案根本沒生成才是故障（應 exit 5）。若一律 `-s` 判死，會把合法情境變成紅燈，製造另一種形式的噪音；若一律放行，就回到假成功。這個判斷寫進了 `verify_artifact` 的註解與 AC-E22，使它可被後人檢驗。
3. **探針的品質要用「突變測試」量，不是用「現在是綠的」量**。本輪 3 次突變（還原假成功 / 移除警告 / 弄壞 fixture 守衛）逼出「紅路徑」證據；沒有這一步，AC-E21/E22 只是兩條看起來很認真的斷言。
4. **二審的價值在「它的建議會咬到作者自己」**。二審要我把 AC-E21 釘成 `-eq 5`，一釘就紅 —— 暴露出我新寫的 6 處 `${var}` 全角地雷。若當時只聽「approve / risk low」就收工，這 6 個 bug 會以「綠燈」形式一起進 repo，並在未來某次錯誤路徑才隨機爆開。**把斷言收緊會立刻懲罰作者，這正是它值得做的原因。**
5. **透明度是 SOP 的地基**。本輪如實揭露了三件不體面的事：在用戶機器裝了 poppler / shellcheck、`markdownlint` 本機沒裝（未跑）、以及「二審後又改了 7 處」屬第二輪裁定卻未開第三輪（依 TMO-023 慣例：只剩 reviewer 自己建議的 P2、零放寬）。這些揭露比多一次綠燈更有價值。
6. **不足**：① 本輪 diff 已偏大（產品碼 + 探針 + CI + 文件），我刻意把「SKILL.md 矛盾」「CI trigger」等 P1 留在票外 —— 但也因此讓「修好 trigger 會立刻見紅」這個**已知的紅**繼續存在，這是一個用「小而完整」換「暫不處理更大問題」的自覺取捨，應在下一輪優先償還。② 我仍未建立 repo 級靜態守衛來擋 `${var}` 全角地雷，只能靠人記得 —— 已列入 P2。