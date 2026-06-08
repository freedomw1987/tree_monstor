#!/usr/bin/env python3
"""RWD audit: take screenshots of all pages at iPhone 14 viewport (390x844)."""
import asyncio
from playwright.async_api import async_playwright
import os

OUT = "/tmp/rwd_audit"
os.makedirs(OUT, exist_ok=True)

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
                path = f"{OUT}/{name}.png"
                await page.screenshot(path=path, full_page=True)
                body_width = await page.evaluate("document.body.scrollWidth")
                overflow = body_width > 390
                print(f"  {name}: body_width={body_width}px, overflow={overflow} -> {path}")
            except Exception as e:
                print(f"  {name}: ERROR {e}")
        await browser.close()

asyncio.run(main())
