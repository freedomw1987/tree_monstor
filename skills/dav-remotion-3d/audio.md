# Audio — 音軌層（配樂 ＋ 旁白 ＋ 混音）

> 對應主檔 Step 5 嘅音軌部分。三個原則：**① 一律生成器產出 → ② 落檔凍結 → ③ 分軌做混音**。
> 為什麼要分開一支子檔：畫面流程（`workflow.md`）同音軌層會各自長大；音軌改動唔應該推爆畫面流程嘅篇幅。

## 落點（固定，一律喺 project 目錄下）

- **生成器**：配樂 `<project>/remotion/tools/make-music.mjs`；旁白 `<project>/remotion/tools/make-vo.mjs`（＋稿資料檔 `props/vo.json`）
- **音檔**：`<project>/remotion/public/audio/` —— `<clip>-music.wav`、`vo-01.wav`、`vo-01-en.wav`、`sfx-*.wav`
- **量出嚟嘅時長／句界／雜湊**：`<project>/remotion/out/check/`
- **唔准**：`~/Music/`、`/tmp`、雲端臨時 URL 做「源」（雲端只可以做生成入口，成品一定要落返 project）

## A. 配樂（一律 JS 合成，seeded）

- **生成器**：`node tools/make-music.mjs`（npm script 例：`"music": "node tools/make-music.mjs"`）
- **選型（按優先）**：
  - **純 JS 樣本合成**（零依賴，首選）：自寫 oscillator（sine／saw／square／tri）＋ ADSR envelope ＋ lowpass／delay 近似混響 → 砌 Float32Array → 自寫 16-bit PCM WAV 編碼（44-byte header）
  - `Tone.js`（`Tone.Offline` 離線 render）：樂器／scheduler／效果器現成，音樂性最快；要鎖版本（依賴 = 決定性風險）
  - `node-web-audio-api`（`OfflineAudioContext`）：寫法同瀏覽器一致；native binding 要留意跨機一致性
  - headless 瀏覽器 `OfflineAudioContext`（Playwright／Puppeteer）：環境同 Remotion 最近，多一層 browser
- **決定性**：seed 由 props／const 傳入（**唔准** `Date.now()`／`Math.random()`）；envelope／filter 參數係常數或由 BPM／frame 推導 → 同一 seed 重生兩次，wav 逐 byte 一致
- **音樂 spec（先寫落 storyboard 旁邊）**：BPM（令「段長 = 整數小節」最好編）、調性、結構（intro → build → hook → outro）對 timeline 段落、每 2–3 秒一個 music event 對視覺焦點轉移、總長 = 片長 + 1–2 秒（尾段留 fade）
- **出檔**：`public/audio/<clip>-music.wav` —— **用 wav 唔用 mp3**（有損編碼有 encoder delay、唔係逐 sample 決定性）；要細檔就出片後另壓交付副本
- **版控二選一**（唔好兩邊都做）：① wav 一次生成就 commit（大檔用 LFS，出片最穩、最快）② 唔入版控 → 出片前必跑生成（idempotent，同一 seed 重生）＋ CI 記住加呢步

## B. 旁白（VO：稿先、聲後）

- **稿係單一真相**：句子寫落 props 資料檔（例：`vo: [{id, text, from}]`，`from` = 起始 frame）
  - 同一份稿同時做三件事：**TTS 輸入**、**字幕**（DOM 疊層）、**SRT 輸出** → 唔准手打第二份
  - 句子時間由 timeline 推導（每句 assigned frames）→ 改節奏只改一處
- **來源選型（按優先）**：
  - **本地離線 TTS**（首選）：Node／JS 跑 VITS／Piper 類 ONNX 模型（onnxruntime bindings）或者系統內建 TTS CLI → 零 API、模型版本可鎖、多數做到**逐 byte 驗**
  - **雲端 TTS API**：質素最好、最省事；但每次結果可能唔同（唔決定性）＋要 key／quota／商用條款 → 生成一次就**落檔凍結**，之後唔再重生
  - **真人錄音**：質素天花板；收 48k／24-bit wav ＋ 逐句時間，TTS 只做後備版本
- **長度對齊（硬規則）**：每句量長（`ffprobe -show_entries format=duration`，或 Remotion `getAudioDurationInSeconds`）→ 句長 ≤ 分配時間（通常 = 對應段落 dur − 0.3s 呼吸）；**超長就改稿減字，唔准加快語速／time-stretch**（會似機械，亦破壞可讀時間）
- **可讀時間**：中文 ≥0.18 秒／字、英文 ≥0.28 秒／詞（最低；有數字、專有名詞再放寬）→ 用來反推「一句最多幾個字」
- **讀得出嘅寫法**：稿唔可以照抄畫面文字（會分心）；網址、代號、數字要寫成讀得出嘅形式（例：`app.boardware.com` → 「app 點 boardware 點 com」；`1920×1080` → 「一九二零乘一零八零」）
- **一語一句一個檔**：`vo-01.wav`、`vo-01-en.wav` → 多語言 = 多一組檔，唔 fork 專案；**段落長度要夠最長嗰個語言**
- **凍結**：TTS 生成 → 試聽 → 揀 take → 落檔入版控；只有改稿先重生
- **唔准**：未授權聲音（名人／未買授權嘅聲音克隆）、未核商用條款嘅服務

## C. 混音（Remotion 內）

- 三條獨立軌、各自一個檔：`audio/<clip>-music.wav`、`audio/vo-*.wav`、`audio/sfx-*.wav` —— 唔好喺生成器內混死（換旁白／調音量唔使重生音樂）
- `<Audio src={staticFile('audio/vo-01.wav')} />`；音樂用 `volume={(f) => duckAt(f)}`：旁白句子嘅 frame range 內音樂 **−6 dB**，句子前後各約 6 幀 ramp（避免啪聲）
- 淡入淡出同 duck 全部由 frame 推導（**唔用 CSS／實時**，否則破壞決定性）
- 音量目標（master）：全片 `mean_volume` −18～−14 dBFS、`max_volume` ≤ −1 dBFS；**人聲要比音樂突出 4–8 dB**
- 有聲／無聲兩版：同一個 composition 用 prop（`audio`）開關，唔 fork 專案
- 交付可以另出分軌（`-vn -c:a copy` 抽 `m4a`，或交原始 wav），令對方可重混

## D. 唔准（音軌層）

- render 時即場生成（音樂／TTS 都會唔同 → 決定性崩）
- mp3 做「源」（交付副本可以）；time-stretch 硬塞字數
- 用未授權聲音／音樂；把雲端 URL 當專案資產（會過期）
