# pm-system tracker-divergence case history

## Pattern 9: Implementation 與 tracker 計劃出現分歧時嘅 spec 重對齊(2026-06-10 pm-system US-5.6)

### 問題

E2E 寫嘅時候撞咗「tracker 講過會有 X,但 implementation 唔係 X」嘅情況。撞過(pm-system 2026-06-10 US-5.6 Project detail bug tab):
- **Tracker 講**:Bugs list 嘅 status / severity 篩選係 **server-side**(plan 寫住 `?status=OPEN&severity=BUG`)
- **Implementation 係**:`<ProjectDetailPage>` 嘅 bug tab 用 `useState + useMemo` 喺 client-side filter,backend 冇 `?status=...` query support
- **3 個錯誤應對**(都要避免):
  1. **❌ 盲從 tracker** — 寫 spec 用 `?status=OPEN&severity=BUG` query,backend 唔認得 → test 永遠 fail
  2. **❌ 反轉 implementation** — 為咗對齊 tracker plan 就改 backend 加 server-side filter
  3. **❌ Skip test** — `describe.skip` 標 DIVERGED,等下個 sprint 再處理

### ✅ 正確做法:Update spec to match reality + inline comment 解釋

```typescript
// ✅ OK: Test 對齊 actual implementation(用 client-side filter),
// 同時 inline 註解講點解同 tracker plan 唔同
test('US-5.6: project bug tab filters by status client-side', async ({ page }) => {
  // Note (2026-06-10): tracker planned server-side filter via
  // `?status=OPEN&severity=BUG`, but `<ProjectDetailPage>` actually
  // uses client-side `useMemo` filter (see ProjectDetailPage.tsx#L210-218).
  // Server-side filter is a future improvement (T-XX). E2E verifies
  // the current client-side behavior; the spec is the contract.
  await page.goto(`/projects/${projId}/bugs?status=OPEN`)
  // Click OPEN status filter button
  await page.getByRole('button', { name: 'Open', exact: true }).click()
  // Assert: only OPEN bugs visible
  const rows = page.getByTestId('bug-row')
  await expect(rows).toHaveCount(2)
  for (const row of await rows.all()) {
    await expect(row).toContainText('OPEN')
  }
})
```

**點解**:
1. **Test 係 spec,唔係 plan** — 個 US 嘅 expected behavior 由 spec 表達,唔由 plan 規定
2. **Implementation = ground truth** — Plan 係 intention;implementation 係 deployed reality
3. **Divergence 必須文件化** — Inline comment 寫住 (a) 邊日發現,(b) tracker 點講,(c) implementation 點做,(d) 將來點 reconcile
4. **唔好 hardcode 期待 server-side behavior** — 將來如果 backend 真係加 `?status=`,spec 要 update

### 配套 checklist(任何「tracker plan 講 X 但 implementation 做 Y」撞到時)

- [ ] `git grep <X-feature>` 確認 implementation 真係做 Y
- [ ] 寫 1-line inline comment 解釋 divergence(日子、tracker ref、implementation 嘅 source 位置)
- [ ] Spec assert implementation 而唔係 plan
- [ ] (Optional) 開新 T-XX follow-up 入 `docs/QA-TRACKER.md`「Plan 對齊 sprint」標 PARTIAL,等下個 sprint 處理
- [ ] (Optional) Patch plan doc 標 divergence(例:`docs/PRD.md` US-5.6 改個 status 標 ⏸️ deferred)

**Anti-patterns**(要避免):

| Anti-pattern | 點解 NG |
|---|---|
| Skip test with TODO | Spec 失 cover,user 唔知呢個 behavior 係 work 定 broken |
| 為咗 spec pass 反轉 implementation | Implementation 為 product/user 設計,test 唔應該 override product decision |
| 改 tracker 扮冇分歧 | 文件失真,將來再睇會誤導 |
| 寫 spec 同時 assert 兩種 behavior | Race condition + 將來一邊 implement 改咗,spec 兩邊都會 fail |

### 點解唔用 Step 5 「A/B/C failure class」處理

Step 5 處理**失敗**嘅 case(tracker 同 implementation 對齊但 test 仲 fail)。Pattern 9 處理**冇失敗**嘅 case(tracker 同 implementation 唔對齊但 implementation 正常)— 兩者唔同。**呢個 pattern 屬於「寫 spec 嘅時候」唔係「triage failure 嘅時候」**。

---

