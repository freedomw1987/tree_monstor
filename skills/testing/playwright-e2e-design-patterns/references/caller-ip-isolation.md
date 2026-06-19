# Caller IP isolation for E2E — full rationale

## 點解要用 `127.0.0.<n>` 而唔係其他 form

| IP form | 撞 backend rate limit? | 撞內部 routing? | Verdict |
|---------|----------------------|----------------|---------|
| `127.0.0.<n>` (n in 1-254) | ❌ 唔撞(每個 caller 獨立 bucket) | ❌ 唔撞(localhost) | ✅ **推薦** |
| `::1` / IPv6 | ⚠️ Depends on backend | ❌ 唔撞 | ❌ Backend 普遍只睇 x-forwarded-for (IPv4) |
| `localhost` | ✅ 撞(hostname 唔 split) | ❌ 唔撞 | ❌ 全部 caller 同 bucket |
| 真實 public IP | ❌ 唔撞 | ⚠️ May hit external | ❌ E2E 唔應該 leak 真實 IP |
| `:0` random port | ❌ 唔撞 | ⚠️ Docker network 唔識 | ❌ Overkill |

**`127.0.0.<n>` 完勝** —— 完全 localhost,完全 IPv4,完全可控,254 個 unique bucket 夠用。

## 點解 stable hash 而唔用 `Date.now()`

```typescript
// ❌ Bad: Date.now() 唔 stable
function ipSuffixForTest(testTitle: string): number {
  return (Date.now() % 200) + 1
}

// ✅ Good: stable per test title
function ipSuffixForTest(testTitle: string): number {
  let h = 0
  for (let i = 0; i < testTitle.length; i++) {
    h = (h * 31 + testTitle.charCodeAt(i)) | 0
  }
  return (Math.abs(h) % 200) + 1
}
```

**Use cases for stability**:
1. **Retry** — Playwright `retries: 2` 喺 CI 環境會重跑,穩定 hash 確保 retry 撞同一個 IP,backend bucket 累計計得通(假設同一個 test 失敗 → retry → 失敗訊息一致)
2. **Debugging** — 睇 backend log 知道「IP 127.0.0.42 對應 test `developer cannot create project`」,直搗黃龍
3. **Snapshot test** — 如果將來做 rate limit invariant snapshot,stable IP 確保 snapshot 唔 flake

**Counter-argument 點解唔用 UUID v4 hash**:
- 200 個 bucket 對大多數 suite 夠用
- UUID hash 撞 200 buckets 機率比 stable string hash 高(test title 短 string,collisions controlled)

## 200 個 bucket 嘅 collision rate

`n = 200`, `tests = 17`:撞機率 ~ 0
`n = 200`, `tests = 100`:撞機率 ~ 11% (Birthday paradox)
`n = 200`, `tests = 200`:撞機率 ~ 50%

**如果 suite > 100 tests → 加 bucket size**:
```typescript
return (Math.abs(h) % 1000) + 1   // 1000 buckets
```

但要 check backend 嘅 rate limit window + bucket size(eg. 60s × 5 attempts = 300 個 test 可撞)。

## Hash function 點解用 `h * 31`

Java String `hashCode()` 標準做法:
- 質數 31 → 撞 collision 機率低
- `| 0` 確保 32-bit int(避免 bit overflow 變 weird negative)

`for (let i = 0; i < str.length; i++) { h = (h * 31 + str.charCodeAt(i)) | 0 }`

可以用其他 hash(djb2, fnv-1a),呢個夠用。

## 點解唔將 IP suffix derive 放 `beforeAll`

`beforeAll` 喺 file 級別跑一次,**冇 `testInfo`**,要自己 derive:
```typescript
test.describe('RBAC negative', () => {
  test.beforeAll(async ({ request }) => {
    const fileIp = `127.0.0.${ipSuffixForTest('RBAC negative')}`
    // 用呢個 IP 預先 warm up ...
  })
})
```

**唔建議** — 將 file 級 IP 同 test 級 IP 混,debug 難。除非真有需要(eg. file 級 setup 要建 shared resource),否則全部 per-test IP 就夠。

## 點解唔喺 `page.context()` 加 `extraHTTPHeaders`

Playwright 提供 `context.setExtraHTTPHeaders()`:
```typescript
test.beforeEach(async ({ page }) => {
  await page.context().setExtraHTTPHeaders({ 'X-Forwarded-For': '127.0.0.99' })
})
```

**唔建議**:
- 唔可以 per-test 唔同 IP(同一個 context)
- 影響所有 request(連 frontend 嘅 static asset 都加 header,可能 backend routing 撞)
- helper 注入係更 localized 嘅做法

## 點解唔喺 backend 改 rate-limit 設計

Backend IP-based rate limit **係 intended behavior**,production 必備。E2E 設計應該**配合**而唔係**避開**。
