# TMO-064 + TMO-065 交付報告：`pptx-slim` 圖片管線 ＋ 突變測試自動化

> **交付日期**: 2026-10-05
> **對應 Backlog**: TMO-064（圖片壓縮）、TMO-065（突變測試自動化）— 皆 US 級，見 `docs/backlog.md`
> **Sprint / Module**: tree_monstor 建置／skills 模組（`skills/pptx-slim/`）＋ CI（`scripts/ci/`）
> **交付狀態**: ✅ 完成（4 Gate 全綠；26 支 mutant 全紅；V03 二審**兩輪**
> 皆 `approve-with-comments`（P0 0）—— Round-1：P1 1／P2 4／P3 10；Round-2 delta：P1 1／P2 4／P3 9，
> 全數處置與證據見 §4.4）

## 1. 這次完成什麼

兩件事：① 把「圖片體積」納入 `pptx-slim`（TMO-064）；② 把「探針真的咬得住突變」從**一次性人工動作**
變成 CI 每次都會跑的檢查（TMO-065）。

**關鍵成果**：

- ✅ 新工具 `skills/pptx-slim/scripts/pptx-shrink-images.py`（272 行）：預設 `--mode lossless`
  （PNG 重壓／TIFF deflate，**像素逐點自證**）；`--mode lossy` 才啟用長邊上限＋品質＋PNG 量化。
  與影片共用同一 `--media-dir`，一次 repack 完成。
- ✅ `pptx-verify.py` 新增**畫質關 G2d**（只有帶 `--image-mode` 才跑，既有四關語意不變）：
  無損 ⇒ 像素完全相同；有損 ⇒ 長邊 ≤ 上限且 PSNR ≥ 門檻；沒有可比對的光柵圖 ⇒ 明示不適用。
- ✅ 圖片探針 **21 條**（`tests/pptx-slim-images.bats`，本輪 13 → 21）、結構探針 9 條、功能探針 12 條、
  ffmpeg 探針 9 條、突變工具探針 5 條。
- ✅ 突變表 `scripts/ci/mutants.tsv`（**26 支**：11 圖片／12 影片與打包／3 ffmpeg 版本鎖）＋
  驅動器 `scripts/ci/mutant-must-die.py`（253 行）＋ CI 步驟 `Verify probes still kill mutants`。
  **本機實測 26/26 全紅、每支都有綠 baseline、跑完 md5 自證 working tree 未變（約 53 秒）**。
- ✅ 自動化**第一次實跑就抓到 2 個真的空過**（G1 新檔 CRC、FF-M3 能力實測被換成裝飾）→ 各補一支探針
  （`PPTX-SLIM-12`、`FV-9`），這正是這張表存在的理由。
- ✅ V03 二審**兩輪**：Round-1（P1 1／P2 4／P3 10）與 Round-2 delta review（P1 1／P2 4／P3 9）
  **全部落地並附證據**（§4.4）。Round-2 最關鍵的一條是 MMD-5 漏咬 `if:`（step 掛 `if: false`
  就能讓整張突變表靜默不跑）→ 檢查邏輯重寫成「剝註解＋正規化」並在探針內**反向自測 10 種假綠**。

### 1.2 為什麼做這個改動

- **為什麼做圖片（TMO-064）**：實戰案例裡影片壓完後，**圖片是第二大來源（139 MiB，含 29 MiB TIFF）**，
  但工具只自動化了影片 —— 剩下的得靠手做，而且手做沒有驗證。圖片與影片的風險不同：影片掉質感投影機上看不出，
  **圖片掉畫質很明顯**（字體發糊、線條生鬼影），所以拆成兩支腳本：圖片**預設無損**，有損必須自己說，
  而且要拿 PSNR 當證據。
- **為什麼做突變自動化（TMO-065）**：26 支 mutant 的價值在於「證明驗證器咬得住」，但**人工種的 mutant 只在
  寫下的那個 commit 有效**。之後任何人把 `report.gate(..., True, ...)` 改成恒真、把 `if after >= before` 拿掉、
  把精確比對改回子字串，都不會有探針紅、也不會有人記得重跑那張清單。這是一種**假信心**：
  文件上寫著「已用突變測試證明」，實際上那個證明已經過期。
- **為什麼突變在副本上做**：突變＝故意把碼改壞。若直接改 working tree，中斷就會留下壞碼，
  且「還原」只能靠事後自證。改成「複製一份 → 在副本上手術」，working tree 從頭到尾沒被碰過（雙重保險：仍比對 md5）。
- **成功怎麼看**：① 圖片無損模式對任何無法保證無損的圖**明示 SKIP 並說原因**，絕不偷偷降質；
  ② 把任一支 mutant 改回正常碼，對應探針必須綠（表真的在鎖行為）；③ CI 紅＝真的有人把護欄拿掉了。
  走錯的訊號：如果哪天為了讓 CI 快一點而把 mutant 表縮小、或加上 `--list`／`|| true`，就是紀律崩了 ——
  這件事本身也寫成探針（MMD-5）在盯。

## 2. 做了什麼改動

### 2.1 新增檔案

| 檔案 | 行數 | 用途 |
|------|------|------|
| `skills/pptx-slim/scripts/pptx-shrink-images.py` | 272 | 圖片重壓（lossless／lossy）；寫 `image-log.tsv`；rc 0/1/2/3 |
| `scripts/ci/mutants.tsv` | 34 | 26 列 × 6 欄：id／目標檔／整行原文／替換／探針檔／探針名 |
| `scripts/ci/mutant-must-die.py` | 253 | 在 working tree 副本上套突變 → 對應探針必須變紅 |
| `tests/pptx-slim-images.bats` | 398 | IMG-1～IMG-21 |
| `tests/mutant-must-die.bats` | 163 | MMD-1～MMD-5（鎖「這支檢查本身可信」＋10 種假綠反向自測） |

### 2.2 修改檔案

| 檔案 | 改動 |
|------|------|
| `skills/pptx-slim/scripts/pptx-verify.py` | 新增 G2d 畫質關、`RASTER_IMAGE_EXT`（由 `IMAGE_EXT` 推導）、刻意保留豁免（分塊比對）、`kept` 計數 |
| `skills/pptx-slim/scripts/pptx_common.py` | 新增 `match_only()`／`pillow()`／`png_bit_depth()`／`pixel_bytes()`／`pixels_same()`／`psnr()`；`psnr()` 改在較小尺寸比 |
| `skills/pptx-slim/scripts/pptx-shrink-media.py` | 新增 `--src`＝`--out` 護欄（rc=1，不原地覆蓋原檔） |
| `skills/pptx-slim/SKILL.md` | 規則表補圖片畫質關與 alpha 限制；變動歷史 v1.3（26 支／21 條探針） |
| `skills/pptx-slim/examples.md` | §4 踩雷表（ICC／刻意保留／PSNR 語意／向量圖／alpha／G2d 界線）；§5 兩個門檻語意與覆蓋率 |
| `skills/pptx-slim/CHANGELOG.md` | v1.2／v1.3 兩列 |
| `tests/pptx-slim.bats` | 11 → 12（`PPTX-SLIM-12`＝新檔 CRC 壞掉要紅） |
| `tests/ffmpeg-version.bats` | 8 → 9（`FV-9`＝能力實測字串 ≡ `scale_filter(1920)`） |
| `tests/restruct-pptx-slim.bats` | 腳本清單 4 → 5（含 `pptx-shrink-images.py` 且必須可執行） |
| `.github/workflows/ci.yml` | 新增 step `Verify probes still kill mutants`（不得 `if:` 停用／OR 短路／`continue-on-error` 假綠）|
| `docs/backlog.md`／`CONTRIBUTING.md`／`README.md` | 對齊數字（21 條探針／26 支 mutant／CI 步驟說明） |

### 2.4 改動背後的理由

| 決策 | 理由 |
|------|------|
| 圖片與影片拆兩支腳本 | 風險不同（影片掉質感看不出、圖片很明顯）；預設值必須不同（圖片預設無損） |
| 兩道護欄：格式／位深白名單 ＋ 像素自證 | 只靠像素自證抓不到「降位深」（8-bit 值看起來一樣）；只靠白名單抓不到「實作偷偷套濾鏡」——缺一不可 |
| 畫質關是 G2d（子關卡）而非新一關 | `--image-mode` 沒帶就不跑 ⇒ 既有的影片流程語意完全不變 |
| G2d 有損模式要「逐 byte 相同豁免」 | 壓縮器刻意保留的原檔（SKIP／KEPT／`--min-bytes`／`--only` 沒選到）尺寸本來就可能超上限，一視同仁會誤紅 |
| `psnr()` 在縮圖尺寸比 | 降採樣是預期的；把小圖放大回母帶再比等於懲罰合法的縮圖（實測 24.8 dB vs 28.5 dB） |
| 突變用 `.py` 而非 `.sh` | `scripts/ci/*.sh` 必須在每個本機 bash 版本下無參數跑得過（ENV-EQ-19）；重量級 sweep 放 `.sh` 會被那條守門規則擋 |
| 突變只發生在副本 | 中斷不會留下壞碼；working tree 全程未被碰（仍以 md5 自證） |
| 每支 mutant 都先跑 baseline | 否則「探針紅了」只代表探針本身壞了＝假信心 |

## 3. 驗收標準對應

| AC | 要求 | 交付證據 |
|----|------|---------|
| AC-1 | 圖片可無損壓縮且**像素完全相同** | `pptx-shrink-images.py --mode lossless`；IMG-2/IMG-5（`pixels_same()` 逐點比對）；IMG-3 拒 16-bit |
| AC-2 | 有損模式有**尺寸與品質門檻** | `--image-max-edge`／`--image-quality`／`--png-colors`；IMG-6/7/17；G2d |
| AC-3 | 圖片與影片**一次 repack** 完成 | 共用 `--media-dir`；IMG-9（一次 repack 後四關含 G2d 全綠） |
| AC-4 | 圖片壓縮不能動到非媒體 entry | 沿用 `pptx-repack.py` 契約（非媒體逐 byte 原樣）＋ G2b G3a G4 |
| AC-5 | 突變表**檔案化**、CI 會跑 | `scripts/ci/mutants.tsv` ＋ CI step `Verify probes still kill mutants` |
| AC-6 | 突變**不會改到 working tree** | `mutant-must-die.py` 在副本上動手術 + 跑完比對 md5（實測 6 個目標檔全數未變） |
| AC-7 | 「這支檢查本身」也有探針 | `tests/mutant-must-die.bats` MMD-1～5；**10 種假綠**反向自測全部咬紅（含 `if: false`）|
| AC-8 | 每個 gate／護欄都有 mutant 對應 | 26 支：11 圖片＋12 影片與打包＋3 ffmpeg；全紅 |

## 4. 測試結果

| 測試類型 | 通過 / 總數 | 備註 |
|---------|-------------|------|
| 圖片探針（`tests/pptx-slim-images.bats`）| 21 / 21 | IMG-1～21；本輪新增 8 條（14～21） |
| PPTX 功能探針（`tests/pptx-slim.bats`）| 12 / 12 | 含新增 `PPTX-SLIM-12`（新檔 CRC 壞掉） |
| 結構探針（`tests/restruct-pptx-slim.bats`）| 9 / 9 | 5 段結構、行數預警線、無跨目錄連結、5 支腳本存在且可執行 |
| ffmpeg 探針（`tests/ffmpeg-version.bats`）| 9 / 9 | 含新增 `FV-9`（能力實測字串 ≡ `scale_filter(1920)`） |
| 突變工具探針（`tests/mutant-must-die.bats`）| 5 / 5 | MMD-5 重寫：剝註解＋正規化後咬 `if:`／`continue-on-error`／OR 短路／三個旗標，並反向自測 10 種假綠 |
| 突變全表（`scripts/ci/mutant-must-die.py`）| 26 / 26 死亡 | 每支都有綠 baseline；md5 自證；`real 0m52.9s`（改錨點後重跑）|
| 守門探針（skill-local）| 3 / 3 | `SKILLS_DIR_OVERRIDE=$PWD/skills bats skills/*/tests/*.bats` |
| 全量回歸（`bats tests/`）| 5 次中的 3 次 **673 綠 / 0 紅**；另兩次 1～2 紅 | 紅的都是 `M6.3-c`／`M6.3-e`（既有 flaky；隔離重跑也會紅）⇒ 與本輪改動無關（見 §4.3／§5）|

### 4.1 Gate 1（TDD）：先紅後綠

每個新行為都先寫探針看它紅，再補實作。本輪由探針逼出的真 bug／風險：

| # | 現象 | 根因 | 修法 | 鎖住它的探針 |
|---|------|------|------|-------------|
| 1 | 有損模式的長邊上限**誤紅刻意保留的原檔** | 上限檢查一視同仁 | 逐 byte 相同 ⇒ 豁免（不計入上限），detail 明示「N 張是刻意保留的原檔」 | IMG-14（不誤紅）＋ IMG-15（真有重編又超標仍要紅） |
| 2 | 純向量 deck 被 G2d 判 FAIL | `IMAGE_EXT` 含 `.svg`／`.emf`／`.wmf`（Pillow 解不開） | 新增 `RASTER_IMAGE_EXT`，候選只認光柵圖 | IMG-19 |
| 3 | 合法縮圖被 PSNR 誤殺（預設門檻 30） | 把小圖放大回母帶再比 | 改在較小尺寸比（實測 24.83 → 28.46 dB） | IMG-20（門檻 27 兩邊對開） |
| 4 | 壞圖吐 traceback、rc=1 | 只 catch `SystemExit` | catch `(SystemExit, OSError, ValueError)` → rc=3 | IMG-16 |
| 5 | `--src`＝`--out` 會原地覆蓋原圖 | 無護欄 | 兩支腳本都在 main 開頭擋（rc=1） | IMG-21（含 `cmp -s` 證明原檔未變） |
| 6 | `--png-colors` 沒有任何探針證明真的在量化 | 覆蓋率缺口 | 補探針 + mutant | IMG-17、IMG-M11 |

**Mutant 全表（26 支，`python3 scripts/ci/mutant-must-die.py` 全數死亡）**：

| 分組 | 支數 | 代表例（改壞什麼 → 咬住它的探針） |
|------|------|-----------------------------------|
| 圖片（IMG-M1～M11）| 11 | 縮圖失效 → IMG-6；無損白名單移除 → IMG-3；G2d 恒真 → IMG-10/11；PSNR 門檻失效 → IMG-20；**原檔豁免移除 → IMG-14**；Pillow 例外直出 → IMG-16；**PSNR 尺寸正規化移除 → IMG-20**；`--src`＝`--out` 護欄移除 → IMG-21；**向量圖算進光柵 → IMG-19**；`--png-colors` 裝飾 → IMG-17 |
| 影片與打包（V-M1～M12）| 12 | G2b 恒真 → PPTX-SLIM-4；rels 斷鏈檢查恒真 → 5；keep-original 失效 → 3；`src == dst` 移除 → 6；媒體判定退回只認影片 → 7；`--force` 移除 → 9；`--only` 精確比對退回子字串 → 10；G4 系列 → 11；**新檔 CRC → 12** |
| ffmpeg 版本鎖（FF-M1～M3）| 3 | 版本底線 → FV-2；第一組能力實測 → FV-8；**第二組能力實測 → FV-9** |

**「這支檢查本身」的反向自測（probe-of-the-probe）**：造一份假 `ci.yml`（`CI_YML` 環境變數可覆寫），
把該步驟改成 **10 種假綠**各跑一次 MMD-5 → **10 種全部咬紅**，而真 `ci.yml` 仍綠：

| 手法 | 為什麼危險 |
|------|-----------|
| `if: false` | 整步靜默消失（Round-2 P1-1；Round-1 只咬了 OR 短路，沒咬 `if:`）|
| `if: runner.os == 'Linux'` | 本 repo 既有寫法，掛上去同樣能把步驟停掉 |
| `continue-on-error: true` | 步驟紅了也不算失敗 |
| `continue-on-error:true`（無空白）| 精確字串比對會漏（Round-2 P2-1）|
| OR 短路（`true` 前有空白）| 最經典的假綠：失敗被吃掉 |
| OR 短路（無空白）| 同上，只有正規化後才咬得住 |
| `--list` | 「有檔案但沒人叫」：只列清單、不跑任何 mutant |
| `--only IMG-M1` | 「跑到 ≠ 跑過全表」：只跑一支也印 OK |
| `--no-baseline` | 沒有綠 baseline 對照，「紅」不再有意義 |
| `run: echo …mutant-must-die.py` | 只提到腳本名、沒真的叫它（Round-2 P3-5）|

### 4.2 Gate 2（lint / syntax）

| 檢查 | 結果 |
|------|------|
| `markdownlint-cli2`（CI 同款 4 globs）| **137 files / 0 issues** |
| `bash scripts/ci/check-skill-size.sh` | OK：12 個 SKILL.md 皆 ≤ 150 行（最長 148：`dav-skill-creater`；本 skill 69 行）|
| `bash scripts/ci/check-python-heredocs.sh` | OK：9 個 embedded Python heredoc |
| `shellcheck -x -S style $(git ls-files '*.sh' '*.bash')` | OK：23 檔 |
| `bash -n` 自我列舉 | OK：23 檔（下限 20 tripwire）|
| `python3 scripts/ci/lint-probe-*.py .` | secrets／tmp-paths／tools 各 52 探針檔 0 violation；`lint-shell-var-nonascii.py` 78 檔 OK |

### 4.3 Gate 3（regression）

- **全量**：`bats tests/` 本輪共跑 5 次（同一份碼的頭尾＋文件同步前後）：

  | 次 | 結果 | 紅的是誰 |
  |----|------|---------|
  | v15（Round-1 後）| 673 綠 / 0 紅 | — |
  | v16（程式碼修完）| 673 綠 / 0 紅 | — |
  | v17（文件同步後）| 672 / 1 紅 | `M6.3-e` |
  | v18（修改定稿後）| 673 綠 / 0 紅 | — |
  | v19（最終）| 671 / 2 紅 | `M6.3-c`、`M6.3-e` |

  `M6.3-c`／`M6.3-e` 是既有探針（`tests/v2.1-jev-poc.bats`），隔離單獨重跑也會紅（`M6.3-c` 4 次紅 1、
  `M6.3-e` 6 次紅 2），與本輪 pptx-slim／`tests/` 新增檔無關 —— 但這支間歇性會讓「全量全綠」的說法不穩（見 §5）。
- **模仿 CI**：`bats tests/`（含 env-equivalence ENV-EQ-1～19）＋ `SKILLS_DIR_OVERRIDE=... bats skills/*/tests/*.bats`。
- **突變全表連 working tree 一起驗**：跑完比對 6 個目標檔 md5 → 全數未變（突變只發生在已刪除的副本）。
- **非媒體零改動**：所有 pptx 探針都經 `pptx-repack.py` + `pptx-verify.py` 的四關（G1 CRC／G2b 非媒體 byte 相同／
  G2c 媒體一致／G3a rels 零斷鏈／G4 時長漂移），G2d 只在帶 `--image-mode` 時多跑一關。
- **測試工具自身的環境坑**：巢狀 bats 若把 `BATS_*` 全清，內層 bats 會找不到 libexec（`validator.bash: No such file`）→
  只清 `BATS_TEST_*` 前綴 + 明確 deny set。

### 4.4 Gate 4（reviewer 二審，V03）

**Round-1（完整審查；原文在 session artifact，依慣例審查報告不落 `docs/ac/`）**：verdict = `approve-with-comments`，
P0 0／P1 1／P2 4／P3 10。處置如下（每條都有專業證據，不是「已改」）：

| 編號 | 發現 | 處置 | 咬住它的證據 |
|------|------|------|-------------|
| **F-A（P1）** | G2d 有損長邊上限會誤紅 SKIP／KEPT 的原檔 | 逐 byte 相同 ⇒ 豁免 + detail 明示 | IMG-14（不誤紅）／IMG-15（對開：重編又超標仍紅）／IMG-M6 |
| F-B（P2） | MMD-5 漏咬 `--list`／`--only`／`--no-baseline` 等假綠 | MMD-5 重寫 + 4 種假綠反向自測（Round-2 再擴到 10 種，見下）| 4 種全部咬紅；真 CI 綠 |
| F-C（P2） | 只 catch `SystemExit` → traceback rc=1 | catch 三種例外 → rc=3 | IMG-16／IMG-M7 |
| F-D（P2） | 向量圖 deck → `checked == 0` 誤 FAIL | `RASTER_IMAGE_EXT`；不適用則明示 | IMG-19／IMG-M10 |
| F-E（P2） | RGBA/LA TIFF 的 lossy 語意未證 | 實測後保留行為（mode 保住、LA 走 SKIP）＋文件明示 alpha 限制 | 實測：`rgba.tif` 937.7 KiB → 59.1 KiB（93.7%）、mode 仍 RGBA |
| F5（P3）| 存在性檢查在 md5 之後 | 對調 | 碼序 |
| F6（P3）| dead code（`cache` dict）| 刪除 | diff |
| F7（P3）| `PROBE_TIMEOUT` 900s；逾時 rc=124 被當「咬住」 | 300s；rc 124 視為 harness 問題 | 實跑 51.6s |
| F8（P3）| PNG 位深白名單可放寬（1/2/4-bit 精確映射安全）| 放寬至 {1,2,4,8}；同步改 IMG-M5 錨點 | IMG-3 仍擋 16-bit；IMG-M5 仍紅 |
| F10（P3）| PSNR 放大回母帶 → 合法縮圖誤殺 | 改在較小尺寸比 | IMG-20（門檻 27）／IMG-M8；實測 24.83 → 28.46 dB |
| F13（P3）| `--src`＝`--out` 會覆蓋原檔 | 兩支腳本都擋（rc=1）| IMG-21／IMG-M9 |
| F-B～F14 其餘（P3）| 文件數字／註解／命名等 | 逐條修並把數字對齊（20 → 26 支、13 → 21 條）| §4.2 lint 全綠、`examples.md` §4/§5 |

**Round-2（delta review，唯讀無 shell）**：verdict = `approve-with-comments`，**P0 0／P1 1／P2 4／P3 9**。
reviewer 明確確認 F-A～F-E **五條方向全對**、沒有一條是把咬合力豁免掉的假修；並用三條靜態可證的理由背書上一輪唯一 P1 的豁免機制：
豁免只能由「bytes 完全相同」觸發（真重編一定掉進 `else` 照樣紅）、`checked` 不會因全部 kept 變 0（gate 仍 PASS）、
IMG-15 自帶 `cmp -s` 反退化守衛。本輪處置：

| 編號 | 發現 | 處置 | 咬住它的證據 |
|------|------|------|-------------|
| **P1-1** | MMD-5 沒咬 `if:`：step 掛 `if: false` 就靜默消失，探針照樣 PASS | 檢查邏輯重寫：剝註解＋去空白＋大小寫正規化後咬 `if:`／`continue-on-error`／OR 短路；並在探針內**逐一反向自測 10 種假綠**（probe-of-the-probe）| MMD-5：真 `ci.yml` 綠 ＋ 10 種假 `ci.yml` 全紅（`if: false`、`if: runner.os == 'Linux'`、無空白 `continue-on-error:true`、無空白 OR 短路、`--list`／`--only`／`--no-baseline`、「只提到腳本名但沒真的叫」）|
| P2-1 | 兩個禁用字串是精確比對，無空白／大小寫變體可繞過 | 同 P1-1（正規化後才比；`continue-on-error` 也補上剝註解，與 OR 短路對稱）| 同上（變體在自測清單內）|
| P2-2 | F-E 宣稱「文件補 alpha 限制」，但 `SKILL.md`／`examples.md` 零命中 | `examples.md` §4 加一列（alpha 只是有損近似、PSNR 在 RGB 空間量、LA 模式走 SKIP）；`SKILL.md` 限制欄加一句 | 文件本體（case-insensitive 掃 alpha／透明／RGBA 已命中）|
| P2-3 | F-A 新路徑 `read_bytes()` 兩次＝最大那張圖 2 倍常駐記憶體 | 改用同檔既有的分塊 `stream_same(zs, zd, name)`；`mutants.tsv` 的 IMG-M6 錨點同步更新 | 重跑全表：IMG-M6 仍紅（26/26 死）|
| P2-4 | 本輪缺全套回歸證據（bundle §3.1 空）| 補跑 `bats tests/` 全量（其後又跑 4 次；並修正 bundle §6.0）| 5 次中 3 次 673 綠 / 0 紅；紅的兩次都是既有 flaky `M6.3-c`／`M6.3-e`（見 §4.3／§5）|
| P3-1～9 | 九條小洞 | ① `psnr()` docstring 對齊 24.8／28.5；② `examples.md` 表頭 Q70 改 Q80；③ −95% 註明 TIFF 主導；④ G2d detail（與文件）補「全部刻意保留時，本關只證明沒掉畫質、不證明有壓縮」；⑤ runline 加「必須真的用 python 叫那支腳本」並把「只提到腳本名」列入自測；⑥ `return PROBE_TIMEOUT_RC`；⑦ `RASTER_IMAGE_EXT` 改由 `IMAGE_EXT` 推導；⑧ `PPTX-SLIM-12` 搬到 11 之後；⑨ TIFF 有損分支與無損對稱傳 `dpi` | ①～④、⑨ 看文件與 `--help`；⑤⑥⑦ 重跑 56 條探針全綠；⑧ `grep -n '^@test'` 順序 11 → 12 |

**reviewer 明示、我接受不當缺陷的三點**：① G2d 在 lossy 下無法證明「真的有壓縮」（全部刻意保留也 PASS）——
已用 detail 與文件講清楚證明界線，補位的是 IMG-6／IMG-18（log 至少 2 張 `ENCODED`）；
② MMD-5 的 runline 仍是字串比對而不是 YAML 語意——已加「必須真的叫 python 跑那支腳本」＋把該情境列入自測；
③ reviewer 唯讀無 shell，所有執行類結論（26/26 死、56 綠、673 綠）以本報告的實跑輸出為準。

## 5. 已知問題 / 限制

- **真 deck 的圖片仍未實跑**：`examples.md` 的 −98%（TIFF）／−20.8%（PNG）是 fixture 實測；
  2.9 GB 案例的 139 MiB 圖片尚未用新工具跑過（原檔已被用戶移走）。
- **`--min-bytes` 全部圖都 skip 時不寫 `image-log.tsv`**（IMG-13 的既有契約）。若使用者拿這個空目錄當
  `--media-dir`，G2c（至少比到一支）會 FAIL —— 這是刻意的：G2c 的「空過＝FAIL」是防「打錯 `--media-dir`」的護欄，
  兩者衝突時選保留護欄，並在 `examples.md` §4 寫明。
- **TIFF lossy 的 `dpi` 已對稱化**（Round-2 P3-9）。原判斷「Pillow 不傳也會沿用來源 resolution tag」
  經實測成立（300 dpi 來源經 lossy 後仍 300 dpi），但 reviewer 指出這讓 lossy 的行為依賴 Pillow 版本、
  且兩分支不對稱；現兩邊都顯式傳 `dpi=img.info.get("dpi")`。**不加探針**：PPTX 的擺位由 XML 的 EMU extent 決定、
  不靠圖片 dpi tag，這個斷言不可證偽，寫成探針只會是假信心。
- **`pptx-repack.py` 換媒體後用 `ZIP_STORED`** ⇒ 小 fixture 整包可能反而變大（契約：不對已壓縮媒體再 DEFLATE）。
  量測贏面一律以「未壓縮媒體總量」為準（IMG-9 這樣寫）。
- **突變表只覆蓋 pptx-slim 的 5 支 py ＋ ffmpeg 版本鎖**：其他 skill 的護欄尚無 mutant；突變是文字替換，
  改不到的多行重構不在鎖內。
- **G2d 在 lossy 下「只證明沒掉畫質，不證明有壓縮」**（reviewer round-2 §3.1）：`kept` 也計入 `checked`，
  所以「一張都沒真的壓」也會 PASS。已用 detail 訊息（全部刻意保留時明示）與 `examples.md` 講明界線；
  真正的補位證據是 IMG-6／IMG-18（log 至少 2 張 `ENCODED`）。
- **`M6.3-c`／`M6.3-e` 是間歇性紅（既有，非本輪引入）**：兩支都在 `tests/v2.1-jev-poc.bats`（sandbox 的
  `classification` 必須是 `no_change`）。本輪 5 次全量跑：3 次 0 紅、2 次各 1～2 紅；隔離單獨重跑也會紅
  （`M6.3-c` 4 次紅 1、`M6.3-e` 6 次紅 2），所以不是並行／負載造成。與本輪改動無關（同一份碼在更早的全量跑是綠的），
  但會讓「全量全綠」的敘事不穩。**線索**：`tmp/` 下累積了 260 個 `.sandbox-US-M63-*` 目錄（清理不徹底），
  而 M6.3 這族測的就是 sandbox 建／用／清 —— 建議追根因時先看殘留是否影響下一次的分類。本輪不動它。
- **MMD-5 的 CI 檢查仍是字串比對，不是 YAML 語意**（reviewer round-2 P3-5）：`run` 行以子字串判定。
  已加「必須真的用 python 叫 `scripts/ci/mutant-must-die.py`」＋把「只提到腳本名但沒真的叫」列入 10 種反向自測，
  可繞過的路徑只剩「語意等價但寫法奇特」的假紅／假綠邊角。若日後要更硬，可改用 PyYAML 取 `run`／`if` 欄位語意
  （repo 有先例 `tests/poc-bootstrap.bats`）。
- **CI 代價**：全表每次約 53 秒。

## 6. 下一步建議

### 6.1 立即可做（建議優先）

1. **用 PowerPoint 實開減重後的 `.pptx`**（TMO-063 交付檔案）：四關之外的人工最後一關（動畫／時序／書籤）。
2. **對真實案例圖片跑一次**：`pptx-shrink-images.py --mode lossless` → 看實際省下多少（預期 TIFF 佔大宗），
   並把數字補回 `examples.md`。
3. **其他 skill 的護欄補 mutant**：先挑 `dav-wiki`／`regression-guard` 的高風險護欄（各有探針、成本低）。
4. **`M6.3-e` 間歇性紅追根因**（既有問題，非本輪引入；見 §5）：它會讓「全量全綠」變得不穩，
   建議立一個 backlog item 查 sandbox `classification` 為何間歇變成非 `no_change`（編號待你點頭，與上面那條一起編）。

### 6.2 下一個 Sprint 考慮

- `--only` 一詞兩義（精確 vs 子字串）仍在；建議拆 `--only`／`--only-fuzzy`（本次仍先以 WARN 明示）。
- 圖片有損的 PSNR 門檻是「全域一個數字」；若要更準，可依圖片類型（照片 vs 線稿）分開給門檻。

### 6.3 長期方向（Think Big）

- **量測庫**：每次實跑把「原檔／輸出／各類別 bytes」寫成一個小 YAML 存進 `docs/`（不含媒體本體）→ 案例數字可複核。
- **突變表跨 skill 化**：把 `mutants.tsv` 的 schema 抽成 repo 級契約，讓每個 skill 都有自己的 mutant 清單。

## 7. 變更集（`git diff HEAD --numstat`）

13 個已追蹤檔案、+455 / −62 行；另 5 個新檔案共 1,120 行（未 commit，依 SOP 由你驗收後決定）：

```
   9     0  .github/workflows/ci.yml
  14     0  CONTRIBUTING.md
   1     1  README.md
  81    13  docs/backlog.md
   2     0  skills/pptx-slim/CHANGELOG.md
  12     5  skills/pptx-slim/SKILL.md
  62     2  skills/pptx-slim/examples.md
   6    37  skills/pptx-slim/scripts/pptx-shrink-media.py
  91     1  skills/pptx-slim/scripts/pptx-verify.py
 111     0  skills/pptx-slim/scripts/pptx_common.py
  23     0  tests/ffmpeg-version.bats
  40     0  tests/pptx-slim.bats
   3     3  tests/restruct-pptx-slim.bats
 253     0  scripts/ci/mutant-must-die.py        （新）
  34     0  scripts/ci/mutants.tsv               （新）
 272     0  skills/pptx-slim/scripts/pptx-shrink-images.py（新）
 163     0  tests/mutant-must-die.bats           （新）
 398     0  tests/pptx-slim-images.bats          （新）
```

> 本報告自身（`docs/deliverable/2026-10-05-tmo-064-tmo-065-pptx-slim-images-mutants.md`）未列入上表。
> 本輪（Round-2 verdict 後）的修正都在上表內：`pptx-verify.py`（分塊比對／推導集合／detail 界線）、
> `pptx_common.py`（docstring 數字）、`pptx-shrink-images.py`（dpi 對稱）、`mutants.tsv`（IMG-M6 錨點）、
> `tests/mutant-must-die.bats`（MMD-5 重寫）、`tests/pptx-slim.bats`（順序）、`examples.md`／`SKILL.md`（alpha 與界線）。

## 反思（§2.4，US 級反省）

**反省層級**：US（TMO-064／TMO-065 兩項）。**jev 模式**：off（本機無 `jev-use`，依 dav-reflection 軟性降級為純 LLM 評分）。

### 6 維度檢查

| # | 維度 | 結果 | 備註 |
| - | --- | --- | --- |
| 1 | UX/UI 一致性 | ✅ | 訊息格式沿用既有前綴（`OK:`／`SKIP(...)`／`[PASS]`／`[FAIL]`）；每個 gate 都印判準與數字；`--list` 可先看不跑 |
| 2 | RWD 響應式設計 | ✅（N/A）| 無 UI；等價項＝終端寬度：欄寬固定（`{:<20}`／`human_bytes`）不依賴視窗寬度 |
| 3 | 技術債 | ⚠️ | ①真 deck 圖片未實跑（數字未能複核）②`--min-bytes` 全 skip 與 G2c 的語意衝突（刻意保留護欄並寫明）③突變表只覆蓋本 skill |
| 4 | 可維護性 | ⚠️→✅ | 本輪最大的可維護性收穫是**突變表自動化**（護欄不再只靠文件上的「已證明」）；但 `psnr()` 語意改動是**行為變更**，已在 docstring 註記數字 |
| 5 | 測試覆蓋率 | ✅ | 探針 56 條（本 skill 家族）＋ mutant 26 支；**驗證器自身**也有 mutant（不是只覆蓋正常路徑）；10 種假綠反向自測 |
| 6 | 需求對齊 | ✅ | 用戶要「①commit ②圖片壓縮 ③突變 CI」→ 三項全交付；圖片預設無損符合「不能偷掉畫質」的隱性要求 |

### 問題清單（根因 + 建議）

- ⚠️ [P3] **真 deck 圖片沒有實跑** — 根因：原檔已被移走＋本輪時間在驗證上 — 建議：拿到任一含圖片的 PPTX 就跑一次 lossless，把數字補進 `examples.md`。
- ⚠️ [P3] **豁免條件的方向最容易寫錯**（本輪 P1 的教訓）— 根因：為了不誤紅，豁免很容易寫成「只要有保留就不檢查」，
  那會把整段咬合力拿掉 — 建議：未來寫任何豁免都**同時**寫一支「反向制衡」探針（本輪 IMG-15 就是這支）。
- ⚠️ [P3] **`psnr()` 是行為變更**（門檻語意不同）— 根因：原作者（我）用「母帶 vs 產物」的直覺寫比對，但縮圖是預期行為 —
  建議：量測函式改語意時，把「舊語意／新語意的數字」都寫進 docstring（本輪已做）。
- ⚠️ [P2] **「宣稱已修」與「實際交付」不一致**（reviewer round-2 P2-2：F-E 的 alpha 限制上一輪我寫進報告與 CHANGELOG，
  但 `SKILL.md`／`examples.md` 根本沒有那句話）— 根因：把「打算寫進文件」當成「已寫進文件」，
  而當時的自審只看了程式碼 — 建議：宣稱「文件已改」時，**在報告裡貼出那句話的原文或附一次 grep 自證**；
  這一輪已補（`examples.md` §4 一列＋`SKILL.md` 限制欄一句）。
- ⚠️ [P3] **突變工具的 CI 成本是硬支出**（53 秒／次）— 根因：不腐化的代價 — 建議：若 CI 變慢，先考慮「只跑 diff 涉及的 mutant」，
  但**不要**用 `--list` 假綠（已被 MMD-5 咬住）。

### Action Items

1. 對真實案例圖片跑 `--mode lossless`（把數字補回文件）— 指派：下一個 task。
2. `dav-wiki`／`regression-guard` 的高風險護欄補 mutant — 指派：新 backlog item（下一個空號 TMO-066 起；本輪未建，等你點頭）。
3. `M6.3-e` 間歇性紅追根因（sandbox `classification` 為何偶爾不是 `no_change`）— 指派：另一個新 backlog item（編號待你點頭）。
4. `--only` 語意拆分（`--only-fuzzy`）— 指派：Backlog 待排。
