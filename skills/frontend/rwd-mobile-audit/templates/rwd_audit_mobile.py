#!/usr/bin/env python3
"""RWD audit: take screenshots of all pages at iPhone 14 viewport (390x844).

Updated 2026-06-10:
- scrollHeight pre-check (>8000px 跳過 + 提示)— 避免 fullPage screenshot 爆 100k px
- WARN list size 上限提示用戶 fix page 而非 audit tool
"""
import asyncio
from playwright.async_api import async_playwright
import os

OUT = "/tmp/rwd_audit"
os.makedirs(OUT, exist_ok=True)
MAX_SCROLL_HEIGHT = 8000  # 8k px ≈ 9 個 viewport。超過 = page 可能有「無限 render」list, 應該先 fix page

# ====== 改呢度 ======
PAGES = [
    ("home", "http://localhost:5173/"),
    ("exam", "http://localhost:5173/exam/dummy"),
    ("review", "http://localhost:5173/review/dummy"),
    ("stats", "http://localhost:5173/stats"),
]
# ====================

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        ctx = await browser.new_context(
            viewport={"width": 390, "height": 844},
            device_scale_factor=2,
            is_mobile=True,
            has_touch=True,
        )
        page = await ctx.new_page()
        for name, url in PAGES:
            try:
                await page.goto(url, wait_until="networkidle", timeout=10000)
                await page.wait_for_timeout(500)
                # Pre-check: scrollHeight 太長就 warn + skip screenshot (避免 PIL 開唔到 + 失去 verify 訊號)
                scroll_h = await page.evaluate("document.body.scrollHeight")
                if scroll_h > MAX_SCROLL_HEIGHT:
                    print(f"  {name}: WARN scrollHeight={scroll_h}px > {MAX_SCROLL_HEIGHT}px — page 可能有 list render 太多,建議先 fix page 再 audit (e.g. 加 pagination / slice(0, 12))")
                    continue
                path = f"{OUT}/{name}.png"
                await page.screenshot(path=path, full_page=True)
                body_width = await page.evaluate("document.body.scrollWidth")
                overflow = body_width > 390
                print(f"  {name}: body_width={body_width}px, scrollHeight={scroll_h}px, overflow={overflow} -> {path}")
            except Exception as e:
                print(f"  {name}: ERROR {e}")
        await browser.close()

asyncio.run(main())
