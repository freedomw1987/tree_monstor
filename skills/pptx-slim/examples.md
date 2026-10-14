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
| 圖片加碼 | 另壓 `ppt/media/` 下的 PNG 與 TIFF | 影片壓完仍不夠小 | 實測圖片 139 MiB（含 29 MiB TIFF）|

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

## 5. 為什麼「非媒體 entry 逐 byte 原樣」是鐵律

PPTX 的動畫、轉場、旁白書籤、章節時序全都存在 XML（`p:timing`／`p:transition`／slide rels）裡，
它們用 **rId → 媒體檔名** 的方式指過來。只要動到任一個 XML 或改掉媒體檔名，
PowerPoint 就可能靜默丟掉動畫（不一定報錯）。所以本工具的唯一意圖就是「換媒體 bytes」，其他一律原樣搬。
