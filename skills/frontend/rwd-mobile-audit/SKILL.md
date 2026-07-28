---
name: rwd-mobile-audit
description: Audit and fix a web app for mobile RWD (responsive web design) using Playwright at iPhone viewport (390x844). Use when user says 'RWD', '手機兼容', 'mobile compatible', '手機睇', 'responsive', or when delivering a web app and you need to verify it works on small screens before declaring done.
tags: ["rwd", "mobile", "responsive", "playwright", "qa", "frontend"]
---


Last-verified: 2026-07-28
# RWD Mobile Audit Workflow

完整嘅 RWD audit + 修復 workflow。用 Playwright 設 iPhone 14 viewport (390x844) 自動截圖 + overflow 偵測，再用 vision model 視覺檢查。

## 觸發時機

- 交付任何 web app 前最後一步 QA
- 用戶提到「手機」、「mobile」、「RWD」、「響應式」
- 用戶主動要求做 mobile compat

## Step 1: 確認 Playwright Python 可用

```bash
# 確認 pip 喺 system python (唔係 hermes sandbox)
/usr/local/bin/python3 -c "import playwright"
```

如果 missing：
```bash
/usr/local/bin/python3 -m pip install playwright --quiet
/usr/local/bin/python3 -m playwright install chromium  # ~78MB
```

> ⚠️ **Hermes sandbox python 唔同 system python** — `execute_code` 嘅 sub-shell 用 `/usr/local/bin/python3`，但 `which python3` 可能係另一個。用絕對路徑。

> ⚠️ **不要用 Node Playwright** — 喺 Hermes `execute_code` 環境入面，npx 撞 playwright 嘅 post-install message 會 fail。

## Step 2: 寫 audit script (去 `/tmp/`，唔好擺去專案)

```python
# /tmp/rwd_audit_mobile.py
import asyncio, os
from playwright.async_api import async_playwright

OUT = "/tmp/rwd_audit"
os.makedirs(OUT, exist_ok=True)

# 跟住實際 URL 改
PAGES = [
    ("home", "http://localhost:5173/"),
    ("exam", "http://localhost:5173/exam/dummy"),
    ("review", "http://localhost:5173/review/dummy"),
    ("stats", "http://localhost:5173/stats"),
]

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        ctx = await browser.new_context(
            viewport={"width": 390, "height": 844},  # iPhone 14
            device_scale_factor=2,
            is_mobile=True,
            has_touch=True,
        )
        page = await ctx.new_page()
        for name, url in PAGES:
            try:
                await page.goto(url, wait_until="networkidle", timeout=10000)
                await page.wait_for_timeout(500)
                await page.screenshot(path=f"{OUT}/{name}.png", full_page=True)
                body_width = await page.evaluate("document.body.scrollWidth")
                overflow = body_width > 390
                print(f"  {name}: body_width={body_width}px, overflow={overflow}")
            except Exception as e:
                print(f"  {name}: ERROR {e}")
        await browser.close()

asyncio.run(main())
```

執行：
```bash
/usr/local/bin/python3 /tmp/rwd_audit_mobile.py
```

## Step 3: 分析結果

**正面信號**：
- `body_width == viewport_width` (390px) → 冇 horizontal overflow

**負面信號**：
- `body_width > 390` → 有 element 撐爆 viewport
- Vision 檢查發現：navbar 文字 cut、grid 太擠、padding 不足、touch target 太細

## Step 4: Common fixes (按 Tailwind v4 慣用)

| 問題 | Fix pattern |
|---|---|
| 固定 grid 3 col 太擠 | `grid-cols-1 sm:grid-cols-3` |
| 桌面 nav 文字太長 | `<span className="sm:hidden">{short}</span><span className="hidden sm:inline">{full}</span>` |
| 大 padding 浪費 mobile 空間 | `p-4 sm:p-6` |
| 桌面 fontSize 太大 | `text-base sm:text-lg` |
| 卡片數值字體細 | `text-2xl sm:text-3xl` |
| 5 個 flex 掉去第 2 行 (OK 但視覺差) | `grid-cols-3 sm:flex sm:flex-wrap` |
| 缺 touch feedback | 加 `active:scale-[0.98]` |
| 大 card list 太長 | `.slice(0, 5)` + 顯示「睇更多」 |
| Score 數字 + label 撞行 | `flex items-baseline gap-2 flex-wrap` |

**核心理念**：mobile-first，desktop 加強，永遠唔好 1 個 breakpoint 用晒。

## Step 5: 視覺驗收

每改一輪，re-run script，然後用 `vision_analyze` 睇實際截圖：

```
vision_analyze(
  image_url="/tmp/rwd_audit/home.png",
  question="呢個係 390px wide 嘅 mobile 截圖，睇下 layout..."
)
```

## 已知陷阱

1. **exec_code sub-shell 死 long-lived process** — 千祈唔好用 `execute_code` 開 `npm run dev`，用 `terminal(background=true)`。
2. **Tailwind v4 `@theme`** — v4 唔再用 `tailwind.config.js`，custom color 要喺 CSS `@theme { --color-brand-500: ... }`。
3. **flex-wrap 加 grid-cols** 容易爆 — 要 `min-width: 0` 或者 `truncate` 喺 text node 上面。
4. **safe-area** (iPhone notch) — mobile-first app 最好加 `pb-safe` 或者 `env(safe-area-inset-bottom)`。
5. **Dont use `px-6`** 喺 mobile — `px-4` 就夠，慳 16px 兩邊。
6. **`fullPage: true` 對無限 scroll / 大量 list render 嘅 page 會爆 100k px tall screenshot** (撞過 2026-06-10 pm-system Dashboard: 196 個項目 card render 晒 → screenshot 91834px tall，PIL 都開唔到，verify 流程完全冇 feedback)。**Root cause**:`fullPage: true` 會 capture 整個 `scrollHeight`，**唔係 viewport**。**Fix**:
   - **方案 A (推薦,源頭修)**:Page 本身要 `pagination` / `slice(0, N)` — 即係根本唔應該有「無限 render」嘅 page。參考 `pagination-with-preserved-aggregates` skill 嘅「`limit: -1` 唔好用喺 dashboard」 pitfall
   - **方案 B (quick audit)**:Audit script 改用 `page.screenshot({ path, fullPage: false, clip: { x: 0, y: 0, width: 390, height: 844 * 4 } })` — clip 限死範圍(e.g. 4 個 viewport height)，避免無限長
   - **方案 C (預 check)**:用 `await page.evaluate('document.body.scrollHeight')` 預先 check，**>10000px 就 abort + flag** + 提示需要先 fix page:
     ```js
     const scrollH = await page.evaluate('document.body.scrollHeight')
     if (scrollH > 8000) {
       console.log(`  ${name}: WARN scrollHeight=${scrollH}px — page 可能有 list render 太多，audit screenshot 會爆`)
       continue
     }
     ```
7. **SPA page 嘅 RWD audit 一定要先 auth** — 否則 render 嘅係 login page / blank / redirect。**Node Playwright 嘅正確順序**:
   - 1) `await page.goto('http://localhost:8080/login')` — 去 login page 攞 token
   - 2) `const loginResult = await page.evaluate(async () => { const res = await fetch('http://localhost:4001/auth/login', {...}); return await res.json() })` — **唔好用 template literal** 寫 `evaluate` body (見 pitfall 8)
   - 3) `await page.evaluate((t) => { localStorage.setItem('accessToken', t); localStorage.setItem('user', JSON.stringify({...})) }, loginResult.accessToken)`
   - 4) **之後**先 `await page.goto(targetUrl)` — target page 嘅 AuthContext 攞到 localStorage 嘅 user 就有 state
   - **Common mistake**:Step 3 之前已經 `page.goto(targetUrl)` → target 嘅 AuthContext check localStorage 仲未 set → render 個 login / blank → screenshot 完全冇用
8. **Node Playwright 嘅 `page.evaluate` ESM serialization trick** — 用 `await page.evaluate(async () => {...})` 而非 `` await page.evaluate(`async () => {}`) `` template literal。Hermes sandbox 嘅 template literal 喺 ESM mode (`file://...mjs`) 有時候 `evaluate` return undefined (具體證據: 2026-06-10 rwd-audit-s14.mjs 用 template literal 版 `evaluate`，返 undefined → login result 冇 `accessToken` field → audit script crash)。改用函數 literal 即 fix。

## 驗證完成嘅 checklist

- [ ] 4 個 page 都 `body_width == 390`
- [ ] 視覺檢查 Nav/Button/Text 都唔 cut
- [ ] Touch target ≥ 44x44px (Apple HIG)
- [ ] 唔好出現 horizontal scrollbar
- [ ] 主要 CTA 喺 mobile 唔好太細
- [ ] 重 run 多次 confirm fix 唔 regression

## 支援檔案

- `templates/rwd_audit_mobile.py` — Playwright iPhone 14 viewport audit script (copy + 改 PAGES list 即用)
