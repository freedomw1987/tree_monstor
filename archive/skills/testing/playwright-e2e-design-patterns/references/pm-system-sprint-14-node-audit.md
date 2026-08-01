# pm-system Sprint 14 Node audit case history

## Pattern 11: Node Playwright audit script for SPA auth (2026-06-10 pm-system)

### 問題

`rwd-mobile-audit` skill 推薦用 Python Playwright 跑 SPA screenshot audit。但 **Python 環境 vs Node 環境** 撞過:

| Environment | 撞過嘅 issue |
|---|---|
| Python (`/usr/local/bin/python3`) | `pip install playwright` 撞 PEP 668;`playwright install` 又 install 錯 chromium 版本(頭撞 `chromium-1155`,實際 system 已經有 `chromium-1223`)|
| Node (`e2e/node_modules`) | 已有 `chromium-1223` install,直接 `import { chromium } from 'playwright'` work |

**Recommendation**:**用 Node 而非 Python** (如果 project 已經有 `e2e/` 嘅 Playwright install)。直接 reuse 個 e2e setup。

### 完整 Node script(Sprint 14 嘅 rwd-audit-s14.mjs 簡化版)

```javascript
// /tmp/rwd_audit.mjs
import { chromium } from 'playwright'  // 用 project 嘅 e2e/node_modules
import { promises as fs } from 'fs'

const OUT = '/tmp/rwd_audit_s14'
await fs.mkdir(OUT, { recursive: true })

const PAGES = [
  ['dashboard', 'http://localhost:8080/'],
  ['projects', 'http://localhost:8080/projects'],
]

const browser = await chromium.launch()
const ctx = await browser.new_context({
  viewport: { width: 390, height: 844 },
  isMobile: true, hasTouch: true,
})
const page = await ctx.new_page()

// Step 1: 喺 /login 攞 token
await page.goto('http://localhost:8080/login', { waitUntil: 'networkidle' })
const loginResult = await page.evaluate(async () => {  // ← 函數 literal, 唔用 template literal!
  const res = await fetch('http://localhost:4001/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': '127.0.0.1' },
    body: JSON.stringify({ email: 'admin@test.com', password: 'admin123' })
  })
  if (!res.ok) return { error: 'login failed', status: res.status }
  return await res.json()  // ← 必須 return, 否則 evaluate 返 undefined
})
if (loginResult.error) { console.error(loginResult); process.exit(1) }

// Step 2: Inject localStorage
await page.evaluate((t) => {
  localStorage.setItem('accessToken', t)
  localStorage.setItem('refreshToken', 'rwd-audit-refresh')
  localStorage.setItem('user', JSON.stringify({ id: 'admin', name: '系統管理員', email: 'admin@test.com', role: 'admin' }))
}, loginResult.accessToken)

// Step 3: Audit each page
const results = []
for (const [name, url] of PAGES) {
  await page.goto(url, { waitUntil: 'networkidle' })
  await page.waitFor_timeout(500)
  const scrollH = await page.evaluate('document.body.scrollHeight')
  if (scrollH > 8000) {  // ← Pre-check 避免爆 100k px
    console.log(`  ${name}: WARN scrollH=${scrollH}px > 8000px, skip screenshot`)
    continue
  }
  await page.screenshot({ path: `${OUT}/${name}.png`, fullPage: true })
  const bodyW = await page.evaluate('document.body.scrollWidth')
  results.push({ name, url, scrollH, bodyW, overflow: bodyW > 390 })
}
await browser.close()
await fs.writeFile(`${OUT}/summary.json`, JSON.stringify(results, null, 2))
```

**3 個 critical syntax**:
1. **`await page.evaluate(async () => {...})`** — 函數 literal, 唔好用 `` `async () => {}` `` template literal (會 return undefined)
2. **Step 2 evaluate 帶 argument**:`evaluate((t) => {...}, loginResult.accessToken)` — 第二個 arg 係 serialize 入 page context
3. **Pre-check scrollHeight** — 避免 fullPage screenshot 爆

### 從 project root 跑 vs 從 `e2e/` 跑

**Pitfall**:從 `pm-system/` cwd 跑 `npx playwright test` 撞 root `package.json` 冇 playwright 嘅問題 → npm 自動 install 或者搵到舊 version → conflict。**Rule**:**從 `e2e/` cwd 跑所有 Playwright command**:
```bash
cd /Users/davidchu/Sites/localhost/pm-system/e2e
node rwd-audit-s14.mjs  # 用 e2e 嘅 playwright install
npx playwright test tests/sprint14-projects-search-and-dashboard.spec.ts
```

### Delete 跑 audit 嘅 throwaway script 跑完即刪

Audit script 唔應該 commit 入 `e2e/`(test-results/ 同 playwright-report/ 已經 gitignore,但 custom audit 唔係 spec,屬於 temporary verification):
```bash
rm /Users/davidchu/Sites/localhost/pm-system/e2e/rwd-audit-s14.mjs
```

如果想 keep,擺去 `e2e/scripts/`(sub-dir)或者 `/tmp/`(global temp)— 唔好擺去 `e2e/tests/`(會被 Playwright 當 spec 跑)。
