---
name: dav-remotion-3d
description: >-
  用 Remotion（組版／時間軸／決定性出片）＋ three.js（3D）＋ DOM 疊層製作宣傳片／廣告片為主（產品宣傳、品牌廣告、
  社交投流素材），兼做產品簡介 motion graphic：storyboard、3D 動效、JS 配樂／TTS 旁白、多比例多版本、決定性驗證。
  不適用於純網頁互動動畫、AE 手製動畫、細 icon 動畫。
---

# Dav Remotion 3D — 宣傳片／廣告片

## TL;DR

1. **做什麼**：把「要交一條宣傳片／廣告片」變成可重複產線：storyboard → 時間軸 → 3D 動效 → 音軌 → 出片 → 驗證
2. **何時觸發**：用戶要宣傳片／廣告片／投流素材（或產品簡介片），交 mp4（含配樂／旁白／字幕），要可重複生多版本
3. **關鍵紀律**：決定性三守則 ＋ 全片一個 WebGL canvas ＋ 文字一律 DOM 疊層 ＋ 音軌生成器產出並落檔凍結
4. **必產出物**：一律喺 project 目錄下 —— `<project>/remotion/`、音軌 wav（`public/audio/`）、出片（`out/`）、驗證證據

## 觸發時機

- **宣傳片／廣告片／社交投流素材（6–60 秒，mp4 含配樂／旁白／字幕）**：✅ 必須
- **產品簡介片／片頭／品牌動畫，要可重複生成（多比例／多語言／多優惠）＋需要 3D 動效**：✅ 必須
- **純網頁互動動畫／AE 手製／只要 Lottie 或細 icon 動畫**：❌ 不觸發（GSAP／Motion／SVG／CSS 更快）

## 流程（6 步；動作／為什麼／產出／證據 見子檔）

- **Step 1 定義交貨＋storyboard**：定片長檔位／比例／平台／CTA，逐格寫畫面＋文案＋動態參數；證據：每格有幀範圍＋技術對應
- **Step 2 單一時間軸**：場景時間集中一個檔（from／duration），相機同動畫全由 frame 推導；證據：改節奏只改一處
- **Step 3 組件＋參數化**：三層 props（資料檔 → composition（zod）→ scene），3D 喺底 DOM 喺上；證據：換文案唔改 component
- **Step 4 3D 動效**：揀強度檔位 ＋ 動效配額 ＋ seeded 亂數 ＋ 效能預算；證據：無 `clock`／`Math.random()`
- **Step 5 音軌＋出片**：JS 合成配樂 ＋ 旁白（稿 → SSML → wav）→ 落檔凍結 → 混音、渲染；證據：mp4 含 audio stream
- **Step 6 機械驗證**：逐幀雜湊（只比影像）、亮度曲線、音軌（時長／音量／斷音／句界）、抽幀睇；證據：兩次 render 逐幀一致

## 規則

- **決定性三守則** — 例外：無；限制：值只由 frame 推導；亂數只用 seeded PRNG；禁 CSS animation／transition
- **全片一個 WebGL canvas** — 例外：無；限制：場景切換 = 同 scene graph 切可見性；多 canvas 會撞 context 上限
- **文字一律 DOM 疊層** — 例外：無；限制：3D 內不畫字；DOM 對齊 3D 用相機投影座標，唔好手調數值
- **3D 平面一律雙面材質** — 例外：無；限制：單面平面畀相機背面剔除，結果係「成個 3D 唔見咗」
- **效能預算** — 例外：無；限制：每幀 ≤1 秒（3D 段 ≤1.5 秒）；粒子用 instancing；唔用即時反射／累積陰影
- **產物落點一律喺 project 目錄下** — 例外：用戶另指定；限制：專案 `<project>/remotion/`、出片 `out/`、中間檔 `out/check/`
- **音軌一律生成器產出並落檔凍結** — 例外：純無聲版；限制：配樂必須純 JS 合成（禁外部 API）；旁白用 AWS Polly neural（未裝 CLI 先裝）；稿＝字幕稿
- **廣告片必守** — 例外：無；限制：頭 3 秒 hook；一條片一個訊息；字幕標配；**3D 可主導 ≥80%**；end card 收尾
- **交貨前必驗證＋合規** — 例外：無；限制：逐幀雜湊／規格／亮度曲線／音軌／投放合規五項缺一不可
- **本 skill 自身規範** — 例外：無；限制：主檔 ≤50 行、子檔 ≤150 行、context ≤400 行、每行 ≤120 字；用列表不用表格

## 交叉引用（純文字）

- 廣告結構／時長檔位／平台矩陣／字幕／LUFS／合規／3D 動效清單 → 見子檔 [`ad.md`](./ad.md)
- 音軌層（配樂／旁白／混音）→ [`audio.md`](./audio.md)；各步細節／落點 → [`workflow.md`](./workflow.md)
- 3D 檔位／實作規則／效能／坑 → 見子檔 [`3d-checklist.md`](./3d-checklist.md)；出片＋驗證指令／交付清單 → 見子檔 [`verify.md`](./verify.md)
