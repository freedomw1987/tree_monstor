# DESIGN.md (master) — Template

> **When to use:** Plan 階段（有 UI 的 project）。
> **No-code rule:** 不適用於本檔（tokens + index tables）。Per-component 跟 per-page 檔才套 no-code rule。
> **配套：** per-component 見 `component-contract-template.md`；per-page 見 `page-template.md`。

## 結構

```
docs/
├── DESIGN.md                  ← master: tokens + component/page index
├── components/
│   ├── Button.md              ← per-component contract（props / events / a11y / states）
│   ├── Input.md
│   └── ...
└── pages/
    ├── Login.md               ← per-page: wireframe + interaction spec
    └── ...
```

## 必填區塊

```markdown
# Design Spec — <Project Name>

> **Status:** Living document. Tokens here are single source of truth; per-component specs live in components/, per-page specs in pages/.

## Overview
- 設計理念、品牌定位
- 目標用戶畫像
- 設計參考（inspiration links）

## Design Tokens

### Colors
| Token | HEX | 用途 |
|-------|-----|------|
| --color-primary | #FF6B35 | CTA, 強調 |
| --color-bg | #FFFFFF | 背景 |
| ... | ... | ... |

### Typography
| Token | Font | Size / Line-height | Weight | 用途 |
|-------|------|-------------------|--------|------|
| --text-h1 | Inter | 32/40 | 700 | 頁面標題 |
| --text-body | Inter | 16/24 | 400 | 內文 |
| ... | ... | ... | ... | ... |

### Spacing
- 4px grid system; --space-1: 4px, --space-2: 8px, --space-3: 16px, --space-4: 24px, --space-5: 32px

### Elevation
| Token | 用途 |
|-------|------|
| --elevation-1 | Card |
| --elevation-2 | Modal |
| ... | ... |

### Shapes
- Border radius: 4px (small), 8px (medium), 16px (large)

## Component Index

| Component | 規格 | 對應 US |
|-----------|------|---------|
| Button | [components/Button.md](components/Button.md) | US-001, US-007 |
| Input | [components/Input.md](components/Input.md) | US-001, US-002 |
| ... | ... | ... |

## Page Index

| Page | 規格 | 對應 US |
|------|------|---------|
| Login | [pages/Login.md](pages/Login.md) | US-001 |
| Dashboard | [pages/Dashboard.md](pages/Dashboard.md) | US-007 |
| ... | ... | ... |

## Do's and Don'ts
- ✅ Do: 文字按鈕至少 44x44px
- ❌ Don't: 顏色用純黑/純白(用 neutral 9 / neutral 1)

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
```

## 更新時機
- 加新 component → 加 `components/<Name>.md` + 更新 master index
- 加新 page → 加 `pages/<page>.md` + 更新 master index
- 改 token 值 → DESIGN.md + 全文搜尋影響範圍（影響所有 component/page specs）
- 設計大改 → 升 version (`v1.0` → `v2.0`),保留舊版