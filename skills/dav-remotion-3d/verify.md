# Verify — 出片、驗證、交付

> 對應 workflow Step 5、Step 6。指令按 Remotion CLI 寫；換成同類工具時概念一樣。

## 出片

- **工作目錄**：以下指令一律喺 **project 內嘅 `<project>/remotion/`**（Remotion 專案根）跑；`out/` 即 `<project>/remotion/out/`
  - 驗證中間檔（framemd5、抽幀、log）寫 `out/check/`、**唔准**寫 `/tmp`
  - 專案同出片都必須喺 project 目錄內（一齊版控；`out/` 入 `.gitignore`）
- 本機互動預覽：`npx remotion studio <entry>`
- 出單一條：`npx remotion render <entry> <compositionId> out/<name>.mp4 --gl=angle`
  - `--gl=angle` 係關鍵：headless 預設唔開 GPU → 3D、CSS 模糊、漸層、陰影會慢好多
  - 冇 GPU 嘅機器用軟件光柵模式（慢但穩）
- 抽單幀：`npx remotion still <entry> <compositionId> out/<name>.png --frame=<n> --gl=angle`
- 多比例／多變體矩陣：變體 × 比例 × 語言，每個組合一份 props 資料檔，批量跑
- 雲端批量：官方 lambda 方案（AWS）／支援的容器平台／自家 server
- 音軌：`<Audio>` 會自動混入 mp4；要交分軌就 `ffmpeg -i out/a.mp4 -vn -c:a copy out/check/a.m4a` 抽出
- 字體：出片前確認用渲染端字體 API 載入（唔靠系統字），否則跨機器字型會唔同

## 驗證四項（缺一不可）

### 1. 決定性（最重要）

- 做兩次 render，逐幀比雜湊
- 指令：
  - `npx remotion render <entry> <id> out/a.mp4 --gl=angle`
  - `npx remotion render <entry> <id> out/b.mp4 --gl=angle`
  - `mkdir -p out/check && ffmpeg -i out/a.mp4 -map 0:v -f framemd5 -c copy - | grep -v '^#' > out/check/a.md5`
  - `ffmpeg -i out/b.mp4 -map 0:v -f framemd5 -c copy - | grep -v '^#' > out/check/b.md5`
  - `diff out/check/a.md5 out/check/b.md5 && echo "決定性 OK"`
- `-map 0:v` 係關鍵：有音軌之後，framemd5 會連音頻 frame 一齊比 → 容器／音頻編碼器帶嘅 metadata 會令「決定性」誤報 fail；決定性只比影像，音軌用下面第 4 項獨立驗
- 通過標準：雜湊逐幀完全一致
- 失敗即查：真實時鐘、`Math.random()`、未載入字體、依賴時間的 shader／動畫

### 2. 規格

- `ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name,width,height,r_frame_rate,nb_frames,pix_fmt -of default=noprint_wrappers=1 out/a.mp4`
- 對住 storyboard 逐項對：幀數＝總幀數、幀率、分辨率、像素格式（社交平台用 yuv420p 先至通用）、時長

### 3. 時間軸曲線

- `ffmpeg -v error -i out/a.mp4 -vf "signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" -f null -` 取每幀平均亮度
- 每 15 幀抽樣一次睇變化：每段開始應該有亮度／構圖變化
- 變化點要同 storyboard 對得上（例：穿越 logo 嗰幀應該有亮度峰值；結尾淡出應該回落）

### 4. 音軌（有配樂／旁白／音效時必做）

- **存在**：`ffprobe -v error -select_streams a -show_entries stream=codec_name,channels,sample_rate,duration -of default=noprint_wrappers=1 out/a.mp4` → 要見到 audio stream
- **時長對齊**：影音時長差 <0.1 秒；音軌要**長過**片長（尾段靠 fade 收），唔好靠 `-shortest` 硬切
- **音量**：`ffmpeg -v error -i out/a.mp4 -af volumedetect -f null -` → `max_volume` ≤ −1 dB（唔爆）、`mean_volume` 大約 −18 ～ −14 dBFS
- **斷音／意外靜音**：`ffmpeg -v error -i out/a.mp4 -af silencedetect=noise=-45dB:d=1 -f null -` → 除設計上嘅留白，唔應該有 ≥1 秒靜音
- **配樂本身嘅決定性（JS 生成器）**：`node tools/make-music.mjs` 跑兩次、`shasum -a 256 public/audio/<clip>-music.wav` 逐 byte 一致
- **旁白存在＋句界**：`ffmpeg -hide_banner -i out/a.mp4 -af silencedetect=noise=-40dB:d=0.35 -f null -` → 靜音位應該落喺句子之間，同稿（props 句子表）對得上；多咗／少咗 = 句子被截或漏讀
- **旁白對比音樂**：出一個「音樂靜音」嘅對照版 → 人聲段能量要比音樂段突出 4–8 dB（`volumedetect` 或分段量）
- **可讀時間**：句長 ≥ 字數 × 0.18 秒（中文）／詞數 × 0.28 秒（英文）；不夠就改稿，唔准加速
- **多語言**：每個語言一組 vo 檔、句界要一致；**段長要夠最長嘅語言**
- **字幕**：SRT 由同一份稿生成（唔准手打第二份），出片前對一次時間軸
- **聽唔到就用數字驗**：冇喇叭／純文字環境靠上面 volumedetect ＋ silencedetect ＋ 時長，唔准「冇聽過就算通過」

## 人工抽幀檢查清單

- 每段抽 1 張 + 每個轉場抽 1 張 + 首尾各 1 張
- 檢查：文字有冇出界／被遮／讀唔切；最小字級（1080p 下 ≥26px、字幕 ≥32px）；安全區；logo 比例；3D 物件有冇穿幫
- 冇圖片檢視能力嘅環境（例如純文字 agent）：用 ffmpeg 把幀轉成灰階原始數據，再用字元密度砌成 ASCII 圖睇構圖

## 交付清單

- 比例：16:9 + 9:16 + 1:1（社交平台常要三套）
- 編碼：H.264 mp4（萬能）／AV1 webm（網頁更細）／ProRes 或 webm-alpha（要疊落其他片）
- 幀率：30fps 起步；有運動模糊或介面錄屏流暢度要求先做 60fps
- 版本：有聲發布版／無聲網站版／有字幕版／多語言版
- 音軌：配樂 wav 源檔（`public/audio/`）＋ 旁白 wav（逐語一句一個檔）＋ 分軌（音樂／旁白／音效）令對方可重混；要細檔另出 mp3 交付副本
- 文字：旁白稿（同一份 props）＋ 生成嘅 SRT／多語字幕
- 檔案大小目標：網站 hero 循環版 3–8 MB 以內；社交平台 15 秒以內、10–20 MB 以內
- 交付時一併交：storyboard、props 資料檔、渲染指令（對方要能自己重出）
- 交付路徑要寫明 project 內落點：`<project>/remotion/`（專案）＋ `out/`（出片）

## 授權提醒

- Remotion：個人及 ≤3 人公司免費（含商用）；超出要授權（按人頭／按渲染量計費）
- 配樂：用 JS 自己合成 = 冇第三方音樂授權／平台條款問題（素材庫同生成平台都要逐首核）
- 旁白：TTS 服務條款（商用／輸出擁有權）＋ 聲音授權（唔准用名人／未授權聲音克隆）；真人錄音要填使用範圍（媒體、期限）
- 字體、素材 texture 都要確認商用授權
- 用幾何／程序化生成嘅素材（介面截圖 mockup、logo 形狀）＝ 冇第三方授權風險，最省事
