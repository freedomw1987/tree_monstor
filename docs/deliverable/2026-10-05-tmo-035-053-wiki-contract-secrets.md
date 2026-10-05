# TMO-035 ＋ TMO-053：dav-wiki「缺工具」文實一致 ＋ 探針密鑰遮罩通則

- **日期**：2026-10-05
- **Backlog ID**：TMO-035（缺工具行為文實矛盾）、TMO-053（密鑰遮罩通則）；新開 **TMO-058**（Whisper 假成功）、擴充 **TMO-057**（死引用範圍）
- **作者**：pi（david 的 agent，一般模式；非 trust）
- **狀態**：**待用戶驗收**。Gate 1–4 全綠；Gate 4 兩輪：Round-1 `approve-with-comments`（0 P0／2 P1／6 P2／9 P3）
  → 修正後 Round-2 **`OK with notes`（0 P0／0 P1／1 P2／7 P3）**，條件（P2-1 數字、P3-1/P3-2 文件）
  **已全部修完**；reviewer 明示「**不需再開第三輪**」。
- **commit**：`1ec4aa1`（本批，`--amend` 後雜湊可能微幅變動，以 `git log -1` 為準）；
  前序未 push 鏈：`ef563f3`（item 1 行政清理）→ `b2a775b` → `fbccea1` → `6fd527a`（TMO-040）

## 摘要

兩張票的共同性質是**「文件承諾了不存在的行為」與「防線只存在於一個檔」**：

1. **TMO-035**：`skills/dav-wiki/SKILL.md` 限制表寫「FR-2 多模組需 poppler / ffmpeg / Whisper｜未裝時**降級為純文字模式**」，
   但 `wiki-extract-{audio,video}.sh` / `wiki-extract-media.sh` 的 `require_tool()` 是**硬退 4**，沒有任何降級路徑。
   用戶 2026-10-05 ask-me 拍板 **A 案：改文件對齊現實**（缺必要工具＝該模組直接停 + 安裝提示）。本輪同時發現
   `wiki-ocr.sh` 的 usage 反向說謊（宣稱 `exit 4 必要工具缺失`，但該檔只有「缺 tesseract → 自動 mock」），
   一併對齊並移除死常數 `EXIT_TOOLMISSING`。
2. **TMO-053**：NYH-1 的真實事故——探針的 FAIL 訊息把本機**真實** `OPENROUTER_API_KEY` 印進 session log，
   而 `mask_secrets()` 當時**只定義在單一探針檔內**，其他探針零防線。本輪把它上移到 `tests/helpers/test-env.bash`
   （單一真相）＋新增**鎖 4** `scripts/ci/lint-probe-secrets.py` 靜態鎖（5 條規則＋防空過＋`SECRET-OK` 標記紀律）。

**過程中的重要副產品**：reviewer Round-1 抓出「Whisper/Vision 在文件裡被歸成缺工具，其實 real 模式**未實作且失敗回 rc 0＝假成功**」
（與 TMO-025「不得假成功」紀律直接衝突）→ 文件拆列修正（不再誤歸類）＋**新開 TMO-058** 追真實行為修正。

## 變更清單

| 檔 | 變更 |
| --- | --- |
| `scripts/ci/lint-probe-secrets.py` | **新檔（鎖 4）**：R1 真前綴／R2 檔級（去註解後必須有**呼叫形態**）／R3 行級（`$output` 家族 + **`$OPENROUTER_API_KEY` 直印**）／R4 單一真相（只有 `tests/helpers/test-env.bash` 可定義）／R5 標記必須附理由且不得標在無關行；`--self-test` 16 個案例（含 4 條反向迴歸）；docstring 誠實列 4 類已知限制 |
| `tests/secret-masking.bats` | **新檔，5 條**（SM-1 單一定義 [filesystem `find`]／SM-2 掃描器全綠＋標記錨點／SM-3 遮罩真的遮／SM-4 **反向實測**／SM-5 掃描器會咬＋空樹防空過） |
| `tests/wiki-toolmissing-contract.bats` | **新檔，9 條**（WTM-1 隔離 PATH 正反照／WTM-2~4、8、9 實跑 rc=4 + 安裝提示 + 不留部分產出／WTM-5 限制表靜態鎖／WTM-6 OCR usage 靜態鎖／WTM-7 OCR mock 例外實跑） |
| `tests/helpers/test-env.bash` | 新增共用 `mask_secrets()`（:136 起 13 行） |
| `tests/poc-clean-clone.bats` | 移除本地 `mask_secrets()` 定義（改用共用版）；呼叫點改 `printf … \| mask_secrets`（:284/:298） |
| `skills/dav-wiki/SKILL.md` | 限制表 1 列 → **2 列**（缺必要工具＝停；Whisper/Vision 另列＝real 未實作／假成功／追 TMO-058）；變動歷史 + v2.2.1；「僅保留最近 3 條」措辭補「+ v2.0 首版錨點」 |
| `skills/dav-wiki/CHANGELOG.md` | + v2.2.1 條目（13 行，含 TMO-058 交叉引用） |
| `skills/dav-wiki/scripts/wiki-ocr.sh` | 移除死常數 `EXIT_TOOLMISSING` 與 usage 的「4 必要工具缺失」（對齊實作：缺 tesseract 一律自動 mock） |
| `CONTRIBUTING.md` | 「探針輸出不得外洩密鑰」段落（遮罩呼叫、鎖 4 五規則、標記真實語意） |
| `docs/install-reference.md` | 三個靜態鎖 → **四個**；套件/clean clone 數字全數更新為終值（600／603／557+43）；`祕鑰`→`密鑰` |
| `docs/backlog.md` | TMO-035／TMO-053 → `done (2026-10-05)`；新列 TMO-058（P2）；擴充 TMO-057（12 處死引用）；TMO-043 註記常數已移除 |
| `docs/need-you-help.md` | NYH-2 ✅ 已結案；NYH-4 ✅ 已結案（含 TMO-058 衍生）；原提問保留為引用區塊 |

## 測試驗收證據（4 Gates）

> **依 gates.json 規範，Gate 1 (TDD) 需要：測試先紅後綠，並在對話貼出「測試執行指令 + 失敗輸出 + 通過輸出」。**
> **依 gates.json 規範，Gate 2 (lint/syntax) 需要：語言對應 linter 0 error/0 warning，並貼出完整 linter output。**
> **依 gates.json 規範，Gate 3 (regression) 需要：探針埋好 + 完整測試套件跑過，並貼出「修改前 baseline + 修改後 output + Diff 對比」。**
> **依 gates.json 規範，Gate 4 (reviewer) 需要：checker 回傳「沒找到更多問題」（UI 任務另需 playwright-cli E2E 全綠）。**
> 本任務為 shell 腳本／文件契約，**無 UI → playwright-cli 不適用**（明示）。

### Gate 1（TDD：先紅後綠）

指令：`bats tests/wiki-toolmissing-contract.bats tests/secret-masking.bats`

**首輪紅燈（新檔 12 條）**：`not ok` ＝ WTM-5／WTM-6（文件契約尚未改）＋ SM-1／SM-2／SM-3／SM-5
（共用 `mask_secrets` 與掃描器尚不存在）。
**首輪即綠（誠實申報，characterization lock）**：WTM-1~4、**WTM-8、WTM-9**（第二輪補，見下）、SM-4。
它們鎖的是**既有正確行為**（`require_tool` 早就是硬退 4；`SM-4` 是更加強的反向實測），
敏感度改由**突變驗證**佐證（MUT-A/B/G/I 全咬住）。

**紅→綠四條（可重現，皆實跑取值）**：

```text
### RED-1: SKILL.md 回寫舊承諾 → WTM-5
not ok 1 WTM-5: SKILL.md 限制表對齊現實（不得承諾降級為純文字）
#   `refute_file_contains "$skill" "降級為純文字模式"' failed
# FAIL: file .../skills/dav-wiki/SKILL.md must NOT contain: 降級為純文字模式

### RED-2: wiki-ocr.sh 回寫 EXIT_TOOLMISSING → WTM-6
not ok 1 WTM-6: OCR 腳本自己不再宣稱 exit 4（決策：自動 mock，不硬退）
#   `refute_file_contains "$ocr" "EXIT_TOOLMISSING"' failed
# FAIL: file .../wiki-ocr.sh must NOT contain: EXIT_TOOLMISSING

### RED-3: 掃描器不在（mv 走）→ SM-2
not ok 1 SM-2: 靜態鎖 lint-probe-secrets.py 全綠（含防空過）

### RED-4: mask_secrets 停用（改成 cat）→ SM-3
not ok 1 SM-3: mask_secrets 真的會遮（sk- 前綴 / KEY= 指派），乾淨文字不動
#   `[[ "$output" != *"abc123def456"* ]]' failed
```

**SM-1 的紅燈**＝`MUT-H`（在 `tests/poc-clean-clone.bats` 尾端偷加 `mask_secrets() { cat; }`）：
`not ok 1 SM-1` ＋ 掃描器同報 `FAIL: …重新定義 mask_secrets（應改用共用版）`。

**P1-2（Round-1 reviewer 指出的繞道）確實存在，且已關上**——用「模擬修前語意」實測：

```text
修後語意： ['…/r2-comment.bats: 檔內用到 _load_api_key 但整檔沒有 mask_secrets 呼叫（＝印出去時沒有遮罩能力；註解裡提到名字不算）']
修前語意： （綠＝沒抓到 → 繞道成立）
```

**最終綠燈**：

```text
$ bats tests/wiki-toolmissing-contract.bats tests/secret-masking.bats
1..14
ok 1 WTM-1: 隔離 PATH 可用且真的缺工具（正向＋反向對照，防空過）
ok 2 WTM-2: audio 缺 ffmpeg → rc=4 + 安裝提示，且不留半成品（不降級）
ok 3 WTM-3: media（docx）缺 pandoc → rc=4 + 安裝提示（不留部分產出）
ok 4 WTM-8: media（pdf）缺 poppler → rc=4 + 安裝提示（doc 點名的工具之一）
ok 5 WTM-9: media（pptx）缺 python3 / python-pptx → rc=4 + 提示含 python-pptx
ok 6 WTM-4: video 缺 ffmpeg → rc=4 + 安裝提示
ok 7 WTM-5: SKILL.md 限制表對齊現實（不得承諾降級為純文字）
ok 8 WTM-6: OCR 腳本自己不再宣稱 exit 4（決策：自動 mock，不硬退）
ok 9 WTM-7: OCR 的 mock 降級是唯一例外——文件有寫，且實跑得到
ok 10 SM-1: mask_secrets 只有一份定義（共用 helper），其他檔不得自己再定義
ok 11 SM-2: 靜態鎖 lint-probe-secrets.py 全綠（含防空過）
ok 12 SM-3: mask_secrets 真的會遮（sk- 前綴 / KEY= 指派），乾淨文字不動
ok 13 SM-4: 反向實測——讓 CLEAN-POC-i 真的失敗，bats 輸出不得含密鑰
ok 14 SM-5: 掃描器真的會咬（合成違規）+ 空樹防空過
```

掃描器本體（鎖 4）：

```text
$ python3 scripts/ci/lint-probe-secrets.py --self-test
OK: 鎖 4 自我測試通過（真前綴／標記豁免與濫用／標記附理由／註解／檔級／行級／大括號／環境變數直印／合成樣本／單一真相與變體）
$ python3 scripts/ci/lint-probe-secrets.py .
OK: 掃描 48 個探針檔（其中 2 個直接碰 _load_api_key）；0 violation；5 個 SECRET-OK 標記（審查錨點，請人工確認每個都合理）
```

### Gate 2（lint / syntax）

```text
$ shellcheck -x -S style $(git ls-files '*.sh' '*.bash')
rc=0（零輸出）
$ for f in $(git ls-files '*.sh' '*.bash'); do bash -n "$f"; done
bash -n: 23 files, 0 bad
$ npx markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"
Linting: 129 files
Summary: 0 issues in 0 files
$ python3 -m py_compile scripts/ci/lint-probe-secrets.py
py_compile: OK
```

### Gate 3（regression）

| 量測 | 指令 | 結果 |
| --- | --- | --- |
| baseline（改動前，含未追蹤檔一起 stash） | `git stash push -u` → `bats tests/` | **586 ok / 0 not ok**（plan `1..586`） |
| 首輪改動後 | `bats tests/` | **598 ok / 0 not ok** |
| 最終（Round-2 處置後） | `bats tests/` | **600 ok / 0 not ok**（plan `1..600`；`bats --count tests/` = 600） |
| skill 自帶探針 | `SKILLS_DIR_OVERRIDE="$PWD/skills" bats skills/*/tests/*.bats` | **3 ok** |
| clean clone（暫移 `PoC/.venv`） | `bats tests/` | **557 ok / 43 not ok**（43 不變；**14 條新測試 0 條在紅燈內**） |

Diff 對比（測試名集合，586 → 600）：**只多 14 條，0 條被刪或改名**。
（唯一噪聲是 `M6-g` 的測試名內含隨機 `$BATS_TEST_TMPDIR`，非真差異。）

### Gate 4（reviewer）

- **Round-1**（artifact `/tmp/tmo03553-review.diff`，672 行）：verdict `approve-with-comments`，
  **0 P0／2 P1／6 P2／9 P3**，「可交付用戶驗收？**是（附條件）**」。
- **Round-2**（artifact `/tmp/tmo03553-review2.diff`，812 行）：verdict **`OK with notes`**，
  **0 P0／0 P1／1 P2／7 P3**，reviewer 原文：
  > **Q1｜P1/P2/P3 處置是否到位？** 到位（P1-1/P1-2 實質關閉…）…**不需再開第三輪**（本輪無行為面 P1，
  > 且新鎖/新探針的機制我已逐條靜態驗證）。**Q8｜可交付用戶驗收？** **是（附條件）**。
  > 條件＝先修 P2-1 那 4 個數字（一行一字、零風險），P3-1/P3-2 順手修，P3-3～P3-7 記入交付物。
- reviewer 自行靜態複核的重點（原文摘）：「R1：`sk-or-v1-` 只出現在 `tests/secret-masking.bats`，4 處全帶標記」、
  「R4：`mask_secrets()` 定義唯一在 `tests/helpers/test-env.bash:136`」、「R5 不誤傷 5 個標記」、
  「SM-4 機制正確（shim 路徑／`$2` 判定／`HOME` 未被 helper 蓋掉 → 真走到 FAIL 分支）」、
  「新檔不會被既有的 ENV-EQ-8/9/12 鎖擋」。

#### Round-1 → Round-2 處置對照（含拒絕項）

| 條目 | 處置 |
| --- | --- |
| **P1-1** Whisper 被歸成「缺工具→exit 4」 | ✅ 限制表拆兩列；Whisper/Vision 另列「real 未實作＋rc 0 假成功＋追 TMO-058」；**程式未動**（另開票，超出 doc-alignment 範圍） |
| **P1-2** R2/R3 可被註解滿足 | ✅ `strip_comment()`＋呼叫形態 regex＋`r2_comment`/`r3_comment` 反向迴歸；並附「修前綠／修後紅」實測 |
| P2-1 `${output}` 等形態 | ✅ 擴 regex＋`r3_brace`/`r3_ok_brace`；跨行搬移等 4 類寫入 docstring 已知限制 |
| P2-2 「不能當萬用豁免」過度承諾 | ✅ 三處改為真實語意（只擋標在無關行／沒寫理由；以標記總數為錨點）＋新增 **R5** |
| P2-3 V03.6 申報不實（「既有探針修改：無」） | ✅ 本交付物明列（見下方 V03.6 段）；該錯誤在**我給 reviewer 的證據包**，非 repo 檔 |
| P2-4 TMO-043 列過時 | ✅ 補「TMO-035 後續決策：該常數改為移除」 |
| P2-5「不留半成品」只有 audio 斷言 | ✅ WTM-3/WTM-8 加「不留部分產出」斷言；註解寫明 audio（連目錄都不建）vs media（會留空目錄）差異 |
| P2-6 poppler／pptx 未鎖 | ✅ 新增 WTM-8／WTM-9（首輪即綠＝characterization，敏感度用 MUT-G／MUT-I 佐證） |
| P3-1 簡體「断」 | ✅ 改「斷」 |
| P3-2 證據包 13 vs 12 | ✅ 更正為 12（首輪）→ 14（最終） |
| P3-3「僅保留最近 3 條」vs 4 列 | ✅ 補「+ v2.0 首版錨點（`tests/restruct-dav-wiki.bats` 需要）」 |
| P3-4 R4／SM-1 形式縫隙 | ✅ `MASK_DEF` 容忍前導空白與 `function`；R4/SM-1 目標集擴到 helpers；`r4_space`／`r4_helper` |
| P3-5 深度 1 假設 | ✅ 寫入 docstring＋SM-1 註解（並註明 SM-1 **不**排除 gitignore 檔的理由，與 ENV-EQ-12 慣例不同） |
| P3-6「祕鑰」 | ✅ 統一「密鑰」 |
| P3-7 TMO-057 範圍少一半 | ✅ 實查確認 6 支腳本**又各有 1 處** usage 死引用（:45/:50/:53/:69/:77 等，共 12 處）→ 票面擴充 |
| P3-8 WTM-6 鎖死常數會擋正當演進 | ➖ **不改鎖、加註解**：「未來真要加 OCR 硬退 4＝契約變更，改本探針（走 V03）是預期流程」 |
| **Round-2 P2-1** 文件數字是「中途值」 | ✅ 實跑 `bats --count tests/` = 600 → 全部改終值（555→557、598→600、601→603、333 行 598→600） |
| **Round-2 P3-1** TMO-043 殘句自相矛盾＋半形逗號 | ✅ 改「；`wiki-media-describe.sh` 則自帶同名常數（`:37`，未受影響）」 |
| **Round-2 P3-2** NYH-4 未同步 | ✅ NYH-4 補「✅ 已結案（2026-10-05；衍生 TMO-058）」、`doing`→`done` |
| **Round-2 P3-3** 6 處 usage 死引用 | ✅ 併入 TMO-057 票面 |
| **Round-2 P3-4** SKILL.md 134 行黃區 | ✅ 本交付物明示（見 V03.5 段） |
| **Round-2 P3-5** 標記錨點低估 | ✅ 計數移到「跳過整行註解」之前。**部分拒絕**：不把標記數釘進 SM-2——那會讓每個合格豁免都變成探針修改（V03.6 摩擦）；改為寫進 docstring 已知限制，由人工複核印刷出的數字 |
| **Round-2 P3-6** `$OPENROUTER_API_KEY` 直印無防線 | ✅ 新增 `ENV_KEY` 規則（**不看檔內是否提 `_load_api_key`**）＋`r3_envkey`/`r3_envkey_ok` 兩條自我測試；真樹 0 violation |
| **Round-2 P3-7** `[ ! -e "$dir"/*.md ]` glob 脆弱 | ✅ 改 `find -maxdepth 1 -type f` 計數形態（不依賴 nullglob 語意）＋修正註解「圖檔」超額宣告 |

> **第三輪**：reviewer 明示「不需再開第三輪」。本輪最後的處置（P3-5/P3-6/P3-7 + P2-1 數字）**只從嚴、未放寬**
> （新增偵測、斷言強化、數字校正），故不再送審；已重跑 self-test／全套／突變與 clean clone 佐證。

### V03.6 分類與放寬申報

| 類別 | 有無 | 內容 |
| --- | --- | --- |
| **新增探針** | ✅ 有 | `tests/wiki-toolmissing-contract.bats`（9 條）、`tests/secret-masking.bats`（5 條）；`scripts/ci/lint-probe-secrets.py`（新鎖 4）→ **觸發 V03，已走兩輪二審** |
| **條件放寬** | ❌ 無 | 未刪任何探針、未降低門檻、regex 只從嚴（`MASK_DEF` 更寬是**為了多抓**，目標集擴大亦同） |
| **既有探針修改** | ✅ 有 | ①`tests/helpers/test-env.bash`：新增共用 `mask_secrets()`（集中化）②`tests/poc-clean-clone.bats`：移除本地定義、呼叫點改共用版（從嚴）③本批新增的兩個 `.bats` 在 Round-2 再補強（SM-1 由 `git ls-files` 改 filesystem `find`＝修正真漏洞；WTM-3 斷言由 glob 改 `find -type f`＝強化） |
| **SOP 檔修改** | ❌ 無 | `AGENTS.md`／`docs/sop/gates.json`／`docs/sop/handbook/*` 皆未動 |
| **skill 主檔修改** | ✅ 有 | `skills/dav-wiki/SKILL.md`（限制表 1→2 列、變動歷史 +v2.2.1、措辭修正）；`CHANGELOG.md` +v2.2.1 → 觸發 V03（已走） |

### V03.5 行數預警

`skills/dav-wiki/SKILL.md`：131 → **134 行**，落在 **130–149 黃區**（V03.5 要求預警）。
距硬上限仍遠（`SSG-1` ≤150、`restruct-dav-wiki` ≤220），故僅預警、不瘦身；
下次再動此檔（尤其再加列）前，先做「移內容到子檔」的瘦身會比屆時被動處理便宜。
`skills/dav-wiki/CHANGELOG.md`：13 行（<100 軟上限，安全）。

## 突變驗證（探針真的會咬）

| 突變 | 內容 | 結果 |
| --- | --- | --- |
| MUT-A | SKILL.md 回寫「降級為純文字模式」 | WTM-5 紅 ✓ |
| MUT-B | `require_tool` 改 `exit 0`（假降級成功） | WTM-2 紅 ✓ |
| MUT-C | OCR usage 回寫 `EXIT_TOOLMISSING` | WTM-6 紅 ✓ |
| MUT-D | SM-1 改回 `git ls-files` 列舉 | **揭露真漏洞**：未 commit 的新探針檔掃不到 → 已改 filesystem `find` |
| MUT-E | 移除共用 `mask_secrets` 的遮罩能力（改 `cat`） | SM-3 紅 ✓ |
| MUT-F | 掃描器 R1 停用 | SM-5 紅 ✓ |
| **MUT-G** | `wiki-extract-media.sh` 拿掉 poppler 檢查 | WTM-8 紅 ✓ |
| **MUT-H** | 在探針檔偷加 `mask_secrets() { cat; }` | SM-1 紅 ✓（掃描器 R4 同報） |
| **MUT-I** | `wiki-extract-media.sh` 拿掉 pptx 的 python3 檢查 | WTM-9 紅 ✓ |

全部以 `diff -q` 驗證 **byte-identical 還原**。

## 已知問題（不阻 merge）

1. **TMO-058**（P2，新開）：`wiki-media-describe.sh` real 模式失敗仍 `exit 0` 且零產出＝**假成功**。
   本輪只改文件描述（不再歸類為「缺工具」），**行為未修**（需 TDD＋新探針，另票）。
2. **TMO-057**（P3，擴充）：12 處死引用（`docs/prd/03-knowledge-extraction.md` ×6 行首註解 ×6 usage、
   `docs/plan/…-sprint-08/09.md`），修法需決策（刪行／改指 `docs/system-design.md`／重建 PRD）。
3. **鎖 4 的已知限制（刻意不擋，寫在 docstring）**：跨行搬移（`local m="$output"` → `echo "FAIL: $m"`）、
   其他變數名（`$msg`/`$got`/`$KEY`）、`cat <<<` 與 `sed`/python 間接列印、非 `sk-or-v1-` 形態、
   只掃深度 1（新增 `tests/unit/*.bats` 時鎖 4 與 SM-1 兩處都要同步）。
4. **標記（`SECRET-OK`）不是自動防濫用**：只要一行長得像洩漏樣本，貼上合格理由即放行；
   防線是「人工複核掃描器印出的標記總數」（現值 5）。刻意**不**把數字釘進測試（避免每個合格豁免都要改探針）。
5. **`wiki-extract-media.sh` 失敗時會留下空目錄**（`mkdir -p` 早於 `require_tool`）：契約只承諾
   「不留部分產出」，探針照此鎖；若哪天要「連目錄都不留」是行為變更，需改腳本＋改探針。

## 下一步建議

1. **本輪交付驗收**（TMO-035／TMO-053 完成）。
2. **item 4**：TMO-055（README 加「本機開發前置」區塊）；順帶監控 `dav-skill-creater/SKILL.md`（148/150 行）。
3. **TMO-058**（P2／2pt）：修 `wiki-media-describe.sh` 假成功（單檔 `process_single … || exit $?`、批次收斂非零 rc）＋補探針。
4. **TMO-057**（P3／1pt）：死引用 12 處，需先決定「知識提取 PRD 是否重建」。
5. **item 0**（僅用戶可做）：TMO-054 OpenRouter key 輪替。

## 反思

**做對的**：①把「文件說謊」與「防線只有一份」當成同一類問題（**契約 vs 實作**）一起處理，兩者都用
「靜態鎖 + 實跑探針」雙軌包住；②P1-2 沒有只接受 reviewer 的說法——用「模擬修前語意」跑出**修前綠／修後紅**
的實證，把「他說有洞」變成「洞已關且有前後對照」；③MUT-D 揭露 `git ls-files` 掃不到未 commit 的新探針檔，
是這批最有價值的一次突變（**探針自己也會有盲點**）。

**做錯的**：在收尾突變演練時，我對一個 `git add -N`（intent-to-add）的新檔執行了 `git checkout --`，
**它把 `tests/secret-masking.bats` 直接截成 0 bytes**——檔案沒 commit，等於近失（near-miss）資料損毀。
當下兩個訊號救了我：`wc -l` 顯示 0 行、掃描器自己回報「只有 1 個檔碰 `_load_api_key`」（平時是 2）。
教訓：**突變演練本身比被測物更危險**——這與 TMO-040 的「破壞性腳本先問失敗會怎樣」是同一條紀律的第二次現身；
`git checkout --` 對意圖新增（`-N`）的檔案語意等同「用空內容覆寫 index 版本」，不是「還原」。

**學到的**：①`MASK_DEF` 這種「我在腦中寫對了」的 regex，只有**前導空白**這種小細節會讓整條規則靜默失效
（self-test 的 `r4` 案例當場抓到）；②reviewer 的 P3 未必小——Round-2 的 P3-6（`$OPENROUTER_API_KEY` 直印
完全沒有防線）比它標的 P2 更接近 NYH-1 的真實外洩形態，**分級是相對的，不是絕對的**；
③「標記數當錨點」這種人工防線要誠實標成人工防線，不要寫成自動防濫用（P2-2 的原始措辭就是過度承諾）。

**流程面的觀察**：Round-1 的 P1-2 讓我修掉了一條**看起來有、其實沒有**的規則（只查字面 `mask_secrets`）——
如果只跑「測試綠」就交件，這條會以「已修復」的名義活下來。**規則的可信度只能用「它擋不擋得住繞道」來證明**，
這也是本輪唯一值得留給下次的方法論。
