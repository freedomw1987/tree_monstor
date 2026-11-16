# Verify — 出片、驗證、交付

> 對應 workflow Step 5、Step 6。指令按 Remotion CLI 寫；換同類工具時概念一樣。中間檔一律落 `out/check/`。

## 出片

- **工作目錄**：一律喺 `<project>/remotion/`（專案根）跑；`out/` 即 `<project>/remotion/out/`
- 預覽：`npx remotion studio <entry>`；出片：`npx remotion render <entry> <id> out/<name>.mp4 --gl=angle`；
  抽幀：`npx remotion still <entry> <id> out/<name>.png --frame=<n> --gl=angle`（同時做 poster／縮圖）
  - `--gl=angle` 係關鍵：headless 預設唔開 GPU → 3D、模糊、漸層、陰影會慢好多（冇 GPU 用軟件光柵）
- 多版本矩陣：**比例 × 時長 × 語言 × 優惠**，每個組合一份 props 資料檔批量跑（雲端：官方 lambda／容器平台）
- 音軌：`<Audio>` 自動混入 mp4（要分軌：`ffmpeg -i out/a.mp4 -vn -c:a copy out/check/a.m4a`）；
  字體：出片前確認用渲染端字體 API（唔靠系統字），否則跨機器字型會唔同

## 驗證五項（缺一不可）

### 1. 決定性（最重要）

- 做兩次 render，逐幀比雜湊；**只比影像**（`-map 0:v`）

```bash
npx remotion render <entry> <id> out/a.mp4 --gl=angle
npx remotion render <entry> <id> out/b.mp4 --gl=angle
mkdir -p out/check
ffmpeg -i out/a.mp4 -map 0:v -f framemd5 -c copy - | grep -v '^#' > out/check/a.md5
ffmpeg -i out/b.mp4 -map 0:v -f framemd5 -c copy - | grep -v '^#' > out/check/b.md5
diff out/check/a.md5 out/check/b.md5 && echo "決定性 OK"
```

- 點解要 `-map 0:v`：有音軌之後 framemd5 會連音頻 frame 一齊比 → 容器／編碼器 metadata 會令決定性誤報 fail
- 通過標準：逐幀一致；失敗即查：真實時鐘、`Math.random()`、未載入字體、依賴時間嘅 shader／動畫

### 2. 規格

```bash
ffprobe -v error -show_entries format=duration,size \
  -show_entries stream=codec_name,width,height,r_frame_rate,nb_frames,pix_fmt \
  -of default=noprint_wrappers=1 out/a.mp4
```

- 對住 storyboard 逐項對：幀數 = 總幀數、幀率、分辨率、像素格式（社交用 yuv420p）、時長（對時長檔位）

### 3. 時間軸曲線

```bash
ffmpeg -v error -i out/a.mp4 -vf "signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" -f null -
```

- 每 15 幀抽樣睇變化：每段開始應該有亮度／構圖變化，變化點要同 storyboard 對得上
- 廣告版另要對：**hook 段（頭 3 秒）必須有構圖／亮度大變化**；end card 出現時間要準

### 4. 音軌（有配樂／旁白／音效時必做）

- **存在＋時長對齊**：`ffprobe -v error -select_streams a -show_entries stream=codec_name,channels,sample_rate,duration
  -of default=noprint_wrappers=1 out/a.mp4` → 見到 audio stream；影音時長差 <0.1 秒、音軌要**長過**片長
- **音量＋斷音**：`ffmpeg -i out/a.mp4 -af volumedetect -f null -` → max ≤ −1 dB、mean −18～−14 dBFS；
  `silencedetect=noise=-45dB:d=1` → 唔應該有 ≥1 秒靜音
- **零外部依賴（硬規則）＋源決定性**：`grep -nE "fetch\(|https?://|axios|aws-sdk" tools/make-music.mjs` 要 0 命中；
  配樂同 seed 重生 `shasum` 逐 byte 一致；旁白重生比 `shasum`（唔一致就當已凍結）
- **旁白句界＋對比音樂**：`silencedetect=noise=-40dB:d=0.35` → 靜音位落喺句子之間、同稿對得上；
  出「音樂靜音」對照版 → 人聲段要比音樂段突出 4–8 dB
- **多語言／字幕／聲對版**：每語言一組 vo 檔、句界一致；SRT 由同一份稿生成；檔名或 `out/check/vo-timing.json`
  記低 engine／voice
- **聽唔到就用數字驗**：靠上面 volumedetect ＋ silencedetect ＋ 時長，唔准「冇聽過就算通過」

### 5. 投放合規（廣告片必做）

- **響度**：`loudnorm=print_format=summary` → 睇 input_i 對平台標準（廣播 −23 LUFS；社交常見 −14 LUFS）
- **字幕＋安全區**：靜音睇一次，重要 claim 有冇出字；字幕有冇被平台 UI 遮（9:16 上下各留約 15%）
- **合規＋版本齊**：優惠條款／價格幣值／claim 可驗／肖像＋音樂＋字體授權；版本命名
  `<clip>_<比例>_<時長>_<語言>_<優惠>` 要齊

## 人工抽幀檢查清單

- 每段抽 1 張 + 每個轉場抽 1 張 + 首尾各 1 張（首 3 秒另抽）
- 檢查：文字有冇出界／被遮／讀唔切；最小字級（1080p ≥26px、字幕 ≥32px）；安全區；logo 比例；3D 穿幫
- 冇圖片檢視能力（純文字 agent）：`ffmpeg` 轉灰階砌 ASCII 圖睇構圖

## 交付清單

- 比例：16:9 + 9:16 + 1:1（社交常要三套）；幀率 30fps 起步（有運動模糊先做 60fps）
- 編碼：H.264 mp4（萬能）／AV1 webm（網頁更細）／ProRes 或 webm-alpha（要疊落其他片）；
  版本：有聲發布版／無聲網站版／有字幕版／多語言版／各時長檔位
- 音軌：配樂 wav ＋ 旁白 wav（逐語一句一個檔）＋ 分軌；要細檔另出 mp3 副本；文字：旁白稿（同一份 props）
  ＋ SRT／多語字幕；封面 poster frame
- 檔案大小：網站 hero 循環版 3–8 MB；社交 15 秒以內 10–20 MB；一併交：storyboard、props 資料檔、
  渲染指令（對方要能重出）＋ project 內落點

## 授權提醒

- Remotion：個人及 ≤3 人公司免費（含商用）；超出要授權；字體、素材 texture 都要確認商用授權
- 配樂：用 JS 自己合成 = 冇第三方音樂授權問題；旁白：TTS 服務條款（商用／輸出擁有權）＋ 聲音授權
  （唔准名人／未授權克隆）；真人錄音要填使用範圍
