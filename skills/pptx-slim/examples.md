# Pptx Slim — 實測案例與參數食譜

> 本檔是 `SKILL.md` 的子檔：live 數字、可直接複製的指令、profile 選擇表、踩雷對策。
> 主檔只保留概念與紀律，避免 LLM 注意力被細節淹沒。

## 1. 實測戰績（2026-10-05，澳門政府大模型業務培訓 deck）

| 項目 | 數值 |
|------|------|
| 原檔 | 2,976.8 MiB（3,121,443,653 bytes），1,673 個 zip entry，140 頁 |
| 體積來源 | 影片 2,835 MiB = **95%**（16 支 mp4 + 1 支 mov）；圖片 139 MiB；XML／其他 ≈3 MiB |
| 選定 profile | 1080p（長邊 1920）／H.264 CRF 24／AAC 128k |
| 產出 | **418.4 MiB（438,735,945 bytes，−86%）**；17 支影片替換 16 支（media1 壓完更大 → 保留原檔）|
| 重打包 | 1,673 / 1,673 entries written，0 missing |
| 驗證 | zip CRC 全綠；非媒體 entry 逐 byte 相同；rels 0 斷鏈；時長最大漂移 0.02 s；LibreOffice 轉 PDF 得 140 頁 |

單支對照（MiB；工具輸出亦為 1024 進位）：

| media | 前 | 後 | 說明 |
|-------|----|----|------|
| media4.mp4 | 1,107.5 | 75.8 | 最大咖，省最多 |
| media12.mp4 | 361.5 | 19.3 | |
| media9.mp4 | 164.0 | 28.3 | |
| media17.mov | 265.3 | 4.4 | .mov 一樣原地轉碼、**容器與檔名不改**（保持 .mov）|
| media1.mp4 | 47.0 | 47.6 | 已高度壓縮 → 壓完更大 → **保留原檔** |

## 2. 指令序列（照抄就能跑）

```bash
# 1) 偵察：先知道 95% 體積在哪幾支，並用 30 秒抽樣外推估體積
python3 scripts/pptx-probe.py deck.pptx --top 20 --estimate --crf 24 --max-edge 1920

# 2) 轉碼：輸出到獨立目錄，檔名與 zip 內一致；壓完更大的自動退回原檔
python3 scripts/pptx-shrink-media.py --src deck.pptx --out encoded --crf 24 --max-edge 1920

# 3) 重打包：只換 media，其他 entry 逐 byte 原樣；永遠寫新檔
python3 scripts/pptx-repack.py --src deck.pptx --dst deck_1080p.pptx --media-dir encoded

# 4) 驗證：四關（CRC／entry 齊全＋非媒體 byte 相同／rels 零斷鏈／時長漂移）。
#    原檔很大時 --fast 可跳過原檔 CRC（新檔一定驗）；--media-dir 會逐 byte 核對換上去的媒體
python3 scripts/pptx-verify.py --src deck.pptx --dst deck_1080p.pptx --media-dir encoded --fast

# 5) 實開（人工最後一關）：PDF 頁數必須等於投影片頁數
soffice --headless --convert-to pdf --outdir /tmp deck_1080p.pptx
```

## 3. Profile 選擇表（給用戶挑，第一個是最推薦）

| Profile | 參數 | 適合 | 預期效果 |
|---------|------|------|----------|
| ⭐ 1080p | `--crf 24 --max-edge 1920` | 培訓／會議簡報，投影或 1080p 螢幕 | 實測 −86%，肉眼難辨 |
| 720p | `--crf 28 --max-edge 1280` | 只要求看得清、體積優先 | 再省 40–50%，字幕／細節會軟 |
| 高保真 | `--crf 20 --max-edge 1920` | 有投到 4K 或要再剪輯 | 省 70–80% |
| 精準打擊 | `--only media4,media9` | 只有 1–2 支特別大 | 省下的體積幾乎等於大咖全換 |
| 圖片加碼（無損）| `pptx-shrink-images.py --mode lossless` | 影片壓完仍不夠小，且不能掉畫質 | PNG 重壓、TIFF deflate；fixture 實測 −95%（**TIFF 主導**：TIFF −98%／PNG 只有 −21%）|
| 圖片加碼（有損）| `--mode lossy --image-max-edge 1920 --image-quality 85` | 投影用，接受一點掉畫質 | 再大一圈（縮圖是最有效的那一刀）|

> 圖片那條路是另一支腳本：影片是重編碼，圖片是重壓縮／重採樣，風險不同（見 §5）。

CRF 對照：`18` 近無損、`24` 推薦（訓練用簡報的甜點）、`28` 明顯省。CRF 是「畫質固定、體積浮動」，所以估數只能用抽樣外推。

## 4. 踩雷對策

| 症狀 | 真正原因 | 對策 |
|------|----------|------|
| 新檔 CRC 壞、PowerPoint 說修復 | 直接用 `zipfile` 改寫原 zip（append 模式或就地覆蓋）| 一定要「開原檔 → 寫**全新** zip」，寫完 `testzip()` 驗 CRC |
| 時長漂移 > 0.5 s | 轉碼丟尾格、或音訊被 fps 對齊重採樣 | 加 `-shortest` 的外層要小心；改用 CFR 保持、或只壓影像不壓音訊 |
| rels 斷鏈、動畫散掉 | 改了媒體檔名或容器格式（mp4→webm）| 檔名與容器一律不改；只改編碼參數 |
| 輸出反而比原檔大 | 全部媒體都「保留原檔」，但新 zip 用了 ZIP_STORED | 保留原檔時沿用**原本的壓縮方式**；只有真的換掉的媒體才用 STORED |
| 為什麼媒體不用 deflate | mp4 已是壓縮格式，deflate 只省 < 0.1% 還要多花 CPU | 媒體一律 STORED；文字型 XML 沿用原本壓縮方式 |
| 豎屏影片被壓得太細 | 只封頂長邊、短邊 `-2` 自動偶數；不要對短邊設上限 | 用長邊封頂；有 rotation metadata 交給 ffmpeg 自動轉正 |
| 空間不足 | 峰值＝原檔＋轉碼輸出＋新檔 ≈ 2× 原檔 | 先確認磁碟空間；轉碼輸出可逐支寫入、重打包後即刪。四關的 G4 另需 2× 最大影片的暫存空間（落在 `TMPDIR`，可能是另一個 volume；`--fast` 不省這一項）|
| 打了錯的 `--media-dir` 卻報 OK | 只數「對得上的有幾支」，一支都比不到＝等於沒驗 | G2c 要求至少比到一支；目錄不存在即 FAIL（空目錄不算過關）|
| `--only media1` 連 media10–17 一起壓 | 子字串命中（檔名 stem 含 `media1`）| 精確優先（`media1` 只中 `media1.mp4`）；真要用子字串會先 WARN 並列出命中哪幾支 |
| repack 蓋掉上一輪已驗證的輸出 | `--dst` 已存在且直接覆寫 | 預設拒絕覆寫（要覆蓋請 `--force`），建議每輪換新檔名 |
| 換掉的圖片被報成「非媒體被動過」 | G2b 的媒體判定漏了圖片，把圖當非媒體 | 用同一套媒體判定（`is_media`）；驗證後拿 `--media-dir` 交叉核對換上的檔案 |
| 16-bit PNG／CMYK 圖被「無損」處理後掉階調 | Pillow 讀 16-bit PNG 會降成 8-bit、CMYK 色版會被轉換 | 依檔頭（IHDR 位深）與色彩模式設護欄，不符就 SKIP 並說明（不能只看解碼後像素，因為看不出來）|
| 無損模式卻把 JPEG 重壓了 | 誤以為「重存一次也是無損」 | JPEG 無損重編不可能 → 明示 SKIP；要壓就走 `--mode lossy`（有畫質關頂著）|
| 「壓了圖」卻說不出掉多少畫質 | 只比檔案大小 | 畫質關：無損要像素逐點相同；有損要尺寸 ≤ 上限且 PSNR ≥ 門檻。**注意這一關只證明「沒掉畫質」，不證明「有壓縮」**（全部刻意保留也會 PASS）|
| 無損重壓了 TIFF，整包 PPTX 卻幾乎沒變小 | 那張 entry 在 zip 內**本來就被 deflate 過**，檔案層面的 −98% 不等於整包的 −98% | 看**未壓縮媒體總量**（`pptx-probe.py` 的 file_size／compress_size 對照）再估贏面；整包的大贏面在原本 STORED／未壓縮的媒體（影片）|
| 重壓後像素一模一樣，顏色卻變了 | ICC profile 掉了 —— 像素值沒變，但「顏色長什麼樣」的依據變了，`pixels_same` 抓不到 | 重存時把 `icc_profile` 帶著（PNG／JPEG／TIFF 都帶）；探針 IMG-2 用「來源真的帶 ICC」當對照組，防恒真 |
| 有損縮圖後那張圖沒變小、甚至更大 | 內容高頻的圖縮圖後反而更難壓（PNG 尤其），觸發「壓完沒更小就保留原檔」 | 這是設計好的防呆，不是 bug；看 log 的 `KEPT(not smaller)` 就知道，不要只看「有沒有設上限」|
| 畫質關報「長邊超標」，但那些圖根本沒被壓 | 長邊上限原本一視同仁，把「刻意保留的原檔」（SKIP／`KEPT`／`--min-bytes`／`--only` 沒選到）也算成超標 | 逐 byte 相同 ＝ 刻意保留，不計入長邊上限（探針 IMG-14 咬「不誤紅」、IMG-15 咬「真有重編又超標要紅」）|
| 合法縮圖被 PSNR 判不合格 | 把小圖**放大回母帶尺寸**再比，等於懲罰每一次降採樣 | PSNR 改在**縮圖尺寸**比（同一張產物：舊語意 24.8 dB → 新語意 28.5 dB）；高頻內容分數天生較低，可用 `--image-psnr` 調門檻 |
| 只有向量圖的 deck 被報畫質關 FAIL | `.svg`／`.emf`／`.wmf` 不是 Pillow 的領域，永遠解不開 → 一張都檢查不到 | 畫質關只認光柵圖（png/jpg/tif/gif/bmp/webp）；沒有可比圖片時明示「不適用」而不是 FAIL |
| 一張壞圖讓工具吐 traceback 收場 | 只接住自家 `SystemExit`，Pillow 的例外直接爆出去（rc=1）| 預期中的失敗（`OSError`／`ValueError`）→ 指出第幾張、已完成幾張，收在 rc=3 |
| 帶 alpha（透明）的 TIFF 走有損，透明度怎麼了？| PSNR 只在 RGB 空間量，alpha 通道不在門檻內；alpha 是有損近似 | 想要 alpha 也保證不變就走 `--mode lossless`（像素逐點比）；實測 Pillow 的 `tiff_jpeg` 對 RGBA 會保住 mode，但 `LA` 模式的 TIFF 無法用 jpeg，工具會明示 `SKIP` |
| `--src` 與 `--out` 指同一個目錄 → 原圖被就地覆蓋 | 目錄模式沒有保護：輸出檔名與來源同名 | 直接擋下（rc=1）；要重壓就換一個輸出目錄（本工具永遠不原地覆蓋）|
| 用了 `--no-keep-original` 檔案反而變大 | 該旗標是「就算更大也硬換」（統一參數用）| 預設不帶；log 的 `KEPT(not smaller)` 是幫你省空間，不是失敗 |

## 5. 圖片壓縮（TMO-064）：先無損，不夠才動畫質

```bash
# 無損：PNG 重壓 + TIFF 改 deflate；像素逐點相同，做不到就退回原檔
python3 scripts/pptx-shrink-images.py --src deck.pptx --out encoded --mode lossless

# 有損（無損省不夠才用）：限長邊 1920 + JPEG/TIFF 品質 85；PNG 可加 --png-colors 256
python3 scripts/pptx-shrink-images.py --src deck.pptx --out encoded \
  --mode lossy --image-max-edge 1920 --image-quality 85

# 重打包：圖片與影片可放**同一個** --media-dir（repack 按 basename 對應），一次搞定
python3 scripts/pptx-repack.py --src deck.pptx --dst deck_slim.pptx --media-dir encoded

# 驗證：四關 + 畫質關（無損＝像素必須完全相同；有損＝尺寸上限 + PSNR 門檻）
python3 scripts/pptx-verify.py --src deck.pptx --dst deck_slim.pptx --media-dir encoded \
  --image-mode lossless --fast      # 有損產物改成 --image-mode lossy --image-max-edge 1920
```

fixture 實測數（2026-10-05，`tests/pptx-slim-images.bats` 現場造圖；本案例的真 deck **只跑過影片**，
這些是工具能力的量測，不是那 139 MiB 的真數字）：

| 圖片類型 | 無損 | 有損（長邊 800／Q80） |
|----------|------|------------------------|
| TIFF 1.7 MiB（1,000×750 無壓縮）| 30 KiB（−98.2%）| 48 KiB（−97.2%）|
| PNG 8-bit（1,200×900，帶 ICC）| 8.1 → 6.4 KiB（−20.8%）| **KEPT**（縮到 800×600 反而沒更小）|
| PNG 16-bit（640×480）| **SKIP**（Pillow 讀入會降位深）| 2.6 KiB（−86.1%；有損本來就會掉位深）|
| JPEG（1,000×750）| **SKIP**（無損重編不可能）| 40 → 20 KiB（−49.6%）|

兩個要留意的數字：① 無損對這張 8-bit PNG 只省 20.8%，因為它本來就壓得不錯；
② 有損把那張 PNG 縮到 800×600 後檔案反而沒更小（testsrc 的花紋縮圖後更高頻），
所以被 `KEPT(not smaller)` 留在原尺寸 —— 「設了上限」不等於「一定變小」。

權衡：簡報裡的圖多是圖表、截圖、流程圖，畫質掉得比影片明顯（字變糊、線條生鬼影），
所以預設無損；真的不夠小才 `--mode lossy`，並用 `--image-mode lossy --image-psnr` 把門檻**寫成證據**。

有損模式的兩個「門檻語意」（都是踩過才定下來的）：

1. **尺寸上限只管真的有重編的圖**：逐 byte 相同的圖 ＝ 刻意保留（SKIP／`KEPT`／`--min-bytes`／`--only` 沒選到），
   它原本多大就多大，不該被算成超標。
2. **PSNR 在縮圖尺寸比**：降採樣是預期的（`--image-max-edge` 本來就要縮），把小圖放大回母帶再比會誤殺。

覆蓋率：`tests/pptx-slim-images.bats` **21 條**（IMG-1 … IMG-21）、突變表 `scripts/ci/mutants.tsv` **26 支**
（11 圖片／12 影片與打包／3 ffmpeg 版本鎖）；突變測試在 CI 每次都跑，任何一支「咬不住」都會紅。

## 6. 為什麼「非媒體 entry 逐 byte 原樣」是鐵律

PPTX 的動畫、轉場、旁白書籤、章節時序全都存在 XML（`p:timing`／`p:transition`／slide rels）裡，
它們用 **rId → 媒體檔名** 的方式指過來。只要動到任一個 XML 或改掉媒體檔名，
PowerPoint 就可能靜默丟掉動畫（不一定報錯）。所以本工具的唯一意圖就是「換媒體 bytes」，其他一律原樣搬。
