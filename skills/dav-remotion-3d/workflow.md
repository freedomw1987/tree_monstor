# Workflow — 由 storyboard 到出片

> 對應主檔流程 6 步。每步：動作／為什麼／產出／證據。中間檔一律落 `out/check/`。

## 產物落點（固定，一律喺 project 目錄下）

- **禁止**：`/tmp`、home、skill 目錄 —— 片段同出片要跟 project 一齊版控（`out/` 入 `.gitignore`）
- **Remotion 專案**：`<project>/remotion/` —— `src/`（component／scene／timeline）、`props/`、`package.json`
- **出片**：`<project>/remotion/out/` —— mp4／still（多比例／多變體用檔名分開）
- **驗證中間檔**：`<project>/remotion/out/check/` —— framemd5、抽幀、render log、音量報告
- **音軌**：`<project>/remotion/public/audio/`（配樂／旁白 wav）＋ 生成器 `tools/make-music.mjs`／`make-vo.mjs`
- **多條片**：`<project>/remotion/<clip-name>/` 一層分開，唔好幾條片共用一個 `out/`

## Step 1 定義交貨＋storyboard

**動作**：先定死交付物，再寫逐格 storyboard。
- 交付物寫清：片長、主比例（16:9／9:16／1:1）、幀率、編碼、檔案數、變體（有聲／無聲 loop／多語言）
- 每格寫：目的／畫面／文案／動態參數（位移 px、stagger ms、轉場幀數、鏡頭變化、easing）／音效／技術對應

**為什麼**：呢類片最花時間係結構同節奏，唔係引擎；先定 storyboard 可以喺寫 code 之前驗節奏，改結構成本極低。

**產出**：storyboard 檔（逐格）。**證據**：每格有幀範圍、文案、技術對應；有一句創意概念同情緒曲線。

### 節奏原則

- 每 2–3 秒一個視覺焦點轉移；每格只講一件事；文字最多 1 主焦點＋1 輔助
- 文字可讀 ≥1.2 秒；片尾 CTA ≥1.5 秒
- 轉場用 wipe／dissolve／fade；唔用旋轉、3D flip、逐格 mosaic
- 文案：主標 ≤12 字、副行 ≤18 字、數字要保守得可以 defend

## Step 2 單一時間軸

**動作**：所有場景時間集中一個 timeline 檔（每場景記 from／duration）；相機、動畫、亂數全由 frame 推導。

**為什麼**：改節奏只改一處；呢個檔同時係驗證基準。

**產出**：timeline 檔（場景表＋總幀數）。**證據**：改任何一段時間，只動一個檔。

### 用官方轉場元件嘅會計陷阱

- 相鄰場景會重疊 transition 幀數 → 總片長 = Σduration − Σtransition
- 所以「改 transition 長度」會改總片長 → 片長要由 timeline 推導，唔好兩邊寫死
- 自寫 overlap（Sequence 手動錯開）冇呢個問題，但轉場要自己實作

## Step 3 組件＋參數化

**動作**：三層 props。
- 資料檔層：品牌／文案／配色／語言／比例／旗標（JSON，一個變體一個檔）
- composition 層：資料檔 ＋ schema 驗證（zod）＋ 版權旗標
- scene 層：每個場景自己嘅 props（位置、數量、seed、鏡頭參數）

**為什麼**：令「多比例 × 多語言 × 多版本」變成一份資料驅動，唔使改 component。

**產出**：component 樹＋schema＋props 範本。**證據**：換文案／換比例／加語言，只改資料檔。

### 組件結構原則

- 3D 喺底（一個 canvas）、DOM 喺上（文字永遠清晰）、轉場層夾中間
- 場景組件唔識比例、語言、版本 —— 差異全部經 props 傳入
- 多比例用一個 layout hook 派生（安全區／字級／文字寬度／排列），唔 fork component
- UI 截圖要預備多套（desktop 唔可以硬裁成 9:16）
- Props 必須 pure JSON-serializable（唯一例外：動態 metadata 可以收函數）

## Step 4 3D 場景

**動作**：揀 3D 強度檔位 ＋ 動態效果目錄（見子檔）→ 寫相機關鍵幀 → 場景層逐段建構。

**為什麼**：3D 係成本最高嘅一層，要先定份量；相機用關鍵幀插值，過場自然連貫。

**產出**：3D 層＋相機關鍵幀表。**證據**：全片只有一個 canvas；每個動畫值都追溯到 frame。

### 相機關鍵幀設計

- 每個關鍵幀記：frame、位置、fov、注視點；位置同注視點用同一組幀插值（唔會突然轉向）
- fov 表達情緒：廣角（50→65）= 進入感；窄角（55→48）= 聚焦／壓縮
- 深度：近裁剪面夠細、遠裁剪面夠大（隧道要望到好遠）

### 細節

- 亂數：seeded PRNG（例如 mulberry32），每個場景一個固定 seed
- 材質：介面截圖用不受光材質；卡片／面板共享材質
- 陰影：一次性計算嘅接觸陰影；反光用鏡像平面＋漸變遮罩假反射
- 文字：全部 DOM；3D 內不畫字；細節規格見子檔 [`3d-checklist.md`](./3d-checklist.md)

## Step 5 音軌＋出片

**動作**：做音軌（配樂／旁白生成 → 落檔凍結 → 混音 duck）→ 本機渲染 → 多比例矩陣 → CI／雲端批量。

- **音軌層**：細節同選型 → 見子檔 [`audio.md`](./audio.md)（配樂必須純 JS 合成；旁白用 AWS Polly neural）
- **落點**：生成器 `tools/make-*.mjs`；音檔 `public/audio/*.wav`；量出嘅時長／句界落 `out/check/`
- **唔准**：render 時即場生成、mp3 做源、實時 Web Audio 播放、專案外臨時檔

**為什麼**：音軌同畫面一樣要「每次都出同一條片」；分軌做混音令換旁白／調音量唔使重寫音樂。

**產出**：`tools/make-*.mjs` ＋ `public/audio/*.wav` ＋ mp4（含音軌）→ 落 `out/`。

**證據**：配樂同 seed 重生逐 byte 一致；旁白句界同稿對得上；出片有 audio stream、時長對齊。

## Step 6 機械驗證

**動作**：四項必做 —— 逐幀雜湊（只比影像）、規格、亮度曲線、音軌（時長／音量／斷音／句界）；再抽幀睇。

**為什麼**：動畫嘅 bug 好似「渲染成功但畫面錯」，肉眼睇唔出決定性問題；機械驗證先捉到。

**產出**：驗證證據（雜湊、規格、亮度曲線、音量／靜音報告）→ 落 `out/check/`。

**證據**：兩次 render 影像逐幀一致；規格正確；曲線同 storyboard 對得上。**指令**見子檔 [`verify.md`](./verify.md)。
