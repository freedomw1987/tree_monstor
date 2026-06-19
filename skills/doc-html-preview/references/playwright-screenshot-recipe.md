# Playwright screenshot recipe (2026-06-09 pm-system USER-MANUAL)

> **When to use this**: building USER-MANUAL / ONBOARDING / walkthrough
> docs that need 20+ page screenshots. This is the recipe that produced
> 26 screenshots in one Playwright run for pm-system. The bundled
> HTML's "9-point boss-audit" reference is for the viewer; this
> reference is for the **content** (the screenshots themselves).

## Pattern summary (1-minute version)

```javascript
// e2e/screenshot-manual.js
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const OUT = path.resolve(__dirname, '../docs/screenshots');
const BASE = 'http://localhost:8080';  // frontend :8080 (nginx) preferred over direct :4001
const PAGES = [
  ['01-login',          '/login',                          '登入頁'],
  ['02-dashboard',      '/',                               '儀表板'],
  ['03-projects',       '/projects',                       '項目列表'],
  // ... 20 entries
];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    locale: 'zh-TW',  // <-- ensures 正體中文 labels render correctly
  });
  const page = await ctx.newPage();
  // 1. login (form submit)
  await page.goto(`${BASE}/login`);
  await page.fill('input[type="email"]', 'admin@test.com');
  await page.fill('input[type="password"]', 'admin123');
  await page.click('button[type="submit"]');
  await page.waitForURL((u) => !u.pathname.startsWith('/login'));
  await page.waitForLoadState('networkidle');
  // 2. shoot each page
  for (const [name, route, desc] of PAGES) {
    await page.goto(`${BASE}${route}`, { waitUntil: 'domcontentloaded' });
    try { await page.waitForLoadState('networkidle', { timeout: 5000 }); } catch {}
    await page.waitForTimeout(800);  // settle animations
    await page.screenshot({ path: `${OUT}/${name}.png` });
  }
  await browser.close();
})();
```

## 7 Pitfalls (each one cost ≥ 1 round-trip in pm-system 2026-06-09)

### Pitfall 1: Project's playwright already in `e2e/node_modules/`

**Symptom**: `npm install playwright` 撞 `ENOENT` 喺 frontend dir。

**Fix**: use `e2e/node_modules/playwright` if it exists. pm-system + crm-system both ship it from earlier `playwright install` runs. From script directory:
```bash
cd ~/www/<project>/e2e && node ../e2e/screenshot-manual.js
# or
cd ~/www/<project>/e2e && node screenshot-manual.js  # if script is INSIDE e2e
```

If `e2e/node_modules` has no `playwright`, run `npm install playwright` inside `e2e/` (not frontend). Frontend doesn't need it.

### Pitfall 2: First run needs `npx playwright install chromium`

`~/.cache/ms-playwright/` may have **multiple chromium versions** (1155, 1223, etc.) from past installs. The script auto-selects the right one via `package.json` engines. If you see:
```
browserType.launch: Executable doesn't exist at .../chromium-XXXX/...
```
run from the dir that has playwright: `npx playwright install chromium`. ~30s for fresh download, instant on warm cache.

### Pitfall 3: Standalone pages (e.g. `AgentMonitorPage.tsx`) may have NO `<Route>` registered

**Symptom**: `01-agent-monitor.png` 5 KB, blank. The page source file exists but `App.tsx` never imports it.

**Detection BEFORE writing the script**:
```bash
# 1. Pages that exist as source
ls frontend/src/pages/*.tsx
# 2. Pages actually routed
grep -E "<Route" frontend/src/App.tsx
# 3. Diff
diff <(ls frontend/src/pages/ | sed 's/.tsx//;s/Page$//') <(grep -E "import .*Page from" frontend/src/App.tsx | sed -E 's/import ([A-Za-z]+)Page.*/\1/')
```

pm-system 2026-06-09: `AgentMonitorPage.tsx` 存在但 `App.tsx` 冇 register。改截項目入面嘅「Agent 任務」tab (ProjectDetailPage 個 agents sub-tab)。

### Pitfall 4: Sub-tabs in detail pages use local `useState`, not URL params

**Symptom**: navigate to `/projects/<id>?tab=tasks` 顯示需求 tab（default），唔係任務。

**Fix**: Click the tab button via Playwright `locator`:
```javascript
const tasksTab = page.locator('button').filter({ hasText: /^任務\s*\(/ }).first();
await tasksTab.click();
await page.waitForTimeout(800);
```

OR pass a hash fragment + add a small `useEffect` that reads `location.hash` and sets `activeTab`. Don't try to URL-encode tab state when the source doesn't support it.

### Pitfall 5: Modals need explicit button click, then `waitForTimeout`

**Symptom**: `21-create-project-modal.png` shows the page, not the modal. The "+" button locator matched a different element (e.g. a sidebar icon).

**Fix**: filter button text more precisely:
```javascript
const createBtn = page.locator('button').filter({
  hasText: /^(新增|新建|建立|創建|Add|Create|New).*$/  // strict start-of-string
}).first();
```

After click, `await page.waitForTimeout(500)` for modal animation. Then screenshot. Then `await page.keyboard.press('Escape')` to close before next page.

### Pitfall 6: 5 KB screenshots = blank/redirect — re-shoot, don't ship

**Detection**:
```bash
# List blank screenshots
ls -la docs/screenshots/*.png | awk '$5<10000 {print}'
```

**Likely causes**:
- Page 404 (route doesn't exist → see Pitfall 3)
- Auth redirect (token expired between pages, re-login)
- Modal didn't open (Pitfall 5)
- Page renders SSR-only content that needs JS hydration time

**Fix**: targeted re-shoot script (see `e2e/reshoot-wiki.js` from pm-system):
```javascript
// Reshoot just the missing page
await page.goto(`${BASE}/projects/${PROJECT_ID}`);
await page.waitForLoadState('networkidle');
// Find the specific button by exact text
const btn = page.locator('button').filter({ hasText: /^(建立第一頁|新建頁面)$/ }).first();
await btn.click();
await page.waitForTimeout(1000);
await page.screenshot({ path: 'docs/screenshots/23-wiki-editor.png' });
```

### Pitfall 7: Seed data has dup records → URL IDs drift between runs

**Symptom**: 第一次跑 screenshot 成功，第二次 seed script 報「already exists」check 失敗，skip create，但 `req.get(...).get('projects', [])` list endpoint 包裹多咗層（`'projects': [...]` vs `[...]`），list 變空，新 `pid = resp['id']` 又撞 dup。

**Fix**: 每次跑 screenshot 之前先 `python3 -c "import urllib.request, json; print(json.loads(urllib.request.urlopen(urllib.request.Request('http://localhost:4001/api/projects', headers={'Authorization': 'Bearer <TOKEN>'})).read())['projects'][0]['id'])"` 攞當下嘅 project ID，再 hardcode 入 script。**Hardcode IDs as constants** at top of file:
```javascript
const PROJECT_ID = 'bfba6607-c843-449c-97a4-75815e5f483c';  // <-- paste from API output
const REQ_ID     = 'ae85bc2c-de5a-4c8d-b1e1-dae1f8ff8fb9';
const TASK_ID    = '27e47044-2cbe-42a8-9dc8-77a86de1b191';
```

## Seed data recipe

```python
# /tmp/seed_manual.py
import urllib.request, json
from datetime import datetime, timedelta, timezone

BASE = "http://localhost:4001"
H = {"Authorization": "Bearer <admin_token>", "Content-Type": "application/json"}

def req(m, p, b=None):
    d = json.dumps(b).encode() if b else None
    r = urllib.request.Request(f"{BASE}{p}", data=d, method=m, headers=H)
    return json.loads(urllib.request.urlopen(r).read())

# Find or create project
projects = req("GET", "/api/projects")["projects"]
demo = [p for p in projects if p["name"] == "示範項目 - 客戶管理系統"]
pid = demo[0]["id"] if demo else req("POST", "/api/projects", {...})["project"]["id"]

# Add requirement/task/bug/worklog (handle response wrap: .get('requirement', r))
```

**Critical**: response shape is `{project: {...}}` not bare `{...}`. Always use `.get('entity', r)['id']` to be safe.

## Verification checklist (before committing screenshots)

```bash
# 1. All 26+ files present
ls docs/screenshots/ | wc -l   # → 26 (or expected count)

# 2. No blank (5 KB) screenshots
ls -la docs/screenshots/*.png | awk '$5<10000 {print "BLANK:", $NF}'

# 3. .gitignore allows screenshots folder
grep -E "screenshots/\*\.png" .gitignore   # → !docs/screenshots/*.png

# 4. MD file references match file names
# (spot check: pick 3 MD image refs, verify each PNG exists)
```

## Stack notes

- **Playwright 1.60+** supports `locale: 'zh-TW'` natively (no need for system font install).
- **headless: true** + 1440x900 viewport = consistent across CI and local.
- **`waitForLoadState('networkidle', { timeout: 5000 })` with try/catch** is the right pattern — pages with WebSocket connections (agent monitor, chat) never reach networkidle, so the try/catch is the only sane default.
- **`page.waitForTimeout(800)`** is acceptable for animation settle. Don't replace with arbitrary sleep — 800 ms is the empirical sweet spot for React + Tailwind.
