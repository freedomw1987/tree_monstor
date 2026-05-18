---
name: html5-animated-explainer
description: 用純 HTML5 + CSS 3D transforms 生成動態視覺解說影片。Single-file, no libraries, no build step — 雙擊即可運行。
version: 2.3.1
author: David Chu / Hermes Agent
license: MIT
dependencies: []
metadata:
  hermes:
    tags: [HTML5, CSS3D, animation, visual-explainer, narrated, single-file]
    trigger_conditions: [HTML5動畫, 視覺解說, CSS 3D, 場景切換, 滾動視差, 雙擊運行]
    related_skills: [ascii-art, excalidraw, manim-video]

---

# HTML5 Animated Visual Explainer Skill

用純 HTML5 + CSS 3D transforms 生成動態視覺解說。雙擊運行，無需任何依赖。

## Trigger Condition

當用戶要求生成以下類型的內容時，自動加載此 skill：
- 「做一個 HTML5 動畫」
- 「視覺解說」、「動態簡報」、「滾動視差網頁」
- 「雙擊就能跑的動畫」
- 「CSS 3D 效果」、「翻牌動畫」、「立方體翻轉」
- 直接提供一個 topic 並要求「做成動畫」

---

## 引擎架構（固定不變）

所有產出都必須符合以下 8 項規範，不可擅自改動：

### 1. 單一 HTML 文件
- 所有 HTML + CSS + JS 全部 inline
- 唯一允許的外部資源：Google Fonts
- 禁止：WebGL、Canvas、任何第三方 library

### 2. Scene + Caption 引擎
```
scenes[] = { start, end, html }   // 場景內容
subs[]   = { s, e, t }            // 字幕：開始秒、結束秒、文字
TOTAL = 總秒數
```
- `requestAnimationFrame` 驅動：currentTime、字幕、場景切換、進度條、章節點、[data-at] 定時浮入
- 當前場景加 `.active`，退出場景加 `.zoom-out`
- `data-at="N"` = 當 currentTime >= N 時淡入/滑入
- 字幕切換使用 `.cap-in` 淡入動畫

### 3. 控制欄（固定在底部 44px）
- ◀ 上一頁 / ▶ 播放 / ▶ 下一頁 按鈕（class `cb`，啟動狀態 `.on`）
- 單行字幕（超長時 truncate + ellipsis）
- mm:ss / mm:ss 計時器
- 3px 進度條（可點擊 seek）
- 章節點（每個場景起始位置一個，場景 0 有 `.past` 和 `.next` 脈動狀態）
- 鍵盤：Space = 播放/暫停，←/→ = 上一頁/下一頁
- 觸控：水平滑動 = 上一頁/下一頁

### 4. 環境層（Ambient Layer）
- 18 個漂浮粒子 + 2 個大型模糊背景形狀緩慢飄動
- 每次場景切換時 `#sceneFlash` radial-gradient 閃光

### 5. 設計 Token（CSS Variables）
```css
--bg:#F9F7F7       --bg2:#EEF1F7
--card:#fff        --teal:#3F72AF
--teal-soft:rgba(63,114,175,0.08)
--coral:#E07A5F    --coral-soft:rgba(224,122,95,0.08)
--navy:#112D4E     --text:#112D4E
--muted:rgba(17,45,78,0.7)
--border:rgba(17,45,78,0.08)
--shadow:0 2px 20px rgba(17,45,78,0.06)
```

### 6. 字體（Google Fonts）
```css
--font-heading: 'Chiron GoRound TC', 'Instrument Serif', sans-serif
--font-body: 'Chiron GoRound TC', sans-serif
--font-mono: 'DM Mono', monospace
```
- `.subtitle` = mono, teal, uppercase, letter-spaced
- `.title` = heading, navy, 含 `.hl` spans 為 teal
- `.note` = body, muted, max 640px, 支援 inline `<code>` chips

### 7. Stage（舞台區域）
- 全螢幕 minus 44px 控制欄，perspective: 1800px
- 每個 `.scene` absolute-positioned, flex-column-centered
- cubic-bezier(.4,0,.2,1) 過渡 opacity + transform

### 8. 無障礙（Accessibility）
```css
@media (prefers-reduced-motion:reduce) {
  *,*::before,*::after{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important}
}
```

---

## Motion Direction Core（整合 LottieFiles motion-design-skill）

此章節整合自 LottieFiles `motion-design-skill` 的 motion design principles，用於所有 HTML5 動畫輸出。它是「動畫導演層」，先決定情緒、節奏、層次，再寫 CSS/JS。

### 8-Step Motion Checklist

在生成任何場景前，先回答：

1. **Emotional target?** — 要觀眾感到 joy / calm / urgency / elegance / trust / excitement？
2. **Motion personality?** — Playful / Premium / Corporate / Energetic？整個動畫只選一個主人格。
3. **Primary property?** — position / scale / rotation / opacity / color / shadow？
4. **Duration?** — 根據元素重量選擇，不要所有東西同速。
5. **Easing family?** — entrance = decelerate，exit = accelerate，ambient = sine ease-in-out。
6. **Hero element?** — 每場景只允許一個主視覺 hero，其他元素支援它。
7. **Secondary + ambient layers?** — 主動作之外要有 shadow、icon、背景 blobs、粒子等第二/環境層。
8. **1/3 rules?** — 運動距離與同時移動元素不能過量。

### Three Pillars（必須滿足）

| Pillar | 問題 | 影響 |
|---|---|---|
| **Emotional Intent** | 觀眾應該感到什麼？ | easing、duration、amplitude |
| **Visual Narrative** | 微故事是什麼？ | setup → action → resolution |
| **Motion Craft** | 如何讓它可信？ | physics、secondary motion、paths |

**每個場景至少三層 motion：**
- **Primary:** 觀眾要追看的主動作，例如 card reveal、phone mockup、hero headline。
- **Secondary:** 支援質感，例如 shadow delayed settle、icon shift、line draw-in。
- **Ambient:** 背景生命，例如 blobs drift、particles、soft glow、orbit ring。

### Motion Personality Archetypes

| Archetype | Duration | Easing | Overshoot | 適用 |
|---|---:|---|---:|---|
| **Playful** | 150–300ms | ease-out-back | 10–20% | cute、fun、micro interactions |
| **Premium** | 350–600ms | cubic-bezier(.4,0,.2,1) | 0% | Apple-like、高級、克制 |
| **Corporate** | 200–400ms | cubic-bezier(.2,0,0,1) | 0–3% | SaaS、dashboard、企業簡報 |
| **Energetic** | 100–250ms | ease-out-expo | 15–30% | Okalpha/Jomor、大膽、快節奏 |

**Brand Motion Identity 要固定三件事：**
1. Signature easing：80% 動畫用同一條曲線。
2. Duration palette：quick / standard / slow 三個時長。
3. Entrance pattern：一致的入場方式。

### Duration Table

| Element Type | Duration | 用途 |
|---|---:|---|
| Tooltip / micro-feedback | 80–120ms | 即時反饋 |
| Button press / toggle | 120–180ms | 點擊感 |
| Icon transition | 150–250ms | 狀態切換 |
| Card enter / exit | 200–350ms | 空間感 |
| Modal / dialog | 300–400ms | 聚焦轉移 |
| Page / scene transition | 400–600ms | 上下文轉換 |
| Dramatic reveal | 600–1200ms | hero / cinematic reveal |

規則：
- 距離越大，時長越長：100px = base，200px = 1.3x，400px = 1.6x。
- Entrance 要比 exit 慢 30–50%，因為觀眾更關心出現的內容。
- Hover <100ms；press <150ms；settle 200–300ms。

### Easing Selection

| Situation | Easing |
|---|---|
| Entrance | ease-out / decelerate |
| Exit | ease-in / accelerate |
| On-screen motion | ease-in-out |
| Ambient loop | sine-like ease-in-out |
| Premium / Apple-like | cubic-bezier(.4,0,.2,1) 或 cubic-bezier(.28,.11,.32,1) |
| Corporate / SaaS | cubic-bezier(.2,0,0,1) 或 cubic-bezier(.22,1,.36,1) |
| Energetic | ease-out-expo / cubic-bezier(.77,0,.175,1) |
| Playful | cubic-bezier(.175,.885,.32,1.275) |

### Property Selection

| Effect Goal | Primary Property | Secondary Properties |
|---|---|---|
| Entrance / Exit | position | opacity, scale |
| Emphasis / Attention | scale | subtle rotation, opacity pulse |
| State Change | opacity, color | scale press feedback |
| Direction / Flow | position | rotation follows path |
| Depth / 3D Feel | scale + shadow | parallax position |
| Loading / Progress | rotation / line width | scale, opacity pulse |
| Success | scale pop | color, checkmark draw |
| Error / Alert | horizontal position shake | red tint, wobble |

**Simplicity threshold:** 一個 property = direct，兩個 = polished，三個以上容易過度。只有 hero element 才能用 3+ properties。

### Choreography Rules

- **Lead with hero:** 主視覺先進場，secondary content 之後 80–200ms。
- **Spatial consistency:** 同一場景元素從相同方向或有邏輯的方向進入。
- **Counter-motion:** hero 右移時，ambient 可用 20–30% 速度往反方向漂移。
- **Stagger budget:**
  - Micro cascade: 20–40ms，總 <200ms。
  - Standard cards: 50–100ms，總 <400ms。
  - Dramatic hero: 100–200ms，總 <600ms。
- **1/3 distance rule:** 物件不要一口氣移動超過畫面 1/3，否則加中途 keyframe。
- **1/3 active elements rule:** 3 個以上元素時，同時大幅移動的元素不超過 1/3。

### Common Patterns

**Button Press**
1. Anticipation: scale .97 / 50ms。
2. Press: scale .96 / 80–120ms。
3. Settle: scale 1 / 200ms。
4. Secondary: shadow shrink / icon down 2px。

**Card Entrance**
1. Start: 20px below + opacity 0。
2. Ease-out deceleration。
3. Shadow delayed 50ms after card。
4. Content fades in 100ms after card lands。

**Success State**
1. Primary: scale pop。
2. Secondary: checkmark line draw。
3. Ambient: subtle particle burst。
4. Total: 300–400ms。

**Error Shake**
1. Position oscillates 2–3 times, ±10–15px。
2. Total: 300–400ms。
3. No playful overshoot unless brand is playful。

### Quality Rules（不可違反）

1. **Never linear for spatial movement** — linear 只用於 spinner / progress bar。
2. **Never opacity-only for important state change** — 必須加 position 或 scale。
3. **Never exceed 1/3 screen without intermediate keyframe**。
4. **Always three motion layers** — primary + secondary + ambient。
5. **No generic easing everywhere** — 根據 personality 統一但不僵硬。
6. **Do not animate everything** — 有靜止物件才看得出主動作。

### Troubleshooting

| Problem | Likely Cause | Fix |
|---|---|---|
| Looks robotic | linear easing / no arcs | 加 easing + curved path |
| Feels too slow | duration 過長 | 查 duration table，縮短或改 ease-out |
| Feels cheap/flat | 缺 secondary/ambient | 加 shadow motion、背景呼吸、icon shift |
| Too distracting | 太多元素同時動 | 用 1/3 rule，減 amplitude |
| No personality | easing/節奏混亂 | 選一個 personality，固定 signature easing |

---

## 視覺组件库（Visual Component Library）

**每個場景至少要有 1 個視覺组件，不能只有純文字。** 以下是可直接使用的 CSS 组件，全部可搭配 `data-at` 延遲浮入：

### 📊 數據卡片（Stat Cards）
```css
.stat-card{background:var(--card);border-radius:12px;padding:16px;border:1px solid var(--border);box-shadow:var(--shadow)}
.stat-number{font-family:var(--font-mono);font-size:28px;color:var(--teal)}
.stat-label{font-size:11px;color:var(--muted);line-height:1.4}
```

### 🏗️ 架構層（Architecture Layers）
```css
.arch-layer{border-radius:10px;padding:14px 16px;margin-bottom:8px}
.app-layer{background:linear-gradient(135deg,#e0f2fe,#bae6fd);border:2px solid #0284c7}
.ai-layer{background:linear-gradient(135deg,#e0e7ff,#c7d2fe);border:2px solid #6366f1}
.data-layer{background:linear-gradient(135deg,#ecfdf5,#d1fae5);border:2px solid #10b981}
.arch-item{background:rgba(255,255,255,.8);border-radius:6px;padding:5px 10px;font-size:11px;font-family:var(--font-mono)}
```

### 📋 流程步驟（Process Steps）
```css
.step-row{display:flex;align-items:center;gap:12px;margin-bottom:8px}
.step-num{width:36px;height:36px;border-radius:50%;background:var(--teal);color:#fff;display:flex;align-items:center;justify-content:center;font-size:16px;flex-shrink:0}
.step-title{font-family:var(--font-mono);font-size:11px;font-weight:500;text-transform:uppercase}
.step-desc{font-size:11px;color:var(--muted)}
```

### 📈 數據網格（Data Grid）
```css
.data-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.data-cell{background:var(--card);border-radius:12px;padding:16px;border:1px solid var(--border);box-shadow:var(--shadow)}
.data-cell.highlight{background:linear-gradient(135deg,var(--teal-soft),var(--coral-soft));border-color:var(--teal)}
```

### 📱 手機模型（Phone Mockup）
```css
.phone{width:80px;height:150px;background:#1a1a2e;border-radius:18px;border:3px solid #333;position:relative;margin:0 auto}
.phone::before{content:'';position:absolute;top:8px;left:50%;transform:translateX(-50%);width:36px;height:5px;background:#333;border-radius:2px}
.phone-screen{position:absolute;inset:20px 5px 5px 5px;background:linear-gradient(180deg,var(--teal),var(--navy));border-radius:10px}
```

### 🔄 翻牌效果（Flip Card）
```css
.flipcard-scene{perspective:1000px}
.flipcard{width:280px;height:160px;position:relative;transform-style:preserve-3d;animation:flipAnim 4s ease-in-out infinite}
.flipcard .fc{position:absolute;width:100%;height:100%;backface-visibility:hidden;border-radius:16px;display:flex;align-items:center;justify-content:center;font-family:var(--font-heading);font-size:22px;color:#fff}
.flipcard .fc.front{background:var(--teal)}
.flipcard .fc.back{background:var(--coral);transform:rotateY(180deg)}
@keyframes flipAnim{0%,100%{transform:rotateY(0deg)}50%{transform:rotateY(180deg)}}
```

### 🎲 旋轉立方體（Rotating Cube）
```css
.cube-scene{perspective:800px}
.cube{width:160px;height:160px;position:relative;transform-style:preserve-3d;animation:cubeSpin 10s linear infinite}
.cube .face{position:absolute;width:160px;height:160px;background:var(--card);border:1px solid var(--border);box-shadow:var(--shadow);display:flex;align-items:center;justify-content:center;font-family:var(--font-mono);font-size:11px;color:var(--muted);backface-visibility:hidden}
.cube .face:nth-child(1){transform:rotateY(0deg)translateZ(80px)}
.cube .face:nth-child(2){transform:rotateY(90deg)translateZ(80px)}
.cube .face:nth-child(3){transform:rotateY(180deg)translateZ(80px)}
.cube .face:nth-child(4){transform:rotateY(-90deg)translateZ(80px)}
.cube .face:nth-child(5){transform:rotateX(90deg)translateZ(80px)}
.cube .face:nth-child(6){transform:rotateX(-90deg)translateZ(80px)}
@keyframes cubeSpin{0%{transform:rotateX(-20deg)rotateY(0deg)}100%{transform:rotateX(-20deg)rotateY(360deg)}}
```

### 🎯 彈出聚光燈（Spotlight Grid）
```css
.spotlight{display:grid;grid-template-columns:1fr 1fr;gap:12px;width:280px}
.spotlight-item{background:var(--card);border-radius:12px;padding:14px;border:1px solid var(--border);box-shadow:var(--shadow);text-align:center}
.spotlight-item.highlight{background:var(--teal-soft);border:2px solid var(--teal)}
```

### 🔗 節點網絡（Node Network）
```css
.node-ring{position:relative;width:260px;height:200px;display:flex;align-items:center;justify-content:center}
.node{position:absolute;width:64px;height:64px;border-radius:50%;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px}
.node-center{background:var(--card);border:2px solid var(--teal);color:var(--teal);font-size:22px}
.node-sat{background:var(--teal);color:#fff;animation:nodeFloat 3s ease-in-out infinite}
@keyframes nodeFloat{0%,100%{transform:translateY(0)}50%{transform:translateY(-8px)}}
```

### 📉 對比面板（Before/After Panels）
```css
.compare{display:flex;gap:16px;align-items:center}
.compare-panel{flex:1;border-radius:12px;padding:16px;border:2px solid var(--border)}
.compare-panel.before{background:var(--coral-soft);border-color:var(--coral)}
.compare-panel.after{background:var(--teal-soft);border-color:var(--teal)}
.compare-value{font-family:var(--font-mono);font-size:28px;font-weight:500}
.compare-panel.before .compare-value{color:var(--coral)}
.compare-panel.after .compare-value{color:var(--teal)}
```

---

## Okalpha-inspired Motion Pack（參考 okalpha.co）

當用戶要求「參考 Okalpha」、「更像 motion studio」、「更有動畫感」、「大膽一點」時，採用此風格包。**不要複製 Okalpha 原始素材或網站代碼，只複製動效語言與設計方向。**

### 風格語言
- **超大標題**：bold editorial typography，標題可佔畫面 40–60%。
- **高飽和原色**：blue / red / yellow / black / white，減少柔和漸層，改用強烈色塊。
- **巨大幾何背景**：超大 pill / circle / rounded rectangle 從畫面邊緣切入。
- **2.5D extrusion**：按鈕、卡片、人物/物件用多層 offset shadow 製造厚度。
- **Project-card reveal**：卡片展開/收合、圖片/影片區域滑入，文字和視覺物件分欄。
- **Micro hover feel**：hover/active 時物件不是只放大，而是 `translate(-5px,-10px)` + shadow 加厚。
- **節奏**：少量元素、每個元素動得明確；避免同一場景塞太多小字。

### Okalpha Palette Tokens
```css
--ok-red:#ff1f25;
--ok-blue:#005cef;
--ok-blue-dark:#003286;
--ok-yellow:#ffdd18;
--ok-yellow-dark:#d7b229;
--ok-black:#000;
--ok-white:#fff;
```

### 2.5D Extruded Button / Card
```css
.ok-extrude{
  background:var(--ok-yellow);
  color:var(--ok-black);
  border:0;
  box-shadow:
    1px 1px 0 var(--ok-yellow-dark),
    2px 2px 0 var(--ok-yellow-dark),
    3px 3px 0 var(--ok-yellow-dark),
    4px 4px 0 var(--ok-yellow-dark),
    5px 5px 0 var(--ok-yellow-dark),
    6px 6px 0 var(--ok-yellow-dark),
    7px 7px 0 var(--ok-yellow-dark);
  transform:translate(-5px,-10px);
  transition:transform .25s cubic-bezier(.77,0,.175,1), box-shadow .25s ease;
}
.ok-extrude:hover{
  transform:translate(-10px,-16px);
  box-shadow:
    1px 1px 0 var(--ok-yellow-dark),2px 2px 0 var(--ok-yellow-dark),
    3px 3px 0 var(--ok-yellow-dark),4px 4px 0 var(--ok-yellow-dark),
    5px 5px 0 var(--ok-yellow-dark),6px 6px 0 var(--ok-yellow-dark),
    7px 7px 0 var(--ok-yellow-dark),8px 8px 0 var(--ok-yellow-dark),
    9px 9px 0 var(--ok-yellow-dark),10px 10px 0 var(--ok-yellow-dark);
}
```

### Oversized Pill Background
```css
.ok-pill-bg{
  position:absolute;
  width:1200px;
  height:600px;
  border-radius:1000px;
  background:var(--ok-blue);
  transform:translate3d(20%,-20%,0) rotate(-8deg);
  animation:okPillDrift 10s ease-in-out infinite alternate;
  z-index:-1;
}
@keyframes okPillDrift{
  from{transform:translate3d(20%,-20%,0) rotate(-8deg)}
  to{transform:translate3d(15%,-14%,0) rotate(-2deg)}
}
```

### Big Editorial Title
```css
.ok-title{
  font-family:var(--font-heading);
  font-size:clamp(54px,14vw,160px);
  line-height:.9;
  letter-spacing:-.06em;
  color:var(--ok-black);
}
.ok-title .red{color:var(--ok-red)}
.ok-title .blue{color:var(--ok-blue)}
```

### Project Reveal Panel
```css
.ok-project{
  display:grid;
  grid-template-columns:1.1fr .9fr;
  min-width:320px;
  max-width:760px;
  background:var(--ok-red);
  color:var(--ok-white);
  overflow:hidden;
  transform:translateY(-8px);
}
.ok-project-media{
  min-height:220px;
  background:var(--ok-yellow);
  transform:translateX(-1px);
  transition:padding .3s cubic-bezier(.047,.352,.25,1);
}
.ok-project-copy{
  padding:48px;
  display:flex;
  flex-direction:column;
  justify-content:center;
}
.ok-project:hover .ok-project-media{padding:14px}
```

### 使用規則
- Okalpha mode 每個場景最多 1 個主視覺 + 1 個 CTA / 數據組，不要密集排版。
- 比起玻璃擬態和柔和陰影，優先使用**實色塊、厚陰影、巨大留白**。
- 場景轉場可使用：`slide-up reveal`、`accordion expand`、`oversized shape wipe`、`extruded hover pop`。
- 適合：作品集、產品 teaser、品牌動畫、重點數據展示、motion-studio 風格 proposal。

---

## Jomor-inspired Motion Pack（參考 jomor-design-2019.webflow.io）

當用戶要求「參考 Jomor」、「更 edgy」、「更像設計工作室 landing page」、「skew / scroll typography / 黑底大字」時，採用此風格包。**不要複製 Jomor 原始素材或網站代碼，只複製動效語言與設計方向。**

### 風格語言
- **黑底 + 白色超粗 uppercase**：hero 可用 8–12vw 字級，font-weight 900，line-height 1。
- **文字斜切進場**：大量使用 `skew(0,-5deg)`、`translateY(-15%)`、opacity reveal。
- **透明描邊文字**：`color: transparent; -webkit-text-stroke: 1px #fff;`，用於背景大字或副標。
- **旋轉側邊標籤**：例如 WORK / FEATURED / SCROLL 旋轉 90deg 放在畫面邊緣。
- **GIF / image 浮層感**：右上角大圖塊 `position:fixed/absolute`、skew、圓角、opacity reveal。
- **圓形 CTA**：大圓形 outline button，letter-spacing 很大，hover 時 letter-spacing 收緊或放大。
- **Custom cursor / view dot 感**：用黑色圓點或 view badge 跟隨/浮出，表示互動。
- **幽默感文案**：短句、直接、略帶玩味，例如 “You can scroll.” / “Ok. Let’s move.”。

### Jomor Palette Tokens
```css
--jo-black:#1b1b1b;
--jo-white:#f7f7f7;
--jo-green:#12e09b;
--jo-orange:#d86018;
--jo-red:#e4002b;
--jo-muted:#838383;
```

### Skew Reveal Title
```css
.jo-title{
  color:var(--jo-white);
  text-transform:uppercase;
  font-size:clamp(54px,10vw,150px);
  font-weight:900;
  line-height:1em;
  letter-spacing:-.04em;
  transform:translate3d(0,-15%,0) skew(0deg,-5deg);
  opacity:0;
  transition:opacity .7s cubic-bezier(.77,0,.175,1), transform .7s cubic-bezier(.77,0,.175,1);
}
.scene[data-visible] .jo-title{
  opacity:1;
  transform:translate3d(0,0,0) skew(0deg,0deg);
}
```

### Transparent Stroke Text
```css
.jo-stroke{
  color:transparent;
  -webkit-text-stroke:1px var(--jo-white);
  text-transform:uppercase;
  font-size:clamp(42px,8vw,120px);
  font-weight:900;
  line-height:1;
  opacity:.45;
}
```

### Rotated Side Label
```css
.jo-side-label{
  position:absolute;
  left:-20px;
  bottom:10vh;
  transform:rotate(-90deg);
  transform-origin:left center;
  font-family:var(--font-mono);
  font-size:12px;
  letter-spacing:.4em;
  color:var(--jo-muted);
  text-transform:uppercase;
}
```

### Floating Skew Media Card
```css
.jo-media{
  position:absolute;
  right:-3vw;
  top:-7vh;
  width:min(60vw,900px);
  aspect-ratio:16/10;
  border-radius:10px;
  background:linear-gradient(135deg,var(--jo-green),var(--jo-orange));
  transform:skew(6deg,-4deg) translateY(-20px);
  opacity:0;
  transition:opacity .6s ease .25s, transform .7s cubic-bezier(.77,0,.175,1) .25s;
}
.scene[data-visible] .jo-media{
  opacity:1;
  transform:skew(6deg,-4deg) translateY(0);
}
```

### Circular CTA
```css
.jo-circle-cta{
  color:var(--jo-white);
  letter-spacing:7px;
  text-transform:uppercase;
  border:2px solid var(--jo-white);
  border-radius:50%;
  width:190px;
  height:190px;
  display:flex;
  align-items:center;
  justify-content:center;
  text-align:center;
  font-family:var(--font-mono);
  font-size:13px;
  transition:letter-spacing .2s, transform .25s;
}
.jo-circle-cta:hover{
  letter-spacing:3px;
  transform:scale(1.06) rotate(-4deg);
}
```

### View Dot / Cursor Badge
```css
.jo-view-dot{
  width:100px;
  height:100px;
  border-radius:50%;
  background:var(--jo-black);
  color:var(--jo-white);
  display:flex;
  align-items:center;
  justify-content:center;
  font-family:var(--font-mono);
  font-size:11px;
  letter-spacing:.08em;
  text-transform:uppercase;
  opacity:0;
  transform:scale(.8);
  transition:opacity .25s, transform .25s;
}
.jo-card:hover .jo-view-dot{
  opacity:1;
  transform:scale(1);
}
```

### 使用規則
- Jomor mode 優先用 **黑底、白字、skew reveal、stroke text**；比 Okalpha 更暗、更 edgy。
- 每個場景可使用一個斜切 media block 或一個圓形 CTA，避免像 dashboard。
- 適合：品牌故事、設計/創意型產品、landing page teaser、年輕化 proposal。
- 如果內容是政府/企業方案，要保留可信任數據，但用更大、更少的文字呈現。

---

## Apple Product Launch Motion Pack（參考 apple.com/iphone-17-pro）

當用戶要求「參考 Apple」、「像 iPhone product page」、「高級產品發布」、「cinematic scroll」、「premium glass / metal」時，採用此風格包。**不要複製 Apple 原始素材、圖片或網站代碼，只複製動效語言與設計方向。**

### 風格語言
- **克制、高級、電影感**：少元素、超大產品主視覺、深色背景、柔和聚光。
- **大留白 + 精準文案**：一句主標 + 一句 supporting copy，不做密集卡片。
- **Product hero reveal**：產品 mockup 從暗部慢慢浮現，搭配 scale / blur / opacity。
- **Sticky chapter feeling**：每一屏像 scroll-sticky section，畫面停住但文案逐步切換。
- **Glass / metal 材質**：深色玻璃、鈦金/鋁金屬邊框、柔和 highlight rim light。
- **Feature highlight carousel**：一屏一個 feature：Design / Chip / Camera / OS / Intelligence。
- **Spec callouts**：用極簡數據 callout，例如 `60%`、`262.5h`、`12–18 months`，配細線和小標。
- **Cinematic timing**：慢進慢出，`cubic-bezier(.28,.11,.32,1)`，不要快速彈跳。

### Apple-like Palette Tokens
```css
--ap-bg:#000;
--ap-panel:#121214;
--ap-text:#f5f5f7;
--ap-muted:#86868b;
--ap-blue:#2997ff;
--ap-orange:#f77e2d;
--ap-silver:#e8e8ed;
--ap-line:rgba(255,255,255,.16);
--ap-glow:rgba(247,126,45,.28);
```

### Product Hero Mockup
```css
.ap-hero-product{
  position:relative;
  width:min(52vw,520px);
  aspect-ratio:9/18;
  border-radius:42px;
  background:linear-gradient(145deg,#2f2f32,#0b0b0c);
  border:2px solid rgba(255,255,255,.18);
  box-shadow:
    inset 0 0 0 1px rgba(255,255,255,.08),
    0 40px 120px rgba(0,0,0,.75),
    0 0 80px var(--ap-glow);
  transform:translateY(40px) scale(.92);
  filter:blur(8px);
  opacity:0;
  transition:opacity 1s cubic-bezier(.28,.11,.32,1), transform 1.2s cubic-bezier(.28,.11,.32,1), filter 1s;
}
.scene[data-visible] .ap-hero-product{
  opacity:1;
  transform:translateY(0) scale(1);
  filter:blur(0);
}
.ap-hero-product::before{
  content:'';
  position:absolute;
  inset:16px;
  border-radius:32px;
  background:radial-gradient(circle at 70% 10%,rgba(255,255,255,.22),transparent 30%),linear-gradient(180deg,#18181a,#050505);
}
```

### Cinematic Headline
```css
.ap-headline{
  color:var(--ap-text);
  font-size:clamp(48px,8vw,128px);
  font-weight:700;
  letter-spacing:-.06em;
  line-height:.95;
  opacity:0;
  transform:translateY(36px);
  transition:opacity .9s cubic-bezier(.28,.11,.32,1), transform 1s cubic-bezier(.28,.11,.32,1);
}
.scene[data-visible] .ap-headline{
  opacity:1;
  transform:translateY(0);
}
.ap-copy{
  color:var(--ap-muted);
  font-size:clamp(18px,2.2vw,30px);
  line-height:1.35;
  max-width:720px;
}
```

### Feature Glass Card
```css
.ap-feature-card{
  background:linear-gradient(180deg,rgba(255,255,255,.08),rgba(255,255,255,.03));
  border:1px solid var(--ap-line);
  border-radius:28px;
  padding:32px;
  backdrop-filter:blur(24px);
  box-shadow:0 24px 80px rgba(0,0,0,.45);
}
.ap-feature-kicker{
  color:var(--ap-orange);
  font-family:var(--font-mono);
  font-size:12px;
  letter-spacing:.18em;
  text-transform:uppercase;
}
.ap-feature-title{
  color:var(--ap-text);
  font-size:clamp(32px,5vw,72px);
  letter-spacing:-.04em;
  line-height:1;
}
```

### Spec Callout Line
```css
.ap-callout{
  display:flex;
  align-items:center;
  gap:14px;
  color:var(--ap-text);
}
.ap-callout::before{
  content:'';
  width:64px;
  height:1px;
  background:var(--ap-line);
}
.ap-callout-number{
  font-size:clamp(42px,6vw,88px);
  font-weight:700;
  letter-spacing:-.05em;
  color:var(--ap-orange);
}
.ap-callout-label{
  color:var(--ap-muted);
  font-size:14px;
  line-height:1.4;
}
```

### Titanium / Metal Ring
```css
.ap-metal-ring{
  width:min(46vw,420px);
  aspect-ratio:1;
  border-radius:50%;
  border:2px solid rgba(255,255,255,.16);
  background:
    radial-gradient(circle at 50% 50%,transparent 42%,rgba(255,255,255,.08) 43%,transparent 48%),
    conic-gradient(from 120deg,#272729,#f77e2d,#e8e8ed,#2b3145,#272729);
  filter:drop-shadow(0 40px 90px rgba(0,0,0,.65));
  animation:apRing 16s linear infinite;
}
@keyframes apRing{to{transform:rotate(360deg)}}
```

### 使用規則
- Apple mode 不要用厚黑邊卡片、過度彈跳、太多 emoji；改用高級 mockup、glass card、callout line。
- 每個場景只講一個 feature，文案短而有力度。
- 適合企業產品時，可把產品比作「Pro workflow」：Design / Intelligence / Performance / Security / Ecosystem。
- 色彩可根據 TerraMind 使用 `ap-orange` 作 signature accent，呼應 iPhone 17 Pro 宇宙橙。

---

## SaaS Product Ad Motion Pack（參考 YouTube: Community Analytics Software Ad）

當用戶提供 SaaS / AI product ad video 參考，或要求「像產品廣告」、「AI SaaS explainer」、「floating UI cards」、「soft pastel dashboard」時，採用此風格包。參考影片例：`https://www.youtube.com/watch?v=fjWf0qUagtk`。**不要複製原影片素材，只複製動效語言與產品廣告節奏。**

### 風格語言
- **Soft pastel gradient background**：mint / cyan / peach 大型模糊 blobs，慢速漂移。
- **Floating SaaS UI card**：白色 rounded card，柔和陰影，像 dashboard / feedback result panel。
- **Input + CTA interaction**：上方 pill input + coral CTA button，加入 typing / click / generated-result 節奏。
- **Sequential content generation**：卡片內文字、placeholder lines、section headings 逐段 draw-in。
- **Floating category tags**：例如 Character / Story / Sentiment / Trend，從左右滑入並微浮動。
- **Clean product ad pacing**：每 2–3 秒完成一個微互動，不要太多 3D 旋轉。
- **Friendly AI product feel**：低壓、高信任、清爽、清晰；適合 SaaS demo / AI analytics / feedback tool。

### SaaS Ad Palette Tokens
```css
--saas-mint:#BEEFEA;
--saas-cyan:#D8F5F2;
--saas-peach:#F6B8A8;
--saas-bg:#EEF1F0;
--saas-card:#FFFFFF;
--saas-coral:#F07A5F;
--saas-teal:#39BFB7;
--saas-text:#222222;
--saas-line:#DADADA;
--saas-shadow:0 18px 48px rgba(30,50,70,.16);
```

### Pastel Blob Background
```css
.saas-bg{
  position:absolute;
  inset:0;
  background:var(--saas-bg);
  overflow:hidden;
}
.saas-blob{
  position:absolute;
  width:520px;
  height:520px;
  border-radius:50%;
  filter:blur(70px);
  opacity:.75;
  animation:saasBlob 9s ease-in-out infinite alternate;
}
.saas-blob.mint{background:var(--saas-mint);left:-120px;bottom:-100px;}
.saas-blob.peach{background:var(--saas-peach);right:-120px;top:-80px;animation-delay:-3s;}
.saas-blob.cyan{background:var(--saas-cyan);left:35%;top:20%;animation-delay:-6s;}
@keyframes saasBlob{
  from{transform:translate3d(0,0,0) scale(1)}
  to{transform:translate3d(40px,-30px,0) scale(1.08)}
}
```

### Input + CTA Row
```css
.saas-input-row{
  display:flex;
  align-items:center;
  gap:12px;
  justify-content:center;
  opacity:0;
  transform:translateY(20px);
  transition:opacity .55s ease, transform .55s cubic-bezier(.22,1,.36,1);
}
.scene[data-visible] .saas-input-row{opacity:1;transform:translateY(0)}
.saas-input{
  min-width:260px;
  padding:15px 20px;
  border-radius:999px;
  background:#fff;
  color:var(--saas-text);
  box-shadow:0 10px 28px rgba(30,50,70,.12);
  font-size:15px;
}
.saas-button{
  padding:15px 22px;
  border-radius:999px;
  background:var(--saas-coral);
  color:#fff;
  box-shadow:0 10px 28px rgba(240,122,95,.28);
  animation:saasButtonClick 4s ease-in-out infinite;
}
@keyframes saasButtonClick{0%,70%,100%{transform:scale(1)}75%{transform:scale(.96)}80%{transform:scale(1)}}
```

### Generated Feedback Card
```css
.saas-card{
  width:min(620px,86vw);
  background:var(--saas-card);
  border-radius:22px;
  padding:28px;
  box-shadow:var(--saas-shadow);
  opacity:0;
  transform:translateY(30px) scale(.96);
  transition:opacity .65s ease .25s, transform .75s cubic-bezier(.22,1,.36,1) .25s;
}
.scene[data-visible] .saas-card{opacity:1;transform:translateY(0) scale(1)}
.saas-section{margin-bottom:18px;}
.saas-section-title{font-weight:700;color:var(--saas-text);font-size:14px;margin-bottom:10px;}
.saas-line{
  height:9px;
  border-radius:999px;
  background:var(--saas-line);
  margin:8px 0;
  width:0;
  animation:saasLineDraw .75s cubic-bezier(.22,1,.36,1) forwards;
}
.saas-line:nth-child(2){animation-delay:.5s;width:92%;}
.saas-line:nth-child(3){animation-delay:.7s;width:76%;}
.saas-line:nth-child(4){animation-delay:.9s;width:64%;}
@keyframes saasLineDraw{from{width:0;opacity:0}to{opacity:1}}
```

### Floating Tags
```css
.saas-tag{
  position:absolute;
  padding:12px 20px;
  border-radius:999px;
  color:#fff;
  font-weight:700;
  box-shadow:0 12px 28px rgba(30,50,70,.18);
  opacity:0;
  transform:translateY(20px);
  transition:opacity .55s ease .55s, transform .65s cubic-bezier(.22,1,.36,1) .55s;
  animation:saasTagFloat 3.2s ease-in-out infinite alternate;
}
.saas-tag.coral{background:var(--saas-coral);left:-30px;top:45%;}
.saas-tag.teal{background:var(--saas-teal);right:-24px;top:32%;animation-delay:-1.2s;}
.scene[data-visible] .saas-tag{opacity:1;transform:translateY(0)}
@keyframes saasTagFloat{from{translate:0 0}to{translate:0 -8px}}
```

### 使用規則
- 這個 mode 適合 AI SaaS / analytics / feedback / dashboard / marketing video。
- 每場景用「一個 UI micro-interaction」講一個功能：input → analyze → categorize → insights → report。
- 轉場應柔和：fade + rise + scale，不要 Okalpha 厚重撞色，也不要 Jomor 黑底 skew。
- 如果生成 TerraMind，可轉成：收件輸入 → AI 摘要 → SLA tags → 部門流轉 → 回覆生成 → 效益報告。

---

## 場景建構規則（升級版）

每個場景 **必須** 包含以下四個元素：

| 元素 | 規則 |
|------|------|
| **`.subtitle`** | 一行小標籤，mono 字體，teal 色 |
| **`.title`** | 主標題，含一個 `.hl` span 為 teal |
| **視覺组件** | 從上面的 Visual Component Library 選擇，**至少 1 個**，不可只有文字 |
| **`.note`** | 說明文字，muted 色，最大 640px |

**data-at 分配參考：**
- `data-at="1"` → subtitle（第 1 秒浮入）
- `data-at="2"` → title（第 2 秒浮入）
- `data-at="3"` → 視覺组件（第 3 秒浮入）
- `data-at="5"` → note（第 5 秒浮入）

---

## 可用的 3D 技法詞彙（擴充版）

| 技法 | 適用場景 | 視覺特性 |
|------|---------|---------|
| Rotating Cube | 概念介紹、產品功能 | 6 面立體方塊持續旋轉 |
| Flip Card | 前後對比、雙面資訊 | 定時翻轉動畫 |
| Floating Phone Mockup | 產品展示、mobile UI | 漂浮搖擺手機 |
| Spotlight Grid | 功能列表、數據展示 | 2×2 卡片网格 |
| Node Network | 架構圖、系統流程 | 中心節點 + 衛星節點 |
| Architecture Layers | 技術架構、平台層次 | 堆疊的彩色層 |
| Process Steps | 流程、路線圖 | 時間軸式步驟列 |
| Stat Cards | 數據報告、效益量化 | 數字 + 標籤卡片 |
| Compare Panels | Before/After、效果對比 | 左右雙面板 |
| Tilted Cards | 列表、特性展示 | 3D傾斜卡片組 |
| Orbiting Ring | 生態系統、網絡概念 | 環形軌道上的節點 |
| 3D Text Extrusion | 標題、關鍵數字 | 多層陰影擠出文字 |

---

## 字幕規則

- 每個場景 2–4 條字幕
- 風格：短、尖銳、一行一個概念
- 如要雙語，維持一致

---

## 輸出格式

直接輸出完整 HTML 文件，雙擊可運行。

---

## 使用方式（Prompt Template）

當用戶提供 topic 和 content 時，將以下結構填入並生成：

```markdown
## Topic / One-Line Pitch

[用一句話描述主題]

## Total Target Duration

[總秒數，如 180]

## Caption Language

[如：繁體中文 / 雙語]

## Scenes

### Scene 1 — [場景標題]

**Point:** [要傳達的核心概念]

**Visual Component:** [從 Component Library 選擇，如：Stat Cards / Architecture Layers / Process Steps / Spotlight Grid]

**Required on-screen elements:**
- [必須出現的視覺元素 + 數據]

### Scene 2 — [場景標題]
...

## Optional Palette/Font Overrides

[如無則填：None]
```

---

## 外部網站風格參考萃取 Workflow

當用戶提供一個網站 URL 並說「參考這個動畫/風格可以嗎」時，使用以下流程，把網站轉化成可重用的 style pack：

1. **先嘗試瀏覽器視覺檢查**
   - 用 browser 打開網站，觀察 hero、scroll、hover、transition、色彩、字體、布局。
   - 如果 browser 在 container 因 sandbox 問題打不開，不要卡住，改用 HTML/CSS 抽取。

2. **HTML/CSS 抽取分析**
   - 用 `requests` 下載 HTML。
   - 從 `<link href="...css">` 抓主要 CSS。
   - 抽取：
     - CSS variables / hex colors。
     - 含 `transform` / `transition` / `animation` / `perspective` / `clip-path` / `filter` / `mix-blend` 的 selector。
     - 頁面文字節奏與文案風格。
     - img/video/source assets 類型，但不要複製素材。

3. **歸納為動效語言，不複製原站代碼**
   - 只保存可泛化的 design language：palette、typography、motion primitives、layout pattern、interaction feel。
   - 避免直接使用對方圖片、影片、品牌文案、原始 Webflow animation data。

4. **寫入 Style Pack**
   - 加入：風格語言、palette tokens、3–6 個 reusable CSS components、使用規則。
   - 命名格式：`[SiteName]-inspired Motion Pack（參考 domain）`。
   - 明確註記：不要複製原始素材或網站代碼，只複製動效語言與設計方向。
   - 同時標明對應的 motion personality（例如 Apple=Premium、Okalpha/Jomor=Energetic、SaaS Ad=Corporate/Playful）。

5. **生成測試動畫並 QA**
   - David 通常在你問「要不要做一版？」後用「好 / yes」確認；收到這種確認時，直接生成對應 style 的 TerraMind/當前主題動畫，不要再追問。
   - 對同一產品做一版短動畫測試，確認 style pack 實際可用。
   - QA 檢查應包含：scene div count、最後 scene 存在、palette tokens、style-specific visual classes、controls、keyboard/touch nav、prefers-reduced-motion、file size。

---

## YouTube 影片風格參考萃取 Workflow

當用戶提供 YouTube URL 並問「可以做到這個影片效果嗎」時，按以下流程處理：

1. **先嘗試完整影片分析**
   - 用 `yt-dlp --dump-json` 取得 title、duration、channel、description、thumbnail。
   - 如可下載，用 ffmpeg 每 2–5 秒抽 keyframes，再用 vision 分析畫面節奏、色彩、轉場、UI 元件、鏡頭語言。
   - 如有字幕，用 youtube transcript 工具取得 transcript，理解敘事結構。

2. **YouTube bot check / cloud IP blocked fallback**
   - 若 `yt-dlp` 回傳 `Sign in to confirm you’re not a bot`，或 transcript API 回傳 `RequestBlocked`，不要卡住。
   - 改用 YouTube oEmbed / noembed 取得 title、channel、thumbnail：
     - `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=VIDEO_ID&format=json`
     - `https://noembed.com/embed?url=https://www.youtube.com/watch?v=VIDEO_ID`
   - 對 `thumbnail_url` 使用 vision 分析，萃取可見的視覺語言。
   - 明確告知：目前只能根據 metadata + thumbnail 做 70–90% 風格估算；如果用戶上傳 mp4，可做更準。

3. **從影片/縮圖提煉 Motion Pack**
   - 保存可泛化元素：背景、palette、UI 結構、轉場節奏、微互動、敘事 flow。
   - 不複製原影片素材，不假裝看過完整影片。
   - 若只看過 thumbnail，style pack 名稱應避免過度具體，例如 `SaaS Product Ad Motion Pack`，並記錄參考 YouTube URL。

4. **適合 SaaS/AI product ad 的生成節奏**
   - 使用「問題 → 輸入 → AI 分析 → tags/categorization → generated results → impact」流程。
   - 每場景呈現一個 UI micro-interaction：typing、button click、card appears、line draw-in、floating tags、report reveal。

---

## 實戰產出經驗（David animation preferences）

以下經驗來自 TerraMind Inbox 多輪動畫迭代，後續生成時要優先套用：

### 1. 不要只輸出文字
- David 明確偏好「看起來好不好看」和「有視覺衝擊力」。
- 每個場景必須有 cards / modal / grid / 3D object / large shape / orbit / timeline 其中之一。
- 純 `.subtitle + .title + .note` 不合格，即使文字內容正確也不應交付。

### 2. 3D 動感要主動加強
當用戶說「多一點 3D」、「動感多一點」時，優先採用這些組合：
- Helix / orbit ring：封面或 AI orchestration。
- Card deck：痛點與功能列表。
- 3D tilted architecture stack：平台架構。
- Parallax depth layers：文件 → AI → 回覆流程。
- Tilted stats wall：效益數據。
- Z-axis step arc：roadmap / implementation plan。
- Flip stack + phone 3D：CTA / product showcase。
- Direction-aware scene exit：next = slide/rotate right, prev = slide/rotate left。

### 3. Okalpha-inspired mode 的成功配方
Okalpha-style 不應做成密集 dashboard。它應該像 motion studio teaser：
- 9 scenes / 約 90 秒是合適節奏。
- 每個 scene 以一個超大標題 + 一個主視覺為主。
- 使用紅/藍/黃/黑/白強色塊，不用太多柔和玻璃擬態。
- 使用 2.5D thick shadow：`box-shadow: 1px 1px ... 7px 7px 0`。
- 使用 oversized pill/circle background 漂移製造畫面張力。
- 使用 project reveal panel 表現產品流程，像作品集案例展示。

### 4. QA 檢查注意事項
- 檢查 scene 數量時，不要用 `html.match(/data-scene=/g)`，因為 JS selector 也會包含 `data-scene`，會誤判。
- 應使用較精確 regex：`/<div class="scene" data-scene="\\d+"/g`。
- QA 最低檢查項：scene div count、最後一個 scene 存在、palette tokens、核心 visual classes、controls、keyboard/touch nav、prefers-reduced-motion、file size。

---

## 驗收標準

- [ ] 雙擊 .html 文件可直接運行（無需 server）
- [ ] **每個場景至少包含 1 個視覺组件**（不能只有純文字）
- [ ] Play/Pause/Prev/Next 正常運作
- [ ] 進度條可點擊 seek
- [ ] 章節點點擊可跳轉
- [ ] `prefers-reduced-motion` 媒體查詢存在且有效
- [ ] 所有 3D 動畫使用純 CSS transforms，無 library
- [ ] Google Fonts 載入成功
- [ ] 無 console error