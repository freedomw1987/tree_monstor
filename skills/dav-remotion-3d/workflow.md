# Workflow — 由 storyboard 到出片

> 對應主檔 6 步。每步：動作／為什麼／產出／證據。中間檔一律落 `out/check/`。

## 產物落點（固定，一律喺 project 目錄下）

- **Remotion 專案**：`<project>/remotion/` —— `src/`（component／scene／timeline）、`props/`、`tools/`、`package.json`
- **出片**：`<project>/remotion/out/`；**驗證中間檔**：`out/check/`；**音軌**：`public/audio/*.wav`
- **禁止**：`/tmp`、home、skill 目錄；`out/` 入 `.gitignore`，其餘跟 project 一齊版控
- **多條片**：`<project>/remotion/<clip-name>/` 一層分開，唔好幾條片共用一個 `out/`

## Step 1 定義交貨＋storyboard

**動作**：先定死交付物（片長檔位／比例／平台／CTA），再寫逐格 storyboard：目的／畫面／文案／動態參數／音效／技術對應。
**為什麼**：最花時間係結構同節奏；先寫 storyboard 可以喺寫 code 之前驗節奏，改結構成本極低。
**產出**：storyboard 檔。**證據**：每格有幀範圍、文案、技術對應；有一句創意概念同情緒曲線。

### 節奏原則

- 每 2–3 秒一個視覺焦點轉移；每格只講一件事；文字最多 1 主焦點＋1 輔助
- 文字可讀 ≥1.2 秒；片尾 CTA／end card ≥1.5 秒；轉場用 wipe／dissolve／fade
- 文案：主標 ≤12 字、副行 ≤18 字；優惠／數字 claim 要保守得可以 defend

## Step 2 單一時間軸

**動作**：所有場景時間集中一個 timeline 檔（每場景 from／duration）；相機、動畫、亂數全由 frame 推導。
**為什麼**：改節奏只改一處；呢個檔同時係驗證基準。**證據**：改任何一段時間，只動一個檔。

### 用官方轉場元件嘅會計陷阱

- 相鄰場景會重疊 transition 幀數 → 總片長 = Σduration − Σtransition；片長要由 timeline 推導，唔好兩邊寫死
- 自寫 overlap（Sequence 手動錯開）冇呢個問題，但轉場要自己實作

## Step 3 組件＋參數化

**動作**：三層 props —— 資料檔（品牌／文案／語言／比例／優惠，一個變體一個檔）→ composition（zod 驗證）→
scene（位置／seed／鏡頭參數）。
**為什麼**：令多比例 × 多語言 × 多優惠版本變成一份資料驅動。**證據**：換文案／比例／語言，只改資料檔。

### 組件結構原則

- 3D 喺底（一個 canvas）、DOM 喺上、轉場層夾中間；場景組件唔識比例／語言／版本（差異經 props 入）
- 多比例用一個 layout hook 派生；UI 截圖預備多套（desktop 唔可以硬裁成 9:16）
- Props 必須 pure JSON-serializable（唯一例外：動態 metadata 可以收函數）

## Step 4 3D 動效

**動作**：揀強度檔位（見 [`3d-checklist.md`](./3d-checklist.md)）＋ 動效配額（廣告／宣傳片可 **≥80% 3D**；簡介片 3–5 個）→
寫相機關鍵幀 → 場景層逐段建構。
**為什麼**：3D 係成本最高嘅一層，要先定份量；相機用關鍵幀插值，過場自然連貫。
**產出**：3D 層＋相機關鍵幀表。**證據**：全片只有一個 canvas；每個動畫值都追溯到 frame。

### 相機關鍵幀設計

- 每個關鍵幀記：frame、位置、fov、注視點；位置同注視點用同一組幀插值（唔會突然轉向）
- fov 表達情緒：廣角（50→65）= 進入感；窄角（55→48）= 聚焦；近裁剪面夠細、遠裁剪面夠大
- 亂數用 seeded PRNG（例如 mulberry32）；材質共享；陰影一次性；文字全部 DOM

## Step 5 音軌＋出片

**動作**：做音軌（配樂／旁白生成 → 落檔凍結 → 混音 duck）→ 本機渲染 → 比例 × 時長矩陣 → CI／雲端批量。
- **音軌層**：選型同細節見 [`audio.md`](./audio.md)（配樂必須純 JS 合成；旁白用 AWS Polly neural）
- **唔准**：render 時即場生成、mp3 做源、實時 Web Audio 播放、專案外臨時檔
**為什麼**：音軌同畫面一樣要「每次都出同一條片」；分軌混音令換旁白／調音量唔使重寫音樂。
**產出**：`tools/make-*.mjs` ＋ `public/audio/*.wav` ＋ mp4（含音軌）。
**證據**：配樂同 seed 逐 byte 一致；旁白句界同稿對得上；出片有 audio stream。

## Step 6 機械驗證

**動作**：四項必做 —— 逐幀雜湊（只比影像）、規格、亮度曲線、音軌（時長／音量／斷音／句界）；再抽幀睇。
**為什麼**：動畫嘅 bug 好似「渲染成功但畫面錯」，肉眼睇唔出決定性問題；機械驗證先捉到。
**產出**：驗證證據（雜湊、規格、亮度曲線、音量／靜音報告）→ `out/check/`。
**證據**：兩次 render 影像逐幀一致；規格正確；曲線同 storyboard 對得上。**指令**見 [`verify.md`](./verify.md)。
