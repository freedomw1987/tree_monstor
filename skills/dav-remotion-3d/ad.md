# Ad — 宣傳片／廣告片（結構、投放適配、3D 動效清單）

> 對應主檔 Step 1（交貨定義）同 Step 4（動效揀選）。廣告片同產品簡介片嘅分別：**目標係轉化**，唔係介紹。

## A. 廣告結構（單一訊息，唔好講兩件事）

- **Hook（0–3 秒）**：一條問題／一個反差／一個 hero beat（爆炸圖、材質 swap、drop-and-settle）
- **Problem → Solution → Proof**：痛點一句、產品點解、證據（數據、剖視、客戶）；
  **Offer ＋ CTA**：優惠要可驗；CTA 只一個動作；**End card**：logo ＋ tagline ＋ CTA ＋ 網址／QR ≥1.5 秒
- **時長檔位**：6s bumper｜15s 投流（主力）｜30s 品牌｜60s 詳細；同一內容由 timeline 派生多個長度
- **靜音觀看為前提**：字幕係標配（大部分社交片靜音睇）；重要 claim 要出字，唔可以只靠旁白

## B. 投放適配（交貨前逐項對）

- **比例 × 平台矩陣**：16:9（YouTube／網站）｜9:16（Reels／TikTok／Stories）｜1:1（feed）；一個 composition 派生
- **安全區／時長**：9:16 上下各留約 15%（平台 UI）、文字唔貼邊；YouTube pre-roll 頭 5 秒定生死；Reels／TikTok ≤15 秒
- **響度（廣告要標準化，唔止 peak）**：廣播 EBU R128 **−23 LUFS**；社交平台常見 **−14 LUFS**；
  驗：`ffmpeg -i out/a.mp4 -af loudnorm=print_format=summary -f null -`（睇 input_i）
- **字幕**：同一份 props 稿出 SRT／burn-in 版本；多語言 = 多組 vo 檔 ＋ 多組字幕
- **版本命名**：`<clip>_<比例>_<時長>_<語言>_<優惠>`（例 `promo_9x16_15s_zh_hk_discount`）
- **合規檢查**：優惠條款（`*受條款限制`）、價格幣值、效果 claim 有無根據、肖像／音樂／字體授權、地區法規
- **封面／poster**：出一張 key frame 做縮圖（`remotion still`），唔使抽片

## C. 3D 動效清單（46 個；廣告／宣傳片可 3D 主導 ≥80%；成本／風險以 three.js frame-driven 為準）

### 產品主角（Hero）
- 1 macro 微距材質特寫（finish／做工）｜2 hero 慢推 ＋ rim light｜3 360° turntable 無縫 loop
- 4 drop-and-settle 有重量感｜5 push-in 講 hook → pull-out 出 offer｜6 snap zoom／snap-cut on beat
- 7 rack focus 景深轉焦（假 DOF：fog ＋ blur plane）

### 工序／結構揭示
- 8 exploded view 爆炸圖 ＋ callout → 重組｜9 assembly 組裝｜10 cutaway／X-ray 剖視
- 11 digital unboxing 開箱｜12 材質 morph（啞→亮、實→液）｜13 顏色／finish swap carousel
- 14 fill-level 注入｜15 shrink／scale comparison｜16 stress-test 模擬（claim 要保守可驗）

### 模擬／物理現象
- 17 liquid 液體｜18 particles／dust｜19 smoke／fog ＋ 體積光｜20 fabric 布料｜21 destruction／debris｜22 energy flow／電光

### 品牌＋文字
- 23 3D logo build（金屬／玻璃／液體）｜24 kinetic type 3D（業界用量最大：14,739 場）
- 25 字被粒子吹散 → 重組｜26 字幕／價格 3D 浮動面板｜27 end card（logo ＋ tagline ＋ CTA ＋ QR）
- 28 light sweep 光帶掃過（997 場）

### 場景／世界
- 29 dot-stream tunnel｜30 grid／wireframe ＋ point cloud｜31 node network／glowing orb
- 32 environment establishing｜33 wet-floor reflection／cyclorama｜34 volumetric light ＋ haze
- 35 match cut／whip-pan 3D 過場｜36 mask wipe 3D（2,091 場）｜37 speed ramp（286 場）

### 戶外／裸眼 3D（另一 pipeline：先定視點，再反向變形）
- 38 anamorphic 3D billboard（forced perspective；要有「box」＋物件穿出邊緣；L 形／弧屏最靚）
- 39 FOOH（CGI 扮實景大屏，純社交傳播）｜40 動態版本化創意（天氣／UV／航班觸發）

### 後處理質感（「貴」感來源，只喺高潮段開）
- 41 bloom／halation｜42 DOF｜43 grain／vignette｜44 chromatic aberration｜45 dither／CRT｜46 品牌色 LUT

## D. 三套起手模板（15 秒投流為例）

- **產品型**：1 macro hook → 8 爆炸圖重組 → 5 push-in ＋ 26 3D 立體字 claim → 27 end card ＋ 28 光帶掃 logo
- **品牌型（30s）**：32 環境建立 → 2 hero 慢 orbit → 12 材質 morph → 25 粒子聚合 logo → 27 end card
- **Bumper（6s）**：4 drop-and-settle ＋ 24 kinetic type ＋ 28 light sweep

## E. 我哋 stack 落唔落得到（誠實分野）

- **落得到、可決定性驗證**：1–16、23–28、29–37、41–46（全部 frame-driven；爆炸圖／粒子／morph／光帶／隧道已有基礎）
- **要預烘或外部工具**：17 liquid、20 fabric、21 destruction、19 體積煙 → Blender／Houdini 出序列圖／影片素材再入片
  （或者用 shader 做近似，成本低但唔係真物理）
- **屬另一 pipeline**：38–40 anamorphic／FOOH → 先定觀眾視點，再反向變形 render（唔係普通 16:9 出片）
- **3D 主導 ≥80% 可行**：但要守效能預算（每幀 ≤1 秒、3D 段 ≤1.5 秒）同「每段一件事」；平面／DOM 只留嚟講 claim

## F. 紀律（廣告最容易犯）

- **配額**：廣告／宣傳片可 3D 主導（≥80% 片長）；產品簡介片 3–5 個動效；同一時間最多 1–2 個 active effect
- **仍然要守**：每段只做一件事、效果之間留呼吸位、hook 3 秒講清、字幕標配、end card 收尾；兩個 claim 就兩條片
  （多版本矩陣正好做 A／B 測試）
