---
name: dav-remotion-3d
description: >-
  用 Remotion（組版／時間軸／決定性出片）＋ three.js（3D 場景）＋ DOM 疊層（文字）製作 motion graphic 影片：storyboard、組件與參數化、3D 場景與鏡頭運動、多比例出片、決定性驗證。不適用於：純網頁互動動畫（用 GSAP／Motion）、After Effects 手製動畫、只要一個細 icon 動畫（用 SVG／CSS）。
---

# Dav Remotion 3D

## TL;DR

1. **做什麼**：將「要交一條 motion graphic 影片」變成可重複嘅產線 — storyboard → 單一時間軸 → 組件＋參數化 → 3D 場景 → 決定性出片 → 機械驗證。
2. **何時觸發**：用戶要產品簡介片段／片頭／社交動畫（交付 mp4），而且要可重複生成（多比例、多語言、多版本）。
3. **SOP 路徑**：一般任務（skill 係輔助工具，唔使走完整 SOP）；要出片就直接按本 skill 流程行。
4. **關鍵紀律**：**決定性三守則**（frame 驅動／seeded 亂數／禁用 CSS 動畫）＋ **全片一個 WebGL canvas** ＋ **文字一律 DOM 疊層** ＋ **音軌（配樂／旁白／音效）一律生成器產出並落檔凍結**；交貨前必過機械驗證。
5. **必產出物**：**一律喺 project 目錄下** —— `<project>/remotion/`（component＋timeline＋props 資料檔）＋ 音軌 wav（`public/audio/`：配樂／旁白）＋ 出片 mp4（`out/`）＋ 驗證證據（規格、逐幀雜湊、時間軸曲線、音軌）。

## 觸發時機

- **用戶要做「用 code 寫出嚟嘅動畫影片」**：✅ 必須
- **產品簡介／片頭／發布短片，要 mp4 交付（含配樂／旁白／音效），且要資料驅動、多比例／多語言／多版本**：✅ 必須
- **需要 3D 場景、鏡頭運動、粒子、景深**：✅ 必須
- **純網站互動動畫（無影片交付）**：❌ 不觸發（用 GSAP／Motion，走前端路徑）
- **After Effects 手製／只想要 Lottie 資產／只要一個細 icon 動畫**：❌ 不觸發（SVG／CSS 更快）

## 流程（6 步；每步動作／為什麼／產出／證據見 [`workflow.md`](./workflow.md)）

- **Step 1 定義交貨＋storyboard**：定片長／比例／交付格式／CTA，逐格寫畫面＋文案＋動態參數 → 產出：storyboard 檔；證據：每格有幀範圍同技術對應
- **Step 2 單一時間軸**：所有場景時間集中一個檔，相機同動畫全部由 frame 推導 → 產出：timeline 檔；證據：改節奏只改一處
- **Step 3 組件＋參數化**：三層 props（資料檔 → composition props（zod 驗證）→ scene props）；3D 喺底、DOM 喺上 → 產出：component 樹＋schema；證據：換文案／比例唔使改 component
- **Step 4 3D 場景**：揀強度檔位、鏡頭語言、seeded 亂數、效能預算 → 產出：3D 層＋相機關鍵幀；證據：無 `Math.random()`、無 `clock`
- **Step 5 音軌＋出片**：生成配樂（JS 合成）同旁白（稿 → TTS → 字幕）→ 落檔凍結 → 分軌混音、本機渲染、多比例矩陣 → 產出：mp4（含音軌）；證據：規格檢查含 audio stream
- **Step 6 機械驗證**：逐幀雜湊決定性、時間軸亮度曲線、音軌（時長／音量／斷音）、抽幀人工睇 → 產出：驗證證據；證據：兩次 render 影像逐幀一致

## 規則

- **決定性三守則** — 例外：無；限制：動畫值只由 frame 推導；亂數只用 seeded PRNG；**禁用 CSS animation／transition**（跟真實時鐘，會破壞決定性）
- **全片一個 WebGL canvas** — 例外：無；限制：場景切換 = 同一 scene graph 切換可見性；多 canvas 會撞 context 上限、慢、記憶體翻倍
- **文字一律 DOM 疊層** — 例外：無；限制：3D 內不畫字（字型 fallback、唔 crisp、冇字幕）；DOM 對齊 3D 用相機投影座標，唔好手調數值
- **3D 平面一律雙面材質** — 例外：無；限制：相機朝 +z 睇時單面平面會被背面剔除，結果係「成個 3D 唔見咗」
- **效能預算** — 例外：無；限制：每幀 ≤1 秒（3D 段 ≤1.5 秒）；粒子用 instancing；陰影用一次性計算；唔用即時反射／累積陰影
- **產物落點一律喺 project 目錄下** — 例外：用戶另指定；限制：Remotion 專案 `<project>/remotion/`、出片 `<project>/remotion/out/`、驗證中間檔 `out/check/`；唔准寫去 `/tmp`、home、skill 目錄
- **授權與成本** — 例外：無；限制：Remotion 個人及 ≤3 人公司免費，超出要授權；出片前先確認公司規模
- **交貨前必機械驗證** — 例外：無；限制：唔可以「睇落啱就算」；逐幀雜湊、規格、時間軸曲線、音軌四項缺一不可
- **音軌一律由生成器產出並落檔凍結** — 例外：純無聲版（`audio:false`）；限制：配樂**必須**純 JS 合成（seeded；**唔准外部 API／素材庫**）、旁白用 **AWS Polly neural**（**未裝 AWS CLI＋credentials 先裝，指引見子檔**；稿 → SSML → wav）再落檔凍結；**旁白稿＝字幕稿（同一份 props）**；唔准 render 時即場叫 API、mp3 做源、time-stretch 塞字
- **本 skill 自身規範** — 例外：無；限制：主檔 ≤50 行、子檔 ≤150 行、context ≤400 行；一律用列表不用表格；唔記變動歷史

## 交叉引用（純文字）

- 音軌層（配樂 JS 合成選型／旁白（AWS Polly neural）稿 → SSML → 字幕／混音 duck／音軌落點）→ 見同套本 skill 子檔 [`audio.md`](./audio.md)；產物落點（目錄結構）／各步產出 → 見同套本 skill 子檔 [`workflow.md`](./workflow.md)；3D 強度檔位／鏡頭語言／效能預算／3D 坑，以及出片指令／多比例矩陣／驗證指令（含音軌）／交付清單 → 見同套本 skill 子檔 [`3d-checklist.md`](./3d-checklist.md) 同 [`verify.md`](./verify.md)
- 規劃技巧（V01／V02 提問紀律）→ 見同套 dav-planner skill；SOP 完整流程 → 見各自承載它嘅 skill（dav-planner／dav-designer／dav-developer／dav-reviewer）
