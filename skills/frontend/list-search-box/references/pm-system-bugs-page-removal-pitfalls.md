# PM-System — 拎走 `/bugs` standalone page 撞過嘅 pitfall

> 來源: pm-system 2026-06-09 (`BugsPage` / `BugDetailPage` / `/bugs` route)。由 `skills/frontend/list-search-box/SKILL.md` pitfall #3 / #4 移出嘅實例 narrative;class-level rule 留喺 SKILL.md。

### 🚨 3. 拎走 standalone page 漏 back-link(BugDetailPage back-link 仲指 `/bugs`)

```tsx
// ❌ 拎走 /bugs route 但 BugDetailPage back-link 仲指 /bugs
<Link to="/bugs">返回缺陷列表</Link>

// ✅ 改去 /my-bugs (或者 user-contextual destination)
<Link to="/my-bugs">返回缺陷列表</Link>
```

**Symptom**: 用戶喺「我的缺陷」click row 入 detail, 「返回」掣 click 落到 blank dashboard (因為 `/bugs` 唔再存在, react-router fallback 返 `/`)。
**Fix**: 拎走 route 之後 5 分鐘 grep audit:
```bash
grep -rn "/x\b" frontend/src/pages/XDetailPage.tsx
```

### 🚨 4. E2E test 拎走 feature 之後唔 skip(red line 12 違規)

```bash
# ❌ 拎走 /bugs route, 但 E2E test 仲 reference
await page.goto(`${FRONTEND}/bugs`)  # break
```

**Symptom**: CI run 之後 test fail, 但**冇人理**因為 feature 已 retire。
**Fix**:
- 用 `test.skip` + deprecation comment 標住
- 同時更新 `docs/QA-TRACKER.md`(紅線 11) + `docs/PRD.md` 標 US DEPRECATED
- **唔好默默 delete test** — 留 audit trail, 等 David 確認 feature 真係 retire
