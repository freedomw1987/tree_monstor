---
name: playwright-node-api-container
description: |
  使用 Node.js Playwright API 在 container/VM 環境中截圖和自動化測試。
  適用於需要登入後才能截圖的頁面（CLI screenshot 無法做到）。
trigger: |
  需要截圖登入後的頁面，或需要自動化測試一個需要 session 的 web app
  （例如：截圖 dashboard、截圖已登入的會員頁面）
---

Last-verified: 2026-07-28
# Playwright Node API 在 Container/VM 環境使用

## Troubleshooting
- **Navigation Timeout**: If you encounter a timeout error waiting for a page to load after login, increase the `await page.waitForURL()` timeout parameter to accommodate possible delays.
- **Verifying Credentials**: Ensure that the correct login credentials are being used. Verify by checking network logs and responses in the browser's dev tools for any login flow issues.


## 問題
- CLI `playwright screenshot` 只能截圖公開頁面，無法處理登入 flow
- Node API 可以執行完整的自動化流程（登入→跳轉→截圖）
- 但在 container/VM 環境中，直接 `require('playwright')` 會 MODULE_NOT_FOUND
- Chromium 在無 X server 環境需要 `--no-sandbox`

## 解決方案

### 找 playwright 模組位置
```bash
find /home/ubuntu -name "playwright" -type d 2>/dev/null | head -5
# 常見路徑：/home/ubuntu/.npm-global/lib/node_modules/playwright
```

### 執行時指定 NODE_PATH
```bash
NODE_PATH=/home/ubuntu/.npm-global/lib/node_modules node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox', '--disable-dev-shm-usage'] });
  const page = await browser.newPage();
  
  // 登入 flow
  await page.goto('https://example.com/login');
  await page.fill('input[type=\"email\"]', 'user@example.com');
  await page.fill('input[type=\"password\"]', 'password');
  await page.click('button[type=\"submit\"]');
  await page.waitForURL('**/dashboard', { timeout: 10000 });
  
  // 截圖
  await page.screenshot({ path: '/tmp/dashboard.png', fullPage: true });
  
  await browser.close();
})();
"
```

### 常用 Chromium launch options（container/VM 必備）
```javascript
chromium.launch({
  args: [
    '--no-sandbox',           // 禁用 sandbox（root 或 container 環境必須）
    '--disable-dev-shm-usage', // 避免 /dev/shm 空間不足導致崩潰
    '--disable-gpu'           // 無 GPU 環境
  ]
})
```

### 捕獲 Console Errors
```javascript
const errors = [];
page.on('console', msg => {
  if (msg.type() === 'error') errors.push(msg.text());
});
// 测试结束后检查
if (errors.length) console.log('JS Errors:', errors);
```

### 常用操作
```javascript
// 填表單
await page.fill('input[type="email"]', 'user@example.com');
await page.click('button[type="submit"]');

// 等待跳轉
await page.waitForURL('**/dashboard', { timeout: 10000 });

// 等待網絡空閒（適用於 SPA）
await page.waitForLoadState('networkidle');

// 滾動截圖
await page.screenshot({ path: '/tmp/page.png', fullPage: true });
```

## 常見錯誤

| 錯誤 | 原因 | 解決 |
|------|------|------|
| `MODULE_NOT_FOUND: playwright` | NODE_PATH 未設定 | `NODE_PATH=/home/ubuntu/.npm-global/lib/node_modules` |
| `Chrome exited early... No usable sandbox` | 容器環境需要 no-sandbox | `args: ['--no-sandbox']` |
| `/dev/shm` 空間不足 | Docker 預設 /dev/shm 只有 64MB | `args: ['--disable-dev-shm-usage']` |

## 截圖多個頁面（完整流程）
```javascript
NODE_PATH=/home/ubuntu/.npm-global/lib/node_modules node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox', '--disable-dev-shm-usage'] });
  const page = await browser.newPage();
  const errors = [];
  page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });

  await page.goto('https://example.com/login');
  await page.fill('[type=email]', 'user@example.com');
  await page.fill('[type=password]', 'pass');
  await page.click('[type=submit]');
  await page.waitForURL('**/dashboard', { timeout: 10000 });
  await page.screenshot({ path: '/tmp/01_dashboard.png', fullPage: true });

  await page.reload();
  await page.waitForURL('**/dashboard', { timeout: 5000 });
  await page.screenshot({ path: '/tmp/02_reload.png', fullPage: true });

  console.log(errors.length ? 'JS Errors: ' + errors.join(', ') : '✅ No JS errors');
  await browser.close();
})();
"
```
