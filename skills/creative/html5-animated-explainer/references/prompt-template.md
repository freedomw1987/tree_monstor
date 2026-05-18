# HTML5 Animated Visual Explainer — Prompt Template

在生成動畫前，先填寫以下 template，再交給 AI 生成完整 HTML 文件。

---

## Template

```markdown
## Topic / One-Line Pitch

[用一句話描述這個動畫要傳達的主題]

## Total Target Duration

[總秒數，如 180]

## Caption Language

[繁體中文 / 英文 / 雙語（繁體中文 + 英文）]

## Scenes

### Scene 1 — [場景標題]

**Point:**  
[這個場景要傳達的核心概念，一句話]

**Required on-screen text / labels / data:**  
- [元素 1]
- [元素 2]
- [元素 3]

**3D Technique:**  
[從以下選擇：Flip Card / Rotating Cube / Parallax Stacked Layers / Carousel Ring / Floating Phone Mockup / 3D Extruded Text / Tilted Browser Mockup / Z-Axis Arc of Steps / 3D Conversation Bubbles / Pop-out Spotlight Grid / Before/After Tilted Panels / Orbiting Concept Network]

---

### Scene 2 — [場景標題]

**Point:**  
[核心概念]

**Required on-screen text / labels / data:**  
- ...

**3D Technique:**  
[選擇技法]

---

（繼續添加更多場景...）

## Optional Palette / Font Overrides

[如無則填：None]
[如有：說明需要的顏色或字體變更]

## Special Instructions

[任何特殊要求，如：需要特定動畫風格、特定元素必須出現等]
```

---

## Example（完整填寫範例）

```markdown
## Topic / One-Line Pitch

AI 是如何學會畫畫的？— 從噪點到藝術的旅程

## Total Target Duration

120 秒（6 個場景，每場約 20 秒）

## Caption Language

繁體中文

## Scenes

### Scene 1 — 一切從噪點開始

**Point:**  
原始 AI 生成圖片就是一片雜訊雪花

**Required on-screen text / labels / data:**  
- 小標籤：NOISE
- 標題：隨機噪點
- 視覺：一個充滿動態噪點的立方體面
- 說明：一切的起點

**3D Technique:**  
Rotating Cube（讓噪點立方體緩慢旋轉）

---

### Scene 2 — 學習輪廓

**Point:**  
AI 首先學會辨識基本的形狀和邊界

**Required on-screen text / labels / data:**  
- 小標籤：EDGE DETECTION
- 標題：看見邊界
- 視覺：Parallax 疊加的輪廓線
- 說明：輪廓 = 形狀的第一步

**3D Technique:**  
Parallax Stacked Layers

---

### Scene 3 — 加入風格

**Point:**  
AI 學會了不同的藝術風格

**Required on-screen text / labels / data:**  
- 小標籤：STYLE TRANSFER
- 標題：風格迁移
- 視覺：動態切換的風格展示（素描、水彩、油畫）
- 說明：一個模型，多種風格

**3D Technique:**  
Flip Card（卡片翻面切換不同風格）

---

### Scene 4 — 從草稿到精細

**Point:**  
AI 從粗略輪廓逐步精化到精細圖像

**Required on-screen text / labels / data:**  
- 小標籤：PROGRESSIVE REFINEMENT
- 標題：逐步精化
- 視覺：Z 軸台階，每層代表一個迭代階段
- 說明：從模糊到清晰

**3D Technique:**  
Z-Axis Arc of Steps

---

### Scene 5 — 理解概念

**Point:**  
AI 不只是複制，而是理解高層概念

**Required on-screen text / labels / data:**  
- 小標籤：CONCEPTUAL
- 標題：理解高層概念
- 視覺：Orbiting Concept Network，每個節點是一個概念（猫、藝術、日落）
- 說明：概念而非像素

**3D Technique:**  
Orbiting Concept Network

---

### Scene 6 — 你現在可以創造了

**Point:**  
說服觀眾立即使用 AI 圖像生成工具

**Required on-screen text / labels / data:**  
- 小標籤：YOUR TURN
- 標題：開始創作
- 視覺：Floating Phone Mockup，螢幕顯示「Type your idea...」
- 說明：雙擊運行，開始你的創作

**3D Technique:**  
Floating Phone Mockup

## Optional Palette / Font Overrides

None（使用預設設計 token）

## Special Instructions

- 動畫節奏輕快活潑
- 每個場景的 particles 數量可以增加
- 最後一個場景要有 CTA 感覺
```

---

## 使用流程

1. 複製以上 template
2. 填入你的內容（topic、每個場景的 point + 必要元素 + 技法）
3. 交給 AI（可以加上：「用 html5-animated-explainer skill 生成」）
4. AI 會輸出完整的 `.html` 文件
5. 雙擊運行，確認沒問題後交付