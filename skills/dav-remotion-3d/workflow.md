# Workflow — 由 storyboard 到出片

> 對應主檔流程 6 步。每步寫明：動作／為什麼／產出／證據。

## 產物落點（固定，一律喺 project 目錄下）

- **禁止**：寫去 `/tmp`、home（`~/`）、`~/.pi/agent/skills/` 或任何專案外位置 —— 片段同出片都必須跟 project 一齊行、一齊版控（`out/` 入 `.gitignore`）
- **Remotion 專案（片段製作本體）**：`<project>/remotion/` —— `src/`（component／scene／timeline）、`props/` 資料檔、`package.json`、`remotion.config.ts`
- **出片**：`<project>/remotion/out/` —— mp4／webm／still png（多比例／多變體用檔名或子目錄分開）
- **配樂／旁白／音效（音軌資產）**：`<project>/remotion/public/audio/` ＋ JS 生成器 `<project>/remotion/tools/make-music.mjs` —— 合成出嚟嘅 wav，入版控；唔放 `~/Music/` 等專案外位置
- **storyboard／props 資料檔原稿**：`<project>` 內跟 project 約定嘅文件位置（唔放 skill 目錄）
- **多任務／多條片**：`<project>/remotion/<clip-name>/` 一層分開，唔好幾個片共用一個 `out/`

## Step 1 定義交貨＋storyboard

**動作**：先定死交付物，再寫逐格 storyboard。
- 交付物要寫清：片長、主比例（16:9／9:16／1:1）、幀率、編碼、交付檔案數、變體（有聲／無聲 loop／多語言）
- 每格寫：目的／畫面／on-screen 文案／動態參數（入、出、stagger、鏡頭）／音效／技術對應／對應組件／注意
- 動態參數要有數字：位移 px、stagger ms、轉場幀數、鏡頭 z 變化、easing 名

**為什麼**：呢類片最花時間嘅係結構同節奏，唔係引擎。先定 storyboard 可以喺寫 code 之前驗證節奏，之後改結構成本極低；寫完 code 先發現節奏錯，返工成本高幾個數量級。

**產出**：storyboard 檔（逐格）。

**證據**：每格都有幀範圍、文案、技術對應；有一句創意概念同一張情緒曲線。

**節奏原則**
- 每 2–3 秒一個視覺焦點轉移；每格只講一件事；文字最多 1 主焦點＋1 輔助
- 文字可讀時間 ≥1.2 秒；片尾 CTA ≥1.5 秒
- 轉場用 wipe／dissolve／fade 類；唔用旋轉、3D flip、逐格 mosaic
- 文案：主標 ≤12 字、副行 ≤18 字、數字要保守得可以 defend

## Step 2 單一時間軸

**動作**：所有場景嘅時間集中喺一個 timeline 檔；每個場景記 from／duration；相機、動畫、亂數全部由 frame 推導。

**為什麼**：改節奏只改一處；避免「時間散落各 component，改唔到」。呢個檔同時係驗證基準。

**產出**：timeline 檔（場景表＋總幀數）。

**證據**：改任何一段時間，只動一個檔。

**會計陷阱（用官方轉場元件時）**
- 相鄰場景會**重疊** transition 幀數 → 總片長 = 各場景 duration 總和 − 各 transition 幀數
- 所以「改 transition 長度」會改變總片長 → 片長應該由 timeline 推導（或用 composition 的動態 metadata 綁定），唔好兩邊寫死
- 自寫 overlap（Sequence 手動錯開）就冇呢個問題，但轉場要自己實作

## Step 3 組件＋參數化

**動作**：三層 props 設計。
1. 資料檔層：品牌／文案／配色／語言／比例／旗標（JSON，一個變體一個檔）
2. composition 層：資料檔＋schema 驗證（zod）＋版權旗標
3. scene 層：每個場景自己嘅 props（位置、数量、seed、鏡頭參數）

**為什麼**：令「多比例 × 多語言 × 多版本」變成一份資料驅動，唔使改 component；亦令文案同數值可以由非工程師維護。

**產出**：component 樹＋schema＋props 資料檔範本。

**證據**：換文案／換比例／加語言，只改資料檔。

**組件結構原則**
- 3D 喺底（一個 canvas）、DOM 喺上（文字永遠清晰）、轉場層夾中間
- 場景組件**唔識**比例、語言、版本 —— 差異全部經 props 傳入
- 多比例用一個 layout hook 派生（安全區／字級／文字寬度／排列方向／標註位置），唔 fork component
- UI 截圖要預備多套（desktop 唔可以硬裁成 9:16）
- Props 必須係 pure JSON-serializable（唯一例外：動態 metadata 函數可以收函數）

## Step 4 3D 場景

**動作**：揀 3D 強度檔位 → 寫相機關鍵幀 → 場景層逐段建構。

**為什麼**：3D 係成本最高嘅一層，要先定份量先落手；相機用關鍵幀插值，令過場自然連貫。

**產出**：3D 層＋相機關鍵幀表。

**證據**：全片只有一個 canvas；每個動畫值都能追溯到 frame。

**相機關鍵幀設計**
- 每個關鍵幀記：frame、位置、fov、注視點
- 位置同注視點用同一組幀插值 → 過場唔會有「突然轉向」
- fov 用嚟表達情緒：廣角（50→65）= 進入感／衝擊；窄角（55→48）= 聚焦／壓縮
- 深度：近裁剪面要夠細，遠裁剪面要夠大（隧道要望到好遠）

**細節**
- 亂數：seeded PRNG（例如 mulberry32），每個場景一個固定 seed
- 材質：介面截圖類用不受光材質，確保顏色同開發環境一致；卡片／面板共享材質
- 陰影：一次性計算的接觸陰影；反光用鏡像平面＋漸變遮罩假反射
- 文字：全部 DOM；3D 內不畫字
- 細節規格（強度分檔／鏡頭語言／坑）見 [`3d-checklist.md`](./3d-checklist.md)

## Step 5 音軌＋出片

**動作**：先做音軌（配樂／旁白生成 → 落檔凍結 → 混音 duck）→ 本機渲染 → 多比例矩陣 → CI／雲端批量。

**音軌層（配樂／旁白／音效）** —— 細節同選型 → 見同套本 skill 子檔 [`audio.md`](./audio.md)
- **一律生成器產出 → 落檔凍結**：配樂 JS 合成（seeded）；旁白 **AWS Polly neural**（未裝 AWS CLI／credentials 先睇子檔）；落點 `tools/make-*.mjs` ＋ `public/audio/*.wav`，量出嘅時長／句界落 `out/check/`
- **旁白稿 = 字幕稿**（同一份 props）：句子時間由 timeline 推導；句長 ≤ 分配時間，**超長改稿減字，唔准 time-stretch**；混音時音樂／旁白／音效三條獨立軌、旁白出聲音樂 −6 dB
- **唔准**：render 時即場生成、mp3 做源、實時 Web Audio 播放、專案外臨時檔

**為什麼**：音軌同畫面一樣要「每次都出同一條片」；生成器 + 落檔令決定性可驗、唔靠外部 API quota／授權；分軌做混音令換旁白、調音量唔使重寫音樂。出片路徑亦要同開發路徑一樣（同一份 code 跑出嚟）。

**產出**：`tools/make-music.mjs`／`tools/make-vo.*` ＋ `public/audio/*.wav` ＋ mp4（多比例／多變體，含音軌）→ 落 `<project>/remotion/out/`（唔准 `/tmp` 或 home）。

**證據**：配樂同一 seed 重生逐 byte 一致；旁白句界同稿對得上；出片有 audio stream、時長對齊；見 [`verify.md`](./verify.md)。

## Step 6 機械驗證

**動作**：四項必做 —— 逐幀雜湊決定性（只比影像）、規格檢查、時間軸曲線、音軌（時長／音量／斷音）；再抽關鍵幀人工睇。

**為什麼**：動畫嘅 bug 好似「渲染成功但畫面錯」，肉眼睇唔出決定性問題；機械驗證先捉到。

**產出**：驗證證據（雜湊比對輸出、規格輸出、亮度曲線、音量／靜音報告）→ 落 `out/check/`。

**證據**：兩次 render 影像逐幀雜湊一致；規格正確；曲線變化同 storyboard 對得上；配樂 wav 重生逐 byte 一致。

**指令**見 [`verify.md`](./verify.md)。
