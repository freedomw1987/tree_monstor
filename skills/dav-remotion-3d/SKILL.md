---
name: dav-remotion-3d
description: >-
  用 Remotion（組版／時間軸／決定性出片）＋ three.js（3D）＋ DOM 疊層（文字）製作 motion graphic 影片：
  storyboard、組件與參數化、3D 場景與鏡頭、音軌（JS 配樂／TTS 旁白）、多比例出片、決定性驗證；不適用於純網頁互動動畫／AE 手製／細 icon 動畫。
---

# Dav Remotion 3D

## TL;DR

1. **做什麼**：把「交一條 motion graphic 影片」變成可重複產線：storyboard → 時間軸 → 組件＋參數化 → 3D → 音軌 → 出片 → 驗證
2. **何時觸發**：用戶要產品簡介／片頭／社交動畫（交 mp4，含配樂／旁白），而且要可重複生成（多比例／多語言）
3. **SOP 路徑**：一般任務（skill 係輔助工具，唔使走完整 SOP）；要出片就直接按本 skill 流程行
4. **關鍵紀律**：決定性三守則 ＋ 全片一個 WebGL canvas ＋ 文字一律 DOM 疊層 ＋ 音軌生成器產出並落檔凍結
5. **必產出物**：一律喺 project 目錄下 —— `<project>/remotion/`、音軌 wav（`public/audio/`）、出片（`out/`）、驗證證據

## 觸發時機

- **產品簡介片／片頭／社交動畫（交 mp4 含配樂／旁白），內容由資料驅動、要多比例／多語言**：✅ 必須
- **需要 3D 場景、鏡頭運動、粒子、景深**：✅ 必須
- **純網頁互動動畫／After Effects 手製／只要 Lottie 或細 icon 動畫**：❌ 不觸發（GSAP／Motion／SVG／CSS 更快）

## 流程（6 步；動作／為什麼／產出／證據 見子檔）

- **Step 1 定義交貨＋storyboard**：定片長／比例／格式／CTA，逐格寫畫面＋文案＋動態參數；證據：每格有幀範圍＋技術對應
- **Step 2 單一時間軸**：場景時間集中一個檔，相機同動畫全由 frame 推導；證據：改節奏只改一處
- **Step 3 組件＋參數化**：三層 props（資料檔 → composition（zod）→ scene），3D 喺底 DOM 喺上；證據：換文案唔改 component
- **Step 4 3D 場景**：揀強度檔位、動態效果目錄、seeded 亂數、效能預算；證據：無 `clock`／`Math.random()`
- **Step 5 音軌＋出片**：JS 合成配樂 ＋ 旁白（稿 → SSML → wav）→ 落檔凍結 → 混音、渲染；證據：mp4 含 audio stream
- **Step 6 機械驗證**：逐幀雜湊（只比影像）、亮度曲線、音軌（時長／音量／斷音／句界）、抽幀睇；證據：兩次 render 逐幀一致

## 規則

- **決定性三守則** — 例外：無；限制：動畫值只由 frame 推導；亂數只用 seeded PRNG；禁 CSS animation／transition
- **全片一個 WebGL canvas** — 例外：無；限制：場景切換 = 同 scene graph 切可見性；多 canvas 會撞 context 上限
- **文字一律 DOM 疊層** — 例外：無；限制：3D 內不畫字；DOM 對齊 3D 用相機投影座標，唔好手調數值
- **3D 平面一律雙面材質** — 例外：無；限制：單面平面畀相機背面剔除，結果係「成個 3D 唔見咗」
- **效能預算** — 例外：無；限制：每幀 ≤1 秒（3D 段 ≤1.5 秒）；粒子用 instancing；唔用即時反射／累積陰影
- **產物落點一律喺 project 目錄下** — 例外：用戶另指定；限制：專案 `<project>/remotion/`、出片 `out/`、中間檔 `out/check/`；禁 `/tmp`、home、skill 目錄
- **音軌一律生成器產出並落檔凍結** — 例外：純無聲版；限制：配樂必須純 JS 合成（seeded，禁外部 API）；旁白用 AWS Polly neural（未裝 CLI 先裝）；稿＝字幕稿
- **授權與成本** — 例外：無；限制：Remotion 個人及 ≤3 人公司免費，超出要授權；出片前先確認公司規模
- **交貨前必機械驗證** — 例外：無；限制：唔可以「睇落啱就算」；逐幀雜湊／規格／亮度曲線／音軌四項缺一不可
- **本 skill 自身規範** — 例外：無；限制：主檔 ≤50 行、子檔 ≤150 行、context ≤400 行、每行 ≤120 字；用列表不用表格

## 交叉引用（純文字）

- 音軌層（配樂 JS 合成／旁白 Polly／混音 duck／落點）→ 見同套本 skill 子檔 [`audio.md`](./audio.md)
- 產物落點／各步細節 → 見同套本 skill 子檔 [`workflow.md`](./workflow.md)；規劃技巧／SOP → 見同套 dav-planner 等 skill
- 3D 檔位／鏡頭／效能／坑 → 見子檔 [`3d-checklist.md`](./3d-checklist.md)；出片＋驗證指令／交付清單 → 見子檔 [`verify.md`](./verify.md)
