# Audio — 音軌層（配樂 ＋ 旁白 ＋ 混音）

> 對應主檔 Step 5 音軌部分。三原則：一律生成器產出 → 落檔凍結 → 分軌混音。

## 落點（固定，一律喺 project 目錄下）

- **生成器**：配樂 `tools/make-music.mjs`；旁白 `tools/make-vo.mjs` ＋ 稿 `props/vo.json`
- **音檔**：`public/audio/` —— `<clip>-music.wav`、`vo-01.wav`、`vo-01-en.wav`、`sfx-*.wav`
- **量出嚟嘅時長／句界／雜湊**：`out/check/`
- **唔准**：`~/Music/`、`/tmp`、雲端臨時 URL 做「源」（雲端只可以做生成入口，成品一定落返 project）

## A. 配樂（必須純 JS 合成，seeded；暫時唔用任何外部 API）

- **生成器**：`node tools/make-music.mjs`（npm script 例 `"music": "node tools/make-music.mjs"`）；
  生成器內**唔准有網絡呼叫**（冇 `fetch(`／`https?://`／雲端 SDK）
- **選型（按優先）**：
  - **純 JS 樣本合成**（零依賴，首選）：自寫 oscillator ＋ ADSR ＋ lowpass／delay 混響 → Float32Array →
    自寫 16-bit PCM WAV 編碼（44-byte header）
  - 要現成樂器／效果器：`Tone.js`（`Tone.Offline`）或 `node-web-audio-api`（`OfflineAudioContext`）—— 要鎖版本
- **決定性**：seed 由 props／const 入（唔准 `Date.now()`／`Math.random()`）→ 同 seed 重生，wav 逐 byte 一致
- **音樂 spec（先寫落 storyboard 旁邊）**：BPM（令「段長 = 整數小節」最好編）、調性、結構對 timeline 段落、
  每 2–3 秒一個 music event 對視覺焦點轉移、總長 = 片長 + 1–2 秒（尾段留 fade）
- **出檔**：`public/audio/<clip>-music.wav`（用 wav 唔用 mp3 —— mp3 有 encoder delay）；版控二選一：① 生成完就
  commit（大檔用 LFS）② 唔入版控 → 出片前必跑生成（idempotent）＋ CI 記住加

## B. 旁白（VO：預設 AWS Polly neural）

- **稿係單一真相**：句子寫落 props（`vo: [{id, text, from}]`，`from` = 起始 frame）
  - 同一份稿做 TTS 輸入／字幕（DOM 疊層）／SRT 輸出 → 唔准手打第二份；句子時間由 timeline 推導
- **引擎／聲**：粵語 `yue-CN` → `Hiujin`；普通話 `cmn-CN` → `Zhiyu`（兩把都係女聲）；先確認 region 有：
  `aws polly describe-voices --language-code <code> --engine neural --query 'Voices[].[VoiceId]' --output text`
  - 要男聲／多把聲／更似真人 → 用戶指定先換引擎（介面不變：一句一個 wav ＋ 同一份稿）
- **前置：AWS CLI ＋ credentials（唔假設對方有；冇就裝，唔好走去瀏覽器手動合成）**
  - 檢查 `command -v aws && aws --version`；裝：macOS `brew install awscli`｜Linux 官方 bundled installer 或
    `pipx install awscli`｜Windows MSI
  - credentials：`aws configure`（access key／secret／region，例 `ap-southeast-1`）或 `aws configure sso` ＋
    `aws sso login`；驗 `aws sts get-caller-identity`
  - IAM 最小權限：`polly:SynthesizeSpeech`（＋`polly:DescribeVoices`；用 lexicon 才加 `polly:PutLexicon`）
  - 唔想裝 CLI：Node SDK `@aws-sdk/client-polly`（一樣出 mp3 → 再轉 wav）
  - 先做 smoke test（一句）確認 region／聲／權限都通，先至寫批量生成
- **生成（實測過）**：

```bash
aws polly synthesize-speech --engine neural --voice-id Hiujin --output-format mp3 \
  --sample-rate 48000 --text "<句子>" out/vo-01.mp3
# SSML（修多音字／停頓／語速）：--text-type ssml --text "file://$PWD/vo-01.ssml"
ffmpeg -y -i out/vo-01.mp3 -ar 48000 -ac 1 -c:a pcm_s16le public/audio/vo-01.wav
```

- SSML 食：`<phoneme alphabet="x-amazon-pinyin" ph="hang2">行</phoneme>`、`<break time="500ms"/>`、`<prosody>`
- mp3 只做中轉（Polly `pcm` 只 8k／16k，所以走 mp3@48k）；專案源用 wav
- 限額：同步 ≤3000 計費字、音訊 ≤10 分鐘、neural 8 tps；超長用 `start-speech-synthesis-task`（輸出落 S3）
- 決定性：實測同請求兩次 SHA-256 一樣，但仍然一律落檔凍結（唔准 render 時即場叫 API）
- **長度對齊（硬規則）**：每句量長（`ffprobe -show_entries format=duration`）→ 句長 ≤ 分配時間
  （通常 = 段落 dur − 0.3s 呼吸）；**超長就改稿減字，唔准加快語速／time-stretch**
- **可讀時間**：中文 ≥0.18 秒／字、英文 ≥0.28 秒／詞（實測 neural：19 字 → 4.0–4.3 秒 ≈0.21 秒／字）
- **響度**：Polly 出嚟偏細（實測 mean −23.7／max −8.0 dBFS）→ 落檔前 `loudnorm` 到 mean ≈ −16、max ≈ −1.5
- **讀得出嘅寫法**：稿唔可以照抄畫面文字；`app.boardware.com` → 「app 點 boardware 點 com」；`1920×1080` →
  「一九二零乘一零八零」
- **一語一句一個檔**：`vo-01.wav`、`vo-01-en.wav` → 多語言 = 多一組檔；**段長要夠最長嗰個語言**；生成 →
  試聽 → 揀 take → 入版控（只有改稿先重生）
- **唔准**：未授權聲音（名人／未買授權嘅克隆）、未核商用條款嘅服務

## C. 混音（Remotion 內）

- 三條獨立軌、各自一個檔（`-music`／`vo-*`／`sfx-*`）—— 唔好喺生成器內混死（換旁白唔使重生音樂）
- `<Audio src={staticFile('audio/vo-01.wav')} />`；音樂 `volume={(f) => duckAt(f)}`：旁白句子嘅 frame range
  內音樂 −6 dB，句子前後各 6 幀 ramp（避免啪聲）
- 淡入淡出同 duck 全部由 frame 推導（唔用 CSS／實時）；音量目標（master）：全片 mean −18～−14 dBFS、
  max ≤ −1 dBFS；人聲要比音樂突出 4–8 dB
- 有聲／無聲兩版：同一個 composition 用 prop（`audio`）開關；交付可另出分軌（`-vn -c:a copy` 抽 `m4a`）

## D. 唔准（音軌層）

- 配樂用外部 API／雲端音樂服務（Suno／Udio 類）／素材庫（暫時一律唔准；用戶明確指定先議）
- render 時即場生成（音樂／TTS 都會唔同 → 決定性崩）；mp3 做「源」；time-stretch 塞字數
- 用未授權聲音／音樂；把雲端 URL 當專案資產（會過期）
